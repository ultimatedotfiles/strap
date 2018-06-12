#!/usr/bin/env bash

set -Eeuo pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

STRAP_DEBUG="${STRAP_DEBUG:-}"
STRAP_SCRIPT="${STRAP_SCRIPT:-}" && [[ -z "$STRAP_SCRIPT" ]] && echo "STRAP_SCRIPT is not set" && exit 1
STRAP_CMD_DIR="${STRAP_CMD_DIR:-}" && [[ -z "$STRAP_CMD_DIR" ]] && echo "STRAP_CMD_DIR is not set" && exit 1
STRAP_LIB_DIR="${STRAP_LIB_DIR:-}" && [[ -z "$STRAP_LIB_DIR" ]] && echo "STRAP_LIB_DIR is not set" && exit 1
command -v strap::lib::import >/dev/null || { echo "strap::lib::import is not available" >&2; exit 1; }
strap::lib::import io || . ../lib/io.sh
strap::lib::import logging || . ../lib/logging.sh

STRAP_SUDO_WAIT_PID=
STRAP_STEP=
STRAP_SUCCESS=
STRAP_QUIET_FLAG="-q"
Q="$STRAP_QUIET_FLAG"

# Are we running interactive?
STRAP_INTERACTIVE= # assume not interactive by default
[[ -t "0" || -p /dev/stdin ]] && STRAP_INTERACTIVE="1" # we're interactive

# sudo keep-alive while strap is running:
command="${1:-}"
if [ "$command" = "--sudo-wait" ]; then
  while true; do
    sudo -n true
    sleep 1
  done
  exit 0
fi

cleanup() {
  set +e
  if [ -n "$STRAP_SUDO_WAIT_PID" ]; then
    sudo kill "$STRAP_SUDO_WAIT_PID"
  fi
  [ -x "$HOME/.strap/.visudo/cleanup" ] && "$HOME/.strap/.visudo/cleanup"
  rm -rf "$HOME/.strap/.visudo"
  sudo -k
  rm -f "$CLT_PLACEHOLDER"
  if [ -z "$STRAP_SUCCESS" ]; then
    if [ -n "$STRAP_STEP" ]; then
      echo "!!! $STRAP_STEP FAILED" >&2
    else
      echo "!!! FAILED" >&2
    fi
    if [ -z "$STRAP_DEBUG" ]; then
      echo "!!! Run '$0 --debug' for debugging output." >&2
      echo "!!! If you're stuck: file an issue with debugging output at:" >&2
      echo "!!!   $STRAP_ISSUES_URL" >&2
    fi
  fi
}
# Trap any exit call:
trap "cleanup" EXIT
# Trap Ctrl-C
trap 'trap "" INT; echo -r "\nAborting …"; cleanup; exit 1' INT

STRAP_GIT_NAME="$(id -F)"
STRAP_GIT_EMAIL=
STRAP_GITHUB_USER=
STRAP_GITHUB_TOKEN=
STRAP_ISSUES_URL="https://github.com/ultimatedotfiles/strap/issues/new"

abort() { STRAP_STEP="";   echo "!!! $*" >&2; exit 1; }
log()   { STRAP_STEP="$*"; echo "--> $*"; }
logn()  { STRAP_STEP="$*"; printf -- "--> $* "; }

println() {
  echo "$2" >> "$1"
}

mkvisudocheck() {
  local dir="$HOME/.strap/.visudo"
  mkdir -p "$dir"
  chmod go-rwx "$dir"
  local file="$dir/check"
  rm -rf "$file"
  touch "$file"
  cat << 'EOF' > "$file"
#!/bin/sh
if [ -z "$1" ]; then
  EDITOR="$0" sudo -E visudo -q >/dev/null 2>&1
else
  file="$1"
  # Only need to set a user-specific timeout if there is a global timeout set to zero:
  if grep -q "^Defaults[[:blank:]]\+timestamp_timeout[[:blank:]]*=[[:blank:]]*0" "$file"; then
    # Only set a user-specific timeout if not already set:
    if ! grep -q "^Defaults:$(logname)[[:blank:]]\+timestamp_timeout[[:blank:]]*=[[:blank:]]*" "$file"; then
      echo "## strap:begin" >> "$file"
      echo "Defaults:$(logname) timestamp_timeout=1" >> "$file"
      echo "## strap:end" >> "$file"
    fi
  fi
fi
EOF
  chmod 700 "$file"
}

mkvisudocleanup() {
  local dir="$HOME/.strap/.visudo"
  mkdir -p "$dir"
  chmod go-rwx "$dir"
  local file="$dir/cleanup"
  rm -rf "$file"
  touch "$file"
  cat << 'EOF' > "$file"
#!/bin/sh
if [ -z "$1" ]; then
  EDITOR="$0" sudo -E visudo -q >/dev/null 2>&1
else
  file="$1"
  # If strap set something, remove it:
  if grep -q '^## strap:begin$' "$file" && grep -q '^## strap:end$' "$file"; then
    sed -i '' '/## strap:begin/,/## strap:end/d' "$file"
  fi
  # remove any blank lines at end of the file:
  sed -i '' -e :a -e '/^\n*$/{\$d;N;};/\n\$/ba' "$file"
fi
EOF
  chmod 700 "$file"
}

# allow subshells to call these functions:
export -f abort
export -f log
export -f logn
export -f println

export _STRAP_MACOSX_VERSION="$(sw_vers -productVersion)"
echo "$_STRAP_MACOSX_VERSION" | grep $Q -E "^10.(9|10|11|12|13)" || { abort "Run Strap on Mac OS X 10.9/10/11/12/13."; }

[ "$USER" = "root" ] && abort "Run Strap as yourself, not root."
groups | grep $Q admin || abort "Add $USER to the admin group."

export _STRAP_USER_DIR="$HOME/.strap"
mkdir -p "$_STRAP_USER_DIR"
mkvisudocheck
mkvisudocleanup

# Initialise sudo now to save prompting later.
log "Enter your password (for sudo access):"
sudo -k
"$_STRAP_USER_DIR/.visudo/check"

sudo bash "$STRAP_SCRIPT" run --sudo-wait &
STRAP_SUDO_WAIT_PID="$!"
ps -p "$STRAP_SUDO_WAIT_PID" &>/dev/null
strap::ok

logn "Checking security settings:"
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaEnabled -bool false
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaEnabledForLocalFiles -bool false
sudo defaults write com.apple.screensaver askForPassword -int 1
sudo defaults write com.apple.screensaver askForPasswordDelay -int 0
sudo defaults write /Library/Preferences/com.apple.alf globalstate -int 1
sudo launchctl load /System/Library/LaunchDaemons/com.apple.alf.agent.plist 2>/dev/null
if [ -n "$STRAP_GIT_NAME" ] && [ -n "$STRAP_GIT_EMAIL" ]; then
  sudo defaults write /Library/Preferences/com.apple.loginwindow \
    LoginwindowText \
    "Found this computer? Please contact $STRAP_GIT_NAME at $STRAP_GIT_EMAIL."
fi
strap::ok

logn "Checking keyboard and finder settings:"
# speed up the keyboard.  Defaults are *slow* for developers:
restart_finder=false
defaults write -g KeyRepeat -int 2
defaults write -g InitialKeyRepeat -int 14
if [ "$(defaults read com.apple.finder AppleShowAllFiles)" != "YES" ]; then
  defaults write com.apple.finder AppleShowAllFiles YES; # show hidden files
  restart_finder=true
fi
if [ "$(defaults read NSGlobalDomain AppleShowAllExtensions)" != "1" ]; then
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true # show all file extensions
  restart_finder=true
fi
[ $restart_finder = true ] && killall Finder 2>/dev/null
strap::ok

# Check and enable full-disk encryption.
logn "Checking full-disk encryption status:"
if fdesetup status | grep $Q -E "FileVault is (On|Off, but will be enabled after the next restart)."; then
  strap::ok
elif [ -n "$STRAP_INTERACTIVE" ]; then
  echo && log "Enabling full-disk encryption on next reboot:"
  sudo fdesetup enable -user "$USER" | tee ~/Desktop/"FileVault Recovery Key.txt"
  strap::ok
else
  echo && abort "Run 'sudo fdesetup enable -user \"$USER\"' to enable full-disk encryption."
fi

logn "Checking Xcode Developer Tools:"
XCODE_DIR=$(xcode-select -print-path 2>/dev/null || true)
if [ -z "$XCODE_DIR" ] || ! [ -f "$XCODE_DIR/usr/bin/git" ] || ! [ -f "/usr/include/iconv.h" ]; then

  log "Installing Xcode Command Line Tools..."
  CLT_PLACEHOLDER="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
  sudo touch "$CLT_PLACEHOLDER"
  CLT_PACKAGE=$(softwareupdate -l | grep -B 1 -E "Command Line (Developer|Tools)" | \
                awk -F"*" '/^ +\*/ {print $2}' | sed 's/^ *//' | head -n1)
  sudo softwareupdate -i "$CLT_PACKAGE"
  sudo rm -f "$CLT_PLACEHOLDER"
  if ! [ -f "/usr/include/iconv.h" ]; then
    if [ -n "$STRAP_INTERACTIVE" ]; then
      echo
      logn "Requesting user install of Xcode Command Line Tools:"
      xcode-select --install
    else
      echo
      abort "Run 'xcode-select --install' to install the Xcode Command Line Tools."
    fi
  fi
fi
strap::ok

# Check if the Xcode license is agreed to and agree if not.
xcode_license() {
  if /usr/bin/xcrun clang 2>&1 | grep $Q license; then
    if [ -n "$INTERACTIVE" ]; then
      logn "Asking for Xcode license confirmation:"
      sudo xcodebuild -license
      strap::ok
    else
      abort "Run 'sudo xcodebuild -license' to agree to the Xcode license."
    fi
  fi
}
xcode_license

# Check and install any remaining software updates.
logn "Checking Apple software updates:"
if ! softwareupdate -l 2>&1 | grep $Q "No new software available."; then
  echo && log "Installing Apple software updates.  This could take a while..."
  sudo softwareupdate --install --all
  xcode_license
fi
strap::ok

#############################################################
# Shell RC File assertions:
#############################################################

export STRAP_SHELL=$(basename $SHELL)
export STRAPRC_FILE="$HOME/.strap/straprc"
export STRAPRC_PRETTY_NAME="\$HOME/.strap/straprc"

straprc_println() {
  println "$STRAPRC_FILE" "$1"
}
export -f straprc_println # export to subshells

logn "Checking $STRAPRC_PRETTY_NAME:"
if [ ! -f $STRAPRC_FILE ]; then
  echo && log "Creating $STRAPRC_PRETTY_NAME..."
  touch $STRAPRC_FILE
  straprc_println '#'
  straprc_println '# WARNING:'
  straprc_println '#'
  straprc_println '# DO NOT MODIFY THIS FILE.  IT MAY BE AUTOMATICALLY RE-GENERATED BY STRAP AT ANY TIME.'
  straprc_println '#'
  straprc_println '# If you want to modify, overwrite or unset anything in here, do that in your'
  straprc_println '# ~/.bash_profile or ~/.zshrc file *after* the line that sources $HOME/.strap/straprc'
  straprc_println '#'
fi
chmod u+x "$STRAPRC_FILE"
strap::ok

declare -a files=("$HOME/.bash_profile" "$HOME/.zshrc")
for file in "${files[@]}"; do

  logn "Checking $file:"
  [ ! -f "$file" ] && echo && log "Creating $file..." && touch "$file"
  chmod u+x "$file"
  strap::ok

  logn "Checking $STRAPRC_PRETTY_NAME referenced in $file: "
  if ! grep -q "$STRAPRC_PRETTY_NAME" "$file"; then
    echo && log "Enabling ${STRAPRC_PRETTY_NAME} in $file..."
    println "$file" ''
    println "$file" "# strap:begin"
    println "$file" "[ -f \"$STRAPRC_PRETTY_NAME\" ] && . \"$STRAPRC_PRETTY_NAME\""
    println "$file" "# strap:end"
  fi
  strap::ok
done


#############################################################
# Homebrew:
#############################################################

logn "Checking Homebrew:"
if ! command -v brew >/dev/null 2>&1; then
  echo && log "Installing Homebrew..."
  yes '' | /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)";

  if [[ "$PATH" != *"/usr/local/bin"* ]]; then
    straprc_println ''
    straprc_println '# homebrew:begin'
    straprc_println 'export PATH="/usr/local/bin:$PATH"'
    straprc_println '# homebrew:end'
    source $STRAPRC_FILE
  fi
fi
strap::ok

logn "Checking Homebrew Cask:"
if ! brew tap | grep ^caskroom/cask$ >/dev/null 2>&1; then
  echo && log "Tapping caskroom/cask..."
  brew tap caskroom/cask
fi
strap::ok

logn "Checking Homebrew Versions:"
if ! brew tap | grep ^caskroom/versions$ >/dev/null 2>&1; then
  echo && log "Tapping caskroom/versions..."
  brew tap caskroom/versions
fi
strap::ok

logn "Checking Homebrew updates:"
brew update >/dev/null
brew upgrade
strap::ok

ensure_formula() {
  local command="$1" && [ -z "$command" ] && abort 'ensure_formula: $1 must be the command'
  local formula="$2" && [ -z "$formula" ] && abort 'ensure_formula: $2 must be the formula id'
  local name="$3" && [ -z "$3" ] && name="$formula"

  logn "Checking $name:"
  if ! ${command} list ${formula} >/dev/null 2>&1; then
    echo && log "Installing $name..."
    ${command} install ${formula}
  fi
  strap::ok
}
ensure_brew() { ensure_formula "brew" $1 $2; }
ensure_cask() {
  local formula="$1" && [ -z "$formula" ] && abort 'ensure_cask: $1 must be the formula id'
  local apppath="$2"

  if [ ! -z "$apppath" ] && [ -d "$apppath" ]; then
    # simulate checking message:
    logn "Checking $formula:"
    if ! brew cask list "$formula" >/dev/null 2>&1; then
      strap::ok
      log
      log "Note: $formula appears to have been manually installed to $apppath."
      log "If you want strap or homebrew to manage $formula version upgrades"
      log "automatically (recommended), you should manually uninstall $apppath"
      log "and re-run strap or manually run 'brew cask install $formula'."
      log
    else
      strap::ok
    fi
  else
    ensure_formula "brew cask" "$formula"
  fi
}

ensure_brew_shellrc_entry() {
  local file="$1" && [ ! -f "$file" ] && abort 'ensure_brew_shellrc_entry: $1 must be the shell rc file'
  local formula="$2" && [ -z "$formula" ] && abort 'ensure_brew_shellrc_entry: $2 must be the formula id'
  local path="$3" && [ -z "$path" ] && abort 'ensure_brew_shellrc_entry: $3 must be the brew script relative path'
  local extraConditions="$4"

  # if extraConditions are present, ensure there is a ' && ' at the end for joining:
  [ -n "$extraConditions" ] && [[ "$extraConditions" != "* && " ]] && extraConditions="$extraConditions && "

  logn "Checking ${formula} in $file:"
  if ! grep -q ${path} ${file}; then
    echo && log "Enabling ${formula} in $file"
    println $file ''
    println $file "# homebrew:${formula}:begin"
    println $file "if $extraConditions[ -f \$(brew --prefix)/${path} ]; then"
    println $file "  . \$(brew --prefix)/${path}"
    println $file 'fi'
    println $file "# homebrew:${formula}:end"
  fi
  strap::ok
}

# allow subshells to call these functions:
export -f ensure_formula
export -f ensure_brew
export -f ensure_cask
export -f ensure_brew_shellrc_entry

#############################################################
# bash:
#############################################################

ensure_brew 'bash'

logn "Checking $(brew --prefix)/bin/bash in /etc/shells:"
if ! grep -q "$(brew --prefix)/bin/bash" /etc/shells; then
  echo "$(brew --prefix)/bin/bash" | sudo tee -a /etc/shells
fi
strap::ok

ensure_brew "bash-completion"
ensure_brew_shellrc_entry "$STRAPRC_FILE" "bash-completion" "etc/bash_completion" '[ -n "$BASH_VERSION" ]'
[ -n "$BASH_VERSION" ] && [ "$SHELL" != "$(which bash)" ] && sudo chsh -s "$(which bash)" "$(logname)"


#############################################################
# zsh:
#############################################################

ensure_brew 'zsh'
logn "Checking $(brew --prefix)/bin/zsh in /etc/shells:"
if ! grep -q "$(brew --prefix)/bin/zsh" /etc/shells; then
  echo "$(brew --prefix)/bin/zsh" | sudo tee -a /etc/shells
fi
strap::ok

ensure_brew 'zsh-completions'
chmod go-w "$(brew --prefix)/share"
[ ! -f "$HOME/.zshrc" ] && touch "$HOME/.zshrc"
if ! grep -q 'share/zsh-completions' "$HOME/.zshrc"; then
  echo "fpath=($(brew --prefix)/share/zsh-completions \$fpath)" >> "$HOME/.zshrc"
fi
[ -n "$ZSH_VERSION" ] && [ "$SHELL" != "$(which zsh)" ] && sudo chsh -s "$(which zsh)" "$(logname)"


#############################################################
# Git & GitHub:
#############################################################

# openssl and jq are pre-requisites for the GitHub interaction below:
ensure_brew "openssl"
ensure_brew "jq"
ensure_brew "git"

logn "Checking git config:"

[ -f "$HOME/.gitconfig" ] || touch "$HOME/.gitconfig"
chmod 700 "$HOME/.gitconfig"

if ! git config --global core.autocrlf >/dev/null; then
  git config --global core.autocrlf input
fi

if git config --global github.user >/dev/null; then
  STRAP_GITHUB_USER="$(git config --global github.user)"
else
  [ -z "$STRAP_GITHUB_USER" ] && printf "\n" && strap::readval STRAP_GITHUB_USER "Enter your GitHub username" false true
  git config --global github.user "$STRAP_GITHUB_USER"
fi

_STRAP_KEYCHAIN_ENTRY_LABEL="Strap GitHub API personal access token"
export _STRAP_GITHUB_API_TOKEN="${STRAP_GITHUB_TOKEN}"
_STRAP_GITHUB_TOKEN_COMMENT='User-supplied GitHub personal access token'
_store_github_token=false

if [ ! -z "$_STRAP_GITHUB_API_TOKEN" ]; then # user specified a token - let's check to see if it is valid:
  _http_code="$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: token $_STRAP_GITHUB_API_TOKEN" https://api.github.com)"
  [[ "$_http_code" == "4*" ]] && abort 'Specified STRAP_GITHUB_TOKEN is invalid. GitHub authentication failed.'
  _STRAP_GITHUB_TOKEN_COMMENT='User-supplied GitHub personal access token'
  _store_github_token=true
elif security find-internet-password -a "$STRAP_GITHUB_USER" -s api.github.com -l "$_STRAP_KEYCHAIN_ENTRY_LABEL" >/dev/null 2>&1; then
  export _STRAP_GITHUB_API_TOKEN=$(security find-internet-password -a "$STRAP_GITHUB_USER" -s api.github.com -l "$_STRAP_KEYCHAIN_ENTRY_LABEL" -w)
  _store_github_token=false # it is already stored
else
  STRAP_GITHUB_PASSWORD=
  # no token yet, we need to get one.  This requires a github password:
  [ -z "$STRAP_GITHUB_PASSWORD" ] && strap::readval STRAP_GITHUB_PASSWORD "Enter (or cmd-v paste) your GitHub password" true

  _STRAP_UTC_DATE="$(date -u +%FT%TZ)"
  _request_body="{\"scopes\":[\"repo\",\"admin:org\",\"admin:public_key\",\"admin:repo_hook\",\"admin:org_hook\",\"gist\",\"notifications\",\"user\",\"delete_repo\",\"admin:gpg_key\"],\"note\":\"Strap-generated token, created at $_STRAP_UTC_DATE\"}"
  _creds="$STRAP_GITHUB_USER:$STRAP_GITHUB_PASSWORD"
  _response=$(curl --silent --show-error -i -u "$_creds" -H "Content-Type: application/json" -X POST -d "$_request_body" https://api.github.com/authorizations)
  _status=$(echo "$_response" | grep 'HTTP/1.1' | awk '{print $2}') && [ -z "$_status" ] && abort "Unable to parse GitHub response status.  GitHub response format is likely to have changed.  Please report this to the Strap developers."
  _otp_type=$(echo "$_response" | grep 'X-GitHub-OTP:' | awk '{print $3}')

  if [ ! -z "$_otp_type" ]; then # two-factor required - ask for code:
    _strap_github_otp=
    strap::readval _strap_github_otp "Enter GitHub two-factor code"

    #try again, this time with the OTP code
    _response=$(curl --silent --show-error -u "$_creds" -H "X-GitHub-OTP: $_strap_github_otp" -H "Content-Type: application/json" -X POST -d "$_request_body" https://api.github.com/authorizations)
  fi

  _token=$(echo "$_response" | grep '^  "token": ' | sed 's/,//' | sed 's/"//g' | awk '{print $2}')
  [ -z "$_token" ] && abort "Unable to parse GitHub response API Token.  GitHub response format may have changed.  Please report this to the Strap developers.  GitHub HTTP response: $_response"

  _tokenUrl=$(echo "$_response" | grep '^  "url": ' | sed 's/,//' | sed 's/"//g' | awk '{print $2}')
  [ -z "$_tokenUrl" ] && abort "Unable to parse GitHub response API Token URL.  GitHub response format may have changed.  Please report this to the Strap developers.  GitHub HTTP response: $_response"

  export _STRAP_GITHUB_API_TOKEN="$_token"
  _STRAP_GITHUB_TOKEN_COMMENT="$_tokenUrl" # use the token url as the comment in this case
  _store_github_token=true

  if [ -z "$_STRAP_GITHUB_API_TOKEN" ] || [ "$_STRAP_GITHUB_API_TOKEN" == "null" ]; then
    abort 'Unable to create GitHub API personal access token.  GitHub response format is likely to have changed.'
  fi
fi
if [ $_store_github_token = true ]; then
  security add-internet-password -r htps -s api.github.com -l "$_STRAP_KEYCHAIN_ENTRY_LABEL" -j "$_STRAP_GITHUB_TOKEN_COMMENT" -t http -a "$STRAP_GITHUB_USER" -w "$_STRAP_GITHUB_API_TOKEN" || { abort "Unable to save GitHub API personal access token to Mac OS X Keychain";}
fi

if git config --global user.email >/dev/null; then
  STRAP_GIT_EMAIL="$(git config --global user.email)"
else
  if [ -z "$STRAP_GIT_EMAIL" ]; then

    #try to find it from the GitHub account:
    JSON=$(curl --silent --show-error -u "$STRAP_GITHUB_USER:$_STRAP_GITHUB_API_TOKEN" https://api.github.com/user/emails)

    STRAP_GIT_EMAIL=$(echo "$JSON" | jq -er '.[] | select(.primary == true) | .email')

    if [ -z "$STRAP_GIT_EMAIL" ] || [ "$STRAP_GIT_EMAIL" == "null" ]; then
      #read from the user, but ensure the read value has an 'at' sign:
      while [[ "$STRAP_GIT_EMAIL" != *"@"* ]]; do
        strap::readval STRAP_GIT_EMAIL "Enter your email address" false true
      done
    fi
  fi

  git config --global user.email "$STRAP_GIT_EMAIL"
fi

if git config --global user.name >/dev/null; then
  STRAP_GIT_NAME="$(git config --global user.name)"
else
  [ -z "$STRAP_GIT_NAME" ] && strap::readval STRAP_GIT_NAME "Enter your first and last name"
  git config --global user.name "$STRAP_GIT_NAME"
fi

if ! git config --global push.default >/dev/null; then
  git config --global push.default simple
fi

if ! git config --global branch.autosetupmerge >/dev/null; then
  git config --global branch.autosetupmerge always
fi

if git credential-osxkeychain 2>&1 | grep $Q "git.credential-osxkeychain"; then

  if [ "$(git config --global credential.helper)" != "osxkeychain" ]; then
    git config --global credential.helper osxkeychain
  fi

  printf "protocol=https\nhost=github.com\n" | git credential-osxkeychain erase
  printf "protocol=https\nhost=github.com\nusername=%s\npassword=%s\n" \
        "$STRAP_GITHUB_USER" "$_STRAP_GITHUB_API_TOKEN" \
        | git credential-osxkeychain store
fi

strap::ok

githubdl() {
  local repo="$1" && [ -z "$repo" ] && abort 'githubdl: $1 must be a qualified repo, e.g. user/reponame'
  local path="$2" && [ -z "$path" ] && abort 'githubdl: $2 must be the repo file path, e.g. file.txt or my/other/file.txt'
  local file="$3" && [ -z "$file" ] && abort 'githubdl: $3 must be the destination file'
  local filedir="${file%/*}"
  mkdir -p "$filedir"
  curl -H "Authorization: token $_STRAP_GITHUB_API_TOKEN" \
       -H "Accept: application/vnd.github.v3.raw" \
       -s -L "https://api.github.com/repos/$repo/contents/$path" --output "$file"
}

ensure_strap_file() {
  local path="$1" && [ -z "$path" ] && abort 'ensure_strap_file: $1 must be a strap file path'
  local dstdir="$2" && [ -z "$dstdir" ] && dstdir="$_STRAP_USER_DIR" #default
  local file="$dstdir/$path"
  [ ! -f "$file" ] && githubdl 'YOURREPO/strap' "$path" "$file"
  chmod go-rwx "$file"
}
export -f githubdl
export -f ensure_strap_file

# make config/state a little more secure, just in case:
chmod -R go-rwx "$STRAP_USER_HOME"

STRAP_SUCCESS="1"
log "Your system is now Strap'd!"