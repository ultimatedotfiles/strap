#!/usr/bin/env bash

set -Eeo pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

command -v strap::lib::import >/dev/null || { echo "strap::lib::import is not available" >&2; exit 1; }
strap::lib::import logging || . logging.sh
strap::lib::import lang || . lang.sh

set -a

strap::git::credential::osxkeychain::available() {
  git help -a | grep -q credential-osxkeychain
}

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