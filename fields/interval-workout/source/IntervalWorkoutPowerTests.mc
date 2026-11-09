import Toybox.Activity;
import Toybox.Test;

(:test)
class IntervalPowerTestView extends IntervalWorkout {
    function initialize() {
        IntervalWorkout.initialize();
    }

    function sample(info as Activity.Info) as Void {
        updatePower(info);
    }

    function averageText() as String {
        return powerText(m30sPower);
    }
}

(:test)
function intervalPowerIgnoresMissingReadings(logger as Test.Logger) as Boolean {
    logger.debug("Checking missing power before connection and between valid samples");
    var view = new IntervalPowerTestView();
    var info = new Activity.Info();
    info.currentPower = null;
    for (var i = 0; i < 30; i += 1) {
        view.sample(info);
    }
    if (!view.averageText().equals("--")) { return false; }

    info.currentPower = 300;
    view.sample(info);
    if (!view.averageText().equals("300")) { return false; }

    info.currentPower = null;
    for (var j = 0; j < 30; j += 1) {
        view.sample(info);
    }
    if (!view.averageText().equals("--")) { return false; }

    info.currentPower = 300;
    view.sample(info);
    if (!view.averageText().equals("300")) { return false; }

    // A real zero-watt reading must still enter the average.
    info.currentPower = 0;
    view.sample(info);
    return view.averageText().equals("200");
}
