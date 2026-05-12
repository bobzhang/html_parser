#!/usr/bin/env python3
"""Check Mooncakes package metadata and README install snippets."""

from __future__ import annotations

import json
import pathlib
import re
import sys
from typing import Any


ROOT = pathlib.Path(__file__).resolve().parents[1]


def error(message: str) -> None:
    print(message, file=sys.stderr)


def expect_string(metadata: dict[str, Any], field: str) -> str | None:
    value = metadata.get(field)
    if not isinstance(value, str) or value == "":
        error(f"moon.mod.json field {field!r} must be a non-empty string")
        return None
    return value


def main() -> int:
    metadata = json.loads((ROOT / "moon.mod.json").read_text())
    ok = True

    name = expect_string(metadata, "name")
    version = expect_string(metadata, "version")
    readme = expect_string(metadata, "readme")
    repository = expect_string(metadata, "repository")
    license_id = expect_string(metadata, "license")
    description = expect_string(metadata, "description")

    keywords = metadata.get("keywords")
    if not isinstance(keywords, list) or not keywords:
        error("moon.mod.json field 'keywords' must be a non-empty list")
        ok = False
    elif not all(isinstance(keyword, str) and keyword for keyword in keywords):
        error("moon.mod.json field 'keywords' must contain only non-empty strings")
        ok = False

    if name is None or version is None or readme is None:
        ok = False
    else:
        if re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", name) is None:
            error(f"package name {name!r} must use owner/package form")
            ok = False

        semver = r"\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?"
        if re.fullmatch(semver, version) is None:
            error(f"version {version!r} must look like a semantic version")
            ok = False

        readme_path = pathlib.PurePosixPath(readme)
        if readme_path.is_absolute() or ".." in readme_path.parts:
            error(f"readme path {readme!r} must stay inside the repository")
            ok = False
            readme_text = ""
        else:
            readme_file = ROOT / readme_path
            if not readme_file.is_file():
                error(f"readme path {readme!r} does not exist")
                ok = False
                readme_text = ""
            else:
                readme_text = readme_file.read_text()

        if readme_text:
            expected_install = f"moon add {name}"
            expected_import = f'"{name}"'
            expected_heading = f"# {name}"
            if expected_heading not in readme_text.splitlines()[:5]:
                error(f"README must start with heading {expected_heading!r}")
                ok = False
            if expected_install not in readme_text:
                error(f"README must document {expected_install!r}")
                ok = False
            if expected_import not in readme_text:
                error(f"README must show import path {expected_import!r}")
                ok = False

    if name is not None and repository is not None:
        expected_repository = f"https://github.com/{name}"
        if repository != expected_repository:
            error(
                f"repository {repository!r} != expected {expected_repository!r}",
            )
            ok = False

    if license_id is not None:
        if license_id != "Apache-2.0":
            error(f"license {license_id!r} must be 'Apache-2.0'")
            ok = False
        license_text = (ROOT / "LICENSE").read_text()
        if "Apache License" not in license_text or "Version 2.0" not in license_text:
            error("LICENSE file does not contain Apache License 2.0 text")
            ok = False

    if description is not None and len(description) > 200:
        error("moon.mod.json description should stay concise")
        ok = False

    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
