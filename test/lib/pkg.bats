#!/usr/bin/env bats

load util

setup() {
  strap::lib::import pkg
}

@test "pkg: import" {
  command -v strap::pkg::id::dir
}
