#!/usr/bin/env python3
"""Check that validation helper scripts are wired into the local CI graph."""

from __future__ import annotations

import pathlib
import subprocess
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]


def error(message: str) -> None:
    print(message, file=sys.stderr)


def require_text(text: str, needle: str, label: str) -> bool:
    if needle not in text:
        error(f"{label} must contain {needle!r}")
        return False
    return True


def tracked_scripts() -> set[str]:
    result = subprocess.run(
        ["git", "ls-files", "scripts/*"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return set(result.stdout.splitlines())


def main(argv: list[str]) -> int:
    if argv:
        error("usage: python3 scripts/check_validation_inventory.py")
        return 2

    ci_text = (ROOT / "scripts" / "check_ci.sh").read_text()
    scripts_text = (ROOT / "scripts" / "check_scripts.sh").read_text()
    mooncakes_text = (ROOT / "scripts" / "verify_mooncakes_package.sh").read_text()
    ok = True

    ci_helpers = [
        "scripts/check_release_version.py",
        "scripts/check_scripts.sh",
        "scripts/check_validation_inventory.py",
        "scripts/check_github_workflows.py",
        "scripts/check_source_layout.py",
        "scripts/check_test_inventory.py",
        "scripts/check_moonbit_style.py",
        "scripts/check_gitignore.py",
        "scripts/check_githooks.py",
        "scripts/check_migration_docs.py",
        "scripts/check_fixture_sync.py",
        "scripts/check_fixture_manifest.py",
        "scripts/check_package_metadata.py",
        "scripts/check_interfaces.sh",
        "scripts/check_tests.sh",
        "scripts/check_coverage.sh",
        "scripts/smoke_native_cli.sh",
        "scripts/verify_mooncakes_package.sh",
    ]
    for helper in ci_helpers:
        ok = require_text(ci_text, helper, "scripts/check_ci.sh") and ok

    smoke_helpers = [
        "scripts/check_ci.sh",
        "scripts/check_scripts.sh",
        "scripts/check_coverage.sh",
        "scripts/check_interfaces.sh",
        "scripts/smoke_native_cli.sh",
        "scripts/verify_mooncakes_package.sh",
        "scripts/check_release_version.py",
        "scripts/check_fixture_sync.py",
        "scripts/check_fixture_manifest.py",
        "scripts/check_validation_inventory.py",
        "scripts/check_github_workflows.py",
        "scripts/check_source_layout.py",
        "scripts/check_test_inventory.py",
        "scripts/check_moonbit_style.py",
        "scripts/check_gitignore.py",
        "scripts/check_githooks.py",
        "scripts/check_migration_docs.py",
        "scripts/check_package_metadata.py",
        "scripts/check_publish_archive.py",
        "scripts/check_tests.sh",
    ]
    for helper in smoke_helpers:
        ok = require_text(scripts_text, helper, "scripts/check_scripts.sh") and ok

    ok = require_text(
        mooncakes_text,
        "scripts/check_publish_archive.py",
        "scripts/verify_mooncakes_package.sh",
    ) and ok

    covered_scripts = set(ci_helpers) | set(smoke_helpers) | {
        "scripts/check_publish_archive.py",
    }
    for helper in sorted(tracked_scripts() - covered_scripts):
        error(f"tracked validation helper is missing from inventory: {helper}")
        ok = False

    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
