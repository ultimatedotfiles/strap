#!/usr/bin/env bash
set -Eeuo pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

if ! command -v strap::lib::import >/dev/null; then
  echo "This file is not intended to be run or sourced outside of a strap execution context." >&2
  [[ "${BASH_SOURCE[0]}" != "${0}" ]] && return 1 || exit 1 # if sourced, return 1, else running as a command, so exit
fi
strap::lib::import logging || . logging.sh
strap::lib::import lang || . lang.sh
strap::lib::import fs || . fs.sh
strap::lib::import git || . git.sh
strap::lib::import os || . os.sh
strap::lib::import pkgmgr || . pkgmgr.sh

STRAP_HOME="${STRAP_HOME:-}"; [[ -n "$STRAP_HOME" ]] || { echo "STRAP_HOME is not set" >&2; exit 1; }
STRAP_USER_HOME="${STRAP_USER_HOME:-}"; [[ -n "$STRAP_USER_HOME" ]] || { echo "STRAP_USER_HOME is not set" >&2; exit 1; }

set -a

function strap::python::install() {

  local distro= pkgname='python'

  distro="$(strap::os::distro)"

  case "${distro}" in
    darwin)        pkgname='python' ;;
    redhat|centos) pkgname='python36' ;;
    fedora)        pkgname='python37' ;;
    *)
      strap::abort 'Unrecognized operating system - cannot install python3. Please open an issue with the Strap team.'
      ;;
  esac

  strap::pkgmgr::pkg::ensure "${pkgname}"
  if ! command -v python3 >/dev/null 2>&1; then
    strap::abort "Python 3 could not be installed."
  fi

  if ! python3 -m pip --version >/dev/null 2>&1; then # must be linux because homebrew includes pip automatically
    strap::pkgmgr::pkg::ensure "${pkgname}-pip"
  fi
}

set +a