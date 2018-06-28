#!/usr/bin/env bats

load util

setup() {
  strap::lib::import logging
}

@test "logging: strap::ok" {
  run strap::ok
  [ "$status" -eq 0 ]
  [ "$output" = "${FONT_GREEN}OK${FONT_CLEAR} " ]
}
