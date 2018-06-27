#!/usr/bin/env bash

set -Eeuo pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

command -v strap::lib::import >/dev/null || { echo "strap::lib::import is not available" >&2; exit 1; }
strap::lib::import logging || . logging.sh

set -a

strap::assert::has_length() {
  local -r arg="${1:-}"
  local -r msg="${2:-}"
  if [[ -z "$arg" ]]; then
    calling_func="${FUNCNAME[1]:-}: "
    strap::abort "${FONT_RED}${calling_func}${msg}${FONT_CLEAR}"
  fi
}

strap::assert() {
  local -r command="${1:-}" && strap::assert::has_length "$command" '$1 must be the command to evaluate'
  local -r msg="${2:-}" && strap::assert::has_length "$msg" '$2 must be the message to print if the command fails'
  if ! eval "$command"; then
    calling_func="${FUNCNAME[1]:-}: "
    strap::abort "${FONT_RED}${calling_func}${msg}${FONT_CLEAR}"
  fi
}

set +a

