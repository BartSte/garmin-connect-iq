#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK_VERSION="${SDK_VERSION:-$(cat "$PROJECT_ROOT/.ciq-sdk-version")}"
FORCE_MANAGER_INSTALL="${FORCE_MANAGER_INSTALL:-0}"

log() {
  printf '[setup-ubuntu] %s\n' "$*"
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$cmd" >&2
    exit 1
  fi
}

append_path_snippet() {
  local shell_rc="$1"
  local marker="# Added by garmin-connect-screens setup"
  local snippet='export PATH="$HOME/.local/bin:$PATH"'

  if [[ ! -f "$shell_rc" ]]; then
    touch "$shell_rc"
  fi

  if ! grep -Fq "$snippet" "$shell_rc"; then
    {
      printf '\n%s\n' "$marker"
      printf '%s\n' "$snippet"
    } >> "$shell_rc"
  fi
}

append_sdk_path_snippet() {
  local shell_rc="$1"
  local marker="# Added by garmin-connect-screens setup"
  local snippet='if command -v connect-iq-sdk-manager >/dev/null 2>&1; then export PATH="$(connect-iq-sdk-manager sdk current-path --bin):$PATH"; fi'

  if [[ ! -f "$shell_rc" ]]; then
    touch "$shell_rc"
  fi

  if ! grep -Fq 'connect-iq-sdk-manager sdk current-path --bin' "$shell_rc"; then
    {
      printf '%s\n' "$marker"
      printf '%s\n' "$snippet"
    } >> "$shell_rc"
  fi
}

install_system_packages() {
  log "Installing Ubuntu packages"
  sudo apt-get update
  sudo apt-get install -y \
    ca-certificates \
    curl \
    default-jre \
    git \
    openssl \
    unzip
}

install_manager() {
  if command -v connect-iq-sdk-manager >/dev/null 2>&1 && [[ "$FORCE_MANAGER_INSTALL" != "1" ]]; then
    log "connect-iq-sdk-manager already installed"
    return
  fi

  log "Installing connect-iq-sdk-manager"
  curl -fsSL \
    https://raw.githubusercontent.com/lindell/connect-iq-sdk-manager-cli/master/install.sh \
    | sh
}

configure_shell_path() {
  export PATH="$HOME/.local/bin:$PATH"
  append_path_snippet "$HOME/.bashrc"
  append_sdk_path_snippet "$HOME/.bashrc"
  if [[ -n "${ZSH_VERSION:-}" || -f "$HOME/.zshrc" ]]; then
    append_path_snippet "$HOME/.zshrc"
    append_sdk_path_snippet "$HOME/.zshrc"
  fi
}

configure_sdk() {
  log "Accepting the Garmin SDK agreement interactively"
  connect-iq-sdk-manager agreement accept

  log "Downloading and activating Connect IQ SDK ${SDK_VERSION}"
  connect-iq-sdk-manager sdk download "${SDK_VERSION}"
  connect-iq-sdk-manager sdk set "${SDK_VERSION}"
  export PATH="$(connect-iq-sdk-manager sdk current-path --bin):$PATH"
}

login_to_garmin() {
  log "Logging in to Garmin for device downloads"
  connect-iq-sdk-manager login
}

download_devices() {
  local manifest

  while IFS= read -r manifest; do
    log "Downloading device definitions for ${manifest#$PROJECT_ROOT/}"
    connect-iq-sdk-manager device download --manifest "$manifest" --include-fonts
  done < <(find "$PROJECT_ROOT/fields" -mindepth 2 -maxdepth 2 -name manifest.xml | sort)
}

main() {
  require_cmd sudo
  require_cmd find
  install_system_packages
  install_manager
  configure_shell_path
  configure_sdk
  login_to_garmin
  download_devices

  cat <<EOF

Setup complete.

Current SDK bin path:
  $(connect-iq-sdk-manager sdk current-path --bin)

Next steps:
  1. Open a new shell so `connect-iq-sdk-manager` and `monkeyc` are on PATH.
  2. Generate a signing key if you do not already have one:
       openssl genrsa -out developer_key.pem 4096
       openssl pkcs8 -topk8 -inform PEM -outform DER \\
         -in developer_key.pem -out developer_key.der -nocrypt
  3. Build a field, for example:
       monkeyc -f fields/example-field/monkey.jungle \\
         -o fields/example-field/bin/example-field.prg \\
         -y developer_key.der -d edgeexplore2 -r -w
EOF
}

main "$@"
