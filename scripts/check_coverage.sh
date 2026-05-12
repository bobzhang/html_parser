#!/usr/bin/env bash
set -euo pipefail

coverage="$(moon coverage analyze)"
printf '%s\n' "$coverage"
printf '%s\n' "$coverage" | grep -F "All source files are fully covered"
