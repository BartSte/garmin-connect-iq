import Toybox.Graphics;
import Toybox.Lang;

const INTERVAL_PHASE_INVALID      = 0;
const INTERVAL_PHASE_READY        = 1;
const INTERVAL_PHASE_STARTING     = 2;
const INTERVAL_PHASE_WORK         = 3;
const INTERVAL_PHASE_RECOVERY     = 4;
const INTERVAL_PHASE_SET_RECOVERY = 5;
const INTERVAL_PHASE_COMPLETE     = 6;

const INTERVAL_START_COUNTDOWN_MS = 5000;

const INTERVAL_DEFAULT_FTP = 248;
const INTERVAL_MIN_FTP = 50;
const INTERVAL_MAX_FTP = 600;
const INTERVAL_MIN_SET_COUNT = 1;
const INTERVAL_MAX_SET_COUNT = 20;
const INTERVAL_MIN_REP_COUNT = 1;
const INTERVAL_MAX_REP_COUNT = 100;
const INTERVAL_MIN_DURATION_SECS = 0;
const INTERVAL_MAX_DURATION_SECS = (120 * 60) + 59;

const INTERVAL_ZONE2_PCT = 55;
const INTERVAL_ZONE3_PCT = 75;
const INTERVAL_ZONE4_PCT = 90;
const INTERVAL_ZONE5_PCT = 105;
const INTERVAL_ZONE6_PCT = 120;
const INTERVAL_ZONE7_PCT = 150;

const INTERVAL_ZONE1_COLOR = 0xAAAAAA;
const INTERVAL_ZONE2_COLOR = 0x0000AA;
const INTERVAL_ZONE3_COLOR = 0x00AA00;
const INTERVAL_ZONE4_COLOR = 0xFFFF00;
const INTERVAL_ZONE5_COLOR = 0xFF8800;
const INTERVAL_ZONE6_COLOR = 0xAA0000;
const INTERVAL_ZONE7_COLOR = 0x800080;
const INTERVAL_POWER_UNKNOWN_COLOR = 0x666666;
const INTERVAL_DEFAULT_CADENCE_MIN = 80;
const INTERVAL_DEFAULT_CADENCE_MAX = 110;
const INTERVAL_MIN_CADENCE = 40;
const INTERVAL_MAX_CADENCE = 150;
const INTERVAL_CADENCE_TARGET_COLOR = 0x00AA00;

module IntervalWorkoutLogic {

    function defaultSettings() as Dictionary {
        return {
            :ftp => INTERVAL_DEFAULT_FTP,
            :setCount => 3,
            :repCount => 10,
            :workSecs => 40,
            :recoverySecs => 20,
            :setRecoverySecs => 240,
            :workZone => 5,
            :recoveryZone => 1,
            :setRecoveryZone => 1,
            :valid => true,
            :error => ""
        };
    }

    function defaultSessionState() as Dictionary {
        return {
            :phase => INTERVAL_PHASE_READY,
            :currentSet => 1,
            :currentRep => 1,
            :remainingMs => 0
        };
    }

    function copySessionState(state as Dictionary) as Dictionary {
        return {
            :phase => state[:phase],
            :currentSet => state[:currentSet],
            :currentRep => state[:currentRep],
            :remainingMs => state[:remainingMs]
        };
    }

    function valueToNumber(value as Lang.Object or Null, fallback as Number) as Number {
        if (value == null) {
            return fallback;
        }
        if (value instanceof Lang.Number) {
            return value as Lang.Number;
        }
        if (value instanceof Lang.Long) {
            return (value as Lang.Long).toNumber();
        }
        if (value instanceof Lang.Float) {
            return (value as Lang.Float).toNumber();
        }
        if (value instanceof Lang.Double) {
            return (value as Lang.Double).toNumber();
        }
        if (value instanceof Lang.String) {
            var parsed = (value as Lang.String).toNumber();
            return (parsed == null) ? fallback : parsed;
        }
        return fallback;
    }

    // Normalize even if XML settings contain reversed or out-of-range values.
    function cadenceBounds(rawMin as Lang.Object or Null, rawMax as Lang.Object or Null) as Dictionary {
        var minimum = valueToNumber(rawMin, INTERVAL_DEFAULT_CADENCE_MIN);
        var maximum = valueToNumber(rawMax, INTERVAL_DEFAULT_CADENCE_MAX);
        if (minimum < INTERVAL_MIN_CADENCE) { minimum = INTERVAL_MIN_CADENCE; }
        if (minimum > INTERVAL_MAX_CADENCE) { minimum = INTERVAL_MAX_CADENCE; }
        if (maximum < INTERVAL_MIN_CADENCE) { maximum = INTERVAL_MIN_CADENCE; }
        if (maximum > INTERVAL_MAX_CADENCE) { maximum = INTERVAL_MAX_CADENCE; }
        if (minimum > maximum) {
            var oldMinimum = minimum;
            minimum = maximum;
            maximum = oldMinimum;
        }
        return { :minimum => minimum, :maximum => maximum };
    }

    function cadenceColors(
        cadence as Number,
        hasCadence as Boolean,
        minimum as Number,
        maximum as Number,
        defaultFg as Number
    ) as Dictionary {
        if (hasCadence && cadence >= minimum && cadence <= maximum) {
            return {
                :foreground => Graphics.COLOR_BLACK,
                :background => INTERVAL_CADENCE_TARGET_COLOR
            };
        }
        return { :foreground => defaultFg, :background => null };
    }

    function durationUnitMultiplier(value as Lang.Object or Null) as Number {
        if (value instanceof Lang.String) {
            var unit = value as Lang.String;
            if (unit.equals("minutes")) {
                return 60;
            }
            if (unit.equals("seconds")) {
                return 1;
            }
        }
        return valueToNumber(value, 1);
    }

    function secondsFromValue(value as Lang.Object or Null, unit as Lang.Object or Null, fallback as Number) as Number {
        var amount = valueToNumber(value, fallback);
        return amount * durationUnitMultiplier(unit);
    }

    function zoneFromValue(value as Lang.Object or Null, fallback as Number) as Number {
        var zone = valueToNumber(value, fallback);
        if (zone < 1) { return 1; }
        if (zone > 7) { return 7; }
        return zone;
    }

    function normalizeSettings(raw as Dictionary) as Dictionary {
        var settings = {
            :ftp => valueToNumber(raw[:ftp], INTERVAL_DEFAULT_FTP),
            :setCount => valueToNumber(raw[:set_count], 3),
            :repCount => valueToNumber(raw[:rep_count], 10),
            :workSecs => secondsFromValue(raw[:work_value], raw[:work_unit], 40),
            :recoverySecs => secondsFromValue(raw[:recovery_value], raw[:recovery_unit], 20),
            :setRecoverySecs => secondsFromValue(raw[:set_recovery_value], raw[:set_recovery_unit], 240),
            :workZone => zoneFromValue(raw[:work_zone], 5),
            :recoveryZone => zoneFromValue(raw[:recovery_zone], 1),
            :setRecoveryZone => zoneFromValue(raw[:set_recovery_zone], 1),
            :valid => true,
            :error => ""
        };

        if (settings[:ftp] <= 0) {
            settings[:valid] = false;
            settings[:error] = "FTP";
        } else if (settings[:setCount] < 1) {
            settings[:valid] = false;
            settings[:error] = "SETS";
        } else if (settings[:repCount] < 1) {
            settings[:valid] = false;
            settings[:error] = "REPS";
        } else if (settings[:workSecs] <= 0) {
            settings[:valid] = false;
            settings[:error] = "WORK";
        } else if (settings[:recoverySecs] <= 0) {
            settings[:valid] = false;
            settings[:error] = "REC";
        } else if (settings[:setRecoverySecs] < 0) {
            settings[:valid] = false;
            settings[:error] = "SET";
        }

        return settings;
    }

    function readyState(settings as Dictionary) as Dictionary {
        var state = defaultSessionState();
        if (!settings[:valid]) {
            state[:phase] = INTERVAL_PHASE_INVALID;
        }
        return state;
    }

    function startCountdownState() as Dictionary {
        return {
            :phase => INTERVAL_PHASE_STARTING,
            :currentSet => 1,
            :currentRep => 1,
            :remainingMs => INTERVAL_START_COUNTDOWN_MS
        };
    }

    function isSessionLockedPhase(phase as Number) as Boolean {
        return (phase == INTERVAL_PHASE_STARTING)
            || (phase == INTERVAL_PHASE_WORK)
            || (phase == INTERVAL_PHASE_RECOVERY)
            || (phase == INTERVAL_PHASE_SET_RECOVERY)
            || (phase == INTERVAL_PHASE_COMPLETE);
    }

    function applyTap(state as Dictionary, settings as Dictionary, timerRunning as Boolean) as Dictionary {
        var nextState = copySessionState(state);
        var started = false;
        var cancelled = false;

        if (state[:phase] == INTERVAL_PHASE_STARTING) {
            nextState = readyState(settings);
            cancelled = true;
        } else if ((state[:phase] == INTERVAL_PHASE_READY) && settings[:valid] && timerRunning) {
            nextState = startCountdownState();
            started = true;
        }

        return {
            :state => nextState,
            :sessionLocked => isSessionLockedPhase(nextState[:phase]),
            :started => started,
            :cancelled => cancelled
        };
    }

    function pushPowerSample(
        powerBuf as Array<Number>,
        powerIdx as Number,
        powerCount as Number,
        rawPower as Number
    ) as Dictionary {
        var nextBuf = [powerBuf[0], powerBuf[1], powerBuf[2]];
        var nextCount = powerCount;

        if (nextCount < 3) {
            nextCount += 1;
            if (nextCount == 1) {
                nextBuf[0] = rawPower;
                nextBuf[1] = rawPower;
                nextBuf[2] = rawPower;
            }
        }

        nextBuf[powerIdx] = rawPower;

        return {
            :buffer => nextBuf,
            :nextIndex => (powerIdx + 1) % 3,
            :sampleCount => nextCount,
            :average => (nextBuf[0] + nextBuf[1] + nextBuf[2] + 1) / 3
        };
    }

    function formatClock(hour as Number, minute as Number) as String {
        return hour.format("%02d") + ":" + minute.format("%02d");
    }

    function formatRideTimer(ms as Number) as String {
        var totalSecs = ms / 1000;
        var hours = totalSecs / 3600;
        var minutes = (totalSecs % 3600) / 60;
        var secs = totalSecs % 60;
        if (hours > 0) {
            return hours.format("%d") + ":" + minutes.format("%02d") + ":" + secs.format("%02d");
        }
        return minutes.format("%02d") + ":" + secs.format("%02d");
    }

    function formatCountdown(ms as Number) as String {
        var totalSecs = ms / 1000;
        var hours = totalSecs / 3600;
        var minutes = (totalSecs % 3600) / 60;
        var secs = totalSecs % 60;
        if (hours > 0) {
            return hours.format("%d") + ":" + minutes.format("%02d") + ":" + secs.format("%02d");
        }
        return minutes.format("%02d") + ":" + secs.format("%02d");
    }

    function formatStartCountdown(ms as Number) as String {
        return ((ms + 999) / 1000).format("%d");
    }

    function formatDuration(seconds as Number) as String {
        var minutes = seconds / 60;
        var remainder = seconds % 60;
        return minutes.format("%d") + ":" + remainder.format("%02d");
    }

    function formatProgress(current as Number, total as Number) as String {
        return current.format("%d") + "/" + total.format("%d");
    }

    function zoneLabel(zone as Number) as String {
        return "Z" + zone.format("%d");
    }

    function zoneBandFromPct(pct as Number) as Number {
        if (pct >= INTERVAL_ZONE7_PCT) { return 7; }
        if (pct >= INTERVAL_ZONE6_PCT) { return 6; }
        if (pct >= INTERVAL_ZONE5_PCT) { return 5; }
        if (pct >= INTERVAL_ZONE4_PCT) { return 4; }
        if (pct >= INTERVAL_ZONE3_PCT) { return 3; }
        if (pct >= INTERVAL_ZONE2_PCT) { return 2; }
        return 1;
    }

    function zoneColor(zone as Number) as Number {
        if (zone == 7) { return INTERVAL_ZONE7_COLOR; }
        if (zone == 6) { return INTERVAL_ZONE6_COLOR; }
        if (zone == 5) { return INTERVAL_ZONE5_COLOR; }
        if (zone == 4) { return INTERVAL_ZONE4_COLOR; }
        if (zone == 3) { return INTERVAL_ZONE3_COLOR; }
        if (zone == 2) { return INTERVAL_ZONE2_COLOR; }
        return INTERVAL_ZONE1_COLOR;
    }

    function zoneTextColor(zone as Number) as Number {
        if (zone >= 6) { return Graphics.COLOR_WHITE; }
        if (zone >= 3) { return Graphics.COLOR_BLACK; }
        if (zone == 2) { return Graphics.COLOR_WHITE; }
        return Graphics.COLOR_BLACK;
    }

    function powerZoneColor(pct as Number) as Number {
        return zoneColor(zoneBandFromPct(pct));
    }

    function powerZoneTextColor(pct as Number) as Number {
        return zoneTextColor(zoneBandFromPct(pct));
    }

    function actualPowerColors(power as Number, ftp as Number, hasPower as Boolean) as Dictionary {
        if (!hasPower || (ftp <= 0)) {
            return {
                :background => INTERVAL_POWER_UNKNOWN_COLOR,
                :foreground => Graphics.COLOR_WHITE
            };
        }

        var pct = (power * 100) / ftp;
        return {
            :background => powerZoneColor(pct),
            :foreground => powerZoneTextColor(pct)
        };
    }

    function targetZoneForPhase(settings as Dictionary, phase as Number) as Number or Null {
        if ((phase == INTERVAL_PHASE_READY) || (phase == INTERVAL_PHASE_STARTING) || (phase == INTERVAL_PHASE_WORK)) {
            return settings[:workZone];
        }
        if (phase == INTERVAL_PHASE_RECOVERY) {
            return settings[:recoveryZone];
        }
        if (phase == INTERVAL_PHASE_SET_RECOVERY) {
            return settings[:setRecoveryZone];
        }
        return null;
    }

    function startWorkState(currentSet as Number, currentRep as Number, settings as Dictionary) as Dictionary {
        return {
            :phase => INTERVAL_PHASE_WORK,
            :currentSet => currentSet,
            :currentRep => currentRep,
            :remainingMs => settings[:workSecs] * 1000
        };
    }

    function recoveryState(state as Dictionary, settings as Dictionary) as Dictionary {
        return {
            :phase => INTERVAL_PHASE_RECOVERY,
            :currentSet => state[:currentSet],
            :currentRep => state[:currentRep],
            :remainingMs => settings[:recoverySecs] * 1000
        };
    }

    function completeState(state as Dictionary) as Dictionary {
        return {
            :phase => INTERVAL_PHASE_COMPLETE,
            :currentSet => state[:currentSet],
            :currentRep => state[:currentRep],
            :remainingMs => 0
        };
    }

    function nextPhaseState(state as Dictionary, settings as Dictionary) as Dictionary {
        if (state[:phase] == INTERVAL_PHASE_STARTING) {
            return startWorkState(1, 1, settings);
        }

        if (state[:phase] == INTERVAL_PHASE_WORK) {
            var isLastRep = state[:currentRep] >= settings[:repCount];
            var hasNextSet = state[:currentSet] < settings[:setCount];

            if (isLastRep && hasNextSet) {
                if (settings[:setRecoverySecs] > 0) {
                    return {
                        :phase => INTERVAL_PHASE_SET_RECOVERY,
                        :currentSet => state[:currentSet] + 1,
                        :currentRep => 1,
                        :remainingMs => settings[:setRecoverySecs] * 1000
                    };
                }
                return startWorkState(state[:currentSet] + 1, 1, settings);
            }

            return recoveryState(state, settings);
        }

        if (state[:phase] == INTERVAL_PHASE_RECOVERY) {
            if (state[:currentRep] < settings[:repCount]) {
                return startWorkState(state[:currentSet], state[:currentRep] + 1, settings);
            }
            return completeState(state);
        }

        if (state[:phase] == INTERVAL_PHASE_SET_RECOVERY) {
            return startWorkState(state[:currentSet], state[:currentRep], settings);
        }

        return state;
    }

    function isTimedPhase(phase as Number) as Boolean {
        return (phase == INTERVAL_PHASE_STARTING)
            || (phase == INTERVAL_PHASE_WORK)
            || (phase == INTERVAL_PHASE_RECOVERY)
            || (phase == INTERVAL_PHASE_SET_RECOVERY);
    }

    function applyElapsed(state as Dictionary, settings as Dictionary, elapsedMs as Number) as Dictionary {
        var nextState = copySessionState(state);
        var transitions = [];
        var remainingDelta = elapsedMs;

        while ((remainingDelta > 0) && isTimedPhase(nextState[:phase])) {
            if (remainingDelta < nextState[:remainingMs]) {
                nextState[:remainingMs] -= remainingDelta;
                remainingDelta = 0;
            } else {
                remainingDelta -= nextState[:remainingMs];
                nextState = nextPhaseState(nextState, settings);
                transitions.add(nextState[:phase]);
                if (!isTimedPhase(nextState[:phase])) {
                    remainingDelta = 0;
                }
            }
        }

        return {
            :state => nextState,
            :transitions => transitions
        };
    }
}
