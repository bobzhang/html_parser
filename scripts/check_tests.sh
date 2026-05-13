#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: bash scripts/check_tests.sh" >&2
}

if [[ "$#" -ne 0 ]]; then
  usage
  exit 2
fi

min_tests=612

run_test_target() {
  local label="$1"
  shift

  printf '\n==> Run %s tests\n' "$label"
  local output
  local exit_code
  set +e
  output="$(moon test "$@" 2>&1)"
  exit_code=$?
  set -e
  printf '%s\n' "$output"
  if (( exit_code != 0 )); then
    exit "$exit_code"
  fi

  local summary
  summary="$(
    printf '%s\n' "$output" \
      | sed -n 's/^Total tests: \([0-9][0-9]*\), passed: \([0-9][0-9]*\), failed: \([0-9][0-9]*\)\.$/\1 \2 \3/p' \
      | tail -n 1
  )"
  if [[ -z "$summary" ]]; then
    echo "moon test output did not include a parseable summary for $label" >&2
    exit 1
  fi

  local total passed failed
  read -r total passed failed <<< "$summary"
  if (( total < min_tests )); then
    echo "$label target ran $total tests, expected at least $min_tests" >&2
    exit 1
  fi
  if (( failed != 0 || passed != total )); then
    echo "$label target reported total=$total passed=$passed failed=$failed" >&2
    exit 1
  fi
}

run_test_target "default"
run_test_target "JS" --target js
run_test_target "native" --target native
