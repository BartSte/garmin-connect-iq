import Toybox.Activity;
import Toybox.Application;
import Toybox.Attention;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

const TOP_ROW_HEIGHT_PCT = 20;
const POWER_ROW_HEIGHT_PCT = 40;
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

    hidden var mPowerBuf as Array<Number> = [0, 0, 0];
    hidden var mPowerIdx as Number = 0;
    hidden var mPowerCount as Number = 0;
    hidden var m3sPower as Number = 0;
    hidden var mHasPower as Boolean = false;
    hidden var m30sAverage as IntervalPowerAverage = new IntervalPowerAverage(30);
    hidden var m30sPower as Number = 0;
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

        var result = IntervalWorkoutLogic.applyTap(mState, mSettings, mTimerRunning);
        mState = result[:state];
        mSessionLocked = result[:sessionLocked];

        if (result[:started]) {
            mLastTimerMs = mTimerMs;
        } else if (result[:cancelled]) {
            if (mPendingSettingsDirty) {
                mSettingsDirty = true;
            }
            mPendingSettingsDirty = false;
            maybeReloadSettings();
            syncIdlePhase();
        }

        WatchUi.requestUpdate();
        return true;
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    function onTimerReset() as Void {
        mTimerMs = 0;
        mLastTimerMs = 0;
        mTimerRunning = false;
        mSessionLocked = false;
        mSettingsDirty = true;
        mPendingSettingsDirty = false;
        maybeReloadSettings();
        syncIdlePhase();
    }

    function onTimerStart() as Void {
        mTimerRunning = true;
    }

    function onTimerResume() as Void {
        mTimerRunning = true;
    }

    function onTimerPause() as Void {
        mTimerRunning = false;
    }

    function onTimerStop() as Void {
        mTimerRunning = false;
    }

    function compute(info as Activity.Info) as Void {
        maybeReloadSettings();

        mTimerMs = IntervalWorkoutLogic.valueToNumber(info has :timerTime ? info.timerTime : null, 0);

        updatePower(info);
        mHasCadence = (info has :currentCadence) && (info.currentCadence != null);
        mCadence = IntervalWorkoutLogic.valueToNumber(info has :currentCadence ? info.currentCadence : null, 0);

        var deltaMs = mTimerMs - mLastTimerMs;
        if (deltaMs > 0) {
            mTimerRunning = true;
        }

        if (mSessionLocked && IntervalWorkoutLogic.isTimedPhase(mState[:phase])) {
            if (deltaMs > 0) {
                var advanced = IntervalWorkoutLogic.applyElapsed(mState, mSettings, deltaMs);
                mState = advanced[:state];
                var transitions = advanced[:transitions] as Array;
                if (transitions.size() > 0) {
                    emitAlertForPhase(transitions[transitions.size() - 1]);
                }
            }
        }

        mLastTimerMs = mTimerMs;
        if (!mSessionLocked) {
            syncIdlePhase();
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var row1H = (h * TOP_ROW_HEIGHT_PCT) / 100;
        var row2H = (h * POWER_ROW_HEIGHT_PCT) / 100;
        var row3H = (h - row1H - row2H) / 2;
        var row4H = h - row1H - row2H - row3H;

        var row1Y = 0;
        var row2Y = row1H;
        var row3Y = row2Y + row2H;
        var row4Y = row3Y + row3H;

        var bg = getBackgroundColor();
        dc.setColor(bg, bg);
        dc.clear();

        var fg = defaultFgColor();
        drawRow(dc, 0, row1Y, w, row1H, fg, null,
            intervalTimeText(), IntervalWorkoutLogic.formatRideTimer(mTimerMs));
        drawPowerRow(dc, w, row2Y, row2H);
        drawTargetCadenceRow(dc, w, row3Y, row3H, fg);
        drawRow(dc, 0, row4Y, w, row4H, fg, null, setProgressText(), repProgressText());
        drawBorders(dc, w, h, row1H, row2Y + row2H, row4Y, fg);
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

    hidden function updatePower(info as Activity.Info) as Void {
        mHasPower = info has :currentPower ? (info.currentPower != null) : false;
        var rawPower = IntervalWorkoutLogic.valueToNumber(info has :currentPower ? info.currentPower : null, 0);
        var powerState = IntervalWorkoutLogic.pushPowerSample(mPowerBuf, mPowerIdx, mPowerCount, rawPower);
        mPowerBuf = powerState[:buffer];
        mPowerIdx = powerState[:nextIndex];
        mPowerCount = powerState[:sampleCount];
        m3sPower = powerState[:average];
        m30sPower = m30sAverage.push(rawPower);
    }

    hidden function powerText(power as Number) as String {
        return mHasPower ? power.format("%d") : "--";
    }

    hidden function intervalTimeText() as String {
        if (mState[:phase] == INTERVAL_PHASE_READY) {
            return mTimerRunning ? "TAP" : "START";
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

    hidden function currentTargetZone() as Number or Null {
        if (!mSettings[:valid]) {
            return null;
        }
        return IntervalWorkoutLogic.targetZoneForPhase(mSettings, mState[:phase]);
    }

    hidden function setProgressText() as String {
        if ((mState[:phase] == INTERVAL_PHASE_COMPLETE) || (mState[:phase] == INTERVAL_PHASE_INVALID)) {
            return "";
        }
        if (mSettings[:setCount] <= 1) {
            return "";
        }
        return IntervalWorkoutLogic.formatProgress(mState[:currentSet], mSettings[:setCount]);
    }

    hidden function repProgressText() as String {
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
        if (phase == INTERVAL_PHASE_WORK) {
            text = "WORK " + IntervalWorkoutLogic.zoneLabel(mSettings[:workZone]);
        } else if (phase == INTERVAL_PHASE_RECOVERY) {
            text = "RECOVERY " + IntervalWorkoutLogic.zoneLabel(mSettings[:recoveryZone]);
        } else if (phase == INTERVAL_PHASE_SET_RECOVERY) {
            text = "SET REC " + IntervalWorkoutLogic.zoneLabel(mSettings[:setRecoveryZone]);
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

    hidden function cadenceText() as String {
        return mHasCadence ? mCadence.format("%d") : "--";
    }

    // Match the Minimal-7 power row: long average on the left, 3s power on the right.
    hidden function drawPowerRow(dc as Graphics.Dc, w as Number, y as Number, h as Number) as Void {
        var half = w / 2;
        var avgColors = IntervalWorkoutLogic.actualPowerColors(
            m30sPower, mSettings[:ftp], mHasPower
        );
        var currentColors = IntervalWorkoutLogic.actualPowerColors(
            m3sPower, mSettings[:ftp], mHasPower
        );
        drawCell(dc, 0, y, half, h, avgColors[:foreground], avgColors[:background],
            powerText(m30sPower), powerFonts());
        drawCell(dc, half, y, w - half, h, currentColors[:foreground], currentColors[:background],
            powerText(m3sPower), powerFonts());
    }

    // The right-hand cadence cell stays in its Minimal-7 position.
    hidden function drawTargetCadenceRow(
        dc as Graphics.Dc, w as Number, y as Number, h as Number, fg as Number
    ) as Void {
        var half = w / 2;
        var targetZone = currentTargetZone();
        if (targetZone == null) {
            drawCell(dc, 0, y, half, h, fg, null, "", standardFonts());
        } else {
            var zone = targetZone as Number;
            drawCell(dc, 0, y, half, h, IntervalWorkoutLogic.zoneTextColor(zone),
                IntervalWorkoutLogic.zoneColor(zone), IntervalWorkoutLogic.zoneLabel(zone),
                standardFonts());
        }
        var cadenceColors = IntervalWorkoutLogic.cadenceColors(
            mCadence, mHasCadence, mCadenceMin, mCadenceMax, fg
        );
        drawCell(dc, half, y, w - half, h, cadenceColors[:foreground], cadenceColors[:background],
            cadenceText(), standardFonts());
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
        dc.drawLine(mid, row1H, mid, row3Y);
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
