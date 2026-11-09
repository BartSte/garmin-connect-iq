import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

const INTERVAL_PICKER_PLAIN = 0;
const INTERVAL_PICKER_FTP = 1;
const INTERVAL_PICKER_ZONE = 2;
const INTERVAL_PICKER_SECONDS = 3;
const INTERVAL_PICKER_CADENCE = 4;

module IntervalWorkoutSettings {

    function load() as Dictionary {
        return IntervalWorkoutLogic.normalizeSettings({
            :ftp => Application.Properties.getValue("ftp"),
            :set_count => Application.Properties.getValue("set_count"),
            :rep_count => Application.Properties.getValue("rep_count"),
            :work_value => Application.Properties.getValue("work_value"),
            :work_unit => Application.Properties.getValue("work_unit"),
            :recovery_value => Application.Properties.getValue("recovery_value"),
            :recovery_unit => Application.Properties.getValue("recovery_unit"),
            :set_recovery_value => Application.Properties.getValue("set_recovery_value"),
            :set_recovery_unit => Application.Properties.getValue("set_recovery_unit"),
            :work_zone => Application.Properties.getValue("work_zone"),
            :recovery_zone => Application.Properties.getValue("recovery_zone"),
            :set_recovery_zone => Application.Properties.getValue("set_recovery_zone")
        });
    }

    function formatPickerValue(value as Number, kind as Number) as String {
        if (kind == INTERVAL_PICKER_FTP) {
            return value.format("%d") + " W";
        }
        if (kind == INTERVAL_PICKER_ZONE) {
            return IntervalWorkoutLogic.zoneLabel(value);
        }
        if (kind == INTERVAL_PICKER_CADENCE) {
            return value.format("%d") + " rpm";
        }
        if (kind == INTERVAL_PICKER_SECONDS) {
            return value.format("%02d");
        }
        return value.format("%d");
    }

    function cadenceBounds() as Dictionary {
        return IntervalWorkoutLogic.cadenceBounds(
            Application.Properties.getValue("cadence_min"),
            Application.Properties.getValue("cadence_max")
        );
    }

    function clampDuration(seconds as Number) as Number {
        if (seconds < INTERVAL_MIN_DURATION_SECS) {
            return INTERVAL_MIN_DURATION_SECS;
        }
        if (seconds > INTERVAL_MAX_DURATION_SECS) {
            return INTERVAL_MAX_DURATION_SECS;
        }
        return seconds;
    }

    function durationParts(seconds as Number) as Dictionary {
        var clamped = clampDuration(seconds);
        return {
            :minutes => clamped / 60,
            :seconds => clamped % 60
        };
    }

    function durationFromParts(minutes as Number, seconds as Number) as Number {
        return (minutes * 60) + seconds;
    }

    function durationIsValid(seconds as Number, allowZero as Boolean) as Boolean {
        return allowZero || (seconds > 0);
    }

    function durationPropertyValues(seconds as Number) as Dictionary {
        return {
            :value => seconds,
            :unit => 1
        };
    }
}

class IntervalWorkoutSettingsMenu extends WatchUi.Menu2 {

    function initialize() {
        Menu2.initialize({:title => Rez.Strings.SettingsTitle});

        var settings = IntervalWorkoutSettings.load();
        addItem(new WatchUi.MenuItem(
            Rez.Strings.FtpTitle,
            IntervalWorkoutSettings.formatPickerValue(settings[:ftp], INTERVAL_PICKER_FTP),
            :ftp,
            null
        ));
        addItem(new WatchUi.MenuItem(
            Rez.Strings.SetCountTitle,
            IntervalWorkoutSettings.formatPickerValue(settings[:setCount], INTERVAL_PICKER_PLAIN),
            :set_count,
            null
        ));
        addItem(new WatchUi.MenuItem(
            Rez.Strings.RepCountTitle,
            IntervalWorkoutSettings.formatPickerValue(settings[:repCount], INTERVAL_PICKER_PLAIN),
            :rep_count,
            null
        ));
        addItem(new WatchUi.MenuItem(
            Rez.Strings.WorkValueTitle,
            IntervalWorkoutLogic.formatDuration(settings[:workSecs]),
            :work_duration,
            null
        ));
        addItem(new WatchUi.MenuItem(
            Rez.Strings.WorkZoneTitle,
            IntervalWorkoutSettings.formatPickerValue(settings[:workZone], INTERVAL_PICKER_ZONE),
            :work_zone,
            null
        ));
        addItem(new WatchUi.MenuItem(
            Rez.Strings.RecoveryValueTitle,
            IntervalWorkoutLogic.formatDuration(settings[:recoverySecs]),
            :recovery_duration,
            null
        ));
        addItem(new WatchUi.MenuItem(
            Rez.Strings.RecoveryZoneTitle,
            IntervalWorkoutSettings.formatPickerValue(settings[:recoveryZone], INTERVAL_PICKER_ZONE),
            :recovery_zone,
            null
        ));
        addItem(new WatchUi.MenuItem(
            Rez.Strings.SetRecoveryValueTitle,
            IntervalWorkoutLogic.formatDuration(settings[:setRecoverySecs]),
            :set_recovery_duration,
            null
        ));
        addItem(new WatchUi.MenuItem(
            Rez.Strings.SetRecoveryZoneTitle,
            IntervalWorkoutSettings.formatPickerValue(settings[:setRecoveryZone], INTERVAL_PICKER_ZONE),
            :set_recovery_zone,
            null
        ));
        var cadence = IntervalWorkoutSettings.cadenceBounds();
        addItem(new WatchUi.MenuItem(
            Rez.Strings.CadenceMinTitle,
            IntervalWorkoutSettings.formatPickerValue(cadence[:minimum], INTERVAL_PICKER_CADENCE),
            :cadence_min, null
        ));
        addItem(new WatchUi.MenuItem(
            Rez.Strings.CadenceMaxTitle,
            IntervalWorkoutSettings.formatPickerValue(cadence[:maximum], INTERVAL_PICKER_CADENCE),
            :cadence_max, null
        ));
    }
}

class IntervalWorkoutSettingsMenuDelegate extends WatchUi.Menu2InputDelegate {

    hidden var mApp as IntervalWorkoutApp;

    function initialize(app as IntervalWorkoutApp) {
        Menu2InputDelegate.initialize();
        mApp = app;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        var settings = IntervalWorkoutSettings.load();

        if (id == :ftp) {
            pushSinglePicker(
                Rez.Strings.FtpTitle,
                settings[:ftp],
                INTERVAL_MIN_FTP,
                INTERVAL_MAX_FTP,
                INTERVAL_PICKER_FTP,
                "ftp",
                item
            );
        } else if (id == :set_count) {
            pushSinglePicker(
                Rez.Strings.SetCountTitle,
                settings[:setCount],
                INTERVAL_MIN_SET_COUNT,
                INTERVAL_MAX_SET_COUNT,
                INTERVAL_PICKER_PLAIN,
                "set_count",
                item
            );
        } else if (id == :rep_count) {
            pushSinglePicker(
                Rez.Strings.RepCountTitle,
                settings[:repCount],
                INTERVAL_MIN_REP_COUNT,
                INTERVAL_MAX_REP_COUNT,
                INTERVAL_PICKER_PLAIN,
                "rep_count",
                item
            );
        } else if (id == :work_duration) {
            pushDurationPicker(
                Rez.Strings.WorkValueTitle,
                settings[:workSecs],
                "work_value",
                "work_unit",
                false,
                item
            );
        } else if (id == :work_zone) {
            pushSinglePicker(
                Rez.Strings.WorkZoneTitle,
                settings[:workZone],
                1,
                7,
                INTERVAL_PICKER_ZONE,
                "work_zone",
                item
            );
        } else if (id == :recovery_duration) {
            pushDurationPicker(
                Rez.Strings.RecoveryValueTitle,
                settings[:recoverySecs],
                "recovery_value",
                "recovery_unit",
                false,
                item
            );
        } else if (id == :recovery_zone) {
            pushSinglePicker(
                Rez.Strings.RecoveryZoneTitle,
                settings[:recoveryZone],
                1,
                7,
                INTERVAL_PICKER_ZONE,
                "recovery_zone",
                item
            );
        } else if (id == :set_recovery_duration) {
            pushDurationPicker(
                Rez.Strings.SetRecoveryValueTitle,
                settings[:setRecoverySecs],
                "set_recovery_value",
                "set_recovery_unit",
                true,
                item
            );
        } else if (id == :set_recovery_zone) {
            pushSinglePicker(
                Rez.Strings.SetRecoveryZoneTitle,
                settings[:setRecoveryZone],
                1,
                7,
                INTERVAL_PICKER_ZONE,
                "set_recovery_zone",
                item
            );
        } else if (id == :cadence_min) {
            var cadence = IntervalWorkoutSettings.cadenceBounds();
            pushSinglePicker(
                Rez.Strings.CadenceMinTitle, cadence[:minimum],
                INTERVAL_MIN_CADENCE, cadence[:maximum],
                INTERVAL_PICKER_CADENCE, "cadence_min", item
            );
        } else if (id == :cadence_max) {
            var cadence = IntervalWorkoutSettings.cadenceBounds();
            pushSinglePicker(
                Rez.Strings.CadenceMaxTitle, cadence[:maximum],
                cadence[:minimum], INTERVAL_MAX_CADENCE,
                INTERVAL_PICKER_CADENCE, "cadence_max", item
            );
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }

    hidden function pushSinglePicker(
        title as Lang.ResourceId,
        currentValue as Number,
        minimum as Number,
        maximum as Number,
        kind as Number,
        propertyKey as String,
        item as WatchUi.MenuItem
    ) as Void {
        var factory = new IntervalWorkoutNumberPickerFactory(minimum, maximum, kind);
        WatchUi.pushView(
            new IntervalWorkoutSinglePicker(title, currentValue, factory),
            new IntervalWorkoutSinglePickerDelegate(mApp, propertyKey, kind, item),
            WatchUi.SLIDE_IMMEDIATE
        );
    }

    hidden function pushDurationPicker(
        title as Lang.ResourceId,
        currentSeconds as Number,
        valuePropertyKey as String,
        unitPropertyKey as String,
        allowZero as Boolean,
        item as WatchUi.MenuItem
    ) as Void {
        var picker = new IntervalWorkoutDurationPicker(title, currentSeconds);
        WatchUi.pushView(
            picker,
            new IntervalWorkoutDurationPickerDelegate(
                mApp,
                picker,
                valuePropertyKey,
                unitPropertyKey,
                allowZero,
                item
            ),
            WatchUi.SLIDE_IMMEDIATE
        );
    }
}

class IntervalWorkoutNumberPickerFactory extends WatchUi.PickerFactory {

    hidden var mMinimum as Number;
    hidden var mMaximum as Number;
    hidden var mKind as Number;

    function initialize(minimum as Number, maximum as Number, kind as Number) {
        PickerFactory.initialize();
        mMinimum = minimum;
        mMaximum = maximum;
        mKind = kind;
    }

    function getIndex(value as Number) as Number {
        var clamped = value;
        if (clamped < mMinimum) {
            clamped = mMinimum;
        } else if (clamped > mMaximum) {
            clamped = mMaximum;
        }
        return clamped - mMinimum;
    }

    function getDrawable(index as Number, selected as Boolean) as WatchUi.Drawable or Null {
        var value = getValue(index) as Number;
        return new WatchUi.Text({
            :text => IntervalWorkoutSettings.formatPickerValue(value, mKind),
            :color => Graphics.COLOR_WHITE,
            :font => Graphics.FONT_NUMBER_HOT,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY => WatchUi.LAYOUT_VALIGN_CENTER
        });
    }

    function getValue(index as Number) as Lang.Object or Null {
        return mMinimum + index;
    }

    function getSize() as Number {
        return mMaximum - mMinimum + 1;
    }
}

class IntervalWorkoutSinglePicker extends WatchUi.Picker {

    function initialize(
        titleResource as Lang.ResourceId,
        currentValue as Number,
        factory as IntervalWorkoutNumberPickerFactory
    ) {
        var title = new WatchUi.Text({
            :text => titleResource,
            :color => Graphics.COLOR_WHITE,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY => WatchUi.LAYOUT_VALIGN_BOTTOM
        });

        Picker.initialize({
            :title => title,
            :pattern => [factory],
            :defaults => [factory.getIndex(currentValue)]
        });
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        Picker.onUpdate(dc);
    }
}

class IntervalWorkoutSinglePickerDelegate extends WatchUi.PickerDelegate {

    hidden var mApp as IntervalWorkoutApp;
    hidden var mPropertyKey as String;
    hidden var mKind as Number;
    hidden var mItem as WatchUi.MenuItem;

    function initialize(
        app as IntervalWorkoutApp,
        propertyKey as String,
        kind as Number,
        item as WatchUi.MenuItem
    ) {
        PickerDelegate.initialize();
        mApp = app;
        mPropertyKey = propertyKey;
        mKind = kind;
        mItem = item;
    }

    function onCancel() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    function onAccept(values as Array) as Boolean {
        var value = values[0];
        if (value instanceof Lang.Number) {
            var numberValue = value as Lang.Number;
            Application.Properties.setValue(mPropertyKey, numberValue);
            mItem.setSubLabel(IntervalWorkoutSettings.formatPickerValue(numberValue, mKind));
            mApp.reloadSettings();
        }

        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        WatchUi.requestUpdate();
        return true;
    }
}

class IntervalWorkoutDurationPicker extends WatchUi.Picker {

    hidden var mTitleResource as Lang.ResourceId;
    hidden var mInitialSeconds as Number;

    function initialize(titleResource as Lang.ResourceId, currentSeconds as Number) {
        mTitleResource = titleResource;
        mInitialSeconds = currentSeconds;

        var minuteFactory = new IntervalWorkoutNumberPickerFactory(0, 120, INTERVAL_PICKER_PLAIN);
        var parts = IntervalWorkoutSettings.durationParts(currentSeconds);

        Picker.initialize({
            :title => durationPartTitle(Rez.Strings.MinutesOption),
            :pattern => [minuteFactory],
            :defaults => [minuteFactory.getIndex(parts[:minutes])]
        });
    }

    function showSeconds() as Void {
        var secondFactory = new IntervalWorkoutNumberPickerFactory(0, 59, INTERVAL_PICKER_SECONDS);
        var parts = IntervalWorkoutSettings.durationParts(mInitialSeconds);

        Picker.setOptions({
            :title => durationPartTitle(Rez.Strings.SecondsOption),
            :pattern => [secondFactory],
            :defaults => [secondFactory.getIndex(parts[:seconds])]
        });
    }

    hidden function durationPartTitle(partResource as Lang.ResourceId) as WatchUi.Text {
        var titleText = WatchUi.loadResource(mTitleResource) as String;
        var partText = WatchUi.loadResource(partResource) as String;
        return new WatchUi.Text({
            :text => titleText + " - " + partText,
            :color => Graphics.COLOR_WHITE,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY => WatchUi.LAYOUT_VALIGN_BOTTOM
        });
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        Picker.onUpdate(dc);
    }
}

class IntervalWorkoutDurationPickerDelegate extends WatchUi.PickerDelegate {

    hidden var mApp as IntervalWorkoutApp;
    hidden var mPicker as IntervalWorkoutDurationPicker;
    hidden var mValuePropertyKey as String;
    hidden var mUnitPropertyKey as String;
    hidden var mAllowZero as Boolean;
    hidden var mItem as WatchUi.MenuItem;
    hidden var mMinutes as Number or Null;

    function initialize(
        app as IntervalWorkoutApp,
        picker as IntervalWorkoutDurationPicker,
        valuePropertyKey as String,
        unitPropertyKey as String,
        allowZero as Boolean,
        item as WatchUi.MenuItem
    ) {
        PickerDelegate.initialize();
        mApp = app;
        mPicker = picker;
        mValuePropertyKey = valuePropertyKey;
        mUnitPropertyKey = unitPropertyKey;
        mAllowZero = allowZero;
        mItem = item;
        mMinutes = null;
    }

    function onCancel() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    function onAccept(values as Array) as Boolean {
        var selectedValue = values[0];
        if (!(selectedValue instanceof Lang.Number)) {
            return true;
        }

        if (mMinutes == null) {
            mMinutes = selectedValue as Lang.Number;
            mPicker.showSeconds();
            WatchUi.requestUpdate();
            return true;
        }

        var totalSeconds = IntervalWorkoutSettings.durationFromParts(
            mMinutes as Number,
            selectedValue as Lang.Number
        );
        if (!IntervalWorkoutSettings.durationIsValid(totalSeconds, mAllowZero)) {
            WatchUi.pushView(
                new WatchUi.Confirmation(
                    WatchUi.loadResource(Rez.Strings.DurationMustBePositive) as String
                ),
                new IntervalWorkoutInvalidDurationDelegate(),
                WatchUi.SLIDE_IMMEDIATE
            );
            return true;
        }

        var propertyValues = IntervalWorkoutSettings.durationPropertyValues(totalSeconds);
        Application.Properties.setValue(mValuePropertyKey, propertyValues[:value]);
        Application.Properties.setValue(mUnitPropertyKey, propertyValues[:unit]);
        mItem.setSubLabel(IntervalWorkoutLogic.formatDuration(totalSeconds));
        mApp.reloadSettings();

        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        WatchUi.requestUpdate();
        return true;
    }
}

class IntervalWorkoutInvalidDurationDelegate extends WatchUi.ConfirmationDelegate {

    function initialize() {
        ConfirmationDelegate.initialize();
    }

    function onResponse(value as WatchUi.Confirm) as Boolean {
        return true;
    }
}
