import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

const MINIMAL7_DEFAULT_FTP = 248;
const MINIMAL7_MIN_FTP = 50;
const MINIMAL7_MAX_FTP = 600;

class Minimal7SettingsView extends WatchUi.Menu2 {

    function initialize() {
        Menu2.initialize({:title => Rez.Strings.SettingsTitle});
        var currentFtp = Minimal7Logic.valueToNumber(
            Application.Properties.getValue("ftp"),
            MINIMAL7_DEFAULT_FTP
        );

        addItem(new WatchUi.MenuItem(Rez.Strings.FtpTitle, currentFtp.format("%d") + " W", :ftp, null));
        var seconds = Minimal7Logic.extraPowerSeconds(Application.Properties.getValue("extra_power_seconds"));
        addItem(new WatchUi.MenuItem(
            Rez.Strings.ExtraPowerTitle,
            Minimal7ExtraPowerPickerFactory.formatValue(seconds),
            :extra_power_seconds,
            null
        ));
    }
}

class Minimal7SettingsDelegate extends WatchUi.Menu2InputDelegate {

    hidden var mApp as Minimal7App;

    function initialize(app as Minimal7App) {
        Menu2InputDelegate.initialize();
        mApp = app;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        if (item.getId() == :ftp) {
            WatchUi.pushView(
                new Minimal7FtpPicker(),
                new Minimal7FtpPickerDelegate(mApp, item),
                WatchUi.SLIDE_IMMEDIATE
            );
        } else if (item.getId() == :extra_power_seconds) {
            WatchUi.pushView(
                new Minimal7ExtraPowerPicker(),
                new Minimal7ExtraPowerPickerDelegate(mApp, item),
                WatchUi.SLIDE_IMMEDIATE
            );
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}

class Minimal7FtpPickerFactory extends WatchUi.PickerFactory {

    function initialize() {
        PickerFactory.initialize();
    }

    function getIndex(value as Number) as Number {
        var clampedValue = value;
        if (clampedValue < MINIMAL7_MIN_FTP) {
            clampedValue = MINIMAL7_MIN_FTP;
        } else if (clampedValue > MINIMAL7_MAX_FTP) {
            clampedValue = MINIMAL7_MAX_FTP;
        }
        return clampedValue - MINIMAL7_MIN_FTP;
    }

    function getDrawable(index as Number, selected as Boolean) as WatchUi.Drawable or Null {
        var value = getValue(index) as Number;
        return new WatchUi.Text({
            :text => value.format("%d") + " W",
            :color => Graphics.COLOR_WHITE,
            :font => Graphics.FONT_NUMBER_HOT,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY => WatchUi.LAYOUT_VALIGN_CENTER
        });
    }

    function getValue(index as Number) as Lang.Object or Null {
        return MINIMAL7_MIN_FTP + index;
    }

    function getSize() as Number {
        return MINIMAL7_MAX_FTP - MINIMAL7_MIN_FTP + 1;
    }
}

class Minimal7FtpPicker extends WatchUi.Picker {

    function initialize() {
        var factory = new Minimal7FtpPickerFactory();
        var currentFtp = Minimal7Logic.valueToNumber(
            Application.Properties.getValue("ftp"),
            MINIMAL7_DEFAULT_FTP
        );
        var title = new WatchUi.Text({
            :text => Rez.Strings.FtpTitle,
            :color => Graphics.COLOR_WHITE,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY => WatchUi.LAYOUT_VALIGN_BOTTOM
        });

        Picker.initialize({
            :title => title,
            :pattern => [factory],
            :defaults => [factory.getIndex(currentFtp)]
        });
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        Picker.onUpdate(dc);
    }
}

class Minimal7FtpPickerDelegate extends WatchUi.PickerDelegate {

    hidden var mApp as Minimal7App;
    hidden var mItem as WatchUi.MenuItem;

    function initialize(app as Minimal7App, item as WatchUi.MenuItem) {
        PickerDelegate.initialize();
        mApp = app;
        mItem = item;
    }

    function onCancel() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    function onAccept(values as Array) as Boolean {
        var value = values[0];
        if (value instanceof Lang.Number) {
            Application.Properties.setValue("ftp", value);
            mItem.setSubLabel(value.format("%d") + " W");
            mApp.reloadSettings();
        }

        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        WatchUi.requestUpdate();
        return true;
    }
}

class Minimal7ExtraPowerPickerFactory extends WatchUi.PickerFactory {

    hidden var mValues as Array<Number> = [0, 10, 20, 30, 60];

    function initialize() {
        PickerFactory.initialize();
    }

    static function formatValue(seconds as Number) as String {
        return seconds == 0 ? WatchUi.loadResource(Rez.Strings.OffOption) as String : seconds.format("%d") + "s";
    }

    function getIndex(value as Number) as Number {
        for (var i = 0; i < mValues.size(); i += 1) {
            if (mValues[i] == value) {
                return i;
            }
        }
        return 0;
    }

    function getDrawable(index as Number, selected as Boolean) as WatchUi.Drawable or Null {
        return new WatchUi.Text({
            :text => formatValue(mValues[index]),
            :color => Graphics.COLOR_WHITE,
            :font => Graphics.FONT_NUMBER_HOT,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY => WatchUi.LAYOUT_VALIGN_CENTER
        });
    }

    function getValue(index as Number) as Lang.Object or Null {
        return mValues[index];
    }

    function getSize() as Number {
        return mValues.size();
    }
}

class Minimal7ExtraPowerPicker extends WatchUi.Picker {

    function initialize() {
        var factory = new Minimal7ExtraPowerPickerFactory();
        var seconds = Minimal7Logic.extraPowerSeconds(Application.Properties.getValue("extra_power_seconds"));
        Picker.initialize({
            :title => new WatchUi.Text({
                :text => Rez.Strings.ExtraPowerTitle,
                :color => Graphics.COLOR_WHITE,
                :locX => WatchUi.LAYOUT_HALIGN_CENTER,
                :locY => WatchUi.LAYOUT_VALIGN_BOTTOM
            }),
            :pattern => [factory],
            :defaults => [factory.getIndex(seconds)]
        });
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        Picker.onUpdate(dc);
    }
}

class Minimal7ExtraPowerPickerDelegate extends WatchUi.PickerDelegate {

    hidden var mApp as Minimal7App;
    hidden var mItem as WatchUi.MenuItem;

    function initialize(app as Minimal7App, item as WatchUi.MenuItem) {
        PickerDelegate.initialize();
        mApp = app;
        mItem = item;
    }

    function onCancel() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    function onAccept(values as Array) as Boolean {
        var seconds = Minimal7Logic.extraPowerSeconds(values[0]);
        Application.Properties.setValue("extra_power_seconds", seconds);
        mItem.setSubLabel(Minimal7ExtraPowerPickerFactory.formatValue(seconds));
        mApp.reloadSettings();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        WatchUi.requestUpdate();
        return true;
    }
}
