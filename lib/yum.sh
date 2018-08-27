#!/usr/bin/env bash

set -Eeuo pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

command -v strap::lib::import >/dev/null || { echo "strap::lib::import is not available" >&2; exit 1; }
strap::lib::import lang || . lang.sh
strap::lib::import logging || . logging.sh
strap::lib::import path || . path.sh

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

##
# Ensures any initialization or setup for yum is required.  This can be a no-op if yum is always already installed
# on the host OS before strap is run.
##
strap::yum::init() {
  if ! strap::yum::pkg::is_installed 'epel-release'; then # needed for jq and maybe others
    strap::yum::pkg::install 'epel-release'
  fi
  if ! strap::yum::pkg::is_installed 'ius-release'; then # needed for git2u (up to date git and git-credential-libsecret)
    sudo yum -y install 'https://centos7.iuscommunity.org/ius-release.rpm'
  fi
}