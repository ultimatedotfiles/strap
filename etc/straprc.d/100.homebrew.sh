#@IgnoreInspection BashAddShebang
export STRAP_HOMEBREW_PREFIX='/usr/local'
command -v brew >/dev/null 2>&1 && export STRAP_HOMEBREW_PREFIX="$(brew --prefix)"
if [ -n "$STRAP_HOMEBREW_PREFIX" ]; then
  # Add homebrew's sbin directory to the $PATH if it's not already there:
  if ! echo "$PATH" | tr ':' '\n' | grep -q "$STRAP_HOMEBREW_PREFIX/sbin"; then
    export PATH="$STRAP_HOMEBREW_PREFIX/sbin:$PATH"
  fi
  # Add homebrew's bin directory to the $PATH if it's not already there:
  if ! echo "$PATH" | tr ':' '\n' | grep -q "$STRAP_HOMEBREW_PREFIX/bin"; then
    export PATH="$STRAP_HOMEBREW_PREFIX/bin:$PATH"
  fi
fi
