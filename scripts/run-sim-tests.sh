#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIM_LOG="$(mktemp)"
SIM_PID=''

cleanup() {
  local result=$?
  if [[ -n "$SIM_PID" ]]; then
    kill "$SIM_PID" 2>/dev/null || true
    wait "$SIM_PID" 2>/dev/null || true
  fi
  if [[ "$result" -ne 0 ]]; then
    cat "$SIM_LOG" >&2
    local app_log=/tmp/com.garmin.connectiq/GARMIN/APPS/LOGS/CIQ_LOG.YML
    if [[ -f "$app_log" ]]; then
      cat "$app_log" >&2
    fi
  fi
  rm -f "$SIM_LOG"
}
trap cleanup EXIT

connectiq >"$SIM_LOG" 2>&1 &
SIM_PID=$!
ready=0
for ((attempt=0; attempt<30; attempt++)); do
  if ! kill -0 "$SIM_PID" 2>/dev/null; then
    printf 'Simulator exited before it was ready.\n' >&2
    exit 1
  fi
  if (exec 3<>/dev/tcp/127.0.0.1/1234) 2>/dev/null; then
    ready=1
    break
  fi
  sleep 1
done
if [[ "$ready" -ne 1 ]]; then
  printf 'Simulator did not become ready within 30 seconds.\n' >&2
  exit 1
fi
RUN_SIM_TESTS=1 "$PROJECT_ROOT/scripts/test-fields.sh"
