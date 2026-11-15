import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

const INTERVAL_PICKER_PLAIN = 0;
const INTERVAL_PICKER_FTP = 1;
const INTERVAL_PICKER_ZONE = 2;
const INTERVAL_PICKER_SECONDS = 3;

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
        if (kind == INTERVAL_PICKER_SECONDS) {
            return value.format("%02d");
        }
        return value.format("%d");
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

    const PRESET_COUNT = 10;

    function presetKey(slot as Number) as String {
        return "workout_preset_" + slot.format("%d");
    }

    function readPreset(slot as Number) as Array or Null {
        var value = Application.Storage.getValue(presetKey(slot));
        if (!(value instanceof Lang.Array)) {
            return null;
        }
        var preset = value as Array;
        if (preset.size() != 9 || !(preset[0] instanceof Lang.String)) {
            return null;
        }
        for (var i = 1; i < 9; i += 1) {
            if (!(preset[i] instanceof Lang.Number)) {
                return null;
            }
        }
        if ((preset[1] as Number) < 1 || (preset[2] as Number) < 1
            || (preset[3] as Number) < 1 || (preset[4] as Number) < 1
            || (preset[5] as Number) < 0) {
            return null;
        }
        for (var zone = 6; zone < 9; zone += 1) {
            if ((preset[zone] as Number) < 1 || (preset[zone] as Number) > 7) {
                return null;
            }
        }
        return preset;
    }

    function savePreset(slot as Number, name as String) as Void {
        var settings = load();
        Application.Storage.setValue(presetKey(slot), [
            name,
            settings[:setCount],
            settings[:repCount],
            settings[:workSecs],
            settings[:recoverySecs],
            settings[:setRecoverySecs],
            settings[:workZone],
            settings[:recoveryZone],
            settings[:setRecoveryZone]
        ]);
    }

    function renamePreset(slot as Number, name as String) as Void {
        var preset = readPreset(slot);
        if (preset != null) {
            (preset as Array)[0] = name;
            Application.Storage.setValue(presetKey(slot), preset);
        }
    }

    function deletePreset(slot as Number) as Void {
        Application.Storage.deleteValue(presetKey(slot));
    }

    function loadPreset(slot as Number) as Boolean {
        var preset = readPreset(slot);
        if (preset == null) {
            return false;
        }
        var values = preset as Array;
        Application.Properties.setValue("set_count", values[1]);
        Application.Properties.setValue("rep_count", values[2]);
        Application.Properties.setValue("work_value", values[3]);
        Application.Properties.setValue("work_unit", 1);
        Application.Properties.setValue("recovery_value", values[4]);
        Application.Properties.setValue("recovery_unit", 1);
        Application.Properties.setValue("set_recovery_value", values[5]);
        Application.Properties.setValue("set_recovery_unit", 1);
        Application.Properties.setValue("work_zone", values[6]);
        Application.Properties.setValue("recovery_zone", values[7]);
        Application.Properties.setValue("set_recovery_zone", values[8]);
        return true;
    }

    function presetSummary(preset as Array) as String {
        return (preset[1] as Number).format("%d") + "x"
            + (preset[2] as Number).format("%d") + " "
            + IntervalWorkoutLogic.formatDuration(preset[3] as Number) + "/"
            + IntervalWorkoutLogic.formatDuration(preset[4] as Number);
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
        addItem(new WatchUi.MenuItem(Rez.Strings.SavedWorkoutsTitle, null, :saved_workouts, null));
    }

    function refresh() as Void {
        var settings = IntervalWorkoutSettings.load();
        setSettingLabel(:ftp, IntervalWorkoutSettings.formatPickerValue(settings[:ftp], INTERVAL_PICKER_FTP));
        setSettingLabel(:set_count, (settings[:setCount] as Number).format("%d"));
        setSettingLabel(:rep_count, (settings[:repCount] as Number).format("%d"));
        setSettingLabel(:work_duration, IntervalWorkoutLogic.formatDuration(settings[:workSecs]));
        setSettingLabel(:recovery_duration, IntervalWorkoutLogic.formatDuration(settings[:recoverySecs]));
        setSettingLabel(:set_recovery_duration, IntervalWorkoutLogic.formatDuration(settings[:setRecoverySecs]));
        setSettingLabel(:work_zone, IntervalWorkoutLogic.zoneLabel(settings[:workZone]));
        setSettingLabel(:recovery_zone, IntervalWorkoutLogic.zoneLabel(settings[:recoveryZone]));
        setSettingLabel(:set_recovery_zone, IntervalWorkoutLogic.zoneLabel(settings[:setRecoveryZone]));
    }

    hidden function setSettingLabel(id as Lang.Symbol, label as String) as Void {
        var item = getItem(findItemById(id));
        if (item != null) {
            (item as WatchUi.MenuItem).setSubLabel(label);
        }
    }
}

class IntervalWorkoutSettingsMenuDelegate extends WatchUi.Menu2InputDelegate {

    hidden var mApp as IntervalWorkoutApp;
    hidden var mMenu as IntervalWorkoutSettingsMenu;

    function initialize(app as IntervalWorkoutApp, menu as IntervalWorkoutSettingsMenu) {
        Menu2InputDelegate.initialize();
        mApp = app;
        mMenu = menu;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        var settings = IntervalWorkoutSettings.load();

        if (id == :saved_workouts) {
            var presets = new IntervalWorkoutPresetsMenu();
            WatchUi.pushView(presets, new IntervalWorkoutPresetsDelegate(mApp, mMenu, presets), WatchUi.SLIDE_IMMEDIATE);
        } else if (id == :ftp) {
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

class IntervalWorkoutPresetsMenu extends WatchUi.Menu2 {

    function initialize() {
        Menu2.initialize({:title => Rez.Strings.SavedWorkoutsTitle});
        for (var slot = 0; slot < IntervalWorkoutSettings.PRESET_COUNT; slot += 1) {
            addItem(new WatchUi.MenuItem("", null, slot, null));
            refreshSlot(slot);
        }
    }

    function refreshSlot(slot as Number) as Void {
        var item = getItem(slot);
        if (item == null) {
            return;
        }
        var menuItem = item as WatchUi.MenuItem;
        var prefix = (slot + 1).format("%d") + ". ";
        var preset = IntervalWorkoutSettings.readPreset(slot);
        if (preset == null) {
            menuItem.setLabel(prefix + (WatchUi.loadResource(Rez.Strings.EmptyWorkout) as String));
            menuItem.setSubLabel(null);
        } else {
            menuItem.setLabel(prefix + ((preset as Array)[0] as String));
            menuItem.setSubLabel(IntervalWorkoutSettings.presetSummary(preset as Array));
        }
    }
}

class IntervalWorkoutPresetsDelegate extends WatchUi.Menu2InputDelegate {

    hidden var mApp as IntervalWorkoutApp;
    hidden var mRoot as IntervalWorkoutSettingsMenu;
    hidden var mPresets as IntervalWorkoutPresetsMenu;

    function initialize(app as IntervalWorkoutApp, root as IntervalWorkoutSettingsMenu, presets as IntervalWorkoutPresetsMenu) {
        Menu2InputDelegate.initialize();
        mApp = app;
        mRoot = root;
        mPresets = presets;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var slot = item.getId() as Number;
        var actions = new IntervalWorkoutPresetActionsMenu(slot);
        WatchUi.pushView(
            actions,
            new IntervalWorkoutPresetActionsDelegate(mApp, mRoot, mPresets, slot),
            WatchUi.SLIDE_IMMEDIATE
        );
    }
}

class IntervalWorkoutPresetActionsMenu extends WatchUi.Menu2 {

    function initialize(slot as Number) {
        Menu2.initialize({:title => (slot + 1).format("%d")});
        var preset = IntervalWorkoutSettings.readPreset(slot);
        if (preset != null) {
            addItem(new WatchUi.MenuItem(Rez.Strings.LoadWorkout, null, :load, null));
        }
        addItem(new WatchUi.MenuItem(Rez.Strings.SaveCurrentWorkout, null, :save, null));
        if (preset != null) {
            addItem(new WatchUi.MenuItem(Rez.Strings.RenameWorkout, null, :rename, null));
            addItem(new WatchUi.MenuItem(Rez.Strings.DeleteWorkout, null, :delete, null));
        }
    }
}

class IntervalWorkoutPresetActionsDelegate extends WatchUi.Menu2InputDelegate {

    hidden var mApp as IntervalWorkoutApp;
    hidden var mRoot as IntervalWorkoutSettingsMenu;
    hidden var mPresets as IntervalWorkoutPresetsMenu;
    hidden var mSlot as Number;

    function initialize(app as IntervalWorkoutApp, root as IntervalWorkoutSettingsMenu,
                        presets as IntervalWorkoutPresetsMenu, slot as Number) {
        Menu2InputDelegate.initialize();
        mApp = app;
        mRoot = root;
        mPresets = presets;
        mSlot = slot;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :load) {
            if (IntervalWorkoutSettings.loadPreset(mSlot)) {
                mRoot.refresh();
                mApp.reloadSettings();
                WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
                WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            }
        } else if (id == :save) {
            if (IntervalWorkoutSettings.readPreset(mSlot) != null) {
                confirmAction(:save, Rez.Strings.ReplaceWorkoutQuestion);
            } else {
                showNamePicker(:save);
            }
        } else if (id == :rename) {
            showNamePicker(:rename);
        } else if (id == :delete) {
            confirmAction(:delete, Rez.Strings.DeleteWorkoutQuestion);
        }
    }

    function showNamePicker(action as Lang.Symbol) as Void {
        var preset = IntervalWorkoutSettings.readPreset(mSlot);
        var name = "Workout " + (mSlot + 1).format("%d");
        if (preset != null) {
            name = (preset as Array)[0] as String;
        }
        WatchUi.pushView(
            new WatchUi.TextPicker(name),
            new IntervalWorkoutPresetNameDelegate(mPresets, mSlot, action, name),
            WatchUi.SLIDE_IMMEDIATE
        );
    }

    hidden function confirmAction(action as Lang.Symbol, message as Lang.ResourceId) as Void {
        WatchUi.pushView(
            new WatchUi.Confirmation(WatchUi.loadResource(message) as String),
            new IntervalWorkoutPresetConfirmDelegate(mPresets, mSlot, action),
            WatchUi.SLIDE_IMMEDIATE
        );
    }
}

class IntervalWorkoutPresetNameDelegate extends WatchUi.TextPickerDelegate {

    hidden var mPresets as IntervalWorkoutPresetsMenu;
    hidden var mSlot as Number;
    hidden var mAction as Lang.Symbol;
    hidden var mDefaultName as String;

    function initialize(presets as IntervalWorkoutPresetsMenu, slot as Number,
                        action as Lang.Symbol, defaultName as String) {
        TextPickerDelegate.initialize();
        mPresets = presets;
        mSlot = slot;
        mAction = action;
        mDefaultName = defaultName;
    }

    function onTextEntered(name as String, changed as Boolean) as Boolean {
        var finalName = name == "" ? mDefaultName : name;
        if (mAction == :save) {
            IntervalWorkoutSettings.savePreset(mSlot, finalName);
        } else {
            IntervalWorkoutSettings.renamePreset(mSlot, finalName);
        }
        mPresets.refreshSlot(mSlot);
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        WatchUi.requestUpdate();
        return true;
    }

    function onCancel() as Boolean {
        return true;
    }
}

class IntervalWorkoutPresetConfirmDelegate extends WatchUi.ConfirmationDelegate {

    hidden var mPresets as IntervalWorkoutPresetsMenu;
    hidden var mSlot as Number;
    hidden var mAction as Lang.Symbol;

    function initialize(presets as IntervalWorkoutPresetsMenu, slot as Number,
                        action as Lang.Symbol) {
        ConfirmationDelegate.initialize();
        mPresets = presets;
        mSlot = slot;
        mAction = action;
    }

    function onResponse(value as WatchUi.Confirm) as Boolean {
        if (value == WatchUi.CONFIRM_YES) {
            if (mAction == :save) {
                var preset = IntervalWorkoutSettings.readPreset(mSlot);
                if (preset != null) {
                    IntervalWorkoutSettings.savePreset(mSlot, (preset as Array)[0] as String);
                }
            } else {
                IntervalWorkoutSettings.deletePreset(mSlot);
            }
            mPresets.refreshSlot(mSlot);
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            WatchUi.requestUpdate();
        }
        return true;
    }
}
