import Toybox.AntPlus;
import Toybox.Lang;
import Toybox.Test;

(:test)
class IndoorFakeEquipment extends AntPlus.FitnessEquipment {
    var tracking as Boolean = true;
    var powerSupported as Boolean or Null = true;
    var failNext as Boolean = false;
    var commands as Number = 0;
    var lastSetting as Number or Null = null;
    var lastValue as Float or Number or Null = null;

    function initialize() {
        FitnessEquipment.initialize(null);
    }

    function getDeviceState() as AntPlus.DeviceState {
        var state = new AntPlus.DeviceState();
        state.state = tracking ? AntPlus.DEVICE_STATE_TRACKING : AntPlus.DEVICE_STATE_CLOSED;
        return state;
    }

    function getTrainerMode() as AntPlus.FitnessEquipmentMode {
        var mode = new AntPlus.FitnessEquipmentMode();
        mode.targetPowerSupported = powerSupported;
        mode.basicResistanceSupported = true;
        return mode;
    }

    function controlEquipment(setting as AntPlus.TrainerValue, data as Float or AntPlus.TrainerMode) as Void {
        commands += 1;
        if (failNext) {
            failNext = false;
            throw new Lang.InvalidValueException("Simulated trainer command failure");
        }
        lastSetting = setting;
        lastValue = data;
    }
}

(:test)
class IndoorControllerUnderTest extends IndoorTrainerController {
    function initialize(equipment as IndoorFakeEquipment) {
        mEquipment = equipment;
        IndoorTrainerController.initialize();
    }
}

(:test)
function indoorTrainerRetriesFailedReconnectTarget(logger as Test.Logger) as Boolean {
    var equipment = new IndoorFakeEquipment();
    var controller = new IndoorControllerUnderTest(equipment);
    var settings = IntervalWorkoutLogic.defaultSettings();
    controller.update(settings, INTERVAL_PHASE_WORK, true, false, 101);
    equipment.tracking = false;
    controller.update(settings, INTERVAL_PHASE_WORK, true, false, 101);
    equipment.tracking = true;
    equipment.failNext = true;
    controller.update(settings, INTERVAL_PHASE_WORK, true, false, 101);
    if (equipment.commands != 2) { return false; }
    controller.update(settings, INTERVAL_PHASE_WORK, true, false, 101);
    if ((equipment.commands != 3) || (equipment.lastValue != 283.0f)) { return false; }
    controller.update(settings, INTERVAL_PHASE_WORK, true, false, 101);
    return equipment.commands == 3;
}

(:test)
function indoorTrainerResendsAfterUnknownCapabilities(logger as Test.Logger) as Boolean {
    var equipment = new IndoorFakeEquipment();
    var controller = new IndoorControllerUnderTest(equipment);
    var settings = IntervalWorkoutLogic.defaultSettings();
    controller.update(settings, INTERVAL_PHASE_WORK, true, false, 100);
    equipment.powerSupported = null;
    controller.update(settings, INTERVAL_PHASE_WORK, true, false, 100);
    equipment.powerSupported = true;
    controller.update(settings, INTERVAL_PHASE_WORK, true, false, 100);
    return (equipment.commands == 2) && (equipment.lastValue == 280.0f);
}

(:test)
function indoorTrainerReleasesOnlyAfterCooldownAndRetriesRelease(logger as Test.Logger) as Boolean {
    var equipment = new IndoorFakeEquipment();
    var controller = new IndoorControllerUnderTest(equipment);
    var settings = IntervalWorkoutLogic.defaultSettings();
    controller.update(settings, INTERVAL_PHASE_COOLDOWN, true, false, 99);
    if ((equipment.commands != 1) || (equipment.lastValue != 124.0f)) { return false; }
    equipment.failNext = true;
    controller.update(settings, INTERVAL_PHASE_COMPLETE, true, false, 99);
    controller.update(settings, INTERVAL_PHASE_COMPLETE, true, false, 99);
    if ((equipment.commands != 3) || (equipment.lastSetting != AntPlus.TRAINER_RESISTANCE)
        || (equipment.lastValue != 0.0f)) { return false; }
    controller.update(settings, INTERVAL_PHASE_COMPLETE, true, false, 99);
    return equipment.commands == 3;
}
