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
fixture_require_err="$(mktemp)"
fixture_arg_err="$(mktemp)"
workflow_arg_err="$(mktemp)"
source_layout_arg_err="$(mktemp)"
moonbit_style_arg_err="$(mktemp)"
gitignore_arg_err="$(mktemp)"
githooks_arg_err="$(mktemp)"
migration_docs_arg_err="$(mktemp)"
publish_archive_arg_err="$(mktemp)"
check_tests_arg_err="$(mktemp)"
trap '
  rm -rf "$tmp_home"
  rm -f "$tmp_out" "$verify_err" "$check_ci_err"
  rm -f "$fixture_require_err" "$fixture_arg_err"
  rm -f "$workflow_arg_err"
  rm -f "$source_layout_arg_err"
  rm -f "$moonbit_style_arg_err"
  rm -f "$gitignore_arg_err"
  rm -f "$githooks_arg_err"
  rm -f "$migration_docs_arg_err"
  rm -f "$publish_archive_arg_err"
  rm -f "$check_tests_arg_err"
' EXIT

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

missing_reference="$tmp_home/missing-reference"
JUSTHTML_REFERENCE_ROOT="$missing_reference" \
  python3 scripts/check_fixture_sync.py > "$tmp_out"
grep -F "Skipping fixture sync check because reference checkout is absent:" \
  "$tmp_out" > /dev/null

set +e
JUSTHTML_REFERENCE_ROOT="$missing_reference" \
  python3 scripts/check_fixture_sync.py --require-reference \
    > "$tmp_out" 2> "$fixture_require_err"
fixture_require_code=$?
python3 scripts/check_fixture_sync.py \
  --bad-option > "$tmp_out" 2> "$fixture_arg_err"
fixture_arg_code=$?
python3 scripts/check_github_workflows.py \
  --bad-option > "$tmp_out" 2> "$workflow_arg_err"
workflow_arg_code=$?
python3 scripts/check_source_layout.py \
  --bad-option > "$tmp_out" 2> "$source_layout_arg_err"
source_layout_arg_code=$?
python3 scripts/check_moonbit_style.py \
  --bad-option > "$tmp_out" 2> "$moonbit_style_arg_err"
moonbit_style_arg_code=$?
python3 scripts/check_gitignore.py \
  --bad-option > "$tmp_out" 2> "$gitignore_arg_err"
gitignore_arg_code=$?
python3 scripts/check_githooks.py \
  --bad-option > "$tmp_out" 2> "$githooks_arg_err"
githooks_arg_code=$?
python3 scripts/check_migration_docs.py \
  --bad-option > "$tmp_out" 2> "$migration_docs_arg_err"
migration_docs_arg_code=$?
python3 scripts/check_publish_archive.py \
  --bad-option > "$tmp_out" 2> "$publish_archive_arg_err"
publish_archive_arg_code=$?
bash scripts/check_tests.sh \
  --bad-option > "$tmp_out" 2> "$check_tests_arg_err"
check_tests_arg_code=$?
set -e

test "$fixture_require_code" -eq 1
grep -F "reference checkout is absent:" "$fixture_require_err" > /dev/null
test "$fixture_arg_code" -eq 2
grep -F "usage: python3 scripts/check_fixture_sync.py" "$fixture_arg_err" > /dev/null
test "$workflow_arg_code" -eq 2
grep -F "usage: python3 scripts/check_github_workflows.py" \
  "$workflow_arg_err" > /dev/null
test "$source_layout_arg_code" -eq 2
grep -F "usage: python3 scripts/check_source_layout.py" \
  "$source_layout_arg_err" > /dev/null
test "$moonbit_style_arg_code" -eq 2
grep -F "usage: python3 scripts/check_moonbit_style.py" \
  "$moonbit_style_arg_err" > /dev/null
test "$gitignore_arg_code" -eq 2
grep -F "usage: python3 scripts/check_gitignore.py" \
  "$gitignore_arg_err" > /dev/null
test "$githooks_arg_code" -eq 2
grep -F "usage: python3 scripts/check_githooks.py" \
  "$githooks_arg_err" > /dev/null
test "$migration_docs_arg_code" -eq 2
grep -F "usage: python3 scripts/check_migration_docs.py" \
  "$migration_docs_arg_err" > /dev/null
test "$publish_archive_arg_code" -eq 2
grep -F "usage: python3 scripts/check_publish_archive.py" \
  "$publish_archive_arg_err" > /dev/null
test "$check_tests_arg_code" -eq 2
grep -F "usage: bash scripts/check_tests.sh" \
  "$check_tests_arg_err" > /dev/null
