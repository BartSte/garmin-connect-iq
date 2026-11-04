import Toybox.Application;
import Toybox.WatchUi;

class ExampleFieldApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        return [new ExampleField()];
    }
}
