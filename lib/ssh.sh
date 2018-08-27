#!/usr/bin/env bash

set -Eeuo pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

command -v strap::lib::import >/dev/null || { echo "strap::lib::import is not available" >&2; exit 1; }
strap::lib::import lang || . lang.sh
strap::lib::import logging || . logging.sh
strap::lib::import os || . os.sh

[[ -z "$STRAP_USER" ]] && strap::abort 'STRAP_USER is not set.'

STRAP_SSH_IDRSA_KEYCHAIN_SERVICE_NAME='strap-idrsa-passphrase'
STRAP_SECRET_TOOL_ID="strap-$STRAP_USER-idrsa"

__strap::ssh::assert_secret_tool() {
  command -v secret-tool >/dev/null 2>&1 || strap::abort "The 'secret-tool' command is required on linux for safe password access"
}

set -a

strap::ssh::idrsa::passphrase::delete() {
  if strap::os::is_mac; then
    security delete-generic-password -a "${STRAP_USER}" -s "${STRAP_SSH_IDRSA_KEYCHAIN_SERVICE_NAME}" >/dev/null 2>&1 || true
  else
    __strap::ssh::assert_secret_tool
    secret-tool clear strap-id "$STRAP_SECRET_TOOL_ID"
  fi
}

strap::ssh::idrsa::passphrase::get() {
  if strap::os::is_mac; then
    security find-generic-password -a "${STRAP_USER}" -s "${STRAP_SSH_IDRSA_KEYCHAIN_SERVICE_NAME}" -w 2>/dev/null || true
  else
    __strap::ssh::assert_secret_tool
    secret-tool lookup strap-id "$STRAP_SECRET_TOOL_ID" || true
  fi
}

strap::ssh::idrsa::passphrase:save() {
  local -r passphrase="${1:-}" && strap::assert::has_length "$passphrase" '$1 must be the passphrase.'

  if strap::os::is_mac; then
    security add-generic-password -a "${STRAP_USER}" -s "${STRAP_SSH_IDRSA_KEYCHAIN_SERVICE_NAME}" -w "$passphrase"
  else
    __strap::ssh::assert_secret_tool
    printf "$passphrase" | secret-tool store --label="$STRAP_SECRET_TOOL_ID" strap-id "$STRAP_SECRET_TOOL_ID"
  fi
}

strap::ssh::idrsa::passphrase::create() {
  openssl rand -base64 48
}

strap::ssh::idrsa::passphrase::ensure() {

  strap::running "Checking id_rsa passphrase"
  passphrase="$(strap::ssh::idrsa::passphrase::get)"

  if [[ -z "$passphrase" ]]; then
    strap::running "Creating id_rsa passphrase"
    passphrase="$(strap::ssh::idrsa::passphrase::create)"
    strap::ssh::idrsa::passphrase:save "$passphrase"
  fi

  strap::ok
}

set +a