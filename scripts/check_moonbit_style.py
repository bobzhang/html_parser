#!/usr/bin/env python3
"""Check project MoonBit source style conventions."""

from __future__ import annotations

import pathlib
import subprocess
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]


def error(message: str) -> None:
    print(message, file=sys.stderr)


def tracked_moonbit_files() -> list[pathlib.Path]:
    result = subprocess.run(
        ["git", "ls-files", "*.mbt"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return [ROOT / path for path in result.stdout.splitlines()]


def main(argv: list[str]) -> int:
    if argv:
        error("usage: python3 scripts/check_moonbit_style.py")
        return 2

    ok = True
    for path in tracked_moonbit_files():
        text = path.read_text()
        if "///|" not in text:
            error(
                f"{path.relative_to(ROOT)} must use block-style separators "
                "marked by '///|'",
            )
            ok = False

    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
