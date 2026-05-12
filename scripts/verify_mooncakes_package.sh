#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: bash scripts/verify_mooncakes_package.sh [--skip-without-credentials]" >&2
}

skip_without_credentials=false
case "${1:-}" in
  "")
    ;;
  "--skip-without-credentials")
    skip_without_credentials=true
    ;;
  *)
    usage
    exit 2
    ;;
esac

if [[ "$#" -gt 1 ]]; then
  usage
  exit 2
fi

if [[ "$skip_without_credentials" == true && ! -f "$HOME/.moon/credentials.json" ]]; then
  echo "Skipping Mooncakes dry-run because this runner is not logged in."
  exit 0
fi

set +e
output="$(moon publish --dry-run 2>&1)"
exit_code=$?
set -e

printf '%s\n' "$output"

if [[ "$exit_code" -eq 0 ]]; then
  exit 0
fi

if printf '%s\n' "$output" | grep -Fq "Dry run completed successfully"; then
  echo "Accepted Mooncakes dry-run success response."
  exit 0
fi

if printf '%s\n' "$output" | grep -Fq "duplicated with an existing version"; then
  echo "Accepted already-published Mooncakes package version."
  exit 0
fi

exit "$exit_code"
