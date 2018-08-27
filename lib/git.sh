#!/usr/bin/env bash

set -Eeuo pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

command -v strap::lib::import >/dev/null || { echo "strap::lib::import is not available" >&2; exit 1; }
strap::lib::import logging || . logging.sh
strap::lib::import lang || . lang.sh

set -a

strap::git::config::ensure() {

  local -r name="${1:-}" && strap::assert::has_length "$name" '$1 must be a git global config entry name'
  local -r value="${2:-}" && strap::assert::has_length "$value" '$2 must be the config entry value'

  strap::running "Checking git config $name"
  local -r existing="$(git config --global "$name" 2>/dev/null || true)"
  if [[ -z "$existing" ]]; then
    strap::action "Setting git config $name = $value"
    git config --global "$name" "$value"
  fi
  strap::ok
}

strap::git::credential::helper::ensure() {

  # TODO: on Linux, enable git-credential-libsecret

  local helper="$(git config --global 'credential.helper' 2>/dev/null || true)"
  if [[ -z "$helper" ]]; then
    helper='osxkeychain' # mac
    git help -a | grep -q "credential-${helper}" || helper='libsecret' # try linux
    git help -a | grep -q "credential-${helper}" || helper='store' # fall back to file storage
  fi

  strap::git::config::ensure 'credential.helper' "$helper"
}

strap::git::credential::delete() {
  local -r host="${1:-}" && strap::assert::has_length "$host" '$1 must be a host'
  local -r username="${2:-}"
  local -r helper="$(git config --global 'credential.helper')"

  local control_string="protocol=https\nhost=${host}\n"

  if [[ -n "$username" ]]; then
    control_string="${control_string}username=${username}\n"
  fi

  printf "$control_string" | git "credential-${helper}" erase >/dev/null
}

strap::git::credential::save() {
  local -r host="${1:-}" && strap::assert::has_length "$host" '$1 must be a host'
  local -r username="${2:-}" && strap::assert::has_length "$username" '$2 must be a username'
  local -r credential="${3:-}" && strap::assert::has_length "$credential" '$3 must be a credential'
  local -r helper="$(git config --global 'credential.helper')"

  strap::git::credential::delete "$host" "$username" # delete any previous value

  printf "protocol=https\nhost=%s\nusername=%s\npassword=%s\n" "$host" "$username" "$credential" | git "credential-${helper}" store >/dev/null
}

strap::git::credential::find() {
  local -r host="${1:-}" && strap::assert::has_length "$host" '$1 must be a host'
  local -r username="${2:-}" && strap::assert::has_length "$username" '$2 must be a username'
  local -r helper="$(git config --global 'credential.helper')"
  printf "protocol=https\nhost=%s\nusername=%s\n" "$host" "$username" | git "credential-${helper}" get | grep 'password=' | cut -d '=' -f2
}

strap::git::remote::available() {
  local -r url="${1:-}" && strap::assert::has_length "$url" '$1 must be a git repository url'
  git ls-remote "$url" >/dev/null 2>&1
}

strap::git::is_in_work_tree() {
  local -r dir="${1:-}" && strap::assert::has_length "$dir" '$1 must be a directory path'
  strap::assert "[ -d ${dir} ]" '$1 must be a directory'
  $(cd "$dir"; git rev-parse --is-inside-work-tree >/dev/null 2>&1)
}

set +a