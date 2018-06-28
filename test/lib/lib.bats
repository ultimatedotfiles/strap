#!/usr/bin/env bats

load util

@test "lib: strap::lib::import exists" {
  run command -v strap::lib::import # should be provided via 'util' above
  [ "$status" -eq 0 ]
}
