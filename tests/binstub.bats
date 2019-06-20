#!/usr/bin/env bats

load '../stub'

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

@test "Error with unstub --exists" {
  # Case 1: Double unstub
  stub mycommand "foo : echo 'Bar'"
  run mycommand foo
  [ "$status" -eq 0 ]
  run unstub mycommand
  [ "$status" -eq 0 ]
  [ "$output" == "" ]
  run unstub mycommand
  [ "$status" -eq 0 ]
  [ "$output" == "" ]
  # With --exists
  stub mycommand "foo : echo 'Bar'"
  run mycommand foo
  [ "$status" -eq 0 ]
  run unstub --exists mycommand
  [ "$status" -eq 0 ]
  [ "$output" == "" ]
  run unstub --exists mycommand
  [ "$status" -eq 1 ]
  [ "$output" == "mycommand is not stubbed" ]
  # Case 2: Unstub non-stubbed command
  run unstub --exists non_stubbed_command
  [ "$status" -eq 1 ]
  run unstub non_stubbed_command2
  [ "$status" -eq 0 ]
  [ "$output" == "" ]
}
