#!/usr/bin/env bash

set -Eeuo pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

command -v strap::lib::import >/dev/null || { echo "strap::lib::import is not available" >&2; exit 1; }
strap::lib::import fonts || . fonts.sh

set -a

strap::ok() {
    echo -e "${FONT_GREEN}OK${FONT_CLEAR} ${1:-}"
}

strap::bot() {
    echo -e "\n${FONT_BOLD}${FONT_BLUE}##${FONT_CLEAR} ${FONT_ULINE}${FONT_BOLD}${1:-}${FONT_CLEAR}\n"
}

strap::running() {
    echo -en "$FONT_SLATE_BLUE_3 ⇒ $FONT_CLEAR ${1:-}: "
}

strap::action() {
    echo -en "\n    $FONT_BOLD$FONT_DODGER_BLUE_3 ⇒  $FONT_CLEAR$FONT_BOLD${1:-} ... "
}

strap::info() {
    echo -e "${FONT_CORNFLOWER_BLUE}    [info]$FONT_CLEAR ${1:-}"
}

strap::warn() {
    echo -e "$FONT_YELLOW[warning]$FONT_CLEAR ${1:-}"
}

strap::error() {
    echo -e "$FONT_RED[error]$FONT_CLEAR ${1:-}" >&2
}

strap::abort() {
  local msg="${1:-}"
  [[ -n "$msg" ]] && strap::error "$msg"
  local -r stack_depth="${#FUNCNAME[@]}"
  local i=0
  while [[ $i < $stack_depth ]]; do
    stack_line="$(caller $i)"
    func_name="$(echo $stack_line | awk '{print $2}')"
    source_file="$(echo $stack_line | awk '{print $3}')"
    line_number="$(echo $stack_line | awk '{print $1}')"
    strap::error "    at ${FONT_LIGHT_SKYBLUE_1}${func_name}${FONT_CLEAR} (${FONT_LIGHT_STEEL_BLUE_1}${source_file}${FONT_CLEAR}:${FONT_SKYBLUE_2}${line_number}${FONT_CLEAR})"
    ((i++))
  done
  exit 1
}

set +a
