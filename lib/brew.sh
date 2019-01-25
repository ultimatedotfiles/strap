#!/usr/bin/env bash

set -Eeuo pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

command -v strap::lib::import >/dev/null || { echo "strap::lib::import is not available" >&2; exit 1; }
strap::lib::import lang || . lang.sh
strap::lib::import logging || . logging.sh
strap::lib::import path || . path.sh
strap::lib::import xcodeclt || . xcodeclt.sh

STRAP_HOME="${STRAP_HOME:-}" && strap::assert::has_length "$STRAP_HOME" 'STRAP_HOME is not set.'
STRAP_USER_HOME="${STRAP_USER_HOME:-}" && strap::assert::has_length "$STRAP_USER_HOME" 'STRAP_USER_HOME is not set.'

set -a

strap::brew::init() {

  # Ensure Xcode Command Line Tools are installed
  strap::xcode::clt::ensure
  strap::xcode::clt::ensure_license

  strap::running "Checking Homebrew"
  if command -v brew >/dev/null 2>&1; then
    strap::ok
    strap::running "Checking Homebrew updates"
    brew update >/dev/null
    brew upgrade
  else
    strap::action "Installing Homebrew"
    (
      set +o pipefail
      set +e
      unset -f $(compgen -A function strap) # homebrew scripts barf when 'strap::' function names are present
      yes '' | /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
      homebrew_exit_code="$?"
      set -o pipefail
      set -e
      if [[ "$homebrew_exit_code" -ne 0 ]]; then echo "Homebrew installation failed." >&2; exit 1; fi
    )
  fi
  strap::ok

  STRAP_HOMEBREW_PREFIX="$(brew --prefix)"
  ! strap::path::contains "$STRAP_HOMEBREW_PREFIX/bin" && export PATH="$STRAP_HOMEBREW_PREFIX/bin:$PATH"

  strap::running "Ensuring Homebrew \$PATH entries"
  local filename="100.homebrew.sh"
  local src="${STRAP_HOME}/etc/straprc.d/$filename"
  [[ ! -f "$src" ]] && strap::abort "Invalid strap installation. Missing file: $src"
  local dest="${STRAP_USER_HOME}/etc/straprc.d/$filename"
  rm -rf "$dest" # remove any old copy that might be there to ensure we get the latest
  cp "$src" "$dest"
  strap::ok
}

strap::brew::pkg::is_installed() {
  local formula="${1:-}" && strap::assert::has_length "$formula" '$1 must be the formula id'
  brew list --versions "$formula" >/dev/null
}

strap::brew::pkg::install() {
  local formula="${1:-}" && strap::assert::has_length "$formula" '$1 must be the formula id'
  brew install "$formula"
}

set +a