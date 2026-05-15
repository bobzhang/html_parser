#!/usr/bin/env python3
"""Check that tracked MoonBit test declarations do not drift silently."""

from __future__ import annotations

import hashlib
import pathlib
import re
import subprocess
import sys
from collections import Counter


ROOT = pathlib.Path(__file__).resolve().parents[1]

EXPECTED_COUNT = 621
EXPECTED_SHA256 = (
    "3f0a356330a10934608fa80978e8dca045c05bc0ebc9aa052ffd43e188a4c46d"
)
TEST_DECLARATION = re.compile(
    r'^\s*(?:async\s+)?test\s+"((?:[^"\\]|\\.)*)"',
    re.MULTILINE,
)


def error(message: str) -> None:
    print(message, file=sys.stderr)


def tracked_moonbit_sources() -> list[pathlib.Path]:
    result = subprocess.run(
        ["git", "ls-files", "*.mbt", "*.mbt.md"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return [ROOT / path for path in result.stdout.splitlines()]


def test_inventory() -> list[str]:
    inventory: list[str] = []
    for path in tracked_moonbit_sources():
        text = path.read_text()
        rel_path = path.relative_to(ROOT).as_posix()
        for match in TEST_DECLARATION.finditer(text):
            inventory.append(f"{rel_path}:{match.group(1)}")
    return sorted(inventory)


def inventory_hash(inventory: list[str]) -> str:
    payload = "".join(f"{item}\n" for item in inventory)
    return hashlib.sha256(payload.encode()).hexdigest()


def main(argv: list[str]) -> int:
    if argv:
        error("usage: python3 scripts/check_test_inventory.py")
        return 2

    inventory = test_inventory()
    observed_count = len(inventory)
    observed_hash = inventory_hash(inventory)
    ok = True

    if observed_count != EXPECTED_COUNT:
        error(
            "MoonBit test inventory count changed: "
            f"expected {EXPECTED_COUNT}, observed {observed_count}"
        )
        ok = False

    duplicates = sorted(item for item, count in Counter(inventory).items() if count > 1)
    if duplicates:
        error("MoonBit test inventory contains duplicate declarations:")
        for item in duplicates:
            error(f"  {item}")
        ok = False

    if observed_hash != EXPECTED_SHA256:
        error(
            "MoonBit test inventory hash changed: "
            f"expected {EXPECTED_SHA256}, observed {observed_hash}"
        )
        error("Review the test declaration changes before updating this guard.")
        ok = False

    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
