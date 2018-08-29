#!/usr/bin/env bash

set -Eeuo pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

command -v strap::lib::import >/dev/null || { echo "strap::lib::import is not available" >&2; exit 1; }
strap::lib::import lang || . lang.sh
strap::lib::import logging || . logging.sh
strap::lib::import path || . path.sh
strap::lib::import xcodeclt || . xcodeclt.sh

STRAP_HOME="${STRAP_HOME:-}" && strap::assert::has_length "$STRAP_HOME" 'STRAP_HOME is not set.'
strap::assert::has_length "$STRAP_SHELL_ENV_FILE" 'STRAP_SHELL_ENV_FILE is not set.'

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

  strap::running "Ensuring Homebrew \$PATH entries in ~/.strap/strapenv"
  if ! grep -q "homebrew:begin" "$STRAP_SHELL_ENV_FILE"; then
    #strap::action "Adding ~/.strap/strapenv check for homebrew \$PATH entries"
    local file="$STRAP_HOME/etc/profile.d/homebrewenv.sh"
    [[ ! -f "$file" ]] && strap::abort "Invalid strap installation. Missing file: $file"
    echo "" >> "$STRAP_SHELL_ENV_FILE"
    cat "$file" >> "$STRAP_SHELL_ENV_FILE"
  fi
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

#__strap::brew::ensure_formula() {
#  local command="${1:-}" && strap::assert::has_length "$command" '$1 must be the command'
#  local formula="${2:-}" && strap::assert::has_length "$formula" '$2 must be the formula id'
#  local name="${3:-}" && [ -z "$name" ] && name="$formula"
#
#  strap::running "Checking $name"
#  if ! ${command} list ${formula} >/dev/null 2>&1; then
#    strap::action "Installing $name..."
#    ${command} install ${formula}
#  fi
#  strap::ok
#}
#
#strap::brew::ensure() { __strap::brew::ensure_formula "brew" "$@"; }
#
#strap::brew::cask::ensure() {
#  local formula="${1:-}" && strap::assert::has_length "$formula" '$1 must be the formula id'
#  local apppath="${2:-}"
#
#  if [ -n "$apppath" ] && [ -d "$apppath" ]; then
#    # simulate checking message:
#    strap::running "Checking brew cask $formula"
#    if ! brew cask list "$formula" >/dev/null 2>&1; then
#      strap::ok
#      strap::info
#      strap::info "$formula appears to have been manually installed to $apppath"
#      strap::info "If you want strap or homebrew to manage $formula version upgrades"
#      strap::info "automatically (recommended), you should manually uninstall $apppath"
#      strap::info "and re-run strap or manually run 'brew cask install $formula'."
#      strap::info
#    else
#      strap::ok
#    fi
#  else
#    __strap::brew::ensure_formula "brew cask" "$formula"
#  fi
#}

strap::brew::ensure_brew_shellrc_entry() {
  local file="${1:-}" && [ ! -f "$file" ] && strap::assert::has_length '' '$1 must be the shell rc file'
  local formula="${2:-}" && strap::assert::has_length "$formula" '$2 must be the formula id'
  local path="${3:-}" && strap::assert "$path" '$3 must be the brew script relative path'
  local extraConditions="${4:-}"

  # if extraConditions are present, ensure there is a ' && ' at the end for joining:
  [ -n "$extraConditions" ] && [[ "$extraConditions" != "* && " ]] && extraConditions="$extraConditions && "

  strap::running "Checking ${formula} in $file"
  if ! grep -q ${path} ${file}; then
    strap::action "Enabling ${formula} in $file"
    println $file ''
    println $file "# homebrew:${formula}:begin"
    println $file "if $extraConditions[ -f \$(brew --prefix)/${path} ]; then"
    println $file "  . \$(brew --prefix)/${path}"
    println $file 'fi'
    println $file "# homebrew:${formula}:end"
  fi
  strap::ok
}

set +a