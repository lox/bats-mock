BATS_MOCK_TMPDIR="${BATS_TMPDIR}"
BATS_MOCK_BINDIR="${BATS_MOCK_TMPDIR}/bin"

PATH="$BATS_MOCK_BINDIR:$PATH"

stub() {
  local program="$1"
  local prefix="$(echo "$program" | tr a-z- A-Z_)"
  shift

  export "${prefix}_STUB_PLAN"="${BATS_MOCK_TMPDIR}/${program}-stub-plan"
  export "${prefix}_STUB_RUN"="${BATS_MOCK_TMPDIR}/${program}-stub-run"
  export "${prefix}_STUB_END"=

  mkdir -p "${BATS_MOCK_BINDIR}"
  ln -sf "${BASH_SOURCE[0]%stub.bash}binstub" "${BATS_MOCK_BINDIR}/${program}"

  rm -f "${BATS_MOCK_TMPDIR}/${program}-stub-plan" "${BATS_MOCK_TMPDIR}/${program}-stub-run"
  touch "${BATS_MOCK_TMPDIR}/${program}-stub-plan"
  for arg in "$@"; do printf "%s\n" "$arg" >> "${BATS_MOCK_TMPDIR}/${program}-stub-plan"; done
}

unstub() {
  local allow_missing=0
  if [ "$1" == "--allow-missing" ]; then
    allow_missing=1
    shift
  fi
  local program="$1"
  local prefix="$(echo "$program" | tr a-z- A-Z_)"
  local path="${BATS_MOCK_BINDIR}/${program}"

  export "${prefix}_STUB_END"=1

  local STATUS=0
  if [ -f "$path" ]; then
    "$path" || STATUS="$?"
  elif [ $allow_missing -eq 0 ]; then
    echo "$program is not stubbed" >&2
    STATUS=1
  fi

  rm -f "$path"
  rm -f "${BATS_MOCK_TMPDIR}/${program}-stub-plan" "${BATS_MOCK_TMPDIR}/${program}-stub-run"
  return "$STATUS"
}
