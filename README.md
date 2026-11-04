# garmin-connect-fields

Custom Connect IQ data fields for the **Garmin Edge Explore 2**, written in [Monkey C](https://developer.garmin.com/connect-iq/overview/).

## Repository layout

```
fields/
└── <field-name>/
    ├── manifest.xml          # app metadata & target device
    ├── monkey.jungle         # build configuration
    ├── source/               # Monkey C source files (.mc)
    └── resources/
        ├── strings/          # localised strings
        └── properties.xml    # user-configurable settings (optional)
```

Each subdirectory under `fields/` is a self-contained Connect IQ project that can be opened, built, and deployed independently.

## Data fields

| Folder                        | Description                                                                                                               |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `minimal-7`                   | Full-screen field: time, timer, 3s power (zone color), speed, cadence, ascent, distance                                   |
| `interval-workout`            | Full-screen interval-training field: touch start, zone-colored 3s power, requested zone, countdown, and set/rep progress |
| `indoor-interval-workout`     | Indoor interval field with automatic ANT+ FE-C target-power control                                                       |
| `example-field`               | Starter template – displays current speed in km/h                                                                         |

## Getting started

1. Install the [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) and VS Code extension (or Eclipse plugin).
2. Open a field folder (e.g. `fields/example-field`) as your project root.
3. Build with `monkeyc` or use the IDE's **Run** action against the Edge Explore 2 simulator.
4. For these private fields, copy the generated `.prg` to `Garmin/Apps/` on the Edge over USB.

### Development on Arch Linux and WSL

The simulator runs in an Ubuntu 22.04 container. This container supplies the
WebKitGTK 4.0 libraries and full Java runtime required by the SDK.
The SDK, Edge Explore 2 definitions, fonts, and signing key must exist on the host.
The required SDK version is in `.ciq-sdk-version`.

Build the container image after changes to `scripts/Dockerfile.simulator`:

```bash
./scripts/dev.sh image
```

Run all unit tests on the Edge Explore 2 simulator:

```bash
./scripts/dev.sh test
```

This command starts a separate simulator with a virtual display. It waits for
the simulator, runs the tests, and removes the container afterward.
Each field has a 120-second timeout for test execution. Set `TEST_TIMEOUT` when
using `scripts/test-fields.sh` directly to change this limit.

Open the visible simulator:

```bash
./scripts/dev.sh simulator
```

In another terminal, compile and load a field:

```bash
./scripts/dev.sh run minimal-7
# Or:
./scripts/dev.sh run interval-workout
```

Create a release build for installation on the Edge:

```bash
./scripts/dev.sh build minimal-7
```

The output is `fields/minimal-7/bin/minimal-7-edgeexplore2.prg`.
Copy this file to `Garmin/Apps/` on the connected Edge. Then disconnect the Edge
and select the data field in the activity profile.

The script uses Docker directly when socket access is available. In WSL, it can
also use `wsl.exe` to run Docker as root in the current distribution.
The application inside the container runs with your user ID.
Do not mount the host `/etc/passwd` or `/etc/group` into the container.

The visible simulator needs WSLg or another X11 display. The test command uses
Xvfb and does not need a visible display.

### Linux setup

This repo includes bootstrap scripts for the two Linux distros requested here:

```bash
# Ubuntu
./scripts/setup-ubuntu.sh

# Arch Linux
./scripts/setup-arch.sh
```

What the scripts do:

- install the base OS packages required here (`curl`, `unzip`, `openssl`, Java runtime, etc.)
- install [`connect-iq-sdk-manager`](https://github.com/lindell/connect-iq-sdk-manager-cli)
- add both `~/.local/bin` and the active Connect IQ SDK `bin` directory to your shell startup files
- accept the Garmin SDK agreement interactively
- download and activate the Connect IQ SDK version in `.ciq-sdk-version`
- download device definitions and simulator fonts for every `fields/*/manifest.xml` in this repo

The scripts assume:

- `sudo` is available
- you will complete the Garmin login flow when `connect-iq-sdk-manager login` prompts for it
- you will generate or provide your own `developer_key.der` for signed builds

## Interval workout field

`fields/interval-workout` is a full-screen training field for structured intervals on the **Edge Explore 2**.

Behavior:

- configure FTP, sets, repetitions, durations, and requested zones directly in
  the field's settings on the Edge
- start the activity timer and warm up for as long as needed
- tap the field once when it shows `TAP` to begin a five-second countdown; tap
  again during that countdown to cancel
- pause the activity timer to freeze the countdown or current interval
- continue riding normally after the final recovery reaches `DONE`

The workout remains passive until it is tapped, so there is no `Enable workout`
setting. Lap and auto-lap events do not start or advance it.

The large three-second power row uses the same actual FTP-zone colors as
Minimal-7. The right-hand badge below it shows the requested zone for the
upcoming or current phase in that zone's color. It is guidance by zone only;
there is no below/in/above-target coloring.

Within a set, each work interval is followed by repetition recovery. After the
last repetition of a non-final set, set recovery replaces repetition recovery.
The last work interval of the workout still includes its normal repetition
recovery before `DONE`.

Example settings:

- threshold blocks `3 × (20m Z4 + 5m Z1)`: 1 set, 3 repetitions, 20:00 Z4
  work, 5:00 Z1 repetition recovery, and 0:00 set recovery
- VO2 blocks `3 × (10 × (40s Z5 + 20s Z1) + 4m Z1)`: 3 sets, 10
  repetitions, 0:40 Z5 work, 0:20 Z1 repetition recovery, and 4:00 Z1 set
  recovery

### Interval Workout on-device settings

The settings UI is compiled into the `.prg`, so it works when the app is
manually sideloaded and does not depend on the Connect IQ Store, Garmin Connect,
or Garmin Express.

1. Build `fields/interval-workout/bin/interval-workout-edgeexplore2.prg`.
2. Copy the `.prg` to `Garmin/Apps/` on the Edge over USB.
3. Disconnect the Edge and open the Connect IQ data-field settings for Interval
   Workout from the activity profile.
4. Select a setting, choose its value, and accept it.

For a duration, first select and accept the minutes, then select and accept the
seconds. The settings menu shows the combined duration, such as `15:00`.

Accepted values are stored in the app's local properties and persist across
device restarts. Further changes need no rebuild, phone synchronization, or USB
connection. Cancelling a picker preserves its old value. Changes made during a
running workout are used after the activity is reset; they do not alter the
locked session.

Keep the UUID in `fields/interval-workout/manifest.xml` unchanged when replacing
the sideloaded `.prg` so the new build continues to use the existing property
storage. Existing phone/Store-style XML settings remain supported as an
alternative.

## Indoor interval workout field

`fields/indoor-interval-workout` is a separate field for indoor ERG workouts.
It keeps the schedule, touchscreen controls, alerts, and layout from the
outdoor interval field.

Start the activity timer with the Edge Start/Stop button. The field shows
`START TIMER` until the timer runs. Then tap the field at `TAP` to start the
five-second workout countdown. A data field cannot start the activity timer.

A connected ANT+ FE-C trainer must support target-power mode. If the trainer
is unavailable, tapping the field shows `NO TRAINER` in the field. The countdown
does not start. The field also shows a `NO ERG TRAINER` alert when Connect IQ
alerts are enabled for this field in the activity settings. The status returns
to `TAP` when the trainer becomes ready.

The settings contain separate power targets for work, repetition recovery, and
recovery between sets. The default target values are 280 W, 125 W, and 125 W.
FTP controls the colors for actual power and the target-power badge.

Warm-up and cool-down each have a duration and a target power. Both durations
default to `0:00`, which skips the phase. Both target powers default to 125 W.
The sequence is countdown, warm-up, intervals, final repetition recovery,
cool-down, then `DONE`. The field shows `WARM-UP` or `COOL-DOWN` during those
phases. Settings changes during a workout apply after the activity resets.

After each update, the field sends no more than one trainer command. If the
update crosses multiple phases, it sends the target for the final current
phase. The field sends the current target again after the trainer reconnects.

A timer pause keeps the current target. Cancellation, completion, timer stop,
timer reset, and application shutdown release trainer control. The preferred
release mode is 0% basic resistance. The fallback target is 0 W.

### Indoor workout settings

The on-device settings menu works without the Connect IQ Store, Garmin
Connect, or Garmin Express.

1. Build `fields/indoor-interval-workout/bin/indoor-interval-workout-edgeexplore2.prg`.
2. Copy the `.prg` to `Garmin/Apps/` on the Edge over USB.
3. Pair and connect the ANT+ FE-C trainer in the Edge sensor settings.
4. Open the data-field settings for Indoor Interval Workout.
5. Set the FTP, schedule, durations, and phase power targets.
6. Set the warm-up and cool-down durations and power targets.
   To skip either phase, set its duration to `0:00`.

The accepted values remain in the local property storage. Keep the application
UUID unchanged when you replace the sideloaded `.prg`.

## Minimal-7 FTP setting

Minimal-7 exposes its FTP setting directly on the Edge Explore 2. This works for
the manually sideloaded build and does not require the Connect IQ Store, Garmin
Connect, or Garmin Express.

1. Build `fields/minimal-7/bin/minimal-7-edgeexplore2.prg`.
2. Connect the Edge over USB and copy the `.prg` to `Garmin/Apps/`.
3. Disconnect the Edge and open the Connect IQ data-field settings for Minimal-7
   from the activity profile.
4. Tap the FTP screen, scroll to a value from 50 W through 600 W, and accept it.

The accepted FTP is stored in the app's local properties and remains available
after the Edge restarts. Further FTP changes happen entirely on the Edge; they do
not require another build, phone synchronization, or USB connection. Keep the
application UUID in `fields/minimal-7/manifest.xml` unchanged when rebuilding so
the new `.prg` uses the same property storage.

### Build a field

Both current fields target `edgeexplore2`, so a local build looks like this:

```bash
mkdir -p fields/example-field/bin

monkeyc \
  -f fields/example-field/monkey.jungle \
  -o fields/example-field/bin/example-field-edgeexplore2.prg \
  -y developer_key.der \
  -d edgeexplore2 \
  -r \
  -w
```

To build `minimal-7`:

```bash
mkdir -p fields/minimal-7/bin

monkeyc \
  -f fields/minimal-7/monkey.jungle \
  -o fields/minimal-7/bin/minimal-7-edgeexplore2.prg \
  -y developer_key.der \
  -d edgeexplore2 \
  -r \
  -w
```

For `interval-workout`:

```bash
mkdir -p fields/interval-workout/bin

monkeyc \
  -f fields/interval-workout/monkey.jungle \
  -o fields/interval-workout/bin/interval-workout-edgeexplore2.prg \
  -y developer_key.der \
  -d edgeexplore2 \
  -r \
  -w
```

For `indoor-interval-workout`:

```bash
mkdir -p fields/indoor-interval-workout/bin

monkeyc \
  -f fields/indoor-interval-workout/monkey.jungle \
  -o fields/indoor-interval-workout/bin/indoor-interval-workout-edgeexplore2.prg \
  -y developer_key.der \
  -d edgeexplore2 \
  -r \
  -w
```

Notes:

- `-f` points to the field's `monkey.jungle`
- `-o` writes the signed output `.prg`
- `-y` is your `developer_key.der`
- `-d` must match the device id in that field's `manifest.xml`
- `-r` builds a release artifact
- `-w` enables warnings

If `monkeyc` is not found, load the SDK bin directory into your shell first:

```bash
export PATH="$(connect-iq-sdk-manager sdk current-path --bin):$PATH"
```

### Run in the simulator

To verify that a field actually runs, start the Connect IQ simulator first:

```bash
export PATH="$(connect-iq-sdk-manager sdk current-path --bin):$PATH"
simulator
```

Then, in a second terminal, push the compiled `.prg` to the running simulator:

```bash
monkeydo fields/example-field/bin/example-field-edgeexplore2.prg edgeexplore2
```

For `minimal-7`:

```bash
monkeydo fields/minimal-7/bin/minimal-7-edgeexplore2.prg edgeexplore2
```

Notes:

- `monkeydo` requires the simulator to already be running
- the device id must match the field's `manifest.xml`
- if the field does not launch, rebuild it first with `monkeyc` and check the simulator logs/output

If the simulator fails with a missing font file under `~/.Garmin/ConnectIQ/Fonts`, download the device assets again with fonts enabled:

```bash
connect-iq-sdk-manager device download \
  --manifest fields/example-field/manifest.xml \
  --include-fonts
```

## Releases

Each field is released independently using a scoped version tag:

```bash
git tag fields/<field-name>/v1.0.0
git push origin fields/<field-name>/v1.0.0
```

The CI workflow (`.github/workflows/release.yml`) picks up the tag, compiles the field
with `monkeyc`, and publishes the device-specific `.prg` files as a GitHub release.

**Required setup (once):**

- `CONNECT_IQ_AGREEMENT_HASH` — repository variable with the accepted Garmin agreement hash.
- `GARMIN_USERNAME` and `GARMIN_PASSWORD` — repository secrets for device downloads.
- `CIQ_DEVELOPER_KEY` — repository secret containing `base64 developer_key.der`.

See the workflow file for key generation instructions.

## Testing

Garmin's official Connect IQ unit-test framework is `Toybox.Test`, and it runs in the simulator.

For the complete container workflow, use `./scripts/dev.sh test`.
The `test.yml` workflow runs the same command on branch pushes and pull requests
from this repository. Fork pull requests cannot use the Garmin account secrets.
CI generates a temporary signing key for tests.

This repo now keeps testable logic in helper modules and places unit tests directly in each field project:

- `fields/example-field/source/ExampleFieldTests.mc`
- `fields/indoor-interval-workout/source/IntervalWorkoutTests.mc`
- `fields/interval-workout/source/IntervalWorkoutTests.mc`
- `fields/minimal-7/source/Minimal7Tests.mc`

To compile the test-enabled `.prg` files for every field:

```bash
./scripts/test-fields.sh
```

To also execute the tests in a running Connect IQ simulator:

```bash
RUN_SIM_TESTS=1 ./scripts/test-fields.sh
```

Notes:

- the script compiles with `monkeyc --unit-test`
- by default it signs test builds with `./developer_key.der`; override with `DEVELOPER_KEY=/path/to/developer_key.der`
- `RUN_SIM_TESTS=1` requires the simulator to already be running and reachable by `monkeydo`
- the default test device is `edgeexplore2`; override it with `DEVICE_ID=<device>`

## Adding a new field

1. Copy `fields/example-field` to a new folder under `fields/`.
2. Generate a fresh UUID for the `id` attribute in `manifest.xml`.
3. Rename the entry class in `manifest.xml` and `source/` to match your new field.
4. Update `resources/strings/strings.xml` with the new app name.
