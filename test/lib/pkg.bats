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