#!/usr/bin/env bash

set -Eeo pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

# see https://misc.flogisoft.com/bash/tip_colors_and_formatting
#     https://unix.stackexchange.com/a/269085
#     https://stackoverflow.com/a/4332530
#     https://en.wikipedia.org/wiki/X11_color_names
#     https://jonasjacek.github.io/colors/

set -a

# Color names here are from https://jonasjacek.github.io/colors/

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

FONT_DARK_BLUE="$(tput setaf 18)"
FONT_DODGER_BLUE_3="$(tput setaf 26)"
FONT_BLUE_VIOLET="$(tput setaf 57)"
FONT_MEDIUM_PURPLE_4="$(tput setaf 60)"
FONT_SLATE_BLUE_3="$(tput setaf 61)"
FONT_CORNFLOWER_BLUE="$(tput setaf 69)"
FONT_SKYBLUE_2="$(tput setaf 111)"
FONT_LIGHT_SKYBLUE_1="$(tput setaf 153)"
FONT_DEEP_PINK_3="$(tput setaf 161)"
FONT_GOLD_3="$(tput setaf 178)"
FONT_LIGHT_STEEL_BLUE_1="$(tput setaf 189)"
FONT_DARK_SEA_GREEN="$(tput setaf 193)"
FONT_RED_1="$(tput setaf 196)"
FONT_ORANGE_RED_1="$(tput setaf 202)"
FONT_ORANGE_1="$(tput setaf 214)"
FONT_GOLD_1="$(tput setaf 220)"
FONT_LIGHT_GOLDENROD_2="$(tput setaf 221)"
FONT_LIGHT_GOLDENROD_1="$(tput setaf 227)"
FONT_KHAKI_1="$(tput setaf 228)"
FONT_WHEAT_1="$(tput setaf 229)"
FONT_CORNSILK_1="$(tput setaf 230)"
FONT_GRAY_93="$(tput setaf 255)"

FONT_BOLD="$(tput bold)"
#FONT_DIM="$(tput dim)" # causes strap::lib::import failure
FONT_ULINE="$(tput smul)"
#FONT_ITALIC="$(tput sitm)" # causes strap::lib::import failure
FONT_UNULINE="$(tput rmul)"
FONT_INVERT="$(tput rev)"

FONT_CLEAR="$(tput sgr 0)"

FONT_CHECKMARK="\342\234\224"
FONT_ERRCROSS="\xE2\x9D\x8C "

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