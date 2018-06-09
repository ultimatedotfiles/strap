#!/usr/bin/env bash

set -Eeuo pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

STRAP_LIB_DIR="${STRAP_LIB_DIR:-}" && [[ -z "$STRAP_LIB_DIR" ]] && echo "STRAP_LIB_DIR is not set." >&2 && exit 1
STRAP_PLUGINS_DIR="${STRAP_PLUGINS_DIR:-}" && [[ -z "$STRAP_PLUGINS_DIR" ]] && echo "STRAP_PLUGINS_DIR is not set." >&2 && exit 1
STRAP_PLUGIN_LIB_DIR="${STRAP_PLUGIN_LIB_DIR:-}"
export STRAP_LIB_LOADED_LIBS="${STRAP_LIB_LOADED_LIBS:-}"

set -a

strap::lib::import() {

  local name=
  local plugin=
  local dir=
  local file=

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

  if [[ -n "$plugin" ]]; then
    dir="$STRAP_PLUGINS_DIR/$plugin"
    if [[ ! -d "$dir" ]]; then
      echo "$dir is not a valid strap plugin directory" >&2
      return 1
    fi
    file="$dir/lib/$name.sh"
    if [[ ! -f "$file" ]]; then
      echo "strap plugin library file '$file' does not exist" >&2
      return 1
    fi
  fi

  [[ ! -f "$file" ]] && [[ -d "$STRAP_PLUGIN_LIB_DIR" ]] && file="$STRAP_PLUGIN_LIB_DIR/$name.sh"

  # if file doesn't exist, fall back to strap root:
  [[ ! -f "$file" ]] && file="$STRAP_LIB_DIR/$name.sh"

  # if file still doesn't exist, it's an error:
  if [[ ! -f "$file" ]]; then
     echo "unable to source library '$name': neither $STRAP_PLUGIN_LIB_DIR/$name.sh nor $STRAP_LIB_DIR/$name.sh could be found." >&2
     return 1
  fi

  source "$file"

  if [[ -z "$STRAP_LIB_LOADED_LIBS" ]]; then
    STRAP_LIB_LOADED_LIBS="$libname"
  else
    STRAP_LIB_LOADED_LIBS="$STRAP_LIB_LOADED_LIBS $libname"
  fi
  export STRAP_LIB_LOADED_LIBS
}

set +a