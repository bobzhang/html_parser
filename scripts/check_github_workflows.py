#!/usr/bin/env python3
"""Check that GitHub Actions workflows stay wired to local validation."""

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


def require_absent(text: str, needle: str, label: str) -> bool:
    if needle in text:
        error(f"{label} must not contain {needle!r}")
        return False
    return True


def tracked_workflows() -> set[str]:
    result = subprocess.run(
        ["git", "ls-files", ".github/workflows/*.yml"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return set(result.stdout.splitlines())


def main(argv: list[str]) -> int:
    if argv:
        error("usage: python3 scripts/check_github_workflows.py")
        return 2

    expected_workflows = {
        ".github/workflows/ci.yml",
        ".github/workflows/copilot-setup-steps.yml",
    }
    actual_workflows = tracked_workflows()
    ok = True
    for path in sorted(expected_workflows - actual_workflows):
        error(f"expected GitHub workflow is not tracked: {path}")
        ok = False
    for path in sorted(actual_workflows - expected_workflows):
        error(f"tracked GitHub workflow is missing from validation: {path}")
        ok = False

    workflow = ROOT / ".github" / "workflows" / "ci.yml"
    if not workflow.is_file():
        error(".github/workflows/ci.yml does not exist")
        return 1

    text = workflow.read_text()
    for needle in [
        "name: CI",
        "pull_request:",
        "workflow_dispatch:",
        "branches:\n      - main",
        "permissions:\n      contents: read",
        "curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash",
        'echo "$HOME/.moon/bin" >> "$GITHUB_PATH"',
        "run: moon version --all",
        "run: bash scripts/check_ci.sh --skip-without-credentials",
    ]:
        ok = require_text(text, needle, ".github/workflows/ci.yml") and ok

    check_ci_refs = text.count("scripts/check_ci.sh")
    if check_ci_refs != 1:
        error(
            ".github/workflows/ci.yml must invoke scripts/check_ci.sh "
            f"exactly once, found {check_ci_refs}",
        )
        ok = False

    for direct_moon_command in [
        "run: moon check",
        "run: moon fmt",
        "run: moon test",
        "run: moon coverage",
        "run: moon publish",
    ]:
        ok = require_absent(text, direct_moon_command, ".github/workflows/ci.yml") and ok

    copilot_workflow = ROOT / ".github" / "workflows" / "copilot-setup-steps.yml"
    if not copilot_workflow.is_file():
        error(".github/workflows/copilot-setup-steps.yml does not exist")
        ok = False
    else:
        copilot_text = copilot_workflow.read_text()
        for needle in [
            'name: "Copilot Setup Steps"',
            "workflow_dispatch:",
            "push:\n    paths:\n      - .github/workflows/copilot-setup-steps.yml",
            "pull_request:\n    paths:\n      - .github/workflows/copilot-setup-steps.yml",
            "copilot-setup-steps:",
            "runs-on: ubuntu-latest",
            "permissions:",
            "contents: read",
            "uses: actions/checkout@v5",
            "curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash",
            'echo "$HOME/.moon/bin" >> "$GITHUB_PATH"',
            "moon version --all",
            "moon update",
        ]:
            ok = require_text(
                copilot_text,
                needle,
                ".github/workflows/copilot-setup-steps.yml",
            ) and ok

    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
