#!/usr/bin/env bash
set -Eeuo pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

if ! command -v strap::lib::import >/dev/null; then
  echo "This file is not intended to be run or sourced outside of a strap execution context." >&2
  [[ "${BASH_SOURCE[0]}" != "${0}" ]] && return 1 || exit 1 # if sourced, return 1, else running as a command, so exit
fi
strap::lib::import logging || . logging.sh
strap::lib::import lang || . lang.sh
strap::lib::import fs || . fs.sh
strap::lib::import git || . git.sh
strap::lib::import os || . os.sh
strap::lib::import pkgmgr || . pkgmgr.sh

set -a

function strap::exec() {

  [[ "$#" -gt 0 ]] || strap::abort "A command to execute is required."

  local output= retval=

  set +eu
  output="$($@ 2>&1)"
  retval="$?"
  set -eu
  [[ "${retval}" -eq 0 ]] || strap::abort "${output}"
}

set +a