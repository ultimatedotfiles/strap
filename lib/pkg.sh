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

strap::pkg::yaml::path() {
  local -r arg="${1:-}" && strap::assert::has_length "$arg" '$1 must be a Strap package id or directory'
  local dir=

  if [[ -d "$arg" ]]; then
    dir="$arg"
  else
    dir="$(strap::pkg::id::dir "$arg")"
  fi

  local -r fname="package.yml"

  local file="${dir}/.strap/${fname}" # prefer a <repo>/.strap/ directory convention
  if [[ ! -f "${file}" ]]; then # fall back to repo root:
    file="${dir}/${fname}"
  fi

  strap::assert "[ -f $file ]" "Package directory $dir does not contain a package.yml file."

  echo "$file"
}

strap::pkg::yaml::jq() {
  local -r file="${1:-}" && strap::assert "[ -f $file ]" '$1 must be a Strap package.yml file'
  local -r query="${2:-}" && strap::assert::has_length "$query" '$2 must be a jq query string'
  python -c 'import sys, yaml, json; json.dump(yaml.full_load(sys.stdin), sys.stdout, indent=2)' < "$file" | jq -r "$query"
}

strap::pkg::yaml::hook::path() {
  local -r arg="${1:-}" && strap::assert::has_length "$arg" '$1 must be a Strap package id or directory'
  local -r hook_name="${2:-}" && strap::assert::has_length "$hook_name" '$2 must be a hook name'
  local -r file="$(strap::pkg::yaml::path "$arg")"
  local -r dir="$(dirname "$file")"

  local hook="$(strap::pkg::yaml::jq "$file" ".hooks.${hook_name} // empty")"

  [[ -z "$hook" ]] && strap::abort "Package $arg package.yml does not contain a hooks.${hook_name} entry"

  # strip leading forward slash if any:
  hook="${hook#/}"

  local -r hook_file="$dir/$hook"
  [[ -f "$hook_file" ]] || strap::abort "Package $arg package.yml hooks.${hook_name}: $hook is not a file."

  echo "$hook_file"
}

strap::pkg::ensure() {
  local id="${1:-}" && strap::assert::has_length "$id" '$1 must be a Strap package id'
  local -r dir="$(strap::pkg::id::dir "$id")"
  local output=
  local parent=
  local cloned=false

  strap::running "Checking package $id"

  strap::pkg::id::dir::ensure "$id" # ensure the directory exists and it is an actual directory (not a file)

  local rev="${dir##*/}" # dir is canonical and always ends with a rev, so get chars after the last '/'

  if [[ -n "$(ls -A ${dir})" ]]; then # dir already has contents

    if ! (cd "${dir}"; git rev-parse --is-inside-work-tree >/dev/null 2>&1); then # dir is not a valid git work tree
      strap::abort "Strap package $id directory $dir is not a valid git clone. Delete this directory and run strap again."
    fi

    if ! (cd "${dir}"; git rev-parse -q --verify "${rev}^{tag}" >/dev/null 2>&1); then # rev is not a tag, we need to git pull

      output="$(cd "$dir"; git pull 2>&1)"
      if [[ "$?" -ne 0 ]]; then # git pull failed
        strap::abort "Unable to update Strap package $id via \`git pull\` in directory $dir: \n\n${output}\n\n"
      fi
      # otherwise git pull succeeded and the directory's .git references are up to date

    else
      strap::ok
      return 0 # $rev is an immutable tag, so we already have the contents we need, just return
    fi

  else

    # otherwise, the directory is empty - let's populate it if we can:

    # https urls are recommended for GitHub per https://help.github.com/articles/which-remote-url-should-i-use/
    local url="$(strap::pkg::id::github::url::https "$id")"

    # let's try to clone to the directory:
    strap::action "Cloning $url"
    if ! git clone "$url" "$dir" >/dev/null 2>&1; then # https clone failed, try ssh url (permissions might be different):

      local -r https_url="$url" #save for error message just in case

      url="$(strap::pkg::id::github::url::ssh "$id")"

      if ! git clone "$url" "$dir" >/dev/null 2>&1; then # git clone failed, exit:

        # cleanup first:
        parent="$(dirname "$dir")"
        rm -rf "$dir"
        strap::pkg::dir::prune "$parent"

        # exit:
        strap::abort "Unable to download Strap package $id via either \`git clone $https_url\` or \`git clone $url\` \
to directory $dir. If you are sure the package id and URLs are correct, you may not have permissions to access the \
repository. If so, please contact the repository administrator and ask for read permissions."
      fi
    fi
    cloned=true
  fi

  # If rev is 'HEAD', it really means 'origin/HEAD' for Strap's purposes, so set that accordingly before checkout:
  [[ "$rev" = "HEAD" ]] && rev="origin/HEAD"

  # ensure the checked-out repo reflects the specified rev:
  if ! (cd "$dir"; git checkout "$rev" >/dev/null 2>&1); then # checkout failed

    if [[ "$cloned" = true ]]; then # cleanup the dir we created:
      parent="$(dirname "$dir")"
      rm -rf "$dir"
      strap::pkg::dir::prune "$parent"
    fi

    strap::abort "Invalid strap package id $id: '$rev' does not equal a known git refname in cloned git directory $dir"
  fi

  strap::ok
}

set +a
