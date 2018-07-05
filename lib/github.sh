#!/usr/bin/env bash

set -Eeuo pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

command -v strap::lib::import >/dev/null || { echo "strap::lib::import is not available" >&2; exit 1; }
strap::lib::import logging || . logging.sh
strap::lib::import lang || . lang.sh
strap::lib::import io || . io.sh
strap::lib::import os || . os.sh
strap::lib::import git || . git.sh

__STRAP_GITHUB_USER_JSON="${__STRAP_GITHUB_USER_JSON:-}"
__STRAP_GITHUB_USER_EMAILS_JSON="${__STRAP_GITHUB_USER_EMAILS_JSON:-}"
__STRAP_GITHUB_USER_KEYS_JSON="${__STRAP_GITHUB_USER_KEYS_JSON:-}"

set -a

strap::github::user::ensure() {

  local github_username="$(git config --global github.user || true)"

  if [[ -z "$github_username" ]]; then
    echo
    strap::readval github_username "Enter your GitHub username" false true
    git config --global github.user "$github_username" || strap::abort "Unable to save GitHub username to git config"
  fi
}

strap::github::user::get() {
  git config --global github.user || strap::abort "GitHub username is not available in git config"
}

strap::github::token::delete() {
  printf "protocol=https\nhost=github.com\n" | git credential-osxkeychain erase >/dev/null # clear any previous value
}

strap::github::token::save() {
  local -r username="${1:-}" && [[ -z "$username" ]] && strap::error 'strap::github::token::find: $1 must be a github username' && return 1
  local -r token="${2:-}" && [[ -z "$token" ]] && strap::error 'strap::github::token::find: $2 must be a github api token' && return 1
  printf "protocol=https\nhost=github.com\n" | git credential-osxkeychain erase # clear any previous value
  printf "protocol=https\nhost=github.com\nusername=%s\npassword=%s\n" "$username" "$token" | git credential-osxkeychain store # save it
}

strap::github::token::find() {

  local -r username="${1:-}" && strap::assert::has_length "$username" '$1 must be a github username'
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
         security delete-internet-password -a "$username" -s api.github.com -l "$label" 2>&1 >/dev/null
      fi

    fi

  fi

  echo "$token"
}

strap::github::api::request() {

  local -r token="${1:-}" && strap::assert::has_length "$token" '$1 must be a github api token'
  local -r url="${2:-}" && strap::assert::has_length "$url" '$2 must be a github api URL'

  local -r response="$(curl --silent --show-error -H "Authorization: token $token" --write-out "HTTPSTATUS:%{http_code}" "$url")"
  local -r body="$(echo "$response" | sed -e 's/HTTPSTATUS\:.*//g')"
  local -r status_code="$(echo "$response" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')"

  if [[ "$status_code" == "200" || "$status_code" == "201" ]]; then
    echo "$body"
  elif [[ "$status_code" == 4* ]]; then
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

  local -r username="${1:-}" && strap::assert::has_length "$username" '$1 must be a github username'
  local -r max_password_attempts=3
  local -r max_otp_attempts=3
  local password_attempts=0
  local otp_attempts=0

  local utc_date=
  local token_description=
  local request_body=
  local token=
  local creds=
  local password=
  local two_factor_code=
  local response=
  local status_code=
  local headers=
  local body=
  local retry_ask=

  local -r machine_desc="$(strap::os::model)"

  while [[ -z "$token" && ${password_attempts} < ${max_password_attempts} ]]; do

    echo
    strap::readval password "Enter (or cmd-v paste) your GitHub password" true
    creds="$username:$password"

    utc_date="$(date -u +%FT%TZ)"
    token_description="Strap auto-generated token created at $utc_date for $machine_desc"
    request_body="{\"scopes\":[\"repo\",\"admin:org\",\"admin:public_key\",\"admin:repo_hook\",\"admin:org_hook\",\"gist\",\"notifications\",\"user\",\"delete_repo\",\"admin:gpg_key\"],\"note\":\"$token_description\",\"note_url\":\"https://github.com/ultimatedotfiles/strap\"}"
    response="$(curl --silent --show-error -i -u "$creds" -H 'Content-Type: application/json' -X POST -d "$request_body" https://api.github.com/authorizations)"
    status_code="$(echo "$response" | head -1 | awk '{print $2}')"
    headers="$(echo "$response" | sed "/^\s*$(printf '\r')*$/q" | sed '/^[[:space:]]*$/d' | tail -n +2)"
    body="$(echo "$response" | sed "1,/^\s*$(printf '\r')*$/d")"
    token="$(echo "$body" | jq -r '.token // empty')"

    password_attempts=$((password_attempts + 1))

    strap::assert::has_length "$status_code" 'Unable to parse GitHub response status.  GitHub response format is likely to have changed.  Please report this to the Strap developers.'

    if [[ ${status_code} -eq 401 ]]; then

      if echo "$headers" | grep -q 'X-GitHub-OTP: required'; then # password correct but two-factor is required

        # the password was correct, so set the attempts equal to max to prevent looping through again:
        password_attempts=${max_password_attempts}

        while [[ -z "$token" && ${otp_attempts} < ${max_otp_attempts} ]]; do

          echo
          strap::readval two_factor_code "Enter GitHub two-factor code"

          #try again with the OTP code:
          utc_date="$(date -u +%FT%TZ)"
          token_description="Strap auto-generated token created at $utc_date for $machine_desc"
          request_body="{\"scopes\":[\"repo\",\"admin:org\",\"admin:public_key\",\"admin:repo_hook\",\"admin:org_hook\",\"gist\",\"notifications\",\"user\",\"delete_repo\",\"admin:gpg_key\"],\"note\":\"$token_description\",\"note_url\":\"https://github.com/ultimatedotfiles/strap\"}"
          response="$(curl --silent --show-error -i -u "$creds" -H "X-GitHub-OTP: $two_factor_code" -H 'Content-Type: application/json' -X POST -d "$request_body" https://api.github.com/authorizations)"
          status_code="$(echo "$response" | head -1 | awk '{print $2}')"
          headers="$(echo "$response" | sed "/^\s*$(printf '\r')*$/q" | sed '/^[[:space:]]*$/d' | tail -n +2)"
          body="$(echo "$response" | sed "1,/^\s*$(printf '\r')*$/d")"
          token="$(echo "$body" | jq -r '.token // empty')"

          otp_attempts=$((otp_attempts + 1))

          if [[ -z "$token" ]]; then
            retry_ask=''
            [[ ${otp_attempts} < ${max_otp_attempts} ]] && retry_ask=' Please try again.'
            strap::error "GitHub rejected the specified two-factor code (perhaps due to a typo or it expired at the last second?).$retry_ask"
          fi
        done
      else
        retry_ask=''
        [[ ${password_attempts} < ${max_password_attempts} ]] && retry_ask=' Please try again.'
        strap::error "GitHub rejected the specified password (perhaps due to a typo?).$retry_ask"
      fi

    fi

  done

  if [[ -z "$token" ]]; then
    #default message if attempts weren't exceeded:
    local msg="Unable to parse GitHub response API Token. GitHub response format may have changed. Please report this to the Strap developers.  GitHub HTTP response: $response"
    if [[ "$otp_attempts" == "$max_otp_attempts" ]]; then
      msg="Reached maximum number of two-factor attempts. Please ensure you're using the correct two-factor application for the '$username' GitHub account."
    elif [[ "$password_attempts" == "$max_password_attempts" ]]; then
      msg="Reached the maximum number of GitHub password attempts. Please locate the correct password for the '$username' GitHub account and then run Strap again"
    fi
    strap::abort "$msg"
  fi

  # we have a token now - save it to secure storage:
  strap::github::token::save "$username" "$token"
}

strap::github::api::user() {

   local json="$__STRAP_GITHUB_USER_JSON"

   if [[ -z "$json" ]]; then
      local -r token="${1:-}" && strap::assert::has_length "$token" '$1 must be a github api token'
      json="$(strap::github::api::request "$token" 'https://api.github.com/user' || true)"
      [[  -z "$json" ]] && return 1
      export __STRAP_GITHUB_USER_JSON="$json"
   fi

   echo "$json"
}

strap::github::api::user::name() {
  local -r user_json="$(strap::github::api::user)"
  echo "$user_json"| jq -r '.name // empty'
}

strap::github::api::token::is_valid() {
  local -r token="${1:-}" && strap::assert::has_length "$token" '$1 must be a github api token'
  local -r json="$(strap::github::api::request "$token" 'https://api.github.com/user' || true)"
  [[ -z "$json" ]] && return 1
  export __STRAP_GITHUB_USER_JSON="$json"
}

strap::github::api::user::emails() {

  local json="$__STRAP_GITHUB_USER_EMAILS_JSON"

  if [[ -z "$json" ]]; then
    local -r token="${1:-}" && strap::assert::has_length "$token" '$1 must be a github api token'
    json="$(strap::github::api::request "$token" 'https://api.github.com/user/emails' || true)"
    [[  -z "$json" ]] && return 1
    export __STRAP_GITHUB_USER_EMAILS_JSON="$json"
  fi

  echo "$json"
}

strap::github::api::user::email() {
  local -r token="${1:-}" && strap::assert::has_length "$token" '$1 must be a github api token'
  local -r json="$(strap::github::api::user::emails "$token")"
  local email="$(echo "$json" | jq -r '[.[] | select(.email | contains("users.noreply.github.com"))][0] | .email // empty')"
  if [[ -z "$email" ]]; then
    email="$(echo "$json" | jq -r '[.[] | select(.verified == true and .primary == true)][0] | .email // empty')"
  fi
  [[ -z "$email" ]] && return 1
  echo "$email"
}

strap::github::api::user::keys() {

  local json="$__STRAP_GITHUB_USER_KEYS_JSON"

  if [[ -z "$json" ]]; then
    local -r token="${1:-}" && strap::assert::has_length "$token" '$1 must be a github api token'
    json="$(strap::github::api::request "$token" 'https://api.github.com/user/keys' || true)"
    [[  -z "$json" ]] && return 1
    export __STRAP_GITHUB_USER_KEYS_JSON="$json"
  fi

  echo "$json"
}

strap::github::api::user::keys::add() {
  local -r token="${1:-}" && strap::assert::has_length "$token" '$1 must be a github api token'
  local -r key="${2:-}" && strap::assert::has_length "$key" '$2 must the contents of an ssh public key file'
  now="$(date -u +%FT%TZ)"
  request_body="{ \"title\": \"Strap-generated RSA public key on $now\", \"key\": \"$key\" }"
  response="$(curl --silent --show-error -i -H "Authorization: token $token" -H 'Content-Type: application/json' -X POST -d "$request_body" https://api.github.com/user/keys)"
  status_code="$(echo "$response" | head -1 | awk '{print $2}')"
  #headers="$(echo "$response" | sed "/^\s*$(printf '\r')*$/q" | sed '/^[[:space:]]*$/d' | tail -n +2)"
  #body="$(echo "$response" | sed "1,/^\s*$(printf '\r')*$/d")"
  if [[ "$status_code" != "201" ]]; then
    strap::abort 'Unable to upload Strap-generated RSA private key to GitHub'
  fi
}

strap::github::api::user::keys::contains() {
  local -r token="${1:-}" && strap::assert::has_length "$token" '$1 must be a github api token'
  local -r key="${2:-}" && strap::assert::has_length "$key" '$2 must be an ssh public key'
  local -r json="$(strap::github::api::user::keys "$token")"
  local result="$(echo "$json" | jq -r ".[] | select(.key == \"$key\") | .key")"
  if [[ -z "$result" ]]; then
    return 1
  fi
}

strap::github::api::user::keys::ensure() {

  local -r token="${1:-}" && strap::assert::has_length "$token" '$1 must be a github api token'
  local -r key="${2:-}" && strap::assert::has_length "$key" '$2 must the contents of an ssh public key file'

  strap::running "Checking ssh public key registered with GitHub"

  if ! strap::github::api::user::keys::contains "$token" "$key"; then

    strap::action "Registering ssh public key with GitHub"

    strap::github::api::user::keys::add "$token" "$key"
    # remove any cached key result since we just added one.  This ensures the next time keys are requested, the
    # complete set will be retrieved:
    unset __STRAP_GITHUB_USER_KEYS_JSON
  fi

  strap::ok
}

set +a