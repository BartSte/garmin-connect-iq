import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Test;

(:test)
class IndoorTestTrainer extends IndoorTrainerController {
    var ready as Boolean = true;
    var controlAllowed as Boolean = false;
    var target as Number or Null = null;

    function initialize() {
        IndoorTrainerController.initialize();
    }

    function canStart() as Boolean {
        return ready;
    }

    function update(settings as Dictionary, phase as Number, allowed as Boolean, forceTarget as Boolean, intensity as Number) as Void {
        controlAllowed = allowed;
        var base = IntervalWorkoutLogic.controlledPowerForPhase(settings, phase);
        target = (allowed && (base != null)) ? IntervalWorkoutLogic.scaledPower(base as Number, intensity) : null;
    }

    function release() as Void {
        controlAllowed = false;
        target = null;
    }
}

(:test)
class IndoorTestView extends IntervalWorkout {
    function initialize(trainer as IndoorTestTrainer) {
        IntervalWorkout.initialize();
        mTrainer = trainer;
    }

    function statusText() as String {
        return intervalTimeText();
    }

    function phase() as Number {
        return mState[:phase];
    }

    function configurePhases() as Void {
        mSettings[:setCount] = 1;
        mSettings[:repCount] = 1;
        mSettings[:workSecs] = 4;
        mSettings[:recoverySecs] = 3;
        mSettings[:warmupSecs] = 10;
        mSettings[:cooldownSecs] = 5;
        mFieldWidth = 240;
        mFieldHeight = 400;
    }

    function intensity() as Number {
        return mIntensity;
    }

    function targetPower() as Number or Null {
        return currentTargetPower();
    }

    hidden function emitAlertForPhase(phase as Number) as Void {
    }

    hidden function emitTrainerUnavailableAlert() as Void {
        // Simulate an activity with Connect IQ alerts disabled.
    }
}

(:test)
function indoorWorkoutExplainsTimerRequirement(logger as Test.Logger) as Boolean {
    var trainer = new IndoorTestTrainer();
    var view = new IndoorTestView(trainer);
    if (!view.statusText().equals("START TIMER")) {
        return false;
    }
    view.handleTap();
    if (view.phase() != INTERVAL_PHASE_READY) {
        return false;
    }
    view.onTimerStart();
    if (!view.statusText().equals("TAP")) {
        return false;
    }
    view.handleTap();
    return (view.phase() == INTERVAL_PHASE_STARTING) && view.statusText().equals("5");
}

(:test)
function indoorWorkoutShowsBlockedTrainerWithoutAlert(logger as Test.Logger) as Boolean {
    var trainer = new IndoorTestTrainer();
    trainer.ready = false;
    var view = new IndoorTestView(trainer);
    view.onTimerStart();
    view.handleTap();
    var info = new Activity.Info();
    info.timerState = Activity.TIMER_STATE_ON;
    info.timerTime = 1000;
    view.compute(info);
    if (!view.statusText().equals("NO TRAINER")) {
        return false;
    }
    trainer.ready = true;
    view.compute(info);
    return view.statusText().equals("TAP");
}

(:test)
function indoorWorkoutDoesNotReenableControlAfterStop(logger as Test.Logger) as Boolean {
    var trainer = new IndoorTestTrainer();
    var view = new IndoorTestView(trainer);
    view.onTimerStart();
    view.handleTap();
    var info = new Activity.Info();
    info.timerState = Activity.TIMER_STATE_ON;
    info.timerTime = 5000;
    view.compute(info);
    if (!trainer.controlAllowed || (view.phase() != INTERVAL_PHASE_WORK)) {
        return false;
    }
    view.onTimerStop();
    info.timerState = Activity.TIMER_STATE_STOPPED;
    info.timerTime = 5500;
    view.compute(info);
    if (trainer.controlAllowed) {
        return false;
    }
    // Missing state must preserve the explicit Stop callback too.
    info.timerState = null;
    info.timerTime = 5600;
    view.compute(info);
    if (trainer.controlAllowed) {
        return false;
    }
    view.onTimerStart();
    info.timerState = Activity.TIMER_STATE_PAUSED;
    view.compute(info);
    return trainer.controlAllowed;
}

(:test)
function indoorWorkoutAdjustsEveryPhaseByOnePercent(logger as Test.Logger) as Boolean {
    var trainer = new IndoorTestTrainer();
    var view = new IndoorTestView(trainer);
    view.configurePhases();
    view.onTimerStart();
    // The footer cannot start a workout.
    view.handleTouch(200, 370);
    if ((view.phase() != INTERVAL_PHASE_READY) || (view.intensity() != 100)) { return false; }
    view.handleTouch(100, 200);
    view.handleTouch(200, 370);
    // Plus and the percentage display cannot cancel the countdown.
    view.handleTouch(120, 370);
    if ((view.phase() != INTERVAL_PHASE_STARTING) || (view.intensity() != 101)) { return false; }
    var info = new Activity.Info();
    info.timerState = Activity.TIMER_STATE_ON;
    info.timerTime = 5000;
    view.compute(info);
    if ((view.phase() != INTERVAL_PHASE_WARMUP) || (trainer.target != 126) || (view.targetPower() != 126)) { return false; }
    view.handleTouch(200, 370);
    if ((view.intensity() != 102) || (trainer.target != 128)) { return false; }
    info.timerTime = 15000;
    view.compute(info);
    if ((view.phase() != INTERVAL_PHASE_WORK) || (trainer.target != 286)) { return false; }
    view.handleTouch(20, 370);
    if ((view.intensity() != 101) || (trainer.target != 283)) { return false; }
    // A manual Stop releases control even if the user continues to adjust.
    view.onTimerStop();
    view.handleTouch(200, 370);
    if (trainer.controlAllowed || (trainer.target != null)) { return false; }
    view.onTimerStart();
    info.timerTime = 19000;
    view.compute(info);
    if ((view.phase() != INTERVAL_PHASE_RECOVERY) || (trainer.target != 128)) { return false; }
    info.timerTime = 22000;
    view.compute(info);
    if ((view.phase() != INTERVAL_PHASE_COOLDOWN) || (trainer.target != 128)) { return false; }
    view.handleTouch(20, 370);
    if (trainer.target != 126) { return false; }
    info.timerTime = 27000;
    view.compute(info);
    if ((view.phase() != INTERVAL_PHASE_COMPLETE) || (trainer.target != null)) { return false; }
    view.handleTouch(200, 370);
    if (view.intensity() != 101) { return false; }
    view.onTimerReset();
    return view.intensity() == 100;
}

(:test)
function indoorWorkoutCancelResetsIntensity(logger as Test.Logger) as Boolean {
    var view = new IndoorTestView(new IndoorTestTrainer());
    view.configurePhases();
    view.onTimerStart();
    view.handleTouch(100, 200);
    view.handleTouch(200, 370);
    view.handleTouch(100, 200);
    return (view.phase() == INTERVAL_PHASE_READY) && (view.intensity() == 100);
}

(:test)
function indoorWorkoutRendersAndUsesLayoutForTouch(logger as Test.Logger) as Boolean {
    var reference = Graphics.createBufferedBitmap({:width => 240, :height => 400});
    var bitmap = reference.get() as Graphics.BufferedBitmap;
    var dc = bitmap.getDc();
    var view = new IndoorTestView(new IndoorTestTrainer());
    view.configurePhases();
    view.onLayout(dc);
    view.onUpdate(dc);
    view.onTimerStart();
    view.handleTouch(100, 200);
    view.handleTouch(200, 370);
    view.onUpdate(dc);
    var info = new Activity.Info();
    info.timerState = Activity.TIMER_STATE_ON;
    // Render every timed phase, then completion.
    var times = [5000, 15000, 19000, 22000, 27000];
    for (var i = 0; i < times.size(); i += 1) {
        info.timerTime = times[i];
        view.compute(info);
        view.onUpdate(dc);
    }
    return (view.phase() == INTERVAL_PHASE_COMPLETE) && (view.intensity() == 101);
}
