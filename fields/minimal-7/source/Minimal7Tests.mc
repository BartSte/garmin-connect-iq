import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Test;

(:test)
function minimal7ExtraPowerSettingsRejectInvalidValues(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking extra power settings and upgrade default");
    return Minimal7Logic.extraPowerSeconds(null) == 0
        && Minimal7Logic.extraPowerSeconds(0) == 0
        && Minimal7Logic.extraPowerSeconds(-10) == 0
        && Minimal7Logic.extraPowerSeconds(15) == 0
        && Minimal7Logic.extraPowerSeconds("30") == 0
        && Minimal7Logic.extraPowerSeconds(10) == 10
        && Minimal7Logic.extraPowerSeconds(20) == 20
        && Minimal7Logic.extraPowerSeconds(30) == 30
        && Minimal7Logic.extraPowerSeconds(60) == 60;
}

(:test)
function minimal7ExtraPowerAverageWarmsUp(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking warm-up without synthetic historical samples");
    var average = new Minimal7PowerAverage(30);
    return average.push(210) == 210
        && average.push(240) == 225
        && average.push(300) == 250
        && average.push(0) == 188;
}

(:test)
function minimal7ExtraPowerAverageRollsAllWindows(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking all windows over multiple buffer wraps, including zero power");
    var windows = [10, 20, 30, 60];
    for (var w = 0; w < windows.size(); w += 1) {
        var seconds = windows[w];
        var average = new Minimal7PowerAverage(seconds);
        for (var i = 0; i < seconds; i += 1) {
            if (average.push(300) != 300) {
                return false;
            }
        }
        for (var j = 1; j <= seconds; j += 1) {
            if (average.push(0) != ((seconds - j) * 300 + seconds / 2) / seconds) {
                return false;
            }
        }
        for (var k = 0; k < seconds; k += 1) {
            average.push(240);
        }
        if (average.push(240) != 240) {
            return false;
        }
    }
    return true;
}

(:test)
function minimal7ExtraPowerPickerMapsChoices(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking extra power picker choices and fallback");
    var factory = new Minimal7ExtraPowerPickerFactory();
    var values = [0, 10, 20, 30, 60];
    if (factory.getSize() != values.size() || factory.getIndex(15) != 0) {
        return false;
    }
    for (var i = 0; i < values.size(); i += 1) {
        if (factory.getIndex(values[i]) != i || factory.getValue(i) != values[i]) {
            return false;
        }
    }
    return Minimal7ExtraPowerPickerFactory.formatValue(0) == "Off"
        && Minimal7ExtraPowerPickerFactory.formatValue(30) == "30s";
}

(:test)
function minimal7FormatsShortTimer(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Formatting sub-hour timer");
    return Minimal7Logic.formatTimer(125000).equals("2:05");
}

(:test)
function minimal7FormatsHourTimer(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Formatting hour timer");
    return Minimal7Logic.formatTimer(3723000).equals("1:02:03");
}

(:test)
function minimal7MapsPowerZones(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking power zone color thresholds");
    return Minimal7Logic.powerZoneColor(120) == MINIMAL7_ZONE6_COLOR
        && Minimal7Logic.powerZoneColor(55) == MINIMAL7_ZONE2_COLOR
        && Minimal7Logic.powerZoneColor(10) == MINIMAL7_ZONE1_COLOR;
}

(:test)
function minimal7CadenceHighlighting(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking cadence target range colors");
    return Minimal7Logic.cadenceTargetBgColor(90, 80, 95) == MINIMAL7_CADENCE_TARGET_COLOR
        && Minimal7Logic.cadenceTargetFgColor(90, 80, 95, Graphics.COLOR_WHITE) == Graphics.COLOR_BLACK
        && Minimal7Logic.cadenceTargetBgColor(70, 80, 95) == null;
}

(:test)
function minimal7PowerBufferWarmsUpWithFirstSample(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking initial power buffer warm-up");
    var result = Minimal7Logic.pushPowerSample([0, 0, 0], 0, 0, 210);
    return result[:average] == 210
        && result[:nextIndex] == 1
        && result[:sampleCount] == 1;
}

(:test)
function minimal7PowerBufferRollsAcrossSamples(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking rolling 3-sample average");
    var result1 = Minimal7Logic.pushPowerSample([0, 0, 0], 0, 0, 210);
    var result2 = Minimal7Logic.pushPowerSample(result1[:buffer], result1[:nextIndex], result1[:sampleCount], 240);
    var result3 = Minimal7Logic.pushPowerSample(result2[:buffer], result2[:nextIndex], result2[:sampleCount], 300);
    return result3[:average] == 250
        && result3[:nextIndex] == 0
        && result3[:sampleCount] == 3;
}

(:test)
function minimal7FtpPickerMapsIndexesAndValues(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking FTP picker size and index/value mapping");
    var factory = new Minimal7FtpPickerFactory();
    return factory.getSize() == 551
        && factory.getIndex(50) == 0
        && factory.getIndex(230) == 180
        && factory.getIndex(600) == 550
        && (factory.getValue(0) as Number) == 50
        && (factory.getValue(180) as Number) == 230
        && (factory.getValue(550) as Number) == 600;
}

(:test)
function minimal7FtpPickerClampsInitialValue(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking FTP picker initial-value clamping");
    var factory = new Minimal7FtpPickerFactory();
    return factory.getIndex(49) == 0
        && factory.getIndex(601) == 550;
}
