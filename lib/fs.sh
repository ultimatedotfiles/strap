#!/usr/bin/env bash

set -Eeuo pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

command -v strap::lib::import >/dev/null || { echo "strap::lib::import is not available" >&2; exit 1; }
strap::lib::import logging || . logging.sh
strap::lib::import lang || . lang.sh

set -a

strap::fs::chmod() {

  local chmod="${1:-}" && strap::assert "$chmod" '$1 must be the chmod mode'
  local target="${2:-}" && strap::assert "$target" '$2 must be the chmod target'
  local name="${3:-}" && [[ -z "$name" ]] && name="$target"

  strap::running "Ensuring chmod $chmod on $name"
  chmod ${chmod} "$target"
  strap::ok
}

strap::fs::dir::ensure() {

  local dir="${1:-}"
  local chmod="${2:-}"
  local name="${3:-}" && [[ -z "$name" ]] && name="$dir"

  strap::running "Checking directory: $name"
  if [[ ! -d "$dir" ]]; then
    [[ -f "$dir" ]] && strap::error "$dir is an existing file and cannot be made a directory" && return 1
    strap::action "Creating directory: $name"
    mkdir -p "$dir"
  fi
  strap::ok

  [[ -n "$chmod" ]] && strap::fs::chmod "$chmod" "$dir" "$name"
}

strap::fs::file::ensure() {

  local file="${1:-}"
  local chmod="${2:-}"
  local name="${3:-}" && [[ -z "$name" ]] && name="$file"

  strap::running "Checking file: $name"
  if [[ ! -f "$file" ]]; then
    [[ -d "$file" ]] && strap::error "$file is an existing directory and cannot be made a file" && return 1
    strap::action "Creating file: $name"
    touch "$file"
  fi
  strap::ok

  [[ -n "$chmod" ]] && strap::fs::chmod "$chmod" "$file" "$name"
}

set +a