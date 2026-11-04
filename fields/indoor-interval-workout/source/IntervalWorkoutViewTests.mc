import Toybox.Activity;
import Toybox.Lang;
import Toybox.Test;

(:test)
class IndoorTestTrainer extends IndoorTrainerController {
    var ready as Boolean = true;
    var controlAllowed as Boolean = false;

    function initialize() {
        IndoorTrainerController.initialize();
    }

    function canStart() as Boolean {
        return ready;
    }

    function update(settings as Dictionary, phase as Number, allowed as Boolean, forceTarget as Boolean) as Void {
        controlAllowed = allowed;
    }

    function release() as Void {
        controlAllowed = false;
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
    if (view.statusText() != "START TIMER") {
        return false;
    }
    view.handleTap();
    if (view.phase() != INTERVAL_PHASE_READY) {
        return false;
    }
    view.onTimerStart();
    if (view.statusText() != "TAP") {
        return false;
    }
    view.handleTap();
    return (view.phase() == INTERVAL_PHASE_STARTING) && (view.statusText() == "5");
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
    if (view.statusText() != "NO TRAINER") {
        return false;
    }
    trainer.ready = true;
    view.compute(info);
    return view.statusText() == "TAP";
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
