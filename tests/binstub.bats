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

@test "Using * as parameter matches any parameter" {
  # * matches any param
  stub mycommand '* : echo OK'
  run mycommand foo
  [ "$status" -eq 0 ]
  [ "$output" == "OK" ]
  # Also works in any position
  stub mycommand 'first second * : echo OK'
  run mycommand first second foo
  [ "$status" -eq 0 ]
  [ "$output" == "OK" ]
  stub mycommand 'first * last : echo OK'
  run mycommand first foo last
  [ "$status" -eq 0 ]
  [ "$output" == "OK" ]
  stub mycommand '* second last : echo OK'
  run mycommand foo second last
  [ "$status" -eq 0 ]
  [ "$output" == "OK" ]
  # Also matches literal *
  stub mycommand '* : echo OK'
  run mycommand '*'
  [ "$status" -eq 0 ]
  [ "$output" == "OK" ]
  unstub mycommand
}

@test "Match parameters with whitespace" {
  # Single quotes
  stub mycommand "'first arg' 'second arg' : echo OK"
  run mycommand "first arg" "second arg"
  [ "$status" -eq 0 ]
  [ "$output" == "OK" ]
  # Double quotes
  stub mycommand '"first arg" "second arg" : echo OK'
  run mycommand "first arg" "second arg"
  [ "$status" -eq 0 ]
  [ "$output" == "OK" ]
  unstub mycommand
}

@test "Match parameter with embedded command line" {
  stub mycommand "-c 'echo \"Hello \$USER\"' : echo OK"
  run mycommand -c 'echo "Hello $USER"'
  [ "$status" -eq 0 ]
  [ "$output" == "OK" ]
  unstub mycommand
}

@test "Allow partial matches" {
  stub mycommand '/foo/bar/* : echo OK'
  run mycommand "/foo/bar/myfile"
  [ "$status" -eq 0 ]
  [ "$output" == "OK" ]
  unstub mycommand
  # But reject others
  stub mycommand '/foo/bar/* : echo OK'
  run mycommand "/foo/baz/myfile"
  [ "$status" -eq 1 ]
  [ "$output" == "" ]
  run unstub mycommand
  [ "$status" -eq 1 ]
}

@test "Allow incremental stubbing" {
  stub mycommand "foo : echo OK"
  stub mycommand "bar : echo 1K"
  stub mycommand "baz : echo 2K"
  run bash -c 'mycommand foo && mycommand bar && mycommand baz'
  [ "$status" -eq 0 ]
  expected='OK
1K
2K'
  [ "$output" = "$expected" ]
}

@test "Stubbing still works when some util binaries are stubbed" {
  stub rm
  stub mkdir
  stub ln
  stub touch
  stub mycommand " : echo OK"
  run mycommand
  [ "$status" -eq 0 ]
  [ "$output" == "OK" ]
  unstub rm
  unstub mkdir
  unstub ln
  unstub touch
  unstub mycommand
}
