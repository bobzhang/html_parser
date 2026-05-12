#!/usr/bin/env bash
set -euo pipefail

for script in scripts/*.sh; do
  bash -n "$script"
done

python3 - <<'PY'
import ast
import pathlib

for path in sorted(pathlib.Path("scripts").glob("*.py")):
    ast.parse(path.read_text(), filename=str(path))
PY

tmp_home="$(mktemp -d)"
tmp_out="$(mktemp)"
verify_err="$(mktemp)"
check_ci_err="$(mktemp)"
trap 'rm -rf "$tmp_home"; rm -f "$tmp_out" "$verify_err" "$check_ci_err"' EXIT

HOME="$tmp_home" bash scripts/verify_mooncakes_package.sh \
  --skip-without-credentials > "$tmp_out"
grep -F "Skipping Mooncakes dry-run because this runner is not logged in." \
  "$tmp_out" > /dev/null

set +e
bash scripts/verify_mooncakes_package.sh \
  --bad-option > "$tmp_out" 2> "$verify_err"
verify_code=$?
bash scripts/check_ci.sh --bad-option > "$tmp_out" 2> "$check_ci_err"
check_ci_code=$?
set -e

test "$verify_code" -eq 2
grep -F "usage: bash scripts/verify_mooncakes_package.sh" "$verify_err" \
  > /dev/null
test "$check_ci_code" -eq 2
grep -F "usage: bash scripts/check_ci.sh" "$check_ci_err" > /dev/null
