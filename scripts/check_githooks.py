#!/usr/bin/env python3
"""Check local Git hook wiring for the shared validation entrypoint."""

from __future__ import annotations

import pathlib
import stat
import subprocess
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]


def error(message: str) -> None:
    print(message, file=sys.stderr)


def require_text(path: pathlib.Path, text: str, needle: str) -> bool:
    if needle not in text:
        error(f"{path.relative_to(ROOT)} must contain {needle!r}")
        return False
    return True


def tracked_githook_files() -> set[str]:
    result = subprocess.run(
        ["git", "ls-files", ".githooks/*"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return set(result.stdout.splitlines())


def main(argv: list[str]) -> int:
    if argv:
        error("usage: python3 scripts/check_githooks.py")
        return 2

    hook = ROOT / ".githooks" / "pre-commit"
    readme = ROOT / ".githooks" / "README.md"
    ok = True
    expected_hook_files = {
        ".githooks/README.md",
        ".githooks/pre-commit",
    }
    actual_hook_files = tracked_githook_files()
    for path in sorted(expected_hook_files - actual_hook_files):
        error(f"expected Git hook file is not tracked: {path}")
        ok = False
    for path in sorted(actual_hook_files - expected_hook_files):
        error(f"tracked Git hook file is missing from validation: {path}")
        ok = False

    if not hook.is_file():
        error(".githooks/pre-commit does not exist")
        ok = False
        hook_text = ""
    else:
        mode = hook.stat().st_mode
        if not mode & stat.S_IXUSR:
            error(".githooks/pre-commit must be executable")
            ok = False
        hook_text = hook.read_text()

    for needle in [
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "git rev-parse --show-toplevel",
        "bash scripts/check_ci.sh --skip-without-credentials",
    ]:
        ok = require_text(hook, hook_text, needle) and ok

    if not readme.is_file():
        error(".githooks/README.md does not exist")
        ok = False
        readme_text = ""
    else:
        readme_text = readme.read_text()

    for needle in [
        "git config core.hooksPath .githooks",
        "bash scripts/check_ci.sh --skip-without-credentials",
    ]:
        ok = require_text(readme, readme_text, needle) and ok

    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
