# AGENTS

- This repo contains apps and data fields for Garmin devices, using the Connect IQ SDK and the Monkey C programming language. The documentation can be found here: https://developer.garmin.com/connect-iq/api-docs/.
- The software is not distributed. Instead, there is only 1 user that manually installs the software on a device.
- The user has an "Garmin Edge Explore 2". This device must always be supported. Any other devices that are supported can be considered a bonus.

## Development

- Use `./scripts/dev.sh test` to compile and run all unit tests in an isolated simulator.
- Use `./scripts/dev.sh build <field>` to create a release `.prg` for the Edge Explore 2.
- Use `./scripts/dev.sh simulator` to open the visible simulator. Use `./scripts/dev.sh run <field>` to load a field.
- The scripts use an Ubuntu container for the simulator dependencies. The required SDK version is in `.ciq-sdk-version`.
- In WSL, `dev.sh` can use `wsl.exe` to run Docker as root. Use this fallback before asking the user to run Docker commands.
