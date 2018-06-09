#!/usr/bin/env bash

set -Eeuo pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

command -v strap::lib::import >/dev/null || { echo "strap::lib::import is not available" >&2; exit 1; }
strap::lib::import logging || . logging.sh

STRAP_HOME="${STRAP_HOME:-}" && [[ -z "$STRAP_HOME" ]] && echo "STRAP_HOME is not set." >&2 && exit 1
STRAP_USER_HOME="${STRAP_USER_HOME:-}" && [[ -z "$STRAP_USER_HOME" ]] && echo "STRAP_USER_HOME is not set." >&2 && exit 1
STRAP_SUDO_CLEANED=''

set -a

STRAP_SUDO_WAIT_PID="${STRAP_SUDO_WAIT_PID:-}"
__strap__sudo__edit="$STRAP_HOME/etc/sudoers/edit"
__strap__sudo__cleanup="$STRAP_HOME/etc/sudoers/cleanup"

strap::sudo::cleanup() {

  [[ -n "$STRAP_SUDO_CLEANED" ]] && return 0

  chmod 700 "$__strap__sudo__cleanup"
  sudo "$__strap__sudo__cleanup"

  if [[ -n "$STRAP_SUDO_WAIT_PID" ]]; then
    kill "$STRAP_SUDO_WAIT_PID" >/dev/null 2>&1 && wait "$STRAP_SUDO_WAIT_PID" >/dev/null 2>&1
    export STRAP_SUDO_WAIT_PID=''
  fi

  trap - SIGINT SIGTERM EXIT

  export STRAP_SUDO_CLEANED="1"

  sudo -k
}

strap::sudo::enable() {

  #[[ -n "$STRAP_SUDO_WAIT_PID" ]] && return 0 # already running

  if [[ ! -f "$__strap__sudo__edit" || ! -f "$__strap__sudo__cleanup" ]]; then
    strap::abort "Invalid STRAP_HOME installation"
  fi

  # Ensure correct file permissions in case they're ever changed by accident:
  chmod 700 "$__strap__sudo__edit" "$__strap__sudo__cleanup"

  sudo -k # clear out any cached time to ensure we start fresh

  echo
  sudo -p "Enter your sudo password: " "$__strap__sudo__edit" "$__strap__sudo__cleanup"

  trap 'strap::sudo::cleanup' SIGINT SIGTERM EXIT

  # spawn keepalive loop in background.  This will automatically exit after strap exits or
  # we explicitly kill it with its PID, whichever comes first:
  while true; do sudo -vn >/dev/null 2>&1; sleep 1; kill -0 "$$" >/dev/null 2>&1 || exit; done &
  export STRAP_SUDO_WAIT_PID="$!"
}

set +a
