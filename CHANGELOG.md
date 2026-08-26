# CHANGELOG

## Indoor Interval Workout

### v0.1.0

- Added a separate indoor interval field for the Garmin Edge Explore 2.
- Added automatic ANT+ FE-C target-power control for work, recovery, and set recovery.
- Required a connected trainer with target-power support before the workout countdown can start.
- Added independent target-power settings with defaults of 280 W, 125 W, and 125 W.
- Sent only the final current phase target when one update crosses multiple phase transitions.
- Restored the current target after a compatible trainer reconnects.
- Released trainer control after cancellation, completion, timer stop, timer reset, or application shutdown.
- Used 0% basic resistance for release and a 0 W target when basic resistance is unavailable.
- Kept FTP-based colors for actual power and the target-power badge.
- Added on-device settings and unit coverage for interval and trainer-control decisions.

## Interval Workout

### v0.2.0

- Replaced lap-to-start with a cancellable five-second touchscreen countdown.
- Removed the `Enable workout` setting; the field remains passive until tapped.
- Added an on-device settings menu for FTP, sets, repetitions, durations, and
  zones that works with USB-sideloaded builds.
- Fixed duration entry on the Edge Explore 2 by selecting minutes and seconds
  in separate steps.
- Changed the fresh-install defaults to FTP 248 W and 4:00 Z1 set recovery.
- Kept existing persisted workout values and duration value/unit properties
  compatible with upgrades.
- Changed the three-second average power row to the exact Minimal-7 FTP-zone
  colors and removed below/in/above-target guidance.
- Added a separately colored requested-zone badge for the upcoming or current
  workout phase.
- Changed non-final set boundaries so set recovery replaces repetition
  recovery; the final repetition recovery still runs before `DONE`.
- Added coverage for threshold blocks, grouped 40/20 VO2 blocks, touchscreen
  control, settings pickers, and zone-color boundaries.

### v0.1.0

- Initial release of the Interval Workout field for the Garmin Edge Explore 2.
- Added phone-configurable workout settings for:
  - enabling or disabling the workout field
  - FTP
  - sets and repetitions
  - work, recovery, and between-set recovery durations
  - work, recovery, and between-set recovery power zones
- Added a bordered 4-row workout layout showing:
  - time of day and ride timer
  - 3s power
  - interval time left and current zone goal
  - set progress and repetition progress
- Added 3-second rolling power guidance with background colors for below target, in target, above target, and unavailable power.
- Added lap-to-start interval execution with support for:
  - indefinite warmup before the first lap
  - single-set and multi-set workouts
  - indefinite cooldown after the workout completes
- Added visual transition alerts and device sounds for workout transitions.
- Kept normal rides unaffected when the field is disabled.
- Fixed zone-threshold handling so exact FTP boundaries are classified into the correct Coggan zone.
- Fixed settings reload behavior so workout settings remain editable during warmup and only lock when the first lap starts the interval session.

## Minimal-7

### v1.2.0

- Numeric fields now use the largest built-in number font that fits their current value while keeping a small cell margin.
- Removed the font-size setting from app settings.
- The cadence field is now green when cadence is between a minimal and a maximal value (default: 80-95 rpm) and white otherwise.

### v1.1.0

- Added a user-configurable FTP setting in the app settings. Default: 230 W.
- Font size can be adjusted to small, medium, or large (default).
- Text now falls back to a smaller built-in font when needed so values stay within their cell bounds.

### V1.0.0

- Initial release of Minimal-7 with the following features:
  - 7 fields: time of day, timer, 3s power, speed, cadence, ascent, and distance.
  - No titles or units are displayed to keep it minimalistic.
  - The background color of the 3s power field changes based on the power zone that can is set in the settings through the user's FTP value (default is 230W).
