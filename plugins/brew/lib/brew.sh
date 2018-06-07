#!/usr/bin/env bash

set -Eeuo pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

command -v strap::lib::import >/dev/null || { echo "strap::lib::import is not available" >&2; exit 1; }
strap::lib::import logging || . ../../../lib/logging.sh

strap::brew::ensure_formula() {
  local command="$1" && [ -z "$command" ] && abort 'strap::brew::ensure_formula: $1 must be the command'
  local formula="$2" && [ -z "$formula" ] && abort 'strap::brew::ensure_formula: $2 must be the formula id'
  local name="$3" && [ -z "$3" ] && name="$formula"

  strap::running "Checking $name"
  if ! ${command} list ${formula} >/dev/null 2>&1; then
    echo && strap::action "Installing $name..."
    ${command} install ${formula}
  fi
  strap::ok
}
strap::brew::ensure_brew() { strap::brew::ensure_formula "brew" $1 $2; }
strap::brew::ensure_cask() {
  local formula="$1" && [ -z "$formula" ] && abort 'ensure_cask: $1 must be the formula id'
  local apppath="$2"

  if [ ! -z "$apppath" ] && [ -d "$apppath" ]; then
    # simulate checking message:
    logn "Checking $formula:"
    if ! brew cask list "$formula" >/dev/null 2>&1; then
      logk
      log
      log "Note: $formula appears to have been manually installed to $apppath."
      log "If you want strap or homebrew to manage $formula version upgrades"
      log "automatically (recommended), you should manually uninstall $apppath"
      log "and re-run strap or manually run 'brew cask install $formula'."
      log
    else
      logk
    fi
  else
    ensure_formula "brew cask" "$formula"
  fi
}

strap::brew::ensure_brew_shellrc_entry() {
  local file="$1" && [ ! -f "$file" ] && abort 'ensure_brew_shellrc_entry: $1 must be the shell rc file'
  local formula="$2" && [ -z "$formula" ] && abort 'ensure_brew_shellrc_entry: $2 must be the formula id'
  local path="$3" && [ -z "$path" ] && abort 'ensure_brew_shellrc_entry: $3 must be the brew script relative path'
  local extraConditions="$4"

  # if extraConditions are present, ensure there is a ' && ' at the end for joining:
  [ -n "$extraConditions" ] && [[ "$extraConditions" != "* && " ]] && extraConditions="$extraConditions && "

  logn "Checking ${formula} in $file:"
  if ! grep -q ${path} ${file}; then
    echo && log "Enabling ${formula} in $file"
    println $file ''
    println $file "# homebrew:${formula}:begin"
    println $file "if $extraConditions[ -f \$(brew --prefix)/${path} ]; then"
    println $file "  . \$(brew --prefix)/${path}"
    println $file 'fi'
    println $file "# homebrew:${formula}:end"
  fi
  logk
}

# allow subshells to call these functions:
export -f ensure_formula
export -f ensure_brew
export -f ensure_cask
export -f ensure_brew_shellrc_entry