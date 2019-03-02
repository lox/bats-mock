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

### Incremental Stubbing

In some cases, when stubbing repeated calls to more than one program, the actual order of flow is often obscured by the default `stub` function's behavior, which is to overwrite any previous stub implementation. In this case, you can `export BATS_MOCK_APPEND=1` to modify the `stub` function to append to the stub program with multiple calls:

```bash
# This would actually be in a separate script, but for example...
function install() {
  apt-get update -q # Initial update for a bare system
  apt-get install -y software-properties-common # Get apt-add-repository utility
  apt-add-repository -y "ppa:/myfancystuff/ppa" # Add my repository
  apt-get update -q # Another update for my repository
  apt-get install -y myfancypackage # Install my stuff
}

@test "test install script awkwardly without incremental stubbing" {
  stub apt-get \
    "update -q : " \
    "install -y software-properties-common : " \
    "update -q : " \
    "install -y myfancypackage : "
  stub apt-add-repository \
    "-y \"ppa:/myfancystuff/ppa\" : "
  run install
  # Checks go here...
  unstub apt-get
  unstub apt-add-repository
}

@test "test install script more naturally with incremental stubbing" {
  export BATS_MOCK_APPEND=1 # This would be better in setup(), but for example...
  # Also, you could now comment on each mock expectation...
  stub apt-get "update -q : "
  stub apt-get "install -y software-properties-common : "
  stub apt-get "update -q : "
  stub apt-get "install -y myfancypackage : "
  stub apt-add-repository "-y \"ppa:/myfancystuff/ppa\" : "
  run install
  # Checks go here...
  unstub apt-get
  unstub apt-add-repository
}
```

## Troubleshooting

It can be difficult to figure out why your mock has failed. You can enable debugging by setting an environment variable (in this case for `date`):

```
export DATE_STUB_DEBUG=/dev/tty
```

With default behavior, stubs for all tests go into the same shared `${BATS_TMPDIR}` (`/tmp` on unix systems). This has the effect that if and when some mocking goes wrong, it can cause failure of later tests that deserve to pass. A good work-around for this is to use the `bats-file` support library from [ztombol/bats-file](https://github.com/ztombol/bats-file) to configure `bats-mock` to run in a sub-directory unique to each test. For example:

```bash
load helpers/file/load
load helpers/mocks/stub

setup() {
  export TEST_TEMP_DIR="$(temp_make)"
  export BATSLIB_TEMP_PRESERVE_ON_FAILURE=1
  # Run bats-mock in TEST_TEMP_DIR to isolate each run
  export BATS_MOCK_TMPDIR="${TEST_TEMP_DIR}/mock"
  export BATS_MOCK_BINDIR="${BATS_MOCK_TMPDIR}/bin"
  export PATH="$BATS_MOCK_BINDIR:$PATH"
}
```

The above combination results in isolating each `@test`'s mocks from each other. The `BATSLIB_TEMP_PRESERVE_ON_FAILURE=1` setting provides the added benefit of leaving the temp directory around for inspection when the test fails, when you find yourself more deeply debugging your stubs.

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
