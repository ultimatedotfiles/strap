#!/usr/bin/env bash

set -Eeuo pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

command -v strap::lib::import >/dev/null || { echo "strap::lib::import is not available" >&2; exit 1; }
strap::lib::import lang || . lang.sh
strap::lib::import logging || . logging.sh
strap::lib::import path || . path.sh

STRAP_INTERACTIVE="${STRAP_INTERACTIVE:-}"

set -a

strap::xcode::clt::ensure() {
  strap::running "Checking Xcode Command Line Tools"
  XCODE_DIR='/Library/Developer/CommandLineTools'
  if [ -z "$XCODE_DIR" ] || ! g++ --version >/dev/null 2>&1 || ! pkgutil --pkg-info=com.apple.pkg.CLTools_Executables >/dev/null 2>&1; then

    strap::action "Installing Xcode Command Line Tools"
    CLT_PLACEHOLDER="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
    touch "$CLT_PLACEHOLDER"
    CLT_PACKAGE=$(softwareupdate -l | grep -B 1 -E "Command Line (Developer|Tools)" | \
                  awk -F"*" '/^ +\*/ {print $2}' | sed 's/^ *//' | grep -iE '[0-9|.]' | sort | tail -n1)
    sudo softwareupdate -i "$CLT_PACKAGE"
    rm -f "$CLT_PLACEHOLDER"
    if ! g++ --version >/dev/null 2>&1; then
      if [ -n "$STRAP_INTERACTIVE" ]; then
        strap::action "Requesting user install of Xcode Command Line Tools"
        xcode-select --install
      else
        echo
        strap::abort "Run 'xcode-select --install' to install the Xcode Command Line Tools."
      fi
    fi
  fi
  strap::ok
}

strap::xcode::clt::ensure_license() {
  if /usr/bin/xcrun clang 2>&1 | grep -q license; then
    if [ -n "$STRAP_INTERACTIVE" ]; then
      strap::running "Asking for Xcode license confirmation"
      sudo xcodebuild -license
      strap::ok
    else
      strap::abort "Run 'sudo xcodebuild -license' to agree to the Xcode license."
    fi
  fi
}

set +a