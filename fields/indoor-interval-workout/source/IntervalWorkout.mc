import Toybox.Activity;
import Toybox.Application;
import Toybox.Attention;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

const TOP_ROW_HEIGHT_PCT = 15;
const POWER_ROW_HEIGHT_PCT = 35;
const BORDER_PADDING = 4;
const TEXT_PADDING = 6;

class IntervalAlertView extends WatchUi.DataFieldAlert {

    hidden var mText as String;

    function initialize(text as String) {
        DataFieldAlert.initialize();
        mText = text;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            dc.getWidth() / 2,
            dc.getHeight() / 2,
            Graphics.FONT_MEDIUM,
            mText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }
}

class IntervalWorkout extends WatchUi.DataField {

    hidden var mSettings as Dictionary = IntervalWorkoutLogic.defaultSettings();
    hidden var mState as Dictionary = IntervalWorkoutLogic.defaultSessionState();
    hidden var mTimerMs as Number = 0;
    hidden var mLastTimerMs as Number = 0;
    hidden var mTimerRunning as Boolean = false;
    hidden var mSessionLocked as Boolean = false;
    hidden var mSettingsDirty as Boolean = true;
    hidden var mPendingSettingsDirty as Boolean = false;
    hidden var mTrainerControlAllowed as Boolean = false;
    hidden var mTrainerBlocked as Boolean = false;
    hidden var mIntensity as Number = INTERVAL_DEFAULT_INTENSITY;
    hidden var mFieldWidth as Number = 0;
    hidden var mFieldHeight as Number = 0;
    hidden var mTrainer as IndoorTrainerController = new IndoorTrainerController();

    hidden var mPowerBuf as Array<Number> = [0, 0, 0];
    hidden var mPowerIdx as Number = 0;
    hidden var mPowerCount as Number = 0;
    hidden var m3sPower as Number = 0;
    hidden var mHasPower as Boolean = false;
    hidden var mCadence as Number = 0;
    hidden var mHasCadence as Boolean = false;
    hidden var mCadenceMin as Number = INTERVAL_DEFAULT_CADENCE_MIN;
    hidden var mCadenceMax as Number = INTERVAL_DEFAULT_CADENCE_MAX;

    function initialize() {
        DataField.initialize();
        loadSettings();
        mSettingsDirty = false;
        syncIdlePhase();
    }

    function handleSettingsChanged() as Void {
        mSettingsDirty = true;
        if (mSessionLocked) {
            mPendingSettingsDirty = true;
            return;
        }
        maybeReloadSettings();
        syncIdlePhase();
    }

    function handleTap() as Boolean {
        maybeReloadSettings();

        var trainerReady = false;
        if (mState[:phase] == INTERVAL_PHASE_READY) {
            trainerReady = mTrainer.canStart();
        }

        var result = IntervalWorkoutLogic.applyTap(
            mState,
            mSettings,
            mTimerRunning,
            trainerReady
        );
        mState = result[:state];
        mSessionLocked = result[:sessionLocked];

        if (result[:started]) {
            mIntensity = INTERVAL_DEFAULT_INTENSITY;
            mTrainerBlocked = false;
            mLastTimerMs = mTimerMs;
        } else if (result[:cancelled]) {
            mTrainer.release();
            finishCancellation();
        } else if (result[:blocked]) {
            mTrainerBlocked = true;
            emitTrainerUnavailableAlert();
        }

        WatchUi.requestUpdate();
        return true;
    }

    function onLayout(dc as Graphics.Dc) as Void {
        mFieldWidth = dc.getWidth();
        mFieldHeight = dc.getHeight();
    }

    function handleTouch(x as Number, y as Number) as Boolean {
        var action = IntervalWorkoutLogic.touchAction(x, y, mFieldWidth, mFieldHeight);
        if (action == INTERVAL_TOUCH_BODY) {
            return handleTap();
        }
        if (IntervalWorkoutLogic.isTimedPhase(mState[:phase])) {
            var delta = 0;
            if (action == INTERVAL_TOUCH_DECREASE) { delta = -1; }
            if (action == INTERVAL_TOUCH_INCREASE) { delta = 1; }
            if (delta != 0) {
                mIntensity = IntervalWorkoutLogic.adjustedIntensity(mIntensity, delta);
                // Apply the target immediately, including while auto-paused.
                mTrainer.update(mSettings, mState[:phase], mTrainerControlAllowed, false, mIntensity);
                WatchUi.requestUpdate();
            }
        }
        return true;
    }

    function onTimerReset() as Void {
        mTrainerControlAllowed = false;
        mTrainer.release();
        mTimerMs = 0;
        mLastTimerMs = 0;
        mTimerRunning = false;
        mTrainerBlocked = false;
        mIntensity = INTERVAL_DEFAULT_INTENSITY;
        mSessionLocked = false;
        mSettingsDirty = true;
        mPendingSettingsDirty = false;
        maybeReloadSettings();
        syncIdlePhase();
    }

    function onTimerStart() as Void {
        mTimerRunning = true;
        mTrainerControlAllowed = true;
    }

    function onTimerResume() as Void {
        mTimerRunning = true;
        mTrainerControlAllowed = true;
    }

    function onTimerPause() as Void {
        mTimerRunning = false;
    }

    function onTimerStop() as Void {
        mTimerRunning = false;
        mTrainerControlAllowed = false;
        mTrainer.release();
    }

    function releaseTrainer() as Void {
        mTrainerControlAllowed = false;
        mTrainer.shutdown();
    }

    function compute(info as Activity.Info) as Void {
        maybeReloadSettings();

        mTimerMs = IntervalWorkoutLogic.valueToNumber(info has :timerTime ? info.timerTime : null, 0);

        updatePower(info);
        mHasCadence = (info has :currentCadence) && (info.currentCadence != null);
        mCadence = IntervalWorkoutLogic.valueToNumber(info has :currentCadence ? info.currentCadence : null, 0);

        var deltaMs = mTimerMs - mLastTimerMs;
        // A final positive timer delta can arrive after Stop. The timer state
        // determines whether control is allowed; elapsed time alone does not.
        var timerState = info has :timerState ? info.timerState : null;
        if (timerState != null) {
            mTimerRunning = timerState == Activity.TIMER_STATE_ON;
            mTrainerControlAllowed = mTimerRunning || (timerState == Activity.TIMER_STATE_PAUSED);
        }

        if ((mState[:phase] == INTERVAL_PHASE_READY) && mTrainer.canStart()) {
            mTrainerBlocked = false;
        }

        var forceTrainerTarget = false;
        if (mSessionLocked && IntervalWorkoutLogic.isTimedPhase(mState[:phase])) {
            if (deltaMs > 0) {
                var startsControlledPhase = (mState[:phase] == INTERVAL_PHASE_STARTING)
                    && (deltaMs >= mState[:remainingMs]);
                if (startsControlledPhase && !mTrainer.canStart()) {
                    mState = IntervalWorkoutLogic.readyState(mSettings);
                    mSessionLocked = false;
                    mTrainer.release();
                    finishCancellation();
                    mTrainerBlocked = true;
                    emitTrainerUnavailableAlert();
                } else {
                    var advanced = IntervalWorkoutLogic.applyElapsed(mState, mSettings, deltaMs);
                    mState = advanced[:state];
                    var transitions = advanced[:transitions] as Array;
                    if (transitions.size() > 0) {
                        forceTrainerTarget = true;
                        emitAlertForPhase(transitions[transitions.size() - 1]);
                    }
                }
            }
        }

        mLastTimerMs = mTimerMs;
        if (!mSessionLocked) {
            syncIdlePhase();
        }
        mTrainer.update(
            mSettings,
            mState[:phase],
            mTrainerControlAllowed,
            forceTrainerTarget,
            mIntensity
        );
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        mFieldWidth = w;
        mFieldHeight = h;
        var row1H = (h * TOP_ROW_HEIGHT_PCT) / 100;
        var row2H = (h * POWER_ROW_HEIGHT_PCT) / 100;
        var row3H = (h * 20) / 100;
        var controlsY = (h * INTERVAL_CONTROLS_TOP_PCT) / 100;
        var row4H = controlsY - row1H - row2H - row3H;

        var row1Y = 0;
        var row2Y = row1H;
        var row3Y = row2Y + row2H;
        var row4Y = row3Y + row3H;

        var bg = getBackgroundColor();
        dc.setColor(bg, bg);
        dc.clear();

        var fg = defaultFgColor();
        var powerColors = IntervalWorkoutLogic.actualPowerColors(
            m3sPower,
            mSettings[:ftp],
            mHasPower
        );
        var targetPower = currentTargetPower();

        drawHeaderRow(dc, w, row1Y, row1H, fg);
        drawPowerRow(
            dc,
            0,
            row2Y,
            w,
            row2H,
            powerColors[:foreground],
            powerColors[:background],
            currentPowerText()
        );
        drawStatusRow(dc, 0, row3Y, w, row3H, fg, intervalTimeText(), targetPower);
        drawRow(dc, 0, row4Y, w, row4H, fg, null, setProgressText(), repProgressText());
        drawBorders(dc, w, controlsY, row1H, row2Y + row2H, row4Y, fg);
        drawIntensityControls(dc, w, controlsY, h - controlsY, fg);
    }

    hidden function maybeReloadSettings() as Void {
        if (mSettingsDirty && !mSessionLocked) {
            loadSettings();
            mSettingsDirty = false;
        }
    }

    hidden function loadSettings() as Void {
        mSettings = IntervalWorkoutSettings.load();
        var cadenceBounds = IntervalWorkoutLogic.cadenceBounds(
            Application.Properties.getValue("cadence_min"),
            Application.Properties.getValue("cadence_max")
        );
        mCadenceMin = cadenceBounds[:minimum];
        mCadenceMax = cadenceBounds[:maximum];
    }

    hidden function syncIdlePhase() as Void {
        if (!mSessionLocked) {
            mState = IntervalWorkoutLogic.readyState(mSettings);
        }
    }

    hidden function finishCancellation() as Void {
        mIntensity = INTERVAL_DEFAULT_INTENSITY;
        if (mPendingSettingsDirty) {
            mSettingsDirty = true;
        }
        mPendingSettingsDirty = false;
        maybeReloadSettings();
        syncIdlePhase();
    }

    hidden function updatePower(info as Activity.Info) as Void {
        mHasPower = info has :currentPower ? (info.currentPower != null) : false;
        var rawPower = IntervalWorkoutLogic.valueToNumber(info has :currentPower ? info.currentPower : null, 0);
        var powerState = IntervalWorkoutLogic.pushPowerSample(mPowerBuf, mPowerIdx, mPowerCount, rawPower);
        mPowerBuf = powerState[:buffer];
        mPowerIdx = powerState[:nextIndex];
        mPowerCount = powerState[:sampleCount];
        m3sPower = powerState[:average];
    }

    hidden function currentPowerText() as String {
        return mHasPower ? m3sPower.format("%d") : "--";
    }

    hidden function intervalTimeText() as String {
        if (mState[:phase] == INTERVAL_PHASE_READY) {
            if (!mTimerRunning) {
                return "START TIMER";
            }
            return mTrainerBlocked ? "NO TRAINER" : "TAP";
        }
        if (mState[:phase] == INTERVAL_PHASE_STARTING) {
            return IntervalWorkoutLogic.formatStartCountdown(mState[:remainingMs]);
        }
        if (mState[:phase] == INTERVAL_PHASE_COMPLETE) {
            return "DONE";
        }
        if (mState[:phase] == INTERVAL_PHASE_INVALID) {
            return "SET";
        }
        return IntervalWorkoutLogic.formatCountdown(mState[:remainingMs]);
    }

    hidden function currentTargetPower() as Number or Null {
        if (!mSettings[:valid]) {
            return null;
        }
        var target = IntervalWorkoutLogic.targetPowerForPhase(mSettings, mState[:phase]);
        return target == null ? null : IntervalWorkoutLogic.scaledPower(target as Number, mIntensity);
    }

    hidden function setProgressText() as String {
        if (mState[:phase] == INTERVAL_PHASE_WARMUP) { return "WARM-UP"; }
        if (mState[:phase] == INTERVAL_PHASE_COOLDOWN) { return "COOL-DOWN"; }
        if ((mState[:phase] == INTERVAL_PHASE_COMPLETE) || (mState[:phase] == INTERVAL_PHASE_INVALID)) {
            return "";
        }
        if (mSettings[:setCount] <= 1) {
            return "";
        }
        return IntervalWorkoutLogic.formatProgress(mState[:currentSet], mSettings[:setCount]);
    }

    hidden function repProgressText() as String {
        if ((mState[:phase] == INTERVAL_PHASE_WARMUP) || (mState[:phase] == INTERVAL_PHASE_COOLDOWN)) {
            return "";
        }
        if ((mState[:phase] == INTERVAL_PHASE_COMPLETE) || (mState[:phase] == INTERVAL_PHASE_INVALID)) {
            return "";
        }
        return IntervalWorkoutLogic.formatProgress(mState[:currentRep], mSettings[:repCount]);
    }

    hidden function emitAlertForPhase(phase as Number) as Void {
        if (!(WatchUi.DataField has :showAlert)) {
            playTransitionTone(phase);
            return;
        }

        var text = "";
        if (phase == INTERVAL_PHASE_WARMUP) {
            text = "WARM-UP " + adjustedPowerText(mSettings[:warmupPower]);
        } else if (phase == INTERVAL_PHASE_COOLDOWN) {
            text = "COOL-DOWN " + adjustedPowerText(mSettings[:cooldownPower]);
        } else if (phase == INTERVAL_PHASE_WORK) {
            text = "WORK " + adjustedPowerText(mSettings[:workPower]);
        } else if (phase == INTERVAL_PHASE_RECOVERY) {
            text = "RECOVERY " + adjustedPowerText(mSettings[:recoveryPower]);
        } else if (phase == INTERVAL_PHASE_SET_RECOVERY) {
            text = "SET REC " + adjustedPowerText(mSettings[:setRecoveryPower]);
        } else if (phase == INTERVAL_PHASE_COMPLETE) {
            text = "COMPLETE";
        }

        if (!text.equals("")) {
            playTransitionTone(phase);
            WatchUi.DataField.showAlert(new $.IntervalAlertView(text));
        }
    }

    hidden function playTransitionTone(phase as Number) as Void {
        if (!(Attention has :playTone)) {
            return;
        }

        if (phase == INTERVAL_PHASE_COMPLETE) {
            Attention.playTone(Attention.TONE_STOP);
        } else {
            Attention.playTone(Attention.TONE_LOUD_BEEP);
        }
    }

    hidden function emitTrainerUnavailableAlert() as Void {
        if (!(WatchUi.DataField has :showAlert)) {
            return;
        }
        WatchUi.DataField.showAlert(new $.IntervalAlertView("NO ERG TRAINER"));
    }

    hidden function targetPowerText(power as Number) as String {
        return power.format("%d") + " W";
    }

    hidden function adjustedPowerText(power as Number) as String {
        return targetPowerText(IntervalWorkoutLogic.scaledPower(power, mIntensity));
    }

    hidden function drawIntensityControls(dc as Graphics.Dc, w as Number, y as Number, h as Number, fg as Number) as Void {
        var third = w / 3;
        var rightX = (w * 2) / 3;
        var buttonColor = IntervalWorkoutLogic.isTimedPhase(mState[:phase]) ? fg : Graphics.COLOR_DK_GRAY;
        drawCell(dc, 0, y, third, h, buttonColor, null, "-", standardFonts());
        drawCell(dc, third, y, rightX - third, h, fg, null, mIntensity.format("%d") + "%", standardFonts());
        drawCell(dc, rightX, y, w - rightX, h, buttonColor, null, "+", standardFonts());
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(0, y, w - 1, y);
        dc.drawLine(0, y, 0, y + h - 1);
        dc.drawLine(w - 1, y, w - 1, y + h - 1);
        dc.drawLine(0, y + h - 1, w - 1, y + h - 1);
        dc.drawLine(third, y, third, y + h - 1);
        dc.drawLine(rightX, y, rightX, y + h - 1);
    }

    hidden function cadenceText() as String {
        return mHasCadence ? mCadence.format("%d") : "--";
    }

    hidden function drawHeaderRow(
        dc as Graphics.Dc,
        w as Number,
        y as Number,
        h as Number,
        fg as Number
    ) as Void {
        var half = w / 2;
        var colors = IntervalWorkoutLogic.cadenceColors(
            mCadence, mHasCadence, mCadenceMin, mCadenceMax, fg
        );
        drawCell(dc, 0, y, half, h, colors[:foreground], colors[:background], cadenceText(), standardFonts());
        drawCell(dc, half, y, w - half, h, fg, null, IntervalWorkoutLogic.formatRideTimer(mTimerMs), standardFonts());
    }

    hidden function drawPowerRow(
        dc as Graphics.Dc,
        x as Number,
        y as Number,
        w as Number,
        h as Number,
        fg as Number,
        bg as Number,
        text as String
    ) as Void {
        dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x + 1, y + 1, w - 2, h - 2);
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        dc.setClip(x + 1, y + 1, w - 2, h - 2);
        dc.drawText(
            x + (w / 2),
            y + (h / 2),
            fittingFont(dc, text, w - (TEXT_PADDING * 2), h - (TEXT_PADDING * 2), powerFonts()),
            text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
        dc.clearClip();
    }

    hidden function drawStatusRow(
        dc as Graphics.Dc,
        x as Number,
        y as Number,
        w as Number,
        h as Number,
        defaultFg as Number,
        statusText as String,
        targetPower as Number or Null
    ) as Void {
        var half = w / 2;
        drawCell(dc, x, y, half, h, defaultFg, null, statusText, standardFonts());

        if (targetPower == null) {
            drawCell(dc, x + half, y, w - half, h, defaultFg, null, "", standardFonts());
            return;
        }

        var power = targetPower as Number;
        var colors = IntervalWorkoutLogic.actualPowerColors(power, mSettings[:ftp], true);
        drawCell(
            dc,
            x + half,
            y,
            w - half,
            h,
            colors[:foreground],
            colors[:background],
            targetPowerText(power),
            standardFonts()
        );
    }

    hidden function drawRow(
        dc as Graphics.Dc,
        x as Number,
        y as Number,
        w as Number,
        h as Number,
        fg as Number,
        bg as Number or Null,
        leftText as String,
        rightText as String
    ) as Void {
        var half = w / 2;
        drawCell(dc, x, y, half, h, fg, bg, leftText, standardFonts());
        drawCell(dc, x + half, y, w - half, h, fg, bg, rightText, standardFonts());
    }

    hidden function drawCell(
        dc as Graphics.Dc,
        x as Number,
        y as Number,
        w as Number,
        h as Number,
        fg as Number,
        bg as Number or Null,
        text as String,
        fonts as Array<Graphics.FontDefinition>
    ) as Void {
        if (bg != null) {
            dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + 1, y + 1, w - 2, h - 2);
        }

        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        dc.setClip(x + 1, y + 1, w - 2, h - 2);
        dc.drawText(
            x + (w / 2),
            y + (h / 2),
            fittingFont(dc, text, w - (TEXT_PADDING * 2), h - (TEXT_PADDING * 2), fonts),
            text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
        dc.clearClip();
    }

    hidden function drawBorders(
        dc as Graphics.Dc,
        w as Number,
        h as Number,
        row1H as Number,
        row3Y as Number,
        row4Y as Number,
        fg as Number
    ) as Void {
        var rightX = w - 1;
        var bottomY = h - 1;
        var mid = w / 2;

        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);

        dc.drawLine(0, 0, rightX, 0);
        dc.drawLine(0, row1H, rightX, row1H);
        dc.drawLine(0, row3Y, rightX, row3Y);
        dc.drawLine(0, row4Y, rightX, row4Y);
        dc.drawLine(0, bottomY, rightX, bottomY);

        dc.drawLine(0, 0, 0, bottomY);
        dc.drawLine(rightX, 0, rightX, bottomY);

        dc.drawLine(mid, 0, mid, row1H);
        dc.drawLine(mid, row3Y, mid, row4Y);
        dc.drawLine(mid, row4Y, mid, bottomY);
    }

    hidden function defaultFgColor() as Number {
        return (getBackgroundColor() == Graphics.COLOR_BLACK) ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
    }

    hidden function standardFonts() as Array<Graphics.FontDefinition> {
        return [
            Graphics.FONT_NUMBER_MEDIUM,
            Graphics.FONT_NUMBER_MILD,
            Graphics.FONT_MEDIUM,
            Graphics.FONT_SMALL,
            Graphics.FONT_TINY
        ];
    }

    hidden function powerFonts() as Array<Graphics.FontDefinition> {
        return [
            Graphics.FONT_NUMBER_THAI_HOT,
            Graphics.FONT_NUMBER_HOT,
            Graphics.FONT_NUMBER_MEDIUM,
            Graphics.FONT_NUMBER_MILD
        ];
    }

    hidden function fittingFont(
        dc as Graphics.Dc,
        text as String,
        maxWidth as Number,
        maxHeight as Number,
        fonts as Array<Graphics.FontDefinition>
    ) as Graphics.FontDefinition {
        for (var i = 0; i < fonts.size(); i += 1) {
            var dimensions = dc.getTextDimensions(text, fonts[i]);
            if ((dimensions[0] <= maxWidth) && (dimensions[1] <= maxHeight)) {
                return fonts[i];
            }
        }
        return fonts[fonts.size() - 1];
    }
}
