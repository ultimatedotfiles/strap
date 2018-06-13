# homebrew:begin
# Add homebrew's bin directory to the $PATH if it's not already there:
command -v brew >/dev/null 2>&1 && STRAP_HOMEBREW_PREFIX="$(brew --prefix)"
if [ -n "$STRAP_HOMEBREW_PREFIX" ] && ! echo "$PATH" | tr ':' '\n' | grep -q "$STRAP_HOMEBREW_PREFIX"; then
  export PATH="$STRAP_HOMEBREW_PREFIX/bin:$PATH"
fi
unset STRAP_HOMEBREW_PREFIX
# homebrew:end
