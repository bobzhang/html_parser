#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: bash scripts/check_ci.sh [--skip-without-credentials]" >&2
}

skip_mooncakes_without_credentials=false
case "${1:-}" in
  "")
    ;;
  "--skip-without-credentials")
    skip_mooncakes_without_credentials=true
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

group_open=false

finish_group() {
  if [[ "${GITHUB_ACTIONS:-}" == "true" && "$group_open" == true ]]; then
    echo "::endgroup::"
    group_open=false
  fi
}

trap finish_group EXIT

step() {
  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    finish_group
    echo "::group::$1"
    group_open=true
  else
    printf '\n==> %s\n' "$1"
  fi
}

step "Check release version consistency"
python3 scripts/check_release_version.py

step "Check validation scripts"
bash scripts/check_scripts.sh

step "Check GitHub workflows"
python3 scripts/check_github_workflows.py

step "Check source layout"
python3 scripts/check_source_layout.py

step "Check gitignore"
python3 scripts/check_gitignore.py

step "Check migration docs"
python3 scripts/check_migration_docs.py

step "Check vendored fixture sync"
python3 scripts/check_fixture_sync.py

step "Check package metadata"
python3 scripts/check_package_metadata.py

step "Check formatting"
moon fmt --check

step "Check generated interfaces"
bash scripts/check_interfaces.sh

step "Type check default target"
moon check --warn-list +73

step "Type check all targets"
moon check --target all --warn-list +73

step "Type check native CLI"
moon check --target native cmd/main --warn-list +73

step "Run tests with count floor"
bash scripts/check_tests.sh

step "Analyze coverage"
bash scripts/check_coverage.sh

step "Build and smoke test native CLI"
bash scripts/smoke_native_cli.sh

step "Verify Mooncakes package"
if [[ "$skip_mooncakes_without_credentials" == true ]]; then
  bash scripts/verify_mooncakes_package.sh --skip-without-credentials
else
  bash scripts/verify_mooncakes_package.sh
fi
