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

  local flags=
  local major=
  local minor=
  local patch=
  local version="${1:-}"
  [[ -n "${2:-}" ]] && version="$2" && [[ "${1:-}" == "-"* ]] && flags="${1:-}"
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
  local flags="${1:-}"
  local version
  case "$STRAP_OS" in
    mac) version="$(sw_vers -productVersion)" ;;
    *) echo "unsupported os" >&2 && return 1 ;;
  esac
  strap::semver::version "$flags" "$version"
}

strap::os::model::mac() {
  local hardware_overview="$(system_profiler SPHardwareDataType)"
  local model_name="$(echo "$hardware_overview" | grep 'Model Name' | awk -F': ' '{print $NF}')"
  local model_id="$(echo "$hardware_overview" | grep 'Model Identifier' | awk -F': ' '{print $NF}')"
  local proc_name="$(echo "$hardware_overview" | grep 'Processor Name' | awk -F': ' '{print $NF}')"
  local proc_speed="$(echo "$hardware_overview" | grep 'Processor Speed' | awk -F': ' '{print $NF}')"
  local serial_number="$(echo "$hardware_overview" | grep 'Serial Number' | awk -F': ' '{print $NF}')"
  local desc="$model_name serial number $serial_number ("

  local file='/System/Library/PrivateFrameworks/ServerInformation.framework/Versions/A/Resources/English.lproj/SIMachineAttributes.plist'
  if [ -f "$file" ]; then
    desc="${desc}$(defaults read "$file" "$model_id" | grep 'marketingModel' | awk -F' = ' '{print $NF}' | sed -e 's/^"//' -e 's/";$//' -e 's/\\\\//') "
  fi

  desc="${desc}$proc_speed $proc_name)"

  echo "$desc"
}

strap::os::model() {
  case "$STRAP_OS" in
    mac) echo "$(strap::os::model::mac)" ;;
    *) echo "UNKNOWN" ;;
  esac
}

readonly STRAP_OS_VERSION="$(strap::os::version)"
readonly STRAP_OS_VERSION_MAJOR="$(strap::os::version -M)"
readonly STRAP_OS_VERSION_MINOR="$(strap::os::version -m)"
readonly STRAP_OS_VERSION_PATCH="$(strap::os::version -p)"

set +a