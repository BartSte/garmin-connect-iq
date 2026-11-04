import Toybox.Graphics;
import Toybox.Lang;

const MINIMAL7_ZONE2_PCT = 55;
const MINIMAL7_ZONE3_PCT = 75;
const MINIMAL7_ZONE4_PCT = 90;
const MINIMAL7_ZONE5_PCT = 105;
const MINIMAL7_ZONE6_PCT = 120;
const MINIMAL7_ZONE7_PCT = 150;

const MINIMAL7_ZONE1_COLOR = 0xAAAAAA;
const MINIMAL7_ZONE2_COLOR = 0x0000AA;
const MINIMAL7_ZONE3_COLOR = 0x00AA00;
const MINIMAL7_ZONE4_COLOR = 0xFFFF00;
const MINIMAL7_ZONE5_COLOR = 0xFF8800;
const MINIMAL7_ZONE6_COLOR = 0xAA0000;
const MINIMAL7_ZONE7_COLOR = 0x800080;
const MINIMAL7_CADENCE_TARGET_COLOR = 0x00AA00;

module Minimal7Logic {

    function extraPowerSeconds(value as Object or Null) as Number {
        if (value instanceof Number) {
            if (value == 10 || value == 20 || value == 30 || value == 60) {
                return value;
            }
        }
        return 0;
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
        return fallback;
    }

    function valueToFloat(value as Lang.Object or Null, fallback as Float) as Float {
        if (value == null) {
            return fallback;
        }
        if (value instanceof Lang.Float) {
            return value as Lang.Float;
        }
        if (value instanceof Lang.Double) {
            return (value as Lang.Double).toFloat();
        }
        if (value instanceof Lang.Long) {
            return (value as Lang.Long).toFloat();
        }
        if (value instanceof Lang.Number) {
            return (value as Lang.Number).toFloat();
        }
        return fallback;
    }

    function speedToKph(speed as Lang.Object or Null) as Float {
        return valueToFloat(speed, 0.0f) * 3.6f;
    }

    function distanceMetersToKm(distance as Lang.Object or Null) as Float {
        return valueToFloat(distance, 0.0f) / 1000.0f;
    }

    function cadenceTargetBgColor(cadence as Number, cadenceMin as Number, cadenceMax as Number) as Number or Null {
        if ((cadence >= cadenceMin) && (cadence <= cadenceMax)) {
            return MINIMAL7_CADENCE_TARGET_COLOR;
        }
        return null;
    }

    function cadenceTargetFgColor(cadence as Number, cadenceMin as Number, cadenceMax as Number, defaultFg as Number) as Number {
        return (cadenceTargetBgColor(cadence, cadenceMin, cadenceMax) != null)
            ? Graphics.COLOR_BLACK
            : defaultFg;
    }

    function powerZoneColor(pct as Number) as Number {
        if (pct >= MINIMAL7_ZONE7_PCT) { return MINIMAL7_ZONE7_COLOR; }
        if (pct >= MINIMAL7_ZONE6_PCT) { return MINIMAL7_ZONE6_COLOR; }
        if (pct >= MINIMAL7_ZONE5_PCT) { return MINIMAL7_ZONE5_COLOR; }
        if (pct >= MINIMAL7_ZONE4_PCT) { return MINIMAL7_ZONE4_COLOR; }
        if (pct >= MINIMAL7_ZONE3_PCT) { return MINIMAL7_ZONE3_COLOR; }
        if (pct >= MINIMAL7_ZONE2_PCT) { return MINIMAL7_ZONE2_COLOR; }
        return MINIMAL7_ZONE1_COLOR;
    }

    function powerZoneTextColor(pct as Number) as Number {
        if (pct >= MINIMAL7_ZONE6_PCT) { return Graphics.COLOR_WHITE; }
        if (pct >= MINIMAL7_ZONE3_PCT) { return Graphics.COLOR_BLACK; }
        if (pct >= MINIMAL7_ZONE2_PCT) { return Graphics.COLOR_WHITE; }
        return Graphics.COLOR_BLACK;
    }

    function formatTimer(ms as Number) as String {
        var totalSecs = ms / 1000;
        var hours = totalSecs / 3600;
        var minutes = (totalSecs % 3600) / 60;
        var secs = totalSecs % 60;
        if (hours > 0) {
            return hours.format("%d") + ":"
                + minutes.format("%02d") + ":"
                + secs.format("%02d");
        }
        return minutes.format("%d") + ":" + secs.format("%02d");
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
}
