import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class IntervalWorkoutApp extends Application.AppBase {

    hidden var mView as IntervalWorkout or Null;

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        mView = new IntervalWorkout();
        return [
            mView as IntervalWorkout,
            new IntervalWorkoutInputDelegate(mView as IntervalWorkout)
        ];
    }

    function getSettingsView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] or Null {
        var menu = new IntervalWorkoutSettingsMenu();
        return [menu, new IntervalWorkoutSettingsMenuDelegate(self)];
    }

    function onStop(state as Dictionary?) as Void {
        if (mView != null) {
            (mView as IntervalWorkout).releaseTrainer();
        }
    }

    function onSettingsChanged() as Void {
        reloadSettings();
    }

    function reloadSettings() as Void {
        if (mView != null) {
            (mView as IntervalWorkout).handleSettingsChanged();
        }
        WatchUi.requestUpdate();
    }
}

class IntervalWorkoutInputDelegate extends WatchUi.BehaviorDelegate {

    hidden var mView as IntervalWorkout;

    function initialize(view as IntervalWorkout) {
        BehaviorDelegate.initialize();
        mView = view;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        return mView.handleTap();
    }
}
