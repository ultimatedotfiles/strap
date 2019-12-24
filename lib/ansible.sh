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
STRAP_INTERACTIVE="${STRAP_INTERACTIVE:-}"; [[ -n "$STRAP_INTERACTIVE" ]] || STRAP_INTERACTIVE=true
STRAP_ANSIBLE_VERSION="${STRAP_ANSIBLE_VERSION:-}"
STRAP_ANSIBLE_DIR="${STRAP_USER_HOME}/ansible"
STRAP_ANSIBLE_LOG_FILE="${STRAP_ANSIBLE_DIR}/ansible.log"
STRAP_ANSIBLE_BIN_DIR="${STRAP_ANSIBLE_DIR}/bin"
STRAP_ANSIBLE_GALAXY_INSTALL_SCRIPT="${STRAP_ANSIBLE_BIN_DIR}/ansible-galaxy-install"
STRAP_ANSIBLE_GALAXY_INSTALL_SCRIPT_VERSION="${STRAP_ANSIBLE_GALAXY_INSTALL_SCRIPT_VERSION:-0.1.0}"
STRAP_ANSIBLE_GALAXY_INSTALL_SCRIPT_URL="${STRAP_ANSIBLE_GALAXY_INSTALL_SCRIPT_URL:-}"
[[ -n "${STRAP_ANSIBLE_GALAXY_INSTALL_SCRIPT_URL}" ]] || STRAP_ANSIBLE_GALAXY_INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/lhazlewood/ansible-galaxy-install/${STRAP_ANSIBLE_GALAXY_INSTALL_SCRIPT_VERSION}/bin/ansible-galaxy-install"
STRAP_ANSIBLE_ROLES_DIR="${STRAP_ANSIBLE_DIR}/roles"
STRAP_ANSIBLE_PLAYBOOKS_DIR="${STRAP_ANSIBLE_DIR}/playbooks"
STRAP_ANSIBLE_IMPLICIT_PLAYBOOK_DIR="${STRAP_ANSIBLE_PLAYBOOKS_DIR}/.implicit"
STRAP_ANSIBLE_GITHUB_URL_PREFIX="${STRAP_ANSIBLE_GITHUB_URL_PREFIX:-}"
if [[ -z "${STRAP_ANSIBLE_GITHUB_URL_PREFIX}" ]]; then
  STRAP_ANSIBLE_GITHUB_URL_PREFIX='https://github.com/'
fi

set -a

function strap::ansible::install() {

  local output= retval= wrapper_file= venv_dir="${STRAP_USER_HOME}/.venv"

  if [[ -n "${STRAP_ANSIBLE_VERSION}" ]]; then
    strap::running "Ensuring strap virtualenv ansible version ${STRAP_ANSIBLE_VERSION}"
    strap::exec python -m pip install ansible=="${STRAP_ANSIBLE_VERSION}"
  else
    strap::running "Ensuring strap virtualenv ansible"
    strap::exec python -m pip install --upgrade ansible
  fi
  strap::ok

  strap::os::is_mac && strap::pkgmgr::pkg::ensure 'gnu-tar' # needed for ansible 'unarchive' module on macOS

  command -v curl >/dev/null 2>&1 || strap::pkgmgr::pkg::ensure 'curl' # needed to download wrapper script

  strap::running "Checking strap ansible-galaxy-install wrapper"
  if [[ ! -f "${STRAP_ANSIBLE_GALAXY_INSTALL_SCRIPT}" ]]; then
    mkdir -p "${STRAP_ANSIBLE_BIN_DIR}"
    strap::action 'Downloading strap ansible-galaxy-install wrapper'
    curl -fsSL "${STRAP_ANSIBLE_GALAXY_INSTALL_SCRIPT_URL}" -o "${STRAP_ANSIBLE_GALAXY_INSTALL_SCRIPT}"
  fi
  [[ -x "${STRAP_ANSIBLE_GALAXY_INSTALL_SCRIPT}" ]] || chmod u+x "${STRAP_ANSIBLE_GALAXY_INSTALL_SCRIPT}"
  strap::ok
}

function strap::ansible() {
  ( # subshell so we don't alter strap's environment
    unset -f $(compgen -A function strap) # remove strap functions from ansible context.  /bin/sh yells otherwise
    ansible "$@"
  )
}

function strap::ansible-galaxy() {
  (
    unset -f $(compgen -A function strap)
    ansible-galaxy "$@"
  )
}

function strap::ansible-galaxy-install() {
  (
    unset -f $(compgen -A function strap)
    "${STRAP_ANSIBLE_GALAXY_INSTALL_SCRIPT}" "$@"
  )
}

function strap::ansible-playbook() {
  (
    unset -f $(compgen -A function strap)
    ansible-playbook "$@"
  )
}

function strap::ansible::os::family() {
  strap::ansible localhost -m setup 2>/dev/null | sed '1 s/^.*$/{/' | jq -r '.ansible_facts.ansible_os_family'
}

function strap::ansible::python::interpreter() {
  head -n1 "$(which ansible-playbook)" | sed 's/#!//g'
}

function strap::ansible::python() {
  local interpreter
  interpreter="$(strap::ansible::python::interpreter)"
  ${interpreter} "$@"
}

function strap::ansible::roles::run() {

  [[ "$#" -gt 0 ]] || strap::abort "One or more ansible role identifiers are required as function arguments."

  local role_id= value=
  local -a role_ids=()
  local -a params=()

  while (( "$#" )); do
    [[ "$1" == --*=* ]] && set -- "${1%%=*}" "${1#*=}" "${@:2}" # normalize `--foo=bar` into `--foo bar`
    case "$1" in
      --role|--with-role)
        role_id="${2:-}"
        [[ -n "${role_id}" && "${role_id}" != '-'* ]] || strap::abort "strap lansible: $1 argument requires a value"
        role_ids+=("${role_id}")
        shift 2
        ;;
      -i|--inventory|--inventory-file)
        strap::abort "strap lansible: $1 is not supported since localhost is always used (lansible = 'localhost ansible')."
        ;;
      -K|--ask-become-pass) # ignore - we add this no matter what
        shift
        ;;
      --) # end argument parsing
        shift
        break
        ;;
      *) # preserve positional args
        params+=("$1")
        shift
        ;;
    esac
  done

  if [[ "${STRAP_INTERACTIVE}" == true ]]; then # false in CI
    params+=( '--ask-become-pass' )
  fi

  if [[ "${#params[@]}" -gt 0 ]]; then
    set -- "${params[@]}" # reset positional arguments
  fi

  local repo_url= roles_dir= interpreter= playbook_dir="${STRAP_ANSIBLE_IMPLICIT_PLAYBOOK_DIR}"
  local requirements_file= playbook_file=
  local src= name= scm= version=
  local -a extra_vars
  role_id=''
  roles_dir="${playbook_dir}/roles"

  # all runs start fresh:
  rm -rf "${playbook_dir}"
  rm -rf "${roles_dir}"
  rm -rf "${STRAP_ANSIBLE_LOG_FILE}"
  mkdir -p "${playbook_dir}" 2>/dev/null
  mkdir -p "${roles_dir}" 2>/dev/null

  requirements_file="${playbook_dir}/requirements.yml"
  playbook_file="${playbook_dir}/playbook.yml"

cat << EOF > "${playbook_file}"
---
- name: Run Strap Ansible roles
  hosts: 127.0.0.1
  connection: local
  tasks:
EOF

  # add roles path to config:
  { echo '[defaults]'; echo "roles_path = ${roles_dir}:${STRAP_ANSIBLE_ROLES_DIR}"; } >> "${playbook_dir}/ansible.cfg"

  echo "---" >> "${requirements_file}"

  for role_id in "${role_ids[@]}"; do

    src="${role_id}"

    if [[ "${src}" == *'#'* ]]; then # the src has a hash character, implying metadata we need
      local entry= i= metadata="${src#*#}" # get everything after the first hash character
      src="${src%%#*}" # get everything before the first hash character
      [[ "${metadata}" != *'#'* ]] || strap::abort "Invalid ansible role identifier: ${role_id}"
      local entries
      IFS='&' read -ra entries <<< "${metadata}"

      i=0
      for entry in "${entries[@]}"; do
        if [[ "${entry}" == 'name='* ]]; then
          name="${entry#'name='}"
        elif [[ "${entry}" == 'scm='* ]]; then
          scm="${entry#'scm='}"
        elif [[ "${entry}" == 'version='* ]]; then
          version="${entry#'version='}"
        else
          [[ -z "${version}" || "${i}" -eq 0 ]] || strap::abort "Invalid ansible role identifier: ${role_id}"
          version="${entry}"
        fi
        i=$((i+1))
      done
    fi

    if [[ "${src}" != *'/'* && "${src}" != *':'* && "${src//[!.]}" == '.' ]]; then
      # src is a standard Ansible Galaxy 'foo.bar' reference.  It should not have an scm or a different name value:
      name="${src}"
      scm=''
    else
      # src is not a standard Ansible Galaxy 'foo.bar' reference.  It must be a URL.  Check for convenience urls:
      if [[ "${src}" != '/'* && "${src//[!\/]}" == '/' && "${src}" != *':'* ]]; then
        # doesn't start with a slash, but contains exactly one, so our heuristics mean this is a github fragment
        name="${src//[\/]/.}" # replace the slash with a period for a fully-qualified galaxy name
        src="${STRAP_ANSIBLE_GITHUB_URL_PREFIX}${src}" # fully qualify the fragment
        scm='git'
      fi
    fi

    # heuristics for git scm.  Covers probably 90% of all popular git URLs:
    if [[ -z "${scm}" ]] && [[ "${src}" == 'git@'* || "${src}" == 'git+'* || "${src}" == 'ssh://git@'* || "${src}" == *'.git' ]]; then
      scm='git'
    fi

    if [[ -z "${name}" && "${src}" == *'/'* && "${src}" != *'.zip' && "${src}" != *'.tar' && "${src}" != *'.gz' ]]; then
      local prefix="${src%/*}" # everything before the last '/'
      local next_to_last= last="${src##*/}"  # everything after the last '/'
      if [[ -n "${last}" ]]; then
        if [[ "${prefix}" == *'/'* ]]; then
          next_to_last="${prefix##*/}"
          [[ -n "${next_to_last}" ]] && name="${next_to_last}.${last}"
        elif [[ "${prefix}" == *':'* ]]; then
          next_to_last="${prefix##*:}"
          [[ -n "${next_to_last}" ]] && name="${next_to_last}.${last}"
        fi
      fi
    fi

    if [[ "${name}" == *'.git' ]]; then
      name="${name%%'.git'}"
    fi

    echo "- src: '${src}'" >> "${requirements_file}"
    if [[ -n "${version}" ]]; then
      echo "  version: '${version}'" >> "${requirements_file}"
    fi
    if [[ -n "${name}" ]]; then
      echo "  name: '${name}'" >> "${requirements_file}"
    fi

    # even if there's no name for the requirements file, we need one for the playbook file:
    [[ -n "${name}" ]] || strap::abort "Heuristics to determine a unique ansible-compatible role name have been exhausted for role id: ${role_id}. Please specify a #name=<namevalue> parameter."
    echo "    - import_role: name=${name}" >> "${playbook_file}"

    if [[ -n "${scm}" ]]; then
      echo "  scm: '${scm}'" >> "${requirements_file}"
    fi
    echo '' >> "${requirements_file}"

    # clear out for next loop iteration:
    src=''
    name=''
    scm=''
    version=''
  done
  echo "" >> "${playbook_file}"

  (
    cd "${playbook_dir}"
    export ANSIBLE_LOG_PATH="${STRAP_ANSIBLE_LOG_FILE}"
    strap::ansible-galaxy-install -r "${requirements_file}"
    printf '\nRunning ansible to manage localhost.'
    if [[ "${STRAP_INTERACTIVE}" == true ]]; then
      printf ' Please enter your SUDO/' # make the --ask-become-pass prompt more visible/obvious
    else
      printf '\n'
    fi
    strap::ansible-playbook -i "${STRAP_HOME}/etc/ansible/hosts" "$@" "${playbook_file}"
  )
}

strap::ansible::playbook::run() {

  local playbook_dir= playbook_file= requirements_file= 
  local -a params=()

  while (( "$#" )); do
    [[ "$1" == --*=* ]] && set -- "${1%%=*}" "${1#*=}" "${@:2}" # normalize `--foo=bar` into `--foo bar`
    case "$1" in
      --playbook|--with-playbook)
        playbook_dir="${2:-${STRAP_WORKING_DIR}/.strap/ansible/playbooks/default}"
        [[ -d "${playbook_dir}" ]] || strap::abort "strap lansible: $1 needs to be a directory"
        shift 2
        ;;
      -i|--inventory|--inventory-file)
        strap::abort "strap lansible: $1 is not supported since localhost is always used (lansible = 'localhost ansible')."
        ;;
      -K|--ask-become-pass) # ignore - we add this no matter what
        shift
        ;;
      --) # end argument parsing
        shift
        break
        ;;
      *) # preserve positional args
        params+=("$1")
        shift
        ;;
    esac
  done

  if [[ "${STRAP_INTERACTIVE}" == true ]]; then # false in CI
    params+=( '--ask-become-pass' )
  fi

  if [[ "${#params[@]}" -gt 0 ]]; then
    set -- "${params[@]}" # reset positional arguments
  fi

  playbook_file="${playbook_dir}/main.yml"
  requirements_file="${playbook_dir}/meta/requirements.yml"
  [[ -f "${requirements_file}" ]] || requirements_file="${playbook_dir}/requirements.yml"

  # run starts fresh
  rm -rf "${STRAP_ANSIBLE_ROLES_DIR}"
  rm -rf "${STRAP_ANSIBLE_LOG_FILE}"

  (
    export ANSIBLE_ROLES_PATH="${STRAP_ANSIBLE_ROLES_DIR}"
    cd "${playbook_dir}"
    export ANSIBLE_LOG_PATH="${STRAP_ANSIBLE_LOG_FILE}"
    [[ -f "${requirements_file}" ]] && strap::ansible-galaxy-install -r "${requirements_file}" 
    printf '\nRunning ansible to manage localhost.'
    if [[ "${STRAP_INTERACTIVE}" == true ]]; then
      printf ' Please enter your SUDO/' # make the --ask-become-pass prompt more visible/obvious
    else
      printf '\n'
    fi
    strap::ansible-playbook -i "${STRAP_HOME}/etc/ansible/hosts" "$@" "${playbook_file}"
  )
}

set +a
