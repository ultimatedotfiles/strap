#!/usr/bin/env bash

set -Eeuo pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

[[ -z "${STRAP_LIB_DIR:-}" ]] && echo "STRAP_LIB_DIR is not set." >&2 && exit 1
STRAP_PLUGIN_LIB_DIR="${STRAP_PLUGIN_LIB_DIR:-}"
STRAP_LIB_LOADED_LIBS="${STRAP_LIB_LOADED_LIBS:-}"

strap::lib::import() {

  local name=
  local plugin=
  local dir=
  local file=
  local oldopts=

  # preserve options in case $file changes them
  # see https://unix.stackexchange.com/questions/383541/how-to-save-restore-all-shell-options-including-errexit for more
  oldopts=$(set +o)
  case $- in
    *e*) oldopts="$oldopts; set -e";;
    *  ) oldopts="$oldopts; set +e";;
  esac

  set -Eeuo pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

  if [[ "$#" -gt "1" ]]; then
    plugin="$1"
    shift
  fi
  name="$1"
  shift

  local libname="$name"
  [[ -n "$plugin" ]] && libname="$plugin.$name"

  # if already loaded, don't load again:
  [[ "$STRAP_LIB_LOADED_LIBS" = *"$libname"* ]] && return 0

#  if [[ -n "$plugin" ]]; then
#    dir="$STRAP_PLUGINS_DIR/$plugin"
#    if [[ ! -d "$dir" ]]; then
#      echo "$dir is not a valid strap plugin directory" >&2
#      return 1
#    fi
#    file="$dir/lib/$name.sh"
#    if [[ ! -f "$file" ]]; then
#      echo "strap plugin library file '$file' does not exist" >&2
#      return 1
#    fi
#  fi

  [[ ! -f "$file" ]] && [[ -d "$STRAP_PLUGIN_LIB_DIR" ]] && file="$STRAP_PLUGIN_LIB_DIR/$name.sh"

  # if file doesn't exist, fall back to strap root:
  [[ ! -f "$file" ]] && file="$STRAP_LIB_DIR/$name.sh"

  # if file still doesn't exist, it's an error:
  if [[ ! -f "$file" ]]; then
     echo "unable to source library '$name': neither $STRAP_PLUGIN_LIB_DIR/$name.sh nor $STRAP_LIB_DIR/$name.sh could be found." >&2
     return 1
  fi

  # restore options before sourcing:
  set +vx; eval "$oldopts"
  # ensure our defaults for all scripts.  A script can change this if desired, but this is Straps default for safety:
  set -Eeuo pipefail

  source "$file"

  # restore options after sourcing:
  set +vx; eval "$oldopts"
  set -Eeuo pipefail

  if [[ -z "$STRAP_LIB_LOADED_LIBS" ]]; then
    STRAP_LIB_LOADED_LIBS="$libname"
  else
    STRAP_LIB_LOADED_LIBS="$STRAP_LIB_LOADED_LIBS $libname"
  fi
  export STRAP_LIB_LOADED_LIBS
}
declare -rfx strap::lib::import
