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
strap::lib::import exec || . exec.sh

STRAP_HOME="${STRAP_HOME:-}"; [[ -n "$STRAP_HOME" ]] || { echo "STRAP_HOME is not set" >&2; exit 1; }
STRAP_USER_HOME="${STRAP_USER_HOME:-}"; [[ -n "$STRAP_USER_HOME" ]] || { echo "STRAP_USER_HOME is not set" >&2; exit 1; }

STRAP_PYTHONUSERBASE="${STRAP_PYTHONUSERBASE:-}"; [[ -n "$STRAP_PYTHONUSERBASE" ]] || STRAP_PYTHONUSERBASE="${STRAP_USER_HOME}/python"

set -a

function strap::python::install() {

  local distro= pythonpkg= pythoncmd= venvpkg= pippkg= output= retval= venv_dir="${STRAP_USER_HOME}/.venv"

  distro="$(strap::os::distro)"

  case "${distro}" in
    darwin)
      pythonpkg='python'
      pythoncmd='python3'
      ;;
    ubuntu)
      pythonpkg='python3.7'
      [[ "$(strap::os::version)" == '14'* ]] && pythonpkg='python3.6' # python 3.7 on 14.04 has pip ssl problems
      venvpkg="${pythonpkg}-venv"
      pythoncmd="${pythonpkg}"
      ;;
    debian)
      pythonpkg='python3.7'
      venvpkg="${pythonpkg}-venv"
      pythoncmd="${pythonpkg}"
      ;;
    *)
      pythonpkg='python36'
      pippkg="${pythonpkg}-pip"
      venvpkg="${pythonpkg}-virtualenv"
      pythoncmd='python3.6'
      ;;
  esac

  strap::pkgmgr::pkg::ensure "${pythonpkg}"
  if ! command -v "${pythoncmd}" >/dev/null 2>&1; then
    strap::abort "Python 3 could not be installed."
  fi

  [[ -n "${pippkg}" ]] && strap::pkgmgr::pkg::ensure "${pippkg}"

  # =========== Virtualenv ============
  if [[ "${distro}" == 'darwin' ]]; then
    strap::running "Checking python virtualenv"
    if ! python3 -c "import virtualenv" >/dev/null 2>&1; then
      strap::action "Installing python virtualenv"
      strap::exec "${pythoncmd}" -m pip install --user --upgrade virtualenv
    fi
    strap::ok
  else # linuxes:
    strap::pkgmgr::pkg::ensure python3-openssl
    strap::pkgmgr::pkg::ensure "${venvpkg}"
  fi

  strap::running "Ensuring strap virtualenv"
  "${pythoncmd}" -m venv "${venv_dir}"
  set +eu
  source "${venv_dir}/bin/activate" || strap::abort "Error - could not source ${venv_dir}/bin/activate"
  set -eu
  strap::ok

  strap::running "Checking strap virtualenv latest pip"
  python -m pip install --upgrade pip >/dev/null 2>&1 || true # we try to upgrade, but it's not a big deal if we can't
  strap::ok
}

set +a