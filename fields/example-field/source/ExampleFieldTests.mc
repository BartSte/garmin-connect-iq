import Toybox.Lang;
import Toybox.Test;

(:test)
function exampleFieldSpeedToKphConvertsMetersPerSecond(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking km/h conversion for 5.0 m/s");
    return ExampleFieldLogic.speedToKph(5.0f).format("%.1f").equals("18.0");
}

(:test)
function exampleFieldSpeedToKphHandlesNull(logger as Test.Logger) as Lang.Boolean {
    logger.debug("Checking null speed fallback");
    return ExampleFieldLogic.speedToKph(null).format("%.1f").equals("0.0");
}
