#!/usr/bin/env bats

load '../stub'

function teardown() {
    # Just clean up
    unstub --allow-missing mycommand
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


@test "Invoke a stub to often" {
  stub mycommand "llamas : echo running llamas"

  run bash -c "mycommand llamas"
  [ "$status" -eq 0 ]
  [ "$output" == "running llamas" ]

  # To often -> return failure
  run bash -c "mycommand llamas"
  [ "$status" -eq 1 ]
  [ "$output" == "" ]

  run unstub mycommand
  [ "$status" -eq 1 ]
  [[ "$output" == "" ]]
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
    " : exit 1" \
    " : exit 42" \
    " : exit 0"
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

@test "Fail if empty stubbed command called" {
  stub mycommand
  mycommand --help || true # Don't fail here
  run unstub mycommand
  [ "$status" -eq 1 ]
  [ "$output" == "" ]
}

@test "Fail if called out of sequence" {
  stub mycommand \
    "foo : echo 'OK'" \
    "bar : echo '1K'" \
    "baz : echo '2K'"
  run bash -c "mycommand foo; mycommand baz; mycommand bar"
  [ "$status" -eq 1 ]
  [ "$output" == "OK" ]
  run unstub mycommand
  [ "$status" -eq 1 ]
  [ "$output" == "" ]
}

@test "Check stdin" {
  file="$(mktemp "${BATS_TMPDIR}/output.XXXXXXXX")"
  stub curl \
    "foo : cat > '${file}'; echo 'mock output'"
  run bash -c "echo 'Some input' | curl foo"
  [ "$status" -eq 0 ]
  [ "$output" == "mock output" ]
  input="$(cat "$file")"
  [ "$input" == "Some input" ]
  rm "$file"
  unstub curl
}

@test "Error with --allow-missing" {
  # Case 1: Double unstub
  stub mycommand "foo : echo 'Bar'"
  run mycommand foo
  [ "$status" -eq 0 ]
  run unstub mycommand
  [ "$status" -eq 0 ]
  [ "$output" == "" ]
  run unstub mycommand
  [ "$status" -eq 1 ]
  [ "$output" == "mycommand is not stubbed" ]
  # With --allow-missing
  stub mycommand "foo : echo 'Bar'"
  run mycommand foo
  [ "$status" -eq 0 ]
  # First removes
  run unstub --allow-missing mycommand
  [ "$status" -eq 0 ]
  [ "$output" == "" ]
  # Then errors with regular
  run unstub mycommand
  [ "$status" -eq 1 ]
  [ "$output" == "mycommand is not stubbed" ]
  # But not with param
  run unstub --allow-missing mycommand
  [ "$status" -eq 0 ]
  [ "$output" == "" ]

  # Case 2: Unstub non-stubbed command
  run unstub non_stubbed_command
  [ "$status" -eq 1 ]
  [ "$output" == "non_stubbed_command is not stubbed" ]
  run unstub --allow-missing non_stubbed_command2
  [ "$status" -eq 0 ]
  [ "$output" == "" ]
}
