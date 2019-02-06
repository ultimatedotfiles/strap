#!/usr/bin/env bash

set -Eeuo pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

strap::fs::readlink() {
  $(type -p greadlink readlink | head -1) "$1" # prefer greadlink if it exists
}

strap::fs::dirpath() {
  [[ -z "$1" ]] && echo "strap::fs::dirpath: a directory argument is required." >&2 && return 1
  [[ ! -d "$1" ]] && echo "strap::fs::dirpath: argument is not a directory: $1" >&2 && return 1
  echo "$(cd -P "$1" && pwd)"
}

strap::fs::filepath() {
  [[ -d "$1" ]] && echo "strap::fs::filepath: directory arguments are not permitted" >&2 && return 1
  local dirname="$(dirname "$1")"
  local filename="$(basename "$1")"
  local canonical_dir="$(strap::fs::dirpath "$dirname")"
  echo "$canonical_dir/$filename"
}

##
# Returns the canonical filesystem path of the specified argument
# Argument must be a directory or a file
##
strap::fs::path() {
  local target="$1"
  local dir
  if [[ -d "$target" ]]; then # target is a directory, get its canonical path:
    target="$(strap::fs::dirpath "$target")"
  else
    while [[ -h "$target" ]]; do # target is a symlink, so resolve it
      target="$(strap::fs::readlink "$target")"
      if [[ "$target" != /* ]]; then # target doesn't start with '/', so it's not yet absolute.  Fix that:
        target="$(strap::fs::filepath "$target")"
      fi
    done
    target="$(strap::fs::filepath "$target")"
  fi
  echo "$target"
}

print_checksums() {
  local -r file="${1:-}"
  if [ ! -f "${file}" ]; then
    echo "${file} is not a file." >&2
    return 1
  fi
  local -r filename="$(basename "${file}")"

  printf "### ${filename}\n\n\`\`\`bash\n"

  algs=( md5 sha1 sha256 sha512 )

  for alg in "${algs[@]}"; do
    printf "\$ openssl dgst -${alg} <${filename}\n"
    printf "$(openssl dgst "-${alg}" <"${file}")\n"
    [[ "${alg}" != "sha512" ]] && printf "\n"
  done

  printf "\`\`\`\n"
}

main() {
  if [[ $# -lt 1 ]]; then
    echo "One or more file arguments must be specified" >&2
    return 1
  fi

  printf "## Checksums\n\n"

  local first=true
  for file in "$@"; do
    [[ $first != true ]] && printf "\n"
    file="$(strap::fs::path "${file}")" # canonicalize
    print_checksums "${file}"
    first=false
  done
}
main "$@"