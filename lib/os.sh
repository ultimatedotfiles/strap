#!/usr/bin/env bash

set -Eeuo pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

command -v strap::lib::import >/dev/null || { echo "strap::lib::import is not available" >&2; exit 1; }
strap::lib::import logging || . logging.sh

set -a

strap::os::category() {
  local os
  local out="$(uname -s)"
  case "${out}" in
    Linux*)  os='linux' ;;
    Darwin*) os='mac' ;;
    CYGWIN*) os='cygwin' ;;
    MINGW*)  os='mingw' ;;
    *)       os="UNKNOWN:${os}" ;;
  esac
  echo "$os"
}
readonly STRAP_OS="$(strap::os::category)"

strap::semver::version() {

  local flags major minor patch
  local version="$1"
  [[ -n "$2" ]] && version="$2" && [[ "$1" == "-"* ]] && flags="$1"
  [[ -z "$version" ]] && strap::error "strap::semver::version requires a version argument" && return 1

  if [[ -n "$flags" ]]; then
    IFS='.' read -r major minor patch <<-_EOF_
$version
_EOF_
    case "$flags" in
      *M*) echo "$major" ;;
      *m*) echo "$minor" ;;
      *p*) echo "$patch" ;;
      *) echo "unsupported option: $flags" >&2 && return 1 ;;
    esac
  else
    echo "$version"
  fi
}

strap::os::version() {
  local version
  case "$STRAP_OS" in
    mac) version="$(sw_vers -productVersion)" ;;
    *) echo "unsupported os" >&2 && return 1 ;;
  esac
  strap::semver::version "$1" "$version"
}

readonly STRAP_OS_VERSION="$(strap::os::version)"
readonly STRAP_OS_VERSION_MAJOR="$(strap::os::version -M)"
readonly STRAP_OS_VERSION_MINOR="$(strap::os::version -m)"
readonly STRAP_OS_VERSION_PATCH="$(strap::os::version -p)"

set +a