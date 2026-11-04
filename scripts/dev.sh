#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${CIQ_IMAGE:-garmin-ciq:ubuntu22}"
DEVICE_ID="${DEVICE_ID:-edgeexplore2}"
DOCKER=(docker)

select_docker() {
  if docker info >/dev/null 2>&1; then
    return
  fi
  local wsl=/mnt/c/Windows/System32/wsl.exe
  if [[ -x "$wsl" ]] && "$wsl" -d "${WSL_DISTRO_NAME:-Arch}" -u root -- docker info >/dev/null 2>&1; then
    DOCKER=("$wsl" -d "${WSL_DISTRO_NAME:-Arch}" -u root -- docker)
  else
    printf 'Docker is unavailable. Start Docker and provide access to its socket.\n' >&2
    exit 1
  fi
}

build_image() {
  "${DOCKER[@]}" build \
    --build-arg "DEV_UID=$(id -u)" \
    --build-arg "DEV_GID=$(id -g)" \
    --build-arg "DEV_HOME=$HOME" \
    -f "$PROJECT_ROOT/scripts/Dockerfile.simulator" \
    -t "$IMAGE" "$PROJECT_ROOT/scripts"
}

container_args() {
  local sdk_bin
  sdk_bin="$(connect-iq-sdk-manager sdk current-path --bin)"
  if [[ ! -x "$sdk_bin/monkeyc" || ! -x "$sdk_bin/simulator" ]]; then
    printf 'The active Connect IQ SDK is incomplete: %s\n' "$sdk_bin" >&2
    exit 1
  fi
  local expected_version compiler_version
  expected_version="$(cat "$PROJECT_ROOT/.ciq-sdk-version")"
  compiler_version="$("$sdk_bin/monkeyc" -v)"
  if [[ "$compiler_version" != "Connect IQ Compiler version: $expected_version" ]]; then
    printf 'Expected SDK %s. Activate it with: connect-iq-sdk-manager sdk set %s\n' \
      "$expected_version" "$expected_version" >&2
    exit 1
  fi
  CONTAINER_ARGS=(run --rm --init
    --user "$(id -u):$(id -g)"
    --env "HOME=$HOME"
    --env "PATH=$sdk_bin:/usr/local/bin:/usr/bin:/bin"
    --env "DEVICE_ID=$DEVICE_ID"
    --mount "type=bind,source=$HOME/.Garmin,target=$HOME/.Garmin"
    --mount "type=bind,source=$PROJECT_ROOT,target=$PROJECT_ROOT"
    --workdir "$PROJECT_ROOT")
}

main() {
  local action="${1:-help}"
  case "$action" in
    image|test|simulator|build|run) ;;
    help|-h|--help)
      printf 'Usage: %s {image|test|simulator|build FIELD|run FIELD}\n' "$0"
      return ;;
    *) printf 'Unknown action: %s\n' "$action" >&2; exit 2 ;;
  esac
  local field="${2:-}"
  if [[ "$action" == build || "$action" == run ]]; then
    if [[ ! "$field" =~ ^[a-zA-Z0-9_-]+$ || ! -f "$PROJECT_ROOT/fields/$field/monkey.jungle" ]]; then
      printf 'Specify an existing field, such as minimal-7 or interval-workout.\n' >&2
      exit 2
    fi
  fi
  select_docker
  if [[ "$action" == image ]]; then
    build_image
    return
  fi
  if ! "${DOCKER[@]}" image inspect "$IMAGE" >/dev/null 2>&1; then
    build_image
  fi
  container_args
  case "$action" in
    test)
      "${DOCKER[@]}" "${CONTAINER_ARGS[@]}" "$IMAGE" \
        dbus-run-session -- xvfb-run -a ./scripts/run-sim-tests.sh ;;
    build)
      "${DOCKER[@]}" "${CONTAINER_ARGS[@]}" "$IMAGE" \
        bash ./scripts/build-field.sh "$field" ;;
    simulator)
      if [[ -z "${DISPLAY:-}" ]]; then
        printf 'DISPLAY is unset. A graphical display is required.\n' >&2
        exit 1
      fi
      "${DOCKER[@]}" "${CONTAINER_ARGS[@]}" --name garmin-ciq-dev \
        --env "DISPLAY=$DISPLAY" \
        --mount type=bind,source=/tmp/.X11-unix,target=/tmp/.X11-unix,readonly \
        "$IMAGE" dbus-run-session -- connectiq ;;
    run)
      "${DOCKER[@]}" exec --workdir "$PROJECT_ROOT" garmin-ciq-dev \
        bash ./scripts/build-field.sh "$field"
      "${DOCKER[@]}" exec --workdir "$PROJECT_ROOT" garmin-ciq-dev \
        monkeydo "fields/$field/bin/$field-$DEVICE_ID.prg" "$DEVICE_ID" ;;
  esac
}

main "$@"
