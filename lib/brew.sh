#!/usr/bin/env bash

set -Eeuo pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

command -v strap::lib::import >/dev/null || { echo "strap::lib::import is not available" >&2; exit 1; }
strap::lib::import lang || . lang.sh
strap::lib::import logging || . logging.sh
strap::lib::import path || . path.sh

set -a

STRAP_HOMEBREW_PREFIX="$(brew --prefix)"
! strap::path::contains "$STRAP_HOMEBREW_PREFIX/bin" && export PATH="$STRAP_HOMEBREW_PREFIX/bin:$PATH"

__strap::brew::ensure_formula() {
  local command="${1:-}" && strap::assert "$command" '$1 must be the command'
  local formula="${2:-}" && strap::assert "$formula" '$2 must be the formula id'
  local name="${3:-}" && [ -z "$name" ] && name="$formula"

  strap::running "Checking $name"
  if ! ${command} list ${formula} >/dev/null 2>&1; then
    strap::action "Installing $name..."
    ${command} install ${formula}
  fi
  strap::ok
}

strap::brew::ensure() { __strap::brew::ensure_formula "brew" "$@"; }

strap::brew::cask::ensure() {
  local formula="${1:-}" && strap::assert "$formula" '$1 must be the formula id'
  local apppath="${2:-}"

  if [ -n "$apppath" ] && [ -d "$apppath" ]; then
    # simulate checking message:
    strap::running "Checking brew cask $formula"
    if ! brew cask list "$formula" >/dev/null 2>&1; then
      strap::ok
      strap::info
      strap::info "$formula appears to have been manually installed to $apppath"
      strap::info "If you want strap or homebrew to manage $formula version upgrades"
      strap::info "automatically (recommended), you should manually uninstall $apppath"
      strap::info "and re-run strap or manually run 'brew cask install $formula'."
      strap::info
    else
      strap::ok
    fi
  else
    __strap::brew::ensure_formula "brew cask" "$formula"
  fi
}

strap::brew::ensure_brew_shellrc_entry() {
  local file="${1:-}" && [ ! -f "$file" ] && strap::assert '' '$1 must be the shell rc file'
  local formula="${2:-}" && strap::assert "$formula" '$2 must be the formula id'
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