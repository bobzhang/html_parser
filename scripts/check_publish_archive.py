#!/usr/bin/env python3
"""Check the Mooncakes dry-run archive for expected package contents."""

from __future__ import annotations

import json
import pathlib
import subprocess
import sys
import zipfile


ROOT = pathlib.Path(__file__).resolve().parents[1]


def error(message: str) -> None:
    print(message, file=sys.stderr)


def expected_archive_path() -> pathlib.Path | None:
    metadata = json.loads((ROOT / "moon.mod.json").read_text())
    name = metadata.get("name")
    version = metadata.get("version")
    if not isinstance(name, str) or "/" not in name:
        error("moon.mod.json field 'name' must use owner/package form")
        return None
    if not isinstance(version, str) or version == "":
        error("moon.mod.json field 'version' must be a non-empty string")
        return None
    owner, package = name.split("/", 1)
    return ROOT / "_build" / "publish" / f"{owner}-{package}-{version}.zip"


def tracked_files() -> set[str]:
    result = subprocess.run(
        ["git", "ls-files"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return set(result.stdout.splitlines())


def expected_published_files() -> set[str]:
    expected: set[str] = set()
    for path in tracked_files():
        pure = pathlib.PurePosixPath(path)
        if pure.name in {"moon.mod.json", "moon.pkg", "LICENSE"}:
            expected.add(path)
        elif pure.parent == pathlib.PurePosixPath(".") and pure.suffix == ".md":
            expected.add(path)
        elif path.startswith("scripts/"):
            expected.add(path)
        elif path.startswith("tests/fixtures/justhtml/"):
            expected.add(path)
        elif path.endswith((".mbt", ".mbt.md", ".mbti", ".c")):
            expected.add(path)
    return expected


def main(argv: list[str]) -> int:
    if len(argv) > 1 or (argv and argv[0].startswith("-")):
        error("usage: python3 scripts/check_publish_archive.py [zip-path]")
        return 2

    archive = pathlib.Path(argv[0]) if argv else expected_archive_path()
    if archive is None:
        return 1
    if not archive.is_file():
        error(f"Mooncakes archive does not exist: {archive}")
        return 1

    ok = True
    with zipfile.ZipFile(archive) as zf:
        names = set(zf.namelist())

        required = expected_published_files()
        for path in sorted(required):
            if path not in names:
                error(f"Mooncakes archive is missing required file: {path}")
                ok = False

        forbidden_prefixes = (
            ".git/",
            ".github/",
            ".githooks/",
            ".repos/",
            "_build/",
            "node_modules/",
            "__pycache__/",
        )
        for name in sorted(names):
            if name.startswith("/") or "/../" in f"/{name}":
                error(f"Mooncakes archive contains unsafe path: {name}")
                ok = False
            if name.startswith(forbidden_prefixes):
                error(f"Mooncakes archive contains non-package path: {name}")
                ok = False
            if "/__pycache__/" in f"/{name}/" or name.endswith(".pyc"):
                error(f"Mooncakes archive contains Python bytecode/cache path: {name}")
                ok = False

        if "README.md" in names and "README.mbt.md" in names:
            if zf.read("README.md") != zf.read("README.mbt.md"):
                error("Mooncakes archive README.md must match README.mbt.md")
                ok = False

    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
