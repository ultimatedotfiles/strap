#!/usr/bin/env bash

set -Eeo pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

command -v strap::lib::import >/dev/null || { echo "strap::lib::import is not available" >&2; exit 1; }
strap::lib::import logging || . logging.sh
strap::lib::import lang || . lang.sh
strap::lib::import fs || . fs.sh
strap::lib::import git || . git.sh

STRAP_USER_HOME="${STRAP_USER_HOME:-}" && strap::assert::has_length "$STRAP_USER_HOME" 'STRAP_USER_HOME is not set.'

set -a

strap::pkg::id::canonicalize() {

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

  echo "$group_id:$pkg_name:$version"
}

strap::pkg::id::dir::relative() {
  local group_id=
  local pkg_name=
  local version=

  local id="${1:-}" && strap::assert::has_length "$id" '$1 must be a Strap package id'
  id="$(strap::pkg::id::canonicalize "$id")"

  local -r tokenized="${id//:/ }" # split on ':' to use for the read command next:
  IFS=' ' read -r group_id pkg_name version <<< "${tokenized}" # assign each token to the vars

  local group_dirs="${group_id//.//}" # swap out periods for forward slashes

  echo "$group_dirs/$pkg_name/$version"
}

strap::pkg::id::dir() {
  local id="${1:-}" && strap::assert::has_length "$id" '$1 must be a Strap package id'
  local relative_dir="$(strap::pkg::id::dir::relative "$id")"
  echo "$STRAP_USER_HOME/packages/$relative_dir"
}

strap::pkg::id::github::url::domain_and_path() {
  local group=
  local name=
  local version=
  local id="${1:-}" && strap::assert::has_length "$id" '$1 must be a Strap package id'
  id="$(strap::pkg::id::canonicalize "$id")"
  IFS=':' read -r group name version <<< "$id" # split on ':' and assign each resulting token to the vars

  local reversed_domain="${group%.*}" # everything leading up to, but not including, the last period character
  local -r repo="${group##*.}" # everything after, but not including, the last period character

  local tokens=
  IFS='.' read -r -a tokens <<< "$reversed_domain"

  # reverse the domain tokens:
  local domain=''
  local len="${#tokens[@]}"
  local last_index=$((len - 1))
  for (( i=$last_index; i >= 0; i-- )); do
    domain="${domain}${tokens[i]}"
    if [[ "$i" -ne "0" ]]; then
      domain="$domain."
    fi
  done

  echo "$domain/$repo/$name.git"
}

strap::pkg::id::github::url::https() {
  local -r id="${1:-}" && strap::assert::has_length "$id" '$1 must be a Strap package id'
  local -r domain_and_path="$(strap::pkg::id::github::url::domain_and_path "$id")"
  echo "https://${domain_and_path}"
}

strap::pkg::id::github::url::ssh() {
  local -r id="${1:-}" && strap::assert::has_length "$id" '$1 must be a Strap package id'
  local domain_and_path="$(strap::pkg::id::github::url::domain_and_path "$id")"
  domain_and_path="${domain_and_path/\//:}" # replace the first (and only the first) forward slash with a colon
  echo "git@${domain_and_path}"
}

strap::pkg::id::dir::ensure() {
  local -r id="${1:-}" && strap::assert::has_length "$id" '$1 must be a Strap package id'
  local -r dir="$(strap::pkg::id::dir "$id")"

  if [[ ! -d "$dir" ]]; then
    [[ -f "$dir" ]] && strap::abort "Strap package $id requires $dir to be a directory, not a file."
    mkdir -p "$dir" || strap::abort "Unable to create directory $dir for strap package $id. Please check directory write permissions for user $STRAP_USER"
  fi
}
