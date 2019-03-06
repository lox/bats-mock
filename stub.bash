BATS_MOCK_TMPDIR="${BATS_TMPDIR}"
BATS_MOCK_BINDIR="${BATS_MOCK_TMPDIR}/bin"
BATS_MOCK_APPEND=${BATS_MOCK_APPEND-0}

PATH="$BATS_MOCK_BINDIR:$PATH"

stub() {
  local program="$1"
  local prefix="$(echo "$program" | tr a-z-. A-Z__)"
  shift

  export "${prefix}_STUB_PLAN"="${BATS_MOCK_TMPDIR}/${program}-stub-plan"
  export "${prefix}_STUB_RUN"="${BATS_MOCK_TMPDIR}/${program}-stub-run"
  export "${prefix}_STUB_END"=

  mkdir -p "${BATS_MOCK_BINDIR}"
  ln -sf "${BASH_SOURCE[0]%stub.bash}binstub" "${BATS_MOCK_BINDIR}/${program}"

  if [ $BATS_MOCK_APPEND -ne 1 ]; then {
    rm -f "${BATS_MOCK_TMPDIR}/${program}-stub-plan" "${BATS_MOCK_TMPDIR}/${program}-stub-run"
  }; fi
  touch "${BATS_MOCK_TMPDIR}/${program}-stub-plan"
  for arg in "$@"; do printf "%s\n" "$arg" >> "${BATS_MOCK_TMPDIR}/${program}-stub-plan"; done
}

unstub() {
  local program="$1"
  local prefix="$(echo "$program" | tr a-z-. A-Z__)"
  local path="${BATS_MOCK_BINDIR}/${program}"

  export "${prefix}_STUB_END"=1

  local STATUS=0
  "$path" || STATUS="$?"

  rm -f "$path"
  rm -f "${BATS_MOCK_TMPDIR}/${program}-stub-plan" "${BATS_MOCK_TMPDIR}/${program}-stub-run"
  return "$STATUS"
}
