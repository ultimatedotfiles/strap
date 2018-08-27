#!/usr/bin/env bash

set -Eeuo pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

command -v strap::lib::import >/dev/null || { echo "strap::lib::import is not available" >&2; exit 1; }
strap::lib::import logging || . logging.sh
strap::lib::import lang || . lang.sh

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

strap::os::distro() {
  local distro=''
  [[ "$STRAP_OS" == 'mac' ]] && distro='darwin'
  [[ -z "$distro" ]] && [[ -f '/etc/ubuntu-release' ]] && distro='ubuntu'
  [[ -z "$distro" ]] && [[ -f '/etc/centos-release' ]] && distro='centos'
  [[ -z "$distro" ]] && [[ -f '/etc/redhat-release' ]] && distro='redhat'
  [[ -z "$distro" ]] && distro='linux' # default
  echo "$distro"
}
readonly STRAP_OS_DISTRO="$(strap::os::distro)"

strap::os::is_mac() {
  if [[ "$STRAP_OS" == 'mac' ]]; then
    return 0
  else
    return 1
  fi
}

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

# From https://stackoverflow.com/a/48487783/407170
strap::semver::compare() {

  local a="${1:-}" && strap::assert::has_length "$a" '$1 must be the version being compared (left operand)'
  local op="${2:-}" && strap::assert::has_length "$op" '$2 must be the semver comparison operation (<, <=, ==, !=, >=, >)'
  local b="${3:-}" && strap::assert::has_length "$b" '$3 must be the version to compare (right operand)'
  local al="${a##*.}"
  local bl="${b##*.}"

  while [[ $al =~ ^[[:digit:]] ]]; do al=${al:1}; done
  while [[ $bl =~ ^[[:digit:]] ]]; do bl=${bl:1}; done
  local ai=${a%$al} bi=${b%$bl}

  local ap=${ai//[[:digit:]]} bp=${bi//[[:digit:]]}
  ap=${ap//./.0} bp=${bp//./.0}

  local w=1 fmt=$a.$b x IFS=.
  for x in $fmt; do [ ${#x} -gt $w ] && w=${#x}; done
  fmt=${*//[^.]}; fmt=${fmt//./%${w}s}
  printf -v a $fmt $ai$bp; printf -v a "%s-%${w}s" $a $al
  printf -v b $fmt $bi$ap; printf -v b "%s-%${w}s" $b $bl

  case $op in
    '<='|'>=' ) [ "$a" ${op:0:1} "$b" ] || [ "$a" = "$b" ] ;;
    * )         [ "$a" $op "$b" ] ;;
  esac
}

strap::os::version() {
  local flags="${1:-}"
  local version=''

  if command -v sw_vers >/dev/null; then # mac
    version="$(sw_vers -productVersion)"
  elif command -v lsb_release >/dev/null; then # linux distro w/ lsb_release
    version="$(lsb_release -r | sed 's/.*\:[[:blank:]]*//')"
  fi

  if [[ -z "$version" ]]; then # try centos/redhat
    local release_file='/etc/centos-release'
    [[ -f "$release_file" ]] || release_file='/etc/redhat-release' # fall back to redhat-release
    [[ -f "$release_file" ]] && version="$(cat ${release_file} | sed 's/^[^0-9]*//g' | awk '{print $1}')"
  fi

  if [[ -z "$version" ]]; then
    echo "unsupported os" >&2
    return 1
  fi

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
    desc="${desc}$(defaults read "$file" "$model_id" | grep 'marketingModel' | awk -F' = ' '{print $NF}' | sed -e 's/^"//' -e 's/";$//' -e 's/\\\\\"/-inch/') "
  fi

  desc="${desc}$proc_speed $proc_name)"

  echo "$desc"
}

strap::os::model() {
  case "$STRAP_OS" in
    mac) echo "$(strap::os::model::mac)" ;;
    *) echo "$(uname -a)" ;;
  esac
}

readonly STRAP_OS_VERSION="$(strap::os::version)"
readonly STRAP_OS_VERSION_MAJOR="$(strap::os::version -M)"
readonly STRAP_OS_VERSION_MINOR="$(strap::os::version -m)"
readonly STRAP_OS_VERSION_PATCH="$(strap::os::version -p)"

set +a