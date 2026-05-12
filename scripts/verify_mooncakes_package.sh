#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--skip-without-credentials" ]] && [[ ! -f "$HOME/.moon/credentials.json" ]]; then
  echo "Skipping Mooncakes dry-run because this runner is not logged in."
  exit 0
fi

set +e
output="$(moon publish --dry-run 2>&1)"
exit_code=$?
set -e

printf '%s\n' "$output"

if [[ "$exit_code" -ne 0 ]] \
  && ! printf '%s\n' "$output" | grep -q "Dry run completed successfully" \
  && ! printf '%s\n' "$output" | grep -q "duplicated with an existing version"; then
  exit "$exit_code"
fi
