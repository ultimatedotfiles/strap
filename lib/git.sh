#!/usr/bin/env bash

set -Eeuo pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

command -v strap::lib::import >/dev/null || { echo "strap::lib::import is not available" >&2; exit 1; }
strap::lib::import logging || . logging.sh
strap::lib::import path || . path.sh

strap::git::config::ensure() {

  local -r name="${1:-}" && [[ -z "$name" ]] && strap::error 'strap::git::config::ensure $1 must be a git global config entry name' && return 1
  local -r value="${2:-}" && [[ -z "$value" ]] && strap::error 'strap::git::config::ensure $2 must be the config entry value' && return 1

  strap::running "Checking git config $name"
  local -r existing="$(git config --global "$name" || true)"
  if [[ -z "$existing" ]]; then
    strap::action "Setting git config $name = $value"
    git config --global "$name" "$value"
  fi
  strap::ok
}