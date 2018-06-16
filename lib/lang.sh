#!/usr/bin/env bash

set -Eeuo pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

command -v strap::lib::import >/dev/null || { echo "strap::lib::import is not available" >&2; exit 1; }
strap::lib::import logging || . logging.sh

set -a

strap::assert() {
  local -r arg="${1:-}"
  local -r msg="${2:-}"
  if [[ -z "$arg" ]]; then
    calling_func="${FUNCNAME[1]:-}: "
    strap::abort "${FONT_RED}${calling_func}${msg}${FONT_CLEAR}"
  fi
}

set +a

