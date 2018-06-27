#!/usr/bin/env bash

set -Eeuo pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

STRAP_LIB_DIR="$(pwd)"
. "$STRAP_LIB_DIR/lib.sh" || . lib.sh

command -v strap::lib::import >/dev/null || { echo "strap::lib::import is not available" >&2; exit 1; }
strap::lib::import logging || . logging.sh
strap::lib::import lang || . lang.sh
strap::lib::import git || . git.sh

STRAP_USER_HOME="${STRAP_USER_HOME:-}" && strap::assert::has_length "$STRAP_USER_HOME" 'STRAP_USER_HOME is not set.'

strap::pkg::dir::relative() {
    local id="${1:-}" && strap::assert::has_length "$id" '$1 must be a Strap package id'
    id="${id//[[:space:]]/}" # remove any whitespace
    id="${id////}" # remove any forward slashes

    IFS=':' read -r -a tokens <<< "$id"
    local -r len="${#tokens[@]}"
    [[ "$len" -ne "2" && "$len" -ne "3" ]] && strap::assert::has_length '' 'Strap package id must contain either one or two colon characters'

    local -r group_id="${tokens[0]}"
    local -r pkg_name="${tokens[1]}"
    local version='HEAD'
    if [[ "$len" -eq "3" ]]; then
      version="${tokens[2]}"
    fi

    local group_dirs="${group_id//.//}" # swap out periods for forward slashes

    echo "$group_dirs/$pkg_name/$version"
}

strap::pkg::dir() {
  local id="${1:-}" && strap::assert::has_length "$id" '$1 must be a Strap package id'
  local relative_dir="$(strap::pkg::dir::relative "$id")"
  echo "$STRAP_USER_HOME/packages/$relative_dir"
}

go() {
  strap::pkg::dir "$@"
}
go "$@"


