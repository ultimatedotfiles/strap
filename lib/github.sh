#!/usr/bin/env bash

set -Eeuo pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

command -v strap::lib::import >/dev/null || { echo "strap::lib::import is not available" >&2; exit 1; }
strap::lib::import logging || . logging.sh
strap::lib::import io || . io.sh
strap::lib::import os || . os.sh
strap::lib::import git || . git.sh

__STRAP_GITHUB_USER_JSON="${__STRAP_GITHUB_USER_JSON:-}"
__STRAP_GITHUB_USER_EMAILS_JSON="${__STRAP_GITHUB_USER_EMAILS_JSON:-}"

strap::github::token::save() {
  local -r username="${1:-}" && [[ -z "$username" ]] && strap::error 'strap::github::token::find: $1 must be a github username' && return 1
  local -r token="${2:-}" && [[ -z "$token" ]] && strap::error 'strap::github::token::find: $2 must be a github api token' && return 1
  printf "protocol=https\nhost=github.com\n" | git credential-osxkeychain erase # clear any previous value
  printf "protocol=https\nhost=github.com\nusername=%s\npassword=%s\n" "$username" "$token" | git credential-osxkeychain store # save it
}

strap::github::token::find() {

  local -r username="${1:-}" && [[ -z "$username" ]] && strap::error 'strap::github::token::find: $1 must be a github username' && return 1
  local token=

  if strap::git::credential::osxkeychain::available; then
    token="$(printf "host=github.com\nprotocol=https\nusername=${username}\n\n" | git credential-osxkeychain get | cut -d "=" -f 2)"
  fi

  # This is for legacy strap environments where strap stored the token manually in the osxkeychain instead of using
  # the git credential helper.  If found, it will be moved to the git credential helper (as this is the de-facto standard)
  # and then removed from the manual osx keychain entry:
  if [[ -z "$token" ]] && [[ "$STRAP_OS" == "mac" ]]; then

    local -r label="Strap GitHub API personal access token"

    if security find-internet-password -a "$username" -s api.github.com -l "$label" >/dev/null 2>&1; then

      token="$(security find-internet-password -a "$username" -s api.github.com -l "$label" -w)"

      if [[ -n "$token" ]]; then # found in the legacy location

         # save to the de-facto location:
         strap::github::token::save "$username" "$token"

         # remove from the legacy location:
         security delete-internet-password -a "$username" -s api.github.com -l "$label"
      fi

    fi

  fi

  echo "$token"
}

strap::github::api::request() {

  local -r token="${1:-}" && [[ -z "$token" ]] && strap::error 'strap::github::api::request: $1 must be a github api token' && return 1
  local -r url="${2:-}" && [[ -z "$url" ]] && strap::error 'strap::github::api::request: $2 must be a github api URL' && return 1

  local -r response="$(curl --silent --show-error -H "Authorization: token $token" --write-out "HTTPSTATUS:%{http_code}" "$url")"
  local -r body="$(echo "$response" | sed -e 's/HTTPSTATUS\:.*//g')"
  local -r status_code="$(echo "$response" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')"

  if [[ "$status_code" == "200" ]]; then
    echo "$body"
  elif [[ "$status_code" == "4*" ]]; then
    return 1
  else
    strap::error "Unexpected GitHub API response:"
    strap::error "    Reqeuest URL: $url"
    strap::error "    Response Status Code: $status_code"
    strap::error "    Response Body: $body"
    return 1
  fi
}

strap::github::api::token::create() {

  local -r username="${1:-}" && [[ -z "$username" ]] && strap::error 'strap::github::token::find: $1 must be a github username' && return 1
  local -r utc_date="$(date -u +%FT%TZ)"
  local password=
  strap::readval password "Enter (or cmd-v paste) your GitHub password" true

  local -r request_body="{\"scopes\":[\"repo\",\"admin:org\",\"admin:public_key\",\"admin:repo_hook\",\"admin:org_hook\",\"gist\",\"notifications\",\"user\",\"delete_repo\",\"admin:gpg_key\"],\"note\":\"Strap-generated token, created at $utc_date\"}"
  local -r creds="$username:$password"
  local response="$(curl --silent --show-error -i -u "$creds" -H "Content-Type: application/json" -X POST -d "$request_body" https://api.github.com/authorizations)"

  status_code="$(echo "$response" | grep 'HTTP/1.1' | awk '{print $2}')" && [[ -z "$status_code" ]] && strap::abort "Unable to parse GitHub response status.  GitHub response format is likely to have changed.  Please report this to the Strap developers."
  otp_type="$(echo "$response" | grep 'X-GitHub-OTP:' | awk '{print $3}')"

  if [[ -n "$otp_type" ]]; then # two-factor required - ask for code:
    local two_factor_code=
    strap::readval two_factor_code "Enter GitHub two-factor code"
    #try again, this time with the OTP code:
    response="$(curl --silent --show-error -u "$creds" -H "X-GitHub-OTP: $two_factor_code" -H "Content-Type: application/json" -X POST -d "$request_body" https://api.github.com/authorizations)"
  fi

  local token="$(echo "$response" | grep '^  "token": ' | sed 's/,//' | sed 's/"//g' | awk '{print $2}')"
  [[ -z "$token" ]] && strap::abort "Unable to parse GitHub response API Token.  GitHub response format may have changed.  Please report this to the Strap developers.  GitHub HTTP response: $response"

  # we have a token now - save it to secure storage:
  strap::github::token::save "$username" "$token"
}

strap::github::api::token::is_valid() {

  local -r token="${1:-}" && [[ -z "$token" ]] && strap::error 'strap::github::api::token::is_valid: $1 must be a github api token' && return 1

  local -r body="$(strap::github::api::request "$token" 'https://api.github.com/user' || true)"

  [[ -z "$body" ]] && return 1

  export __STRAP_GITHUB_USER_JSON="$body"
}

strap::github::api::user::email() {

  local -r token="${1:-}" && [[ -z "$token" ]] && strap::error 'strap::github::api::user::email: $1 must be a github api token' && return 1

  local -r body="$(strap::github::api::request "$token" 'https://api.github.com/user/emails' || true)"

  [[  -z "$body" ]] && return 1

  export __STRAP_GITHUB_USER_EMAILS_JSON="$body"

  echo "$body" | jq -er '.[] | select(.primary == true) | .email'
}
