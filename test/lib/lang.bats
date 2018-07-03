#!/usr/bin/env bats

load util

setup() {
  strap::lib::import lang
  tempdir=
}

teardown() {
  rm -rf "$tempdir"
}

@test "lang: import" {
  command -v strap::assert
}

@test "lang: assert::has_length fails with empty argument" {
  run strap::assert::has_length '' 'foo'
  [ "$status" -ne 0 ]
}

@test "lang: assert::has_length succeeds with non-empty argument" {
  run strap::assert::has_length 'foo' 'foo'
  [ "$status" -eq 0 ]
}

@test "lang: assert succeeds with existing directory check" {
  tempdir=$(mktemp -d 2>/dev/null || mktemp -d -t 'strap_test_lang_temp_dir')
  run strap::assert "[ -d $tempdir ]" 'foo'
  [ "$status" -eq 0 ]
  #[ "$output" = "foo" ]
}

@test "lang: assert fails with existing directory missing check" {
  tempdir=$(mktemp -d 2>/dev/null || mktemp -d -t 'strap_test_lang_temp_dir')
  run strap::assert "[ ! -d $tempdir ]" 'foo'
  [ "$status" -ne 0 ]
}

@test "lang: assert succeeds with existing file check" {
  tempdir=$(mktemp -d 2>/dev/null || mktemp -d -t 'strap_test_lang_temp_dir')
  file="$tempdir/whatevs"
  touch "$file"
  run strap::assert "[ -f $file ]" 'foo'
  [ "$status" -eq 0 ]
}

@test "lang: assert fails with existing file missing check" {
  tempdir=$(mktemp -d 2>/dev/null || mktemp -d -t 'strap_test_lang_temp_dir')
  file="$tempdir/whatevs"
  touch "$file"
  run strap::assert "[ ! -f $file ]" 'foo'
  [ "$status" -ne 0 ]
}
