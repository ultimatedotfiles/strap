#!/usr/bin/env bash

set -Eeuo pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

command -v strap::lib::import >/dev/null || { echo "strap::lib::import is not available" >&2; exit 1; }
strap::lib::import lang || . lang.sh
strap::lib::import logging || . logging.sh
strap::lib::import path || . path.sh
strap::lib::import os || . os.sh

set -a

strap::pkgmgr::id() {
  local id

  if command -v brew >/dev/null 2>&1; then
    id='brew'
  elif command -v yum >/dev/null 2>&1; then
    id='yum'
  elif command -v apt-get >/dev/null 2>&1; then
    id='apt'
  else
    echo "Unable to detect $STRAP_OS package manager" >&2
    return 1
  fi

  echo "$id"
}

export STRAP_PKGMGR_ID="$(strap::pkgmgr::id)"

strap::pkgmgr::init() {
  strap::lib::import "$STRAP_PKGMGR_ID" # id is also a package name in lib (i.e. lib/<name>.sh
  "strap::${STRAP_PKGMGR_ID}::init" # init the pkg mgr
}

strap::pkgmgr::pkg::is_installed() {
  local id="${1:-}" && strap::assert::has_length "$id" '$1 must be the package id'
  "strap::${STRAP_PKGMGR_ID}::pkg::is_installed" "$id"
}

strap::pkgmgr::pkg::install() {
  local id="${1:-}" && strap::assert::has_length "$id" '$1 must be the package id'
  "strap::${STRAP_PKGMGR_ID}::pkg::install" "$id"
}

strap::pkgmgr::pkg::ensure() {
  local id="${1:-}" && strap::assert::has_length "$id" '$1 must be the package id'
  strap::running "Checking $id"
  if ! strap::pkgmgr::pkg::is_installed "$id"; then
    strap::action "Installing $id"
    strap::pkgmgr::pkg::install "$id"
  fi
  strap::ok
}

set +a