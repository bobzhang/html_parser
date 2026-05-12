#!/usr/bin/env python3
"""Check local Git hook wiring for the shared validation entrypoint."""

from __future__ import annotations

import pathlib
import stat
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]


def error(message: str) -> None:
    print(message, file=sys.stderr)


def require_text(path: pathlib.Path, text: str, needle: str) -> bool:
    if needle not in text:
        error(f"{path.relative_to(ROOT)} must contain {needle!r}")
        return False
    return True


def main(argv: list[str]) -> int:
    if argv:
        error("usage: python3 scripts/check_githooks.py")
        return 2

    hook = ROOT / ".githooks" / "pre-commit"
    readme = ROOT / ".githooks" / "README.md"
    ok = True

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
