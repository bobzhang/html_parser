#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: bash scripts/check_scrut_cli.sh" >&2
}

if [[ "$#" -ne 0 ]]; then
  usage
  exit 2
fi

scrut_bin="${SCRUT_BIN:-scrut}"
if [[ "$scrut_bin" == */* ]]; then
  if [[ ! -x "$scrut_bin" ]]; then
    echo "SCRUT_BIN is not executable: $scrut_bin" >&2
    exit 1
  fi
elif ! command -v "$scrut_bin" > /dev/null; then
  echo "scrut is required; set SCRUT_BIN or install scrut in PATH" >&2
  exit 1
fi

moon run --target native --release --build-only cmd/main > /dev/null

export JUSTHTML_CLI="$PWD/_build/native/release/build/cmd/main/main.exe"
if [[ ! -x "$JUSTHTML_CLI" ]]; then
  echo "native CLI binary was not built: $JUSTHTML_CLI" >&2
  exit 1
fi

"$scrut_bin" test tests/scrut
