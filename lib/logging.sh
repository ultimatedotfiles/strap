#!/usr/bin/env bash

STRAP_DEBUG="${STRAP_DEBUG:-}" && [ -n "$STRAP_DEBUG" ] && set -x
STRAP_LIB_DIR="${STRAP_LIB_DIR:-}" && [[ -z "$STRAP_LIB_DIR" ]] && echo "STRAP_LIB_DIR is not set" && exit 1
FONT_BLACK="${FONT_BLACK:-}" && [[ -z "$FONT_BLACK" ]]  && . "$STRAP_LIB_DIR/fonts.sh" || . fonts.sh

set -a

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
