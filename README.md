# bats-mock

Mocking/stubbing library for BATS (Bash Automated Testing System)

A maintained fork of https://github.com/jasonkarns/bats-mock, which is dormant.

There are great things happening in the `bats` ecosystem! Anyone actively using it should be installing from [bats-core]: https://github.com/bats-core.

## Installation

Recommended installation is via git submodule. Assuming your project's bats
tests are in `test`:

``` sh
git submodule add https://github.com/lox/bats-mock test/helpers/mocks
git commit -am 'added bats-mock module'
```

then in `test/test_helper.bash`:

``` bash
load helpers/mocks/stub
```

## Usage

After loading `bats-mock/stub` you have two new functions defined:

- `stub`: for creating new stubs, along with a plan with expected args and the results to return when called.
- `unstub`: for cleaning up, and also verifying that the plan was fullfilled.

### Stubbing

The `stub` function takes a program name as its first argument, and any remaining arguments goes into the stub plan, one line per arg.

Each plan line represents an expected invocation, with a list of expected arguments followed by a command to execute in case the arguments matched, separated with a colon:

    arg1 arg2 ... : only_run if args matched

The expected args (and the colon) is optional.

So, in order to stub `date`, we could use something like this in a test case (where `format_date` is the function under test, relying on data from the `date` command):

```bash
load helper

# this is the "code under test"
# it would normally be in another file
format_date() {
  date -r 222
}

setup() {
  _DATE_ARGS='-r 222'
  stub date \
      "${_DATE_ARGS} : echo 'I am stubbed!'" \
      "${_DATE_ARGS} : echo 'Wed Dec 31 18:03:42 CST 1969'"
}

teardown() {
  unstub date
}

@test "date format util formats date with expected arguments" {
  result="$(format_date)"
  [ "$result" == 'I am stubbed!' ]

  result="$(format_date)"
  [ "$result" == 'Wed Dec 31 18:03:42 CST 1969' ]
}
```

This verifies that `format_date` indeed called `date` using the args defined in `${_DATE_ARGS}` (which can not be declared in the test-case with local), and made proper use of the output of it.

The plan is verified, one by one, as the calls come in, but the final check that there are no remaining un-met plans at the end is left until the stub is removed with `unstub`.

### Unstubbing

Once the test case is done, you should call `unstub <program>` in order to clean up the temporary files, and make a final check that all the plans have been met for the stub.

### Verifying stub input

If you want to verify that your stub was passed the correct data in STDIN, you can redirect its content to a temporary file and check it.

```bash
@test "send_message" {

	stub curl \
		"${_CURL_ARGS} : cat > ${_TMP_DIR}/actual-input ; cat ${_RESOURCES_DIR}/mock-output"

	run send_message
	assert_success
	diff "${_TMP_DIR}/actual-input" "${_RESOURCES_DIR}/expected-input"
}
```

### Accepting any arguments

Sometimes the argument is to complicated to determine in advance so you just want to ensure that an argument is given.
Or you want to assert that the argument matches a given pattern, e.g. starts with a prefix.   
When even that is undesired then you can even accept any call with any number of arguments.

```bash
@test "send_message" {

	stub grep \
    '* /home* : printf "%s" "$1" > ${_RESOURCES_DIR}/mock-output' \
    'exit 0'
  
  # Matches first and hence prints the patter to mock-output
  grep "$complicated_pattern" /home/user/file

  # Matches second and simply returns success
  grep -E -i "$some_pattern" "$some_file"

  # If your command contains ' : ' just start with double-colon
  stub cat '::echo "Hello : World"'
  # Prints "Hello : World"
  cat foo bar

  # Note that a single colon at the start is interpreted as "no arguments"
  stub cat ': echo "OK"'
  ! cat foo # `cat` stub fails as an argument was passed

  # But don't forget the space!
  stub cat':echo "OK"'
  # Will accept any arguments and execute `:echo "OK"` -> Fails
  !cat foo # command `:echo` not found
}
```

### Incremental Stubbing

In some case it might be preferable to define the invocation plan incrementally to mirror the actual behavior of the program under test.
This can be done by invocing `stub` multiple times with the same command.   
In case you want to to start with a new plan call `unstub` first.

```bash
# Function to test
function install() {
  apt-get update
  pt-add-repository -y myrepo
  apt-get update
}

@test "test installation" {
  stub apt-get "update : "
  stub apt-add-repository "-y myrepo : "
  stub apt-get "update : " # Appends to existing plan
  run install
  unstub apt-get # Verifies plan and removes all remaining files
  stub apt-get "upgrade" # Start with a new plan
}
```

## Troubleshooting

It can be difficult to figure out why your mock has failed. You can enable debugging by setting an environment variable (in this case for `date`):

```
export DATE_STUB_DEBUG=/dev/tty
```

## How it works

(You may want to know this, if you get weird results there may be stray files lingering about messing with your state.)

Under the covers, `bats-mock` uses three scripts to manage the stubbed programs/functions.

First, it is the command (or program) itself, which when the stub is created is placed in (or rather, the `binstub` script is sym-linked to) `${BATS_MOCK_BINDIR}/${program}` (which is added to your `PATH` when loading the stub library). Secondly, it creates a stub plan, based on the arguments passed when creating the stub, and finally, during execution, the command invocations are tracked in a stub run file which is checked once the command is `unstub`'ed. The `${program}-stub-[plan|run]` files are both in `${BATS_MOCK_TMPDIR}`.

### Caveat

If you stub functions, make sure to unset them, or the stub script wan't be called, as the function will shadow the binstub script on the `PATH`.

## Credits

Forked from https://github.com/jasonkarns/bats-mock originally with thanks to [@jasonkarns](https://github.com/jasonkarns).

Originally extracted from the [ruby-build][] test suite. Many thanks to its author and contributors: [Sam Stephenson][sstephenson] and [Mislav Marohnić][mislav].

[ruby-build]: https://github.com/sstephenson/ruby-build
[sstephenson]: https://github.com/sstephenson
[mislav]: https://github.com/mislav
