#!/usr/bin/env bash

set -Eeuo pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

command -v strap::lib::import >/dev/null || { echo "strap::lib::import is not available" >&2; exit 1; }
strap::lib::import logging || . logging.sh

strap::path::contains() {
  local -r element="${1:-}" && [[ -z "$element" ]] && strap::abort 'strap::path::contains requires a $1 argument'
  echo "$PATH" | tr ':' '\n' | grep -q "$element"
}
