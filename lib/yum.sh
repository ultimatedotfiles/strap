#!/usr/bin/env bash

set -Eeuo pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

command -v strap::lib::import >/dev/null || { echo "strap::lib::import is not available" >&2; exit 1; }
strap::lib::import lang || . lang.sh
strap::lib::import logging || . logging.sh
strap::lib::import path || . path.sh

##
# Ensures any initialization or setup for yum is required.  This can be a no-op if yum is always already installed
# on the host OS before strap is run.
##
strap::yum::init() {
  # implement me? Is this necessary for yum?
  true
}

strap::yum::pkg::is_installed() {
  local package_id="${1:-}" && strap::assert::has_length "$package_id" '$1 must be the package id'
  sudo yum list installed "$package_id" >/dev/null 2>&1
  return "$?"
}

strap::yum::pkg::install() {
  local package_id="${1:-}" && strap::assert::has_length "$package_id" '$1 must be the package id'
  sudo yum -y install "$package_id"
  return "$?"
}