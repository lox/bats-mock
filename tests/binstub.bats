#!/usr/bin/env bats

load '../stub'

function teardown() {
    # Just clean up
    unstub mycommand || true
}

# Uncomment to enable stub debug output:
# export MYCOMMAND_STUB_DEBUG=/dev/tty

@test "Stub a single command with basic arguments" {
  stub mycommand "llamas : echo running llamas"

  run mycommand llamas

  [ "$status" -eq 0 ]
  [[ "$output" == *"running llamas"* ]]

  unstub mycommand
}

@test "Stub a command with multiple invocations" {
  stub mycommand \
    "llamas : echo running llamas" \
    "alpacas : echo running alpacas"

  run bash -c "mycommand llamas && mycommand alpacas"

  [ "$status" -eq 0 ]
  [[ "$output" == *"running llamas"* ]]
  [[ "$output" == *"running alpacas"* ]]

  unstub mycommand
}


@test "Invoke a stub multiple times" {
  stub mycommand "llamas : echo running llamas"

  run bash -c "mycommand llamas && mycommand alpacas"

  [ "$status" -eq 1 ]
}

@test "Stub a single command with quoted strings" {
  stub mycommand "llamas '' 'always llamas' : echo running llamas"

  run mycommand llamas '' always\ llamas

  [ "$status" -eq 0 ]
  [[ "$output" == *"running llamas"* ]]

  unstub mycommand
}

@test "Return status of passed stub" {
  stub myCommand \
    " : return 1" \
    " : return 42" \
    " : return 0"
  run myCommand
  [ "$status" -eq 1 ]
  [ "$output" == "" ]
  run myCommand
  [ "$status" -eq 42 ]
  [ "$output" == "" ]
  run myCommand
  [ "$status" -eq 0 ]
  [ "$output" == "" ]
  unstub myCommand
}

@test "Succeed for empty stubbed command" {
  stub mycommand
  # mycommand not called
  unstub mycommand
}

@test "Fail if empty subbed command called" {
  stub mycommand
  mycommand --help || true # Don't fail here
  run unstub mycommand
  [ "$status" -eq 1 ]
  [[ "$output" == "" ]]
}
