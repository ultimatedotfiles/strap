#!/usr/bin/env bash

set -Eeuo pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

command -v strap::lib::import >/dev/null || { echo "strap::lib::import is not available" >&2; exit 1; }
strap::lib::import lang || . lang.sh
strap::lib::import logging || . logging.sh

[[ -z "$STRAP_USER" ]] && strap::abort 'STRAP_USER is not set.'

STRAP_SSH_IDRSA_KEYCHAIN_SERVICE_NAME='localhost-homedir-dotssh-idrsa-passphrase'

set -a

strap::ssh::idrsa::passphrase::get() {
  echo "$(find-generic-password -a "${STRAP_USER}" -s "${STRAP_SSH_IDRSA_KEYCHAIN_SERVICE_NAME}" -w 2>/dev/null || true)"
}

strap::ssh::idrsa::passphrase:save() {
  local -r passphrase="${1:-}" && strap::assert "$passphrase" '$1 must be the passphrase.'
  security add-generic-password -a "${STRAP_USER}" -s "${STRAP_SSH_IDRSA_KEYCHAIN_SERVICE_NAME}" -w "$passphrase"
}
strap::ssh::idrsa::passphrase::ensure() {

  strap::running "Checking id_rsa passphrase"
  passphrase="$(strap::ssh::idrsa::passphrase::get)"

  if [[ -z "$passphrase" ]]; then
    strap::running "Creating id_rsa passphrase"
    passphrase="$(openssl rand 48 -base64)"
    security add-generic-password -a "${STRAP_USER}" -s "${STRAP_SSH_IDRSA_KEYCHAIN_SERVICE_NAME}" -w "$passphrase"
  fi

  strap::ok
}

set +a