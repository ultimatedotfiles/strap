#!/usr/bin/env bash

set -Eeuo pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

command -v strap::lib::import >/dev/null || { echo "strap::lib::import is not available" >&2; exit 1; }
strap::lib::import lang || . lang.sh
strap::lib::import logging || . logging.sh
strap::lib::import path || . path.sh

##
# Ensures any initialization or setup for apt-get is required.  This can be a no-op if it is always already installed
# on the host OS before strap is run.
##
strap::aptget::init() {
  sudo apt-get update -qq -o Acquire:Check-Valid-Until=false
  sudo apt-get install -y -qq software-properties-common
  sudo apt-add-repository -y ppa:ansible/ansible
  sudo apt-get update -qq -o Acquire:Check-Valid-Until=false
}

strap::aptget::pkg::is_installed() {
  local package_id="${1:-}" && strap::assert::has_length "$package_id" '$1 must be the package id'
  sudo dpkg-query -W -f='${Status}' "$package_id" 2>/dev/null | grep -q "ok installed"
  return "$?"
}

strap::aptget::pkg::install() {
  local package_id="${1:-}" && strap::assert::has_length "$package_id" '$1 must be the package id'
  sudo apt-get install -y "$package_id"
  return "$?"
}