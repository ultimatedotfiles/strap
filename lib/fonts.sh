#!/usr/bin/env bash

set -a

# see https://misc.flogisoft.com/bash/tip_colors_and_formatting
#     https://unix.stackexchange.com/a/269085
#     https://stackoverflow.com/a/4332530
#     https://en.wikipedia.org/wiki/X11_color_names
#     https://jonasjacek.github.io/colors/

FONT_BLACK="$(tput setaf 0)"
FONT_MAROON="$(tput setaf 1)"
FONT_GREEN="$(tput setaf 2)"
FONT_OLIVE="$(tput setaf 3)"
FONT_NAVY="$(tput setaf 4)"
FONT_PURPLE="$(tput setaf 5)"
FONT_TEAL="$(tput setaf 6)"
FONT_SILVER="$(tput setaf 7)"
FONT_GRAY="$(tput setaf 8)"
FONT_RED="$(tput setaf 9)"
FONT_LIME="$(tput setaf 10)"
FONT_YELLOW="$(tput setaf 11)"
FONT_BLUE="$(tput setaf 12)"
FONT_FUSHIA="$(tput setaf 13)"
FONT_AQUA="$(tput setaf 14)"
FONT_WHITE="$(tput setaf 15)"

FONT_BOLD="$(tput bold)"
FONT_DIM="$(tput dim)"
FONT_ULINE="$(tput smul)"
FONT_ITALIC="$(tput sitm)"
#UNULINE="$(tput rmul)"
#INVERT="$(tput rev)"

FONT_CLEAR="$(tput sgr 0 0)"

#font_style() {
#  local flags
#  local color
#  local bold
#  local uline
#  local italic
#  if [[ "$1" == "-"* ]]; then # flags
#    flags="$1" && shift
#    [[ "$flags" == *b* ]] && bold="${FONT_BOLD}"
#    [[ "$flags" == *u* ]] && uline="${FONT_ULINE}"
#    [[ "$flags" == *i* ]] && italic="${FONT_ITALIC}"
#    [[ "$flags" == *"c" ]] && color="$1" && shift
#  fi
#  echo -e "${color}${bold}${uline}${italic}${@}${FONT_CLEAR}"
#}
#
#FG=($FONT_BLACK $FONT_MAROON $FONT_GREEN $FONT_OLIVE $FONT_NAVY $FONT_PURPLE $FONT_TEAL $FONT_SILVER $FONT_GRAY $FONT_RED $FONT_LIME $FONT_YELLOW $FONT_BLUE $FONT_FUSHIA $FONT_AQUA $FONT_WHITE)
#for color in "${FG[@]}"; do
#  echo -e "Hello $(font_style -ui ${color}World!)"
#done