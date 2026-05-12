#!/usr/bin/env python3
"""Check the Mooncakes dry-run archive for expected package contents."""

from __future__ import annotations

import json
import pathlib
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

        required = {
            "moon.mod.json",
            "moon.pkg",
            "pkg.generated.mbti",
            "README.mbt.md",
            "README.md",
            "LICENSE",
            "html_parser.mbt",
            "parser.mbt",
            "tokens.mbt",
            "dom.mbt",
            "serialize.mbt",
            "sanitize.mbt",
            "transforms.mbt",
            "markdown.mbt",
            "linkify.mbt",
            "linkify_dom.mbt",
            "linkify_punycode.mbt",
            "stream.mbt",
            "cli.mbt",
            "types.mbt",
            "cmd/main/moon.pkg",
            "cmd/main/main.mbt",
            "cmd/main/cli_io.c",
            "cmd/main/pkg.generated.mbti",
            "tests/fixtures/justhtml/LICENSE.justhtml",
            "tests/fixtures/justhtml/README.upstream.md",
            "tests/fixtures/justhtml/data/wikipedia.html",
            "tests/fixtures/justhtml/justhtml-sanitize-tests/cases.json",
            "tests/fixtures/justhtml/linkify-it/fixtures/links.txt",
            "tests/fixtures/justhtml/linkify-it/fixtures/not_links.txt",
        }
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
