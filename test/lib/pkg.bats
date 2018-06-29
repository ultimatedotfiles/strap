#!/usr/bin/env bats

load util

setup() {
  strap::lib::import pkg
}

@test "pkg: import" {
  command -v strap::pkg::id::dir
}

@test "pkg: id::canonicalize fails with missing argument" {
  run strap::pkg::id::canonicalize
  [ "$status" -ne 0 ]
  [[ "$output" = *'$1 must be a Strap package id'* ]]
}

@test "pkg: id::canonicalize fails with less than one colon character" {
  run strap::pkg::id::canonicalize 'foo'
  [ "$status" -ne 0 ]
  [[ "$output" = *'Strap package id must contain either one or two colon characters'* ]]
}

@test "pkg: id::canonicalize fails with more than two colon characters" {
  run strap::pkg::id::canonicalize 'foo:bar:baz:bat'
  [ "$status" -ne 0 ]
  [[ "$output" = *'Strap package id must contain either one or two colon characters'* ]]
}

@test "pkg: id::canonicalize strips whitespace" {
  run strap::pkg::id::canonicalize 'com.github.acme : hello : 1.2.3'
  [ "$status" -eq 0 ]
  [ "$output" = "com.github.acme:hello:1.2.3" ]
}

@test "pkg: id::canonicalize strips forward slashes" {
  run strap::pkg::id::canonicalize '/com.github.acme:/hello:/1.2.3/'
  [ "$status" -eq 0 ]
  [ "$output" = "com.github.acme:hello:1.2.3" ]
}

@test "pkg: id::canonicalize with missing version assumes HEAD" {
  run strap::pkg::id::canonicalize 'com.github.acme:hello'
  [ "$status" -eq 0 ]
  [ "$output" = "com.github.acme:hello:HEAD" ]
}

@test "pkg: id::canonicalize with trailing colon and missing version assumes HEAD" {
  run strap::pkg::id::canonicalize 'com.github.acme:hello:'
  [ "$status" -eq 0 ]
  [ "$output" = "com.github.acme:hello:HEAD" ]
}

@test "pkg: id::dir::relative" {
  run strap::pkg::id::dir::relative 'com.github.acme:hello:1.0.2'
  [ "$status" -eq 0 ]
  [ "$output" = "com/github/acme/hello/1.0.2" ]
}

@test "pkg: id::dir::relative fails with missing argument" {
  run strap::pkg::id::dir::relative
  [ "$status" -ne 0 ]
  [[ "$output" = *'$1 must be a Strap package id'* ]]
}

@test "pkg: id::dir" {
  run strap::pkg::id::dir 'com.github.acme:hello:1.0.2'
  [ "$status" -eq 0 ]
  [ "$output" = "$STRAP_USER_HOME/packages/com/github/acme/hello/1.0.2" ]
}

@test "pkg: id::dir fails with missing argument" {
  run strap::pkg::id::dir
  [ "$status" -ne 0 ]
  [[ "$output" = *'$1 must be a Strap package id'* ]]
}

@test "pkg: id::github::url::domain_and_path" {
  run strap::pkg::id::github::url::domain_and_path 'com.github.acme:hello:1.0.2'
  [ "$status" -eq 0 ]
  [ "$output" = "github.com/acme/hello.git" ]
}

@test "pkg: id::github::url::domain_and_path fails with missing argument" {
  run strap::pkg::id::github::url::domain_and_path
  [ "$status" -ne 0 ]
  [[ "$output" = *'$1 must be a Strap package id'* ]]
}

@test "pkg: id::github::url::https" {
  run strap::pkg::id::github::url::https 'com.github.acme:hello:1.0.2'
  [ "$status" -eq 0 ]
  [ "$output" = "https://github.com/acme/hello.git" ]
}

@test "pkg: id::github::url::https fails with missing argument" {
  run strap::pkg::id::github::url::https
  [ "$status" -ne 0 ]
  [[ "$output" = *'$1 must be a Strap package id'* ]]
}

@test "pkg: id::github::url::ssh" {
  run strap::pkg::id::github::url::ssh 'com.github.acme:hello:1.0.2'
  [ "$status" -eq 0 ]
  [ "$output" = "git@github.com:acme/hello.git" ]
}

@test "pkg: id::github::url::ssh fails with missing argument" {
  run strap::pkg::id::github::url::ssh
  [ "$status" -ne 0 ]
  [[ "$output" = *'$1 must be a Strap package id'* ]]
}

@test "pkg: dir::prune fails with files" {
  mkdir -p "$STRAP_USER_HOME"
  file="$STRAP_USER_HOME/testgarbagedeleteme"
  touch "$file"
  run strap::pkg::dir::prune "$file"
  [ "$status" -ne 0 ]
  rm -rf "$file"
}

@test "pkg: dir::prune fails when not a strap package dir" {
  run strap::pkg::dir::prune "$STRAP_USER_HOME"
  [ "$status" -ne 0 ]
}

@test "pkg: dir::prune deletes intermediate directories but not ~/.strap/packages" {
  local -r dir="$STRAP_USER_HOME/packages/foo/bar/baz/bat/1.0.2"
  mkdir -p "$dir"
  run strap::pkg::dir::prune "$dir"
  [ "$status" -eq 0 ]
  [ -d "$STRAP_USER_HOME/packages" ] # should still be there
  [ ! -d "$STRAP_USER_HOME/packages/foo" ] # foo subdir shouldn't be there
}

@test "pkg: ensure fails when ls-remote fails" {
  run strap::pkg::ensure 'com.github.ultimatedotfiles:straps:0.0.1'
  [ "$status" -ne 0 ]
}

@test "pkg: ensure succeeds with HEAD rev" {
  run strap::pkg::ensure 'com.github.ultimatedotfiles:strap'
  [ "$status" -eq 0 ]
  dir="$STRAP_USER_HOME/packages/com/github/ultimatedotfiles/strap/HEAD"
  [ -d "$dir" ]
  rm -rf "$dir"
}

@test "pkg: ensure calls git fetch with existing HEAD directory" {
  strap::pkg::ensure 'com.github.ultimatedotfiles:strap'
  dir="$STRAP_USER_HOME/packages/com/github/ultimatedotfiles/strap/HEAD"
  $(cd "$dir"; git checkout dummy-for-ci-do-not-delete)
  [[ "$(cd "$dir"; git branch)" = "dummy-for-ci-do-not-delete" ]]
  [ -d "$dir" ]
  run strap::pkg::ensure 'com.github.ultimatedotfiles:strap'
  [ "$status" -eq 0 ]
  [ -d "$dir" ]
  [[ "$(cd "$dir"; git branch)" = "dummy-for-ci-do-not-delete" ]]
  rm -rf "$dir"
}