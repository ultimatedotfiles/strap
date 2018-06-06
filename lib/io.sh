#!/usr/bin/env bash

set -a

##
# Prompts a user for a value and potential confirmation value, and if both match, places the result
# in the $1 argument.  Can safely read secure values - see the $3 argument description below.
#
# Example usage
# -------------
#
# RESULT=''
# readval RESULT "Enter your value"
#
# # RESULT will now contain the read value.  For example:
# echo "$RESULT"
#
# Example password usage
# ----------------------
#
# readval RESULT "Enter your password" true
#
# If $3 is true (i.e. secure = true) nd you don't specify a 4th argument, the user will be prompted
# twice by default.
#
#
# Arguments:
#
#  $1: output variable, required.  The read result will be stored in this variable.
#
#  $2: prompt - a string, optional.
#               Defauls to "Enter value"
#               Do not end it with a colon character ':', as one will always be printed
#               at the end of the prompt string automatically.
#
#  $3: secure - a boolean, optional.
#               if true, the user's typing will not echo to the terminal.
#               if false, the user will see what they type.
#
#  $4: confirm - a boolean, optional.
#                Defaults to true if $secure = true.
#                if true, the user will be prompted again with an " (again)" suffix added to
#                the $prompt text.
##
strap::readval() {
  local result=$1
  local prompt="$2" && [ -z "$prompt" ] && prompt="Enter value" #default value
  local secure=$3
  local confirm=$4 && [ -z "$confirm" ] && [ "$secure" = true ] && confirm=true
  local first=""
  local second=""

  # all the read commands below direct input from <$(tty). See:
  # https://stackoverflow.com/questions/38484078/why-does-the-bash-read-command-return-without-any-input?rq=1

  while [ -z "$first" ] || [ -z "$second" ] || [ "$first" != "$second" ]; do
      if [ "$secure" = true ]; then
        read -r -s -p "$prompt: " first </dev/tty
        printf "\n"
      else
        read -r -p "$prompt: " first </dev/tty
      fi

      if [ "$confirm" = true ]; then
          if [ "$secure" = true ]; then
            read -r -s -p "$prompt (again): " second </dev/tty
            printf "\n"
          else
            read -r -p "$prompt (again): " second </dev/tty
          fi
      else
        # if we don't need confirmation, simulate a second entry to stop the loop:
        [ "$confirm" != true ] && second="$first"
      fi

      [ "$first" != "$second" ] && echo "Values are not equal. Please try again."
  done
  eval $result=\$first
}
