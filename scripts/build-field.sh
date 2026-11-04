#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIELD="${1:?Specify a field name}"
DEVICE_ID="${DEVICE_ID:-edgeexplore2}"
if [[ ! "$FIELD" =~ ^[a-zA-Z0-9_-]+$ || ! -f "$PROJECT_ROOT/fields/$FIELD/monkey.jungle" ]]; then
  printf 'Unknown field: %s\n' "$FIELD" >&2
  exit 2
fi
mkdir -p "$PROJECT_ROOT/fields/$FIELD/bin"
monkeyc -f "$PROJECT_ROOT/fields/$FIELD/monkey.jungle" \
  -o "$PROJECT_ROOT/fields/$FIELD/bin/$FIELD-$DEVICE_ID.prg" \
  -d "$DEVICE_ID" -y "${DEVELOPER_KEY:-$PROJECT_ROOT/developer_key.der}" -w -r
