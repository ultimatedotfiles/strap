#!/usr/bin/env bash

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

TEST_LIB_UTIL_SCRIPT="$(strap::test::fs::path "${BASH_SOURCE[0]}")"
TEST_LIB_DIR="$(dirname "$TEST_LIB_UTIL_SCRIPT")"
STRAP_HOME="$(strap::test::fs::path "$TEST_LIB_DIR/../..")"
STRAP_USER_HOME="$(strap::test::fs::path "$HOME/.strap")"
STRAP_LIB_DIR="$STRAP_HOME/lib"

command -v strap::lib::import >/dev/null || . "$STRAP_LIB_DIR/lib.sh"
