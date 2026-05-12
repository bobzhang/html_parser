#!/usr/bin/env python3
"""Check ignore rules for generated, local, and reference-checkout paths."""

from __future__ import annotations

import pathlib
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]


def error(message: str) -> None:
    print(message, file=sys.stderr)


def main(argv: list[str]) -> int:
    if argv:
        error("usage: python3 scripts/check_gitignore.py")
        return 2

    gitignore = ROOT / ".gitignore"
    if not gitignore.is_file():
        error(".gitignore does not exist")
        return 1

    ignored = {
        line.strip()
        for line in gitignore.read_text().splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    }
    required = {
        ".DS_Store",
        "_build/",
        ".mooncakes/",
        ".moonagent/",
        ".repos/",
        "__pycache__/",
    }

    ok = True
    for rule in sorted(required):
        if rule not in ignored:
            error(f".gitignore must contain {rule!r}")
            ok = False

    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
