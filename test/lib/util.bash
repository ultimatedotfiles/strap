#!/usr/bin/env bash

set -a

strap::test::fs::readlink() {
  $(type -p greadlink readlink | head -1) "$1" # prefer greadlink if it exists
}

strap::test::fs::dirpath() {
  [[ -z "$1" ]] && echo "strap::test::fs::dirpath: a directory argument is required." >&2 && return 1
  [[ ! -d "$1" ]] && echo "strap::test::fs::dirpath: argument is not a directory: $1" >&2 && return 1
  echo "$(cd -P "$1" && pwd)"
}

strap::test::fs::filepath() {
  [[ -d "$1" ]] && echo "strap::test::fs::filepath: directory arguments are not permitted" >&2 && return 1
  local dirname="$(dirname "$1")"
  local filename="$(basename "$1")"
  local canonical_dir="$(strap::test::fs::dirpath "$dirname")"
  echo "$canonical_dir/$filename"
}

##
# Returns the canonical filesystem path of the specified argument
# Argument must be a directory or a file
##
strap::test::fs::path() {
  local target="$1"
  local dir
  if [[ -d "$target" ]]; then # target is a directory, get its canonical path:
    target="$(strap::test::fs::dirpath "$target")"
  else
    while [[ -h "$target" ]]; do # target is a symlink, so resolve it
      target="$(strap::test::fs::readlink "$target")"
      if [[ "$target" != /* ]]; then # target doesn't start with '/', so it's not yet absolute.  Fix that:
        target="$(strap::test::fs::filepath "$target")"
      fi
    done
    target="$(strap::test::fs::filepath "$target")"
  fi
  echo "$target"
}

STRAP_HOME="$(strap::test::fs::path "$BATS_TEST_DIRNAME/../..")"
STRAP_USER_HOME="$HOME/.strap"
STRAP_LIB_DIR="$STRAP_HOME/lib"
STRAP_PLUGIN_LIB_DIR="$STRAP_LIB_DIR"

set +a

command -v strap::lib::import >/dev/null || . "$STRAP_LIB_DIR/lib.sh"