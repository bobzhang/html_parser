#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: bash scripts/check_coverage.sh" >&2
}

if [[ "$#" -ne 0 ]]; then
  usage
  exit 2
fi

coverage="$(moon coverage analyze)"
printf '%s\n' "$coverage"
printf '%s\n' "$coverage" | grep -F "All source files are fully covered"
