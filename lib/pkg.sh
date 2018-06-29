#!/usr/bin/env bash

set -Eeo pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

command -v strap::lib::import >/dev/null || { echo "strap::lib::import is not available" >&2; exit 1; }
strap::lib::import logging || . logging.sh
strap::lib::import lang || . lang.sh
strap::lib::import fs || . fs.sh
strap::lib::import git || . git.sh

STRAP_USER_HOME="${STRAP_USER_HOME:-}" && strap::assert::has_length "$STRAP_USER_HOME" 'STRAP_USER_HOME is not set.'

set -a

strap::pkg::id::canonicalize() {

  local id="${1:-}" && strap::assert::has_length "$id" '$1 must be a Strap package id'
  id="${id//[[:space:]]/}" # remove any whitespace
  id="${id////}" # remove any forward slashes

  IFS=':' read -r -a tokens <<< "$id"
  local -r len="${#tokens[@]}"
  [[ "$len" -ne "2" && "$len" -ne "3" ]] && strap::assert::has_length '' 'Strap package id must contain either one or two colon characters'

  local -r group_id="${tokens[0]}"
  local -r pkg_name="${tokens[1]}"
  local version='HEAD'
  if [[ "$len" -eq "3" ]]; then
    version="${tokens[2]}"
  fi

  echo "$group_id:$pkg_name:$version"
}

strap::pkg::id::dir::relative() {
  local group_id=
  local pkg_name=
  local version=

  local id="${1:-}" && strap::assert::has_length "$id" '$1 must be a Strap package id'
  id="$(strap::pkg::id::canonicalize "$id")"

  local -r tokenized="${id//:/ }" # split on ':' to use for the read command next:
  IFS=' ' read -r group_id pkg_name version <<< "${tokenized}" # assign each token to the vars

  local group_dirs="${group_id//.//}" # swap out periods for forward slashes

  echo "$group_dirs/$pkg_name/$version"
}

strap::pkg::id::dir() {
  local id="${1:-}" && strap::assert::has_length "$id" '$1 must be a Strap package id'
  local relative_dir="$(strap::pkg::id::dir::relative "$id")"
  echo "$STRAP_USER_HOME/packages/$relative_dir"
}

strap::pkg::id::github::url::domain_and_path() {
  local group=
  local name=
  local version=
  local id="${1:-}" && strap::assert::has_length "$id" '$1 must be a Strap package id'
  id="$(strap::pkg::id::canonicalize "$id")"
  IFS=':' read -r group name version <<< "$id" # split on ':' and assign each resulting token to the vars

  local reversed_domain="${group%.*}" # everything leading up to, but not including, the last period character
  local -r repo="${group##*.}" # everything after, but not including, the last period character

  local tokens=
  IFS='.' read -r -a tokens <<< "$reversed_domain"

  # reverse the domain tokens:
  local domain=''
  local len="${#tokens[@]}"
  local last_index=$((len - 1))
  for (( i=$last_index; i >= 0; i-- )); do
    domain="${domain}${tokens[i]}"
    if [[ "$i" -ne "0" ]]; then
      domain="$domain."
    fi
  done

  echo "$domain/$repo/$name.git"
}

strap::pkg::id::github::url::https() {
  local -r id="${1:-}" && strap::assert::has_length "$id" '$1 must be a Strap package id'
  local -r domain_and_path="$(strap::pkg::id::github::url::domain_and_path "$id")"
  echo "https://${domain_and_path}"
}

strap::pkg::id::github::url::ssh() {
  local -r id="${1:-}" && strap::assert::has_length "$id" '$1 must be a Strap package id'
  local domain_and_path="$(strap::pkg::id::github::url::domain_and_path "$id")"
  domain_and_path="${domain_and_path/\//:}" # replace the first (and only the first) forward slash with a colon
  echo "git@${domain_and_path}"
}

strap::pkg::id::dir::ensure() {
  local -r id="${1:-}" && strap::assert::has_length "$id" '$1 must be a Strap package id'
  local -r dir="$(strap::pkg::id::dir "$id")"

  if [[ ! -d "$dir" ]]; then
    [[ -f "$dir" ]] && strap::abort "Strap package $id requires $dir to be a directory, not a file."
    mkdir -p "$dir" || strap::abort "Unable to create directory $dir for strap package $id. Please check directory write permissions for user $STRAP_USER"
  fi
}

strap::pkg::dir::prune() {
  local dir="${1:-}" && strap::assert "[[ -d \"${dir}\" && \"${dir}\" = \"$STRAP_USER_HOME/packages/\"* ]]" '$1 must be a Strap package directory'
  local parent=

  while [[ -z "$(ls -A ${dir})" && "$dir" != *"/packages" ]]; do # dir is empty and not the ~/.strap/packages dir
    parent="$(dirname "$dir")"
    rm -rf "$dir"
    dir="$parent"
  done
}

strap::pkg::ensure() {
  local id="${1:-}" && strap::assert::has_length "$id" '$1 must be a Strap package id'
  local -r dir="$(strap::pkg::id::dir "$id")"
  local output=

  strap::pkg::id::dir::ensure "$id" # ensure the directory exists and it is an actual directory (not a file)

  local -r rev="${dir##*/}" # dir is canonical and always ends with a rev, so get chars after the last '/'

  if [[ -n "$(ls -A ${dir})" ]]; then # dir already has contents

    if [[ "$rev" = "HEAD" ]]; then
      # HEAD means current origin HEAD, so we need to git fetch, and abort if that fails:
      output="$(cd "$dir"; git fetch 2>&1)"
      if [[ "$?" -ne 0 ]]; then # git fetch failed
        strap::abort "Unable to update Strap package $id via \`git fetch\` in directory $dir: \n\n${output}\n\n"
      fi
      # otherwise git fetch succeeded and the directory's .git references are up to date
    else
      return 0 # $dir has contents and the $rev is not HEAD, so we already have the contents we need, just return
    fi

  else

    # otherwise, the directory is empty - let's populate it if we can:

    # https urls are recommended for GitHub per https://help.github.com/articles/which-remote-url-should-i-use/
    local -r url="$(strap::pkg::id::github::url::https "$id")"

    if ! strap::git::remote::available "$url"; then
      strap::pkg::dir::prune "$dir"
      local -r msg="Unable to access Strap package $id via \`git ls-remote $url\`. If you are\
sure the package id and resulting URL are correct, you may not have permissions to access the repository.  If\
so, please contact the repository administrator and ask for read permissions."
      strap::abort "$msg"
    fi

    # at this point, the local directory exists, and git ls-remote indicated that we can read from the repo, so
    # let's clone it to that directory:
    output="$(git clone "$url" "$dir" 2>&1)"
    if [[ "$?" -ne 0 ]]; then # git clone failed
      strap::pkg::dir::prune "$dir"
      strap::abort "Unable to download Strap package $id to directory $dir via \`git clone $url\`. If you are sure\
      the package id and URL are correct, you may not have permissions to access the repository.  If so, please\
      contact the repository administrator and ask for read permissions.  Command output: \n\n${output}\n\n"
    fi

  fi

  # ensure the checked-out repo reflects the specified rev:
  local -r hash="$(cd "$dir"; git rev-parse -q --verify "$rev")"

  if [[ -z "$hash" ]]; then
    strap::abort "Invalid Strap package id $id: '$rev' does not equal a known git refname in cloned git directory $dir"
  fi

  $(cd "$dir"; git checkout "$hash")
}