import Toybox.AntPlus;
import Toybox.Lang;

class IndoorTrainerController {

    hidden var mEquipment as AntPlus.FitnessEquipment or Null = null;
    hidden var mLastPhase as Number = INTERVAL_PHASE_INVALID;
    hidden var mLastTarget as Number or Null = null;
    hidden var mControlsTrainer as Boolean = false;
    hidden var mReleasePending as Boolean = false;
    hidden var mWasTracking as Boolean = false;

    function initialize() {
        // Subscribe before the first tap so trainer data can arrive during warmup.
        getEquipment();
    }

    function canStart() as Boolean {
        var equipment = getEquipment();
        if (equipment == null) {
            return false;
        }

        if (mReleasePending) {
            release();
            if (mReleasePending) {
                return false;
            }
        }

        var connectedEquipment = equipment as AntPlus.FitnessEquipment;
        var tracking = isTracking(connectedEquipment);
        var mode = trainerMode(connectedEquipment);
        var targetPowerSupported = (mode == null) ? null : mode.targetPowerSupported;
        return IntervalWorkoutLogic.trainerCanStart(tracking, targetPowerSupported);
    }

    function update(
        settings as Dictionary,
        phase as Number,
        controlAllowed as Boolean,
        forceTarget as Boolean,
        intensity as Number
    ) as Void {
        var target = IntervalWorkoutLogic.controlledPowerForPhase(settings, phase);
        if (!controlAllowed || (target == null)) {
            release();
            return;
        }

        var equipment = getEquipment();
        if (equipment == null) {
            mWasTracking = false;
            return;
        }

        var connectedEquipment = equipment as AntPlus.FitnessEquipment;
        var tracking = isTracking(connectedEquipment);
        if (!tracking) {
            mWasTracking = false;
            return;
        }

        var mode = trainerMode(connectedEquipment);
        var targetPowerSupported = (mode == null) ? null : mode.targetPowerSupported;
        if (!IntervalWorkoutLogic.trainerCanStart(tracking, targetPowerSupported)) {
            // Capabilities can disappear during reconnection before the device
            // reports a tracking-state change. Resend when they become valid.
            mWasTracking = false;
            return;
        }

        var targetPower = IntervalWorkoutLogic.scaledPower(target as Number, intensity);
        var targetChanged = (mLastTarget == null) || ((mLastTarget as Number) != targetPower);
        var phaseChanged = mLastPhase != phase;
        if (!forceTarget && mControlsTrainer && mWasTracking && !targetChanged && !phaseChanged) {
            return;
        }

        try {
            connectedEquipment.controlEquipment(
                AntPlus.TRAINER_TARGET_POWER,
                targetPower.toFloat()
            );
            mLastPhase = phase;
            mLastTarget = targetPower;
            mControlsTrainer = true;
            mReleasePending = false;
            mWasTracking = true;
        } catch (error) {
            // Keep a failed resend pending even when its phase and target match
            // the last successful command before the connection was lost.
            mWasTracking = false;
        }
    }

    function release() as Void {
        if (!mControlsTrainer && !mReleasePending) {
            clearTargetState();
            return;
        }

        mReleasePending = true;
        var equipment = mEquipment;
        if (equipment == null) {
            return;
        }

        var connectedEquipment = equipment as AntPlus.FitnessEquipment;
        if (!isTracking(connectedEquipment)) {
            mWasTracking = false;
            return;
        }

        var mode = trainerMode(connectedEquipment);
        if (mode == null) {
            return;
        }

        var action = IntervalWorkoutLogic.trainerReleaseAction(
            mode.basicResistanceSupported,
            mode.targetPowerSupported
        );
        if (action == INTERVAL_TRAINER_RELEASE_NONE) {
            return;
        }

        try {
            if (action == INTERVAL_TRAINER_RELEASE_BASIC) {
                connectedEquipment.controlEquipment(AntPlus.TRAINER_RESISTANCE, 0.0f);
            } else {
                connectedEquipment.controlEquipment(AntPlus.TRAINER_TARGET_POWER, 0.0f);
            }
            mControlsTrainer = false;
            mReleasePending = false;
            mWasTracking = true;
            clearTargetState();
        } catch (error) {
        }
    }

    function shutdown() as Void {
        release();
    }

    hidden function getEquipment() as AntPlus.FitnessEquipment or Null {
        if (mEquipment != null) {
            return mEquipment;
        }

        try {
            mEquipment = new AntPlus.FitnessEquipment(null);
        } catch (error) {
            mEquipment = null;
        }
        return mEquipment;
    }

    hidden function isTracking(equipment as AntPlus.FitnessEquipment) as Boolean {
        try {
            var deviceState = equipment.getDeviceState();
            return (deviceState.state != null)
                && ((deviceState.state as Number) == AntPlus.DEVICE_STATE_TRACKING);
        } catch (error) {
            return false;
        }
    }

    hidden function trainerMode(
        equipment as AntPlus.FitnessEquipment
    ) as AntPlus.FitnessEquipmentMode or Null {
        try {
            return equipment.getTrainerMode();
        } catch (error) {
            return null;
        }
    }

    hidden function clearTargetState() as Void {
        mLastPhase = INTERVAL_PHASE_INVALID;
        mLastTarget = null;
    }
}
