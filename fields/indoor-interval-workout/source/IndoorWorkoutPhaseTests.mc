import Toybox.Lang;
import Toybox.Test;

(:test)
function indoorWorkoutRunsWarmupAndCooldownOnce(logger as Test.Logger) as Boolean {
    var settings = intervalWorkoutTestSettings(2, 2, 4, 3, 5, 280, 125, 125);
    settings[:warmupSecs] = 10;
    settings[:cooldownSecs] = 15;
    var start = IntervalWorkoutLogic.startCountdownState();
    var warmup = IntervalWorkoutLogic.applyElapsed(start, settings, 5000)[:state] as Dictionary;
    if ((warmup[:phase] != INTERVAL_PHASE_WARMUP) || (warmup[:remainingMs] != 10000)) { return false; }
    if (!IntervalWorkoutLogic.isSessionLockedPhase(INTERVAL_PHASE_WARMUP)
        || !IntervalWorkoutLogic.isSessionLockedPhase(INTERVAL_PHASE_COOLDOWN)) { return false; }
    var all = IntervalWorkoutLogic.applyElapsed(start, settings, 60000);
    var transitions = all[:transitions] as Array;
    var expected = [INTERVAL_PHASE_WARMUP, INTERVAL_PHASE_WORK, INTERVAL_PHASE_RECOVERY,
        INTERVAL_PHASE_WORK, INTERVAL_PHASE_SET_RECOVERY, INTERVAL_PHASE_WORK,
        INTERVAL_PHASE_RECOVERY, INTERVAL_PHASE_WORK, INTERVAL_PHASE_RECOVERY,
        INTERVAL_PHASE_COOLDOWN, INTERVAL_PHASE_COMPLETE];
    if (transitions.size() != expected.size()) { return false; }
    for (var i = 0; i < expected.size(); i += 1) {
        if (transitions[i] != expected[i]) { return false; }
    }
    var finalState = all[:state] as Dictionary;
    return (finalState[:phase] == INTERVAL_PHASE_COMPLETE)
        && (finalState[:currentSet] == 2) && (finalState[:currentRep] == 2);
}

(:test)
function indoorWorkoutSkipsEachOptionalPhaseIndependently(logger as Test.Logger) as Boolean {
    var settings = intervalWorkoutTestSettings(1, 1, 4, 3, 0, 280, 125, 125);
    var start = IntervalWorkoutLogic.startCountdownState();
    settings[:cooldownSecs] = 10;
    var cooldownOnly = IntervalWorkoutLogic.applyElapsed(start, settings, 12000)[:state] as Dictionary;
    if (cooldownOnly[:phase] != INTERVAL_PHASE_COOLDOWN) { return false; }
    settings[:warmupSecs] = 10;
    settings[:cooldownSecs] = 0;
    var warmupOnly = IntervalWorkoutLogic.applyElapsed(start, settings, 22000)[:state] as Dictionary;
    if (warmupOnly[:phase] != INTERVAL_PHASE_COMPLETE) { return false; }
    settings[:warmupSecs] = 0;
    var neither = IntervalWorkoutLogic.applyElapsed(start, settings, 12000)[:state] as Dictionary;
    return neither[:phase] == INTERVAL_PHASE_COMPLETE;
}

(:test)
function indoorWorkoutNormalizesOptionalSettings(logger as Test.Logger) as Boolean {
    var raw = {:warmup_value => 5, :warmup_unit => 60, :warmup_power => "130",
        :cooldown_value => 90, :cooldown_unit => 1, :cooldown_power => 100};
    var settings = IntervalWorkoutLogic.normalizeSettings(raw);
    if ((settings[:warmupSecs] != 300) || (settings[:cooldownSecs] != 90)
        || (settings[:warmupPower] != 130) || (settings[:cooldownPower] != 100)) { return false; }
    raw[:warmup_value] = -1;
    if (IntervalWorkoutLogic.normalizeSettings(raw)[:valid]) { return false; }
    raw[:warmup_value] = 0;
    raw[:cooldown_value] = -1;
    return !IntervalWorkoutLogic.normalizeSettings(raw)[:valid];
}

(:test)
function indoorWorkoutScalesSavedTargetsWithoutDrift(logger as Test.Logger) as Boolean {
    return (IntervalWorkoutLogic.scaledPower(280, 101) == 283)
        && (IntervalWorkoutLogic.scaledPower(280, 99) == 277)
        && (IntervalWorkoutLogic.scaledPower(125, 102) == 128)
        && (IntervalWorkoutLogic.scaledPower(280, 100) == 280)
        && (IntervalWorkoutLogic.scaledPower(4000, 200) == 4000)
        && (IntervalWorkoutLogic.scaledPower(0, 200) == 0)
        && (IntervalWorkoutLogic.adjustedIntensity(100, 1) == 101)
        && (IntervalWorkoutLogic.adjustedIntensity(100, -1) == 99)
        && (IntervalWorkoutLogic.adjustedIntensity(1, -1) == 1)
        && (IntervalWorkoutLogic.adjustedIntensity(200, 1) == 200);
}

(:test)
function indoorWorkoutSeparatesTouchRegions(logger as Test.Logger) as Boolean {
    return (IntervalWorkoutLogic.touchAction(0, 339, 240, 400) == INTERVAL_TOUCH_BODY)
        && (IntervalWorkoutLogic.touchAction(0, 340, 240, 400) == INTERVAL_TOUCH_DECREASE)
        && (IntervalWorkoutLogic.touchAction(79, 399, 240, 400) == INTERVAL_TOUCH_DECREASE)
        && (IntervalWorkoutLogic.touchAction(80, 340, 240, 400) == INTERVAL_TOUCH_NONE)
        && (IntervalWorkoutLogic.touchAction(159, 399, 240, 400) == INTERVAL_TOUCH_NONE)
        && (IntervalWorkoutLogic.touchAction(160, 340, 240, 400) == INTERVAL_TOUCH_INCREASE)
        && (IntervalWorkoutLogic.touchAction(239, 399, 240, 400) == INTERVAL_TOUCH_INCREASE)
        && (IntervalWorkoutLogic.touchAction(240, 370, 240, 400) == INTERVAL_TOUCH_NONE)
        && (IntervalWorkoutLogic.touchAction(10, 400, 240, 400) == INTERVAL_TOUCH_NONE)
        && (IntervalWorkoutLogic.touchAction(-1, 370, 240, 400) == INTERVAL_TOUCH_NONE)
        && (IntervalWorkoutLogic.touchAction(0, 0, 0, 0) == INTERVAL_TOUCH_NONE);
}
