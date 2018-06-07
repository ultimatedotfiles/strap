#!/usr/bin/env bash

set -Eeuo pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

command -v strap::lib::import >/dev/null || { echo "strap::lib::import is not available" >&2; exit 1; }
strap::lib::import fonts || . fonts.sh

strap::ok() {
    echo -e "${FONT_GREEN}[ok]${FONT_CLEAR} $1"
}

strap::bot() {
    echo -e "\n$FONT_GREEN\[._.]/$FONT_CLEAR - "$1
}

strap::running() {
    echo -en "$FONT_YELLOW ⇒ $FONT_CLEAR $1: "
}

strap::action() {
    echo -e "\n$FONT_YELLOW[action]:$FONT_CLEAR\n ⇒ $1..."
}

strap::warn() {
    echo -e "$FONT_YELLOW[warning]$FONT_CLEAR $1"
}

strap::error() {
    echo -e "$FONT_RED[error]$FONT_CLEAR $1" >&2
}

strap::abort() {
  local msg="$1"
  [[ -n "$msg" ]] && strap::error "$msg"
  exit 1
}
