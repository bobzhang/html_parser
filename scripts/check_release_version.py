#!/usr/bin/env python3
"""Check that release version metadata stays in sync."""

from __future__ import annotations

import json
import pathlib
import re
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]


def main() -> int:
    version = json.loads((ROOT / "moon.mod.json").read_text())["version"]
    cli = (ROOT / "cli.mbt").read_text()
    cli_test = (ROOT / "cli_test.mbt").read_text()

    cli_match = re.search(
        r'fn cli_version\(\) -> String \{\s*"([^"]+)"\s*\}',
        cli,
    )
    if cli_match is None:
        print("could not find cli_version()", file=sys.stderr)
        return 1

    cli_version = cli_match.group(1)
    if cli_version != version:
        print(
            f"cli_version {cli_version!r} != module version {version!r}",
            file=sys.stderr,
        )
        return 1

    expected_test = f'assert_eq(version.stdout, "justhtml {version}\\n")'
    if expected_test not in cli_test:
        print(
            "CLI --version test does not assert the module version",
            file=sys.stderr,
        )
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
