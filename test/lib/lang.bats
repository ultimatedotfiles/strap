#!/usr/bin/env bats

load util

setup() {
  strap::lib::import lang
}

@test "lang: import" {
  command -v strap::assert
}
