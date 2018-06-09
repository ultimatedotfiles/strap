#@IgnoreInspection BashAddShebang

# Add /usr/local/bin to the path if it's not already there:
if ! echo "$PATH" | tr ':' '\n' | grep -q '/usr/local/bin'; then
  export PATH="/usr/local/bin:$PATH"
fi
