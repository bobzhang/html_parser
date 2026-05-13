#!/usr/bin/env python3
"""Check that migration notes keep the critical porting gotchas documented."""

from __future__ import annotations

import pathlib
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]


def error(message: str) -> None:
    print(message, file=sys.stderr)


def collapse_whitespace(text: str) -> str:
    return " ".join(text.split())


def require_text(path: pathlib.Path, text: str, needle: str) -> bool:
    if needle not in text and (
        collapse_whitespace(needle) not in collapse_whitespace(text)
    ):
        error(f"{path.relative_to(ROOT)} must contain {needle!r}")
        return False
    return True


def main(argv: list[str]) -> int:
    if argv:
        error("usage: python3 scripts/check_migration_docs.py")
        return 2

    docs = {
        ROOT / "Python2MoonBit.md": [
            "# Python to MoonBit Porting Notes",
            "MoonBit `String` is UTF-16 encoded",
            "`s[i]` returns a `UInt16` code unit",
            "`for ch in s` iterates Unicode-safe `Char` values",
            "Prefer `StringView` for parser cursors and slices",
            "manual `get_char(pos)` loops",
            "advance by `ch.utf16_len()`",
            "Do not run every `BytesView` through UTF-8 lossy decoding",
            "Treat the current Python source as the oracle",
            "`.repos/justhtml`",
            "## CLI and Native I/O",
            "`cmd/main/moon.pkg`",
            "\"native-stub\": [ \"cli_io.c\" ]",
            "Mooncakes",
        ],
        ROOT / "MigrationChecklist.md": [
            "# JustHTML to MoonBit Migration Checklist",
            "## Remaining Feature Work",
            "## Post-Completion Audits",
            "Mooncakes package metadata, GitHub repository, and CI",
            "Port one feature slice at a time",
        ],
        ROOT / "README.mbt.md": [
            "bash scripts/check_ci.sh --skip-without-credentials",
            "GitHub workflow drift",
            "tracked workflow inventory",
            "Copilot setup workflow",
            "source layout",
            "test-name inventory",
            "migration docs",
            "local Git hook wiring",
            "helper suffix/shebang conventions",
            "validation-inventory wiring",
            "vendored fixture sync",
            "vendored fixture manifest hashes",
            "tests with a count floor",
            "native CLI smoke behavior",
            "Mooncakes package validation",
            "dynamic Mooncakes archive inventory/content checks",
        ],
    }

    ok = True
    for path, needles in docs.items():
        if not path.is_file():
            error(f"required migration document is missing: {path.relative_to(ROOT)}")
            ok = False
            continue
        text = path.read_text()
        for needle in needles:
            ok = require_text(path, text, needle) and ok

    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
