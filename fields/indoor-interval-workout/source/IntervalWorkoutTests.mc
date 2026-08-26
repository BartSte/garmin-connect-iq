import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Test;

(:debug)
function intervalWorkoutTestSettings(
    setCount as Number,
    repCount as Number,
    workSecs as Number,
    recoverySecs as Number,
    setRecoverySecs as Number,
    workPower as Number,
    recoveryPower as Number,
    setRecoveryPower as Number
) as Dictionary {
    return IntervalWorkoutLogic.normalizeSettings({
        :ftp => 250,
        :set_count => setCount,
        :rep_count => repCount,
        :work_value => workSecs,
        :work_unit => 1,
        :recovery_value => recoverySecs,
        :recovery_unit => 1,
        :set_recovery_value => setRecoverySecs,
        :set_recovery_unit => 1,
        :work_power => workPower,
        :recovery_power => recoveryPower,
        :set_recovery_power => setRecoveryPower
    });
}

(:test)
function intervalWorkoutUsesFreshInstallDefaults(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking fresh-install defaults");
    var settings = IntervalWorkoutLogic.defaultSettings();
    return (settings[:ftp] == 248)
        && (settings[:setCount] == 3)
        && (settings[:repCount] == 10)
        && (settings[:workSecs] == 40)
        && (settings[:recoverySecs] == 20)
        && (settings[:setRecoverySecs] == 240)
        && (settings[:workPower] == 280)
        && (settings[:recoveryPower] == 125)
        && (settings[:setRecoveryPower] == 125);
}

(:test)
function intervalWorkoutNormalizesLegacyDurationUnits(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking settings normalization");
    var settings = IntervalWorkoutLogic.normalizeSettings({
        :ftp => 250,
        :set_count => 3,
        :rep_count => 10,
        :work_value => 40,
        :work_unit => "seconds",
        :recovery_value => 20,
        :recovery_unit => "seconds",
        :set_recovery_value => 5,
        :set_recovery_unit => "minutes",
        :work_power => "300",
        :recovery_power => "150",
        :set_recovery_power => "125"
    });

    return (settings[:ftp] == 250)
        && (settings[:setRecoverySecs] == 300)
        && (settings[:workPower] == 300)
        && settings[:valid];
}

(:test)
function intervalWorkoutClampsTargetPower(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking target-power bounds");
    return (IntervalWorkoutLogic.targetPowerFromValue(-1, 280) == 0)
        && (IntervalWorkoutLogic.targetPowerFromValue(4001, 280) == 4000)
        && (IntervalWorkoutLogic.targetPowerFromValue(null, 280) == 280);
}

(:test)
function intervalWorkoutRunsWorkoutConfiguredInMinutes(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking 3 x 15/5 minute workout");
    var settings = IntervalWorkoutLogic.normalizeSettings({
        :ftp => 250,
        :set_count => 1,
        :rep_count => 3,
        :work_value => 15,
        :work_unit => 60,
        :recovery_value => 5,
        :recovery_unit => 60,
        :set_recovery_value => 0,
        :set_recovery_unit => 1,
        :work_power => 275,
        :recovery_power => 125,
        :set_recovery_power => 100
    });
    var state = IntervalWorkoutLogic.startWorkState(1, 1, settings);
    var afterWork = IntervalWorkoutLogic.applyElapsed(state, settings, 900000);
    var recovery = afterWork[:state] as Dictionary;
    var afterRecovery = IntervalWorkoutLogic.applyElapsed(recovery, settings, 300000);
    var secondWork = afterRecovery[:state] as Dictionary;
    var complete = IntervalWorkoutLogic.applyElapsed(state, settings, 3600000);
    var completeState = complete[:state] as Dictionary;

    return settings[:valid]
        && (settings[:workSecs] == 900)
        && (settings[:recoverySecs] == 300)
        && (settings[:workPower] == 275)
        && (settings[:recoveryPower] == 125)
        && (recovery[:phase] == INTERVAL_PHASE_RECOVERY)
        && (recovery[:remainingMs] == 300000)
        && (secondWork[:phase] == INTERVAL_PHASE_WORK)
        && (secondWork[:currentRep] == 2)
        && (secondWork[:remainingMs] == 900000)
        && (completeState[:phase] == INTERVAL_PHASE_COMPLETE)
        && (completeState[:currentRep] == 3);
}

(:test)
function intervalWorkoutRejectsInvalidRequiredSettings(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking required-setting validation");
    var normalizedFtp = IntervalWorkoutLogic.normalizeSettings({
        :ftp => 0,
        :set_count => 1,
        :rep_count => 1,
        :work_value => 40,
        :work_unit => 1,
        :recovery_value => 20,
        :recovery_unit => 1,
        :set_recovery_value => 0,
        :set_recovery_unit => 1,
        :work_power => 280,
        :recovery_power => 125,
        :set_recovery_power => 125
    });
    var invalidWork = intervalWorkoutTestSettings(1, 1, 0, 20, 0, 280, 125, 125);
    var invalidRecovery = intervalWorkoutTestSettings(1, 1, 40, 0, 0, 280, 125, 125);

    return !normalizedFtp[:valid]
        && (normalizedFtp[:error] == "FTP")
        && !invalidWork[:valid]
        && (invalidWork[:error] == "WORK")
        && !invalidRecovery[:valid]
        && (invalidRecovery[:error] == "REC");
}

(:test)
function intervalWorkoutFormatsTimers(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking timer formatting");
    return (IntervalWorkoutLogic.formatRideTimer(495000) == "08:15")
        && (IntervalWorkoutLogic.formatCountdown(20000) == "00:20")
        && (IntervalWorkoutLogic.formatStartCountdown(5000) == "5")
        && (IntervalWorkoutLogic.formatStartCountdown(4001) == "5")
        && (IntervalWorkoutLogic.formatDuration(240) == "4:00")
        && (IntervalWorkoutLogic.formatClock(7, 30) == "07:30");
}

(:test)
function intervalWorkoutTracksPowerAverage(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking rolling power average");
    var one = IntervalWorkoutLogic.pushPowerSample([0, 0, 0], 0, 0, 210);
    var two = IntervalWorkoutLogic.pushPowerSample(one[:buffer], one[:nextIndex], one[:sampleCount], 240);
    var three = IntervalWorkoutLogic.pushPowerSample(two[:buffer], two[:nextIndex], two[:sampleCount], 300);
    return (one[:average] == 210)
        && (three[:average] == 250)
        && (three[:sampleCount] == 3);
}

(:test)
function intervalWorkoutStartsAndCancelsCountdownWithTap(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking tap-to-start countdown");
    var settings = intervalWorkoutTestSettings(1, 1, 40, 20, 0, 280, 125, 125);
    var ready = IntervalWorkoutLogic.readyState(settings);
    var pausedTap = IntervalWorkoutLogic.applyTap(ready, settings, false, true);
    var blocked = IntervalWorkoutLogic.applyTap(ready, settings, true, false);
    var blockedState = blocked[:state] as Dictionary;
    var started = IntervalWorkoutLogic.applyTap(ready, settings, true, true);
    var startedState = started[:state] as Dictionary;
    var cancelled = IntervalWorkoutLogic.applyTap(startedState, settings, true, false);
    var cancelledState = cancelled[:state] as Dictionary;

    return ((pausedTap[:state] as Dictionary)[:phase] == INTERVAL_PHASE_READY)
        && !pausedTap[:sessionLocked]
        && (blockedState[:phase] == INTERVAL_PHASE_READY)
        && blocked[:blocked]
        && !blocked[:started]
        && (startedState[:phase] == INTERVAL_PHASE_STARTING)
        && (startedState[:remainingMs] == 5000)
        && started[:sessionLocked]
        && started[:started]
        && (cancelledState[:phase] == INTERVAL_PHASE_READY)
        && !cancelled[:sessionLocked]
        && cancelled[:cancelled];
}

(:test)
function intervalWorkoutRequiresCompatibleTrainer(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking compatible-trainer requirement");
    return IntervalWorkoutLogic.trainerCanStart(true, true)
        && !IntervalWorkoutLogic.trainerCanStart(false, true)
        && !IntervalWorkoutLogic.trainerCanStart(true, false)
        && !IntervalWorkoutLogic.trainerCanStart(true, null);
}

(:test)
function intervalWorkoutSelectsSafeTrainerRelease(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking trainer release selection");
    return (IntervalWorkoutLogic.trainerReleaseAction(true, true) == INTERVAL_TRAINER_RELEASE_BASIC)
        && (IntervalWorkoutLogic.trainerReleaseAction(false, true) == INTERVAL_TRAINER_RELEASE_ZERO_POWER)
        && (IntervalWorkoutLogic.trainerReleaseAction(false, false) == INTERVAL_TRAINER_RELEASE_NONE)
        && (IntervalWorkoutLogic.trainerReleaseAction(null, null) == INTERVAL_TRAINER_RELEASE_NONE);
}

(:test)
function intervalWorkoutCountdownUsesActivityTimerDelta(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking countdown advancement and pause");
    var settings = intervalWorkoutTestSettings(1, 1, 40, 20, 0, 280, 125, 125);
    var countdown = IntervalWorkoutLogic.startCountdownState();
    var paused = IntervalWorkoutLogic.applyElapsed(countdown, settings, 0);
    var pausedState = paused[:state] as Dictionary;
    var advanced = IntervalWorkoutLogic.applyElapsed(countdown, settings, 5000);
    var advancedState = advanced[:state] as Dictionary;
    var transitions = advanced[:transitions] as Array;

    return (pausedState[:phase] == INTERVAL_PHASE_STARTING)
        && (pausedState[:remainingMs] == 5000)
        && (advancedState[:phase] == INTERVAL_PHASE_WORK)
        && (advancedState[:remainingMs] == 40000)
        && (transitions.size() == 1)
        && (transitions[0] == INTERVAL_PHASE_WORK);
}

(:test)
function intervalWorkoutUsesOnlyFinalTargetAfterSkippedTransitions(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking target after multiple transitions");
    var settings = intervalWorkoutTestSettings(1, 2, 10, 5, 0, 300, 100, 75);
    var state = IntervalWorkoutLogic.startWorkState(1, 1, settings);
    var result = IntervalWorkoutLogic.applyElapsed(state, settings, 16000);
    var finalState = result[:state] as Dictionary;
    var transitions = result[:transitions] as Array;

    return (transitions.size() == 2)
        && (transitions[0] == INTERVAL_PHASE_RECOVERY)
        && (transitions[1] == INTERVAL_PHASE_WORK)
        && (finalState[:phase] == INTERVAL_PHASE_WORK)
        && (finalState[:currentRep] == 2)
        && (finalState[:remainingMs] == 9000)
        && (IntervalWorkoutLogic.controlledPowerForPhase(settings, finalState[:phase]) == 300);
}

(:test)
function intervalWorkoutIgnoresTapsAfterCountdown(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking ignored active and complete taps");
    var settings = intervalWorkoutTestSettings(1, 1, 40, 20, 0, 280, 125, 125);
    var work = IntervalWorkoutLogic.startWorkState(1, 1, settings);
    var activeTap = IntervalWorkoutLogic.applyTap(work, settings, true, false);
    var activeState = activeTap[:state] as Dictionary;
    var complete = IntervalWorkoutLogic.completeState(work);
    var completeTap = IntervalWorkoutLogic.applyTap(complete, settings, true, false);
    var completeAfterTap = completeTap[:state] as Dictionary;

    return (activeState[:phase] == INTERVAL_PHASE_WORK)
        && (activeState[:remainingMs] == 40000)
        && activeTap[:sessionLocked]
        && (completeAfterTap[:phase] == INTERVAL_PHASE_COMPLETE)
        && completeTap[:sessionLocked]
        && !activeTap[:started]
        && !activeTap[:cancelled];
}

(:test)
function intervalWorkoutRunsThresholdSequence(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking 3 x 20-minute threshold sequence");
    var settings = intervalWorkoutTestSettings(1, 3, 1200, 300, 0, 280, 125, 125);
    var state = IntervalWorkoutLogic.startWorkState(1, 1, settings);
    var afterFirstWork = IntervalWorkoutLogic.applyElapsed(state, settings, 1200000);
    var firstRecovery = afterFirstWork[:state] as Dictionary;
    var complete = IntervalWorkoutLogic.applyElapsed(state, settings, 4500000);
    var completeState = complete[:state] as Dictionary;

    return (firstRecovery[:phase] == INTERVAL_PHASE_RECOVERY)
        && (firstRecovery[:remainingMs] == 300000)
        && (IntervalWorkoutLogic.targetPowerForPhase(settings, firstRecovery[:phase]) == 125)
        && (completeState[:phase] == INTERVAL_PHASE_COMPLETE)
        && (completeState[:currentRep] == 3);
}

(:test)
function intervalWorkoutSetRecoveryReplacesRepRecovery(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking exact recovery between sets");
    var settings = intervalWorkoutTestSettings(3, 10, 40, 20, 240, 280, 125, 125);
    var lastWorkInSet = IntervalWorkoutLogic.startWorkState(1, 10, settings);
    var afterWork = IntervalWorkoutLogic.applyElapsed(lastWorkInSet, settings, 40000);
    var setRecovery = afterWork[:state] as Dictionary;
    var almostFinished = IntervalWorkoutLogic.applyElapsed(setRecovery, settings, 239999);
    var almostFinishedState = almostFinished[:state] as Dictionary;
    var nextSet = IntervalWorkoutLogic.applyElapsed(setRecovery, settings, 240000);
    var nextSetState = nextSet[:state] as Dictionary;

    return (setRecovery[:phase] == INTERVAL_PHASE_SET_RECOVERY)
        && (setRecovery[:currentSet] == 2)
        && (setRecovery[:remainingMs] == 240000)
        && (almostFinishedState[:phase] == INTERVAL_PHASE_SET_RECOVERY)
        && (almostFinishedState[:remainingMs] == 1)
        && (nextSetState[:phase] == INTERVAL_PHASE_WORK)
        && (nextSetState[:currentSet] == 2)
        && (nextSetState[:currentRep] == 1);
}

(:test)
function intervalWorkoutRunsFullVo2Sequence(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking 3 x 10 x 40/20 VO2 sequence");
    var settings = intervalWorkoutTestSettings(3, 10, 40, 20, 240, 280, 125, 125);
    var state = IntervalWorkoutLogic.startWorkState(1, 1, settings);
    var result = IntervalWorkoutLogic.applyElapsed(state, settings, 2240000);
    var finalState = result[:state] as Dictionary;

    return (finalState[:phase] == INTERVAL_PHASE_COMPLETE)
        && (finalState[:currentSet] == 3)
        && (finalState[:currentRep] == 10);
}

(:test)
function intervalWorkoutSkipsZeroSetRecovery(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking zero set recovery");
    var settings = intervalWorkoutTestSettings(2, 1, 40, 20, 0, 280, 125, 125);
    var state = IntervalWorkoutLogic.startWorkState(1, 1, settings);
    var result = IntervalWorkoutLogic.applyElapsed(state, settings, 40000);
    var nextState = result[:state] as Dictionary;

    return (nextState[:phase] == INTERVAL_PHASE_WORK)
        && (nextState[:currentSet] == 2)
        && (nextState[:currentRep] == 1)
        && (nextState[:remainingMs] == 40000);
}

(:test)
function intervalWorkoutCompletesAfterFinalRecovery(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking final normal recovery");
    var settings = intervalWorkoutTestSettings(1, 1, 40, 20, 0, 280, 125, 125);
    var state = IntervalWorkoutLogic.startWorkState(1, 1, settings);
    var afterWork = IntervalWorkoutLogic.applyElapsed(state, settings, 40000);
    var afterWorkState = afterWork[:state] as Dictionary;
    var afterRecovery = IntervalWorkoutLogic.applyElapsed(afterWorkState, settings, 20000);
    var afterRecoveryState = afterRecovery[:state] as Dictionary;

    return (afterWorkState[:phase] == INTERVAL_PHASE_RECOVERY)
        && (afterWorkState[:remainingMs] == 20000)
        && (afterRecoveryState[:phase] == INTERVAL_PHASE_COMPLETE);
}

(:test)
function intervalWorkoutUsesMinimal7ZoneColors(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking exact Minimal-7 zone colors");
    return (IntervalWorkoutLogic.powerZoneColor(0) == INTERVAL_ZONE1_COLOR)
        && (IntervalWorkoutLogic.powerZoneColor(55) == INTERVAL_ZONE2_COLOR)
        && (IntervalWorkoutLogic.powerZoneColor(75) == INTERVAL_ZONE3_COLOR)
        && (IntervalWorkoutLogic.powerZoneColor(90) == INTERVAL_ZONE4_COLOR)
        && (IntervalWorkoutLogic.powerZoneColor(105) == INTERVAL_ZONE5_COLOR)
        && (IntervalWorkoutLogic.powerZoneColor(120) == INTERVAL_ZONE6_COLOR)
        && (IntervalWorkoutLogic.powerZoneColor(150) == INTERVAL_ZONE7_COLOR)
        && (IntervalWorkoutLogic.powerZoneTextColor(54) == Graphics.COLOR_BLACK)
        && (IntervalWorkoutLogic.powerZoneTextColor(55) == Graphics.COLOR_WHITE)
        && (IntervalWorkoutLogic.powerZoneTextColor(75) == Graphics.COLOR_BLACK)
        && (IntervalWorkoutLogic.powerZoneTextColor(120) == Graphics.COLOR_WHITE);
}

(:test)
function intervalWorkoutHandlesUnavailablePower(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking actual-power colors and unavailable power");
    var unavailable = IntervalWorkoutLogic.actualPowerColors(0, 248, false);
    var invalidFtp = IntervalWorkoutLogic.actualPowerColors(250, 0, true);
    var zoneFour = IntervalWorkoutLogic.actualPowerColors(225, 250, true);

    return (unavailable[:background] == INTERVAL_POWER_UNKNOWN_COLOR)
        && (unavailable[:foreground] == Graphics.COLOR_WHITE)
        && (invalidFtp[:background] == INTERVAL_POWER_UNKNOWN_COLOR)
        && (zoneFour[:background] == INTERVAL_ZONE4_COLOR)
        && (zoneFour[:foreground] == Graphics.COLOR_BLACK);
}

(:test)
function intervalWorkoutShowsTargetPowerForCurrentPhase(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking target-power badge values");
    var settings = intervalWorkoutTestSettings(1, 1, 40, 20, 0, 300, 150, 100);
    return (IntervalWorkoutLogic.targetPowerForPhase(settings, INTERVAL_PHASE_READY) == 300)
        && (IntervalWorkoutLogic.targetPowerForPhase(settings, INTERVAL_PHASE_STARTING) == 300)
        && (IntervalWorkoutLogic.targetPowerForPhase(settings, INTERVAL_PHASE_WORK) == 300)
        && (IntervalWorkoutLogic.targetPowerForPhase(settings, INTERVAL_PHASE_RECOVERY) == 150)
        && (IntervalWorkoutLogic.targetPowerForPhase(settings, INTERVAL_PHASE_SET_RECOVERY) == 100)
        && (IntervalWorkoutLogic.targetPowerForPhase(settings, INTERVAL_PHASE_COMPLETE) == null)
        && (IntervalWorkoutLogic.controlledPowerForPhase(settings, INTERVAL_PHASE_READY) == null)
        && (IntervalWorkoutLogic.controlledPowerForPhase(settings, INTERVAL_PHASE_WORK) == 300);
}

(:test)
function intervalWorkoutPickerBoundsAndMappings(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking picker bounds and index/value mappings");
    var ftp = new IntervalWorkoutNumberPickerFactory(50, 600, INTERVAL_PICKER_FTP);
    var sets = new IntervalWorkoutNumberPickerFactory(1, 20, INTERVAL_PICKER_PLAIN);
    var reps = new IntervalWorkoutNumberPickerFactory(1, 100, INTERVAL_PICKER_PLAIN);
    var minutes = new IntervalWorkoutNumberPickerFactory(0, 120, INTERVAL_PICKER_PLAIN);
    var seconds = new IntervalWorkoutNumberPickerFactory(0, 59, INTERVAL_PICKER_SECONDS);
    var powers = new IntervalWorkoutNumberPickerFactory(0, 4000, INTERVAL_PICKER_POWER);

    return (ftp.getSize() == 551)
        && (ftp.getIndex(49) == 0)
        && (ftp.getIndex(601) == 550)
        && ((ftp.getValue(198) as Number) == 248)
        && (sets.getSize() == 20)
        && (reps.getSize() == 100)
        && (minutes.getSize() == 121)
        && (seconds.getSize() == 60)
        && (powers.getSize() == 4001)
        && (powers.getIndex(-1) == 0)
        && (powers.getIndex(4001) == 4000)
        && ((powers.getValue(280) as Number) == 280);
}

(:test)
function intervalWorkoutDurationPickerEncoding(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking duration picker encoding and validation");
    var maximum = IntervalWorkoutSettings.durationParts(99999);
    var minimum = IntervalWorkoutSettings.durationParts(-1);
    var encoded = IntervalWorkoutSettings.durationPropertyValues(
        IntervalWorkoutSettings.durationFromParts(4, 20)
    );
    var fifteenMinutes = IntervalWorkoutSettings.durationFromParts(15, 0);
    var fiveMinutes = IntervalWorkoutSettings.durationFromParts(5, 0);
    var fifteenMinuteParts = IntervalWorkoutSettings.durationParts(fifteenMinutes);

    return (maximum[:minutes] == 120)
        && (maximum[:seconds] == 59)
        && (minimum[:minutes] == 0)
        && (minimum[:seconds] == 0)
        && (encoded[:value] == 260)
        && (encoded[:unit] == 1)
        && (fifteenMinutes == 900)
        && (fiveMinutes == 300)
        && (fifteenMinuteParts[:minutes] == 15)
        && (fifteenMinuteParts[:seconds] == 0)
        && !IntervalWorkoutSettings.durationIsValid(0, false)
        && IntervalWorkoutSettings.durationIsValid(1, false)
        && IntervalWorkoutSettings.durationIsValid(0, true);
}
