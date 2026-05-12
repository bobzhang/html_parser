#!/usr/bin/env python3
"""Check the checked-in JustHTML fixture subset against its manifest."""

from __future__ import annotations

import hashlib
import pathlib
import subprocess
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]

MANIFEST = {
    "tests/fixtures/justhtml/LICENSE.justhtml": (
        1256,
        "fc806f290894e4f219467135fb21f33048f8d5a817f0f8284246d72da29d572e",
    ),
    "tests/fixtures/justhtml/README.md": (
        589,
        "b761becfae2a02c3a2ae8657c168c4f811e56bf4b0f81ceeb2aa02143cc571c1",
    ),
    "tests/fixtures/justhtml/README.upstream.md": (
        1204,
        "b51b5f6a500839651edb0e0725857fa1cdc8454fd15fc628e8e422acd0cc5805",
    ),
    "tests/fixtures/justhtml/data/wikipedia.html": (
        157021,
        "76c08f0bcbce67ab64d016e8956e4f04429ab3dd50a40c586e75aa2eb00c9ab0",
    ),
    "tests/fixtures/justhtml/justhtml-sanitize-tests/cases.json": (
        25981,
        "c8ae8f94d2c1e863af7f6b3599ef7ccc2295aa6c745ba1c588b53c6e0f80a5dc",
    ),
    "tests/fixtures/justhtml/justhtml-tests/branch_coverage.dat": (
        7561,
        "747006af474730392736d9494aa7b21c147cf53ad45c253002bd5fc17175e127",
    ),
    "tests/fixtures/justhtml/justhtml-tests/coverage_gaps.test": (
        1506,
        "2163c6790cf15854c9191dc36b26e7f0932654c18254bd0c6b55ba02f57f6c18",
    ),
    "tests/fixtures/justhtml/justhtml-tests/empty_stack_edge_cases.dat": (
        1197,
        "ca421e79a47dfa25401d7e7a5041a5089457c1d31eddbd3714ecd5ff91738e9b",
    ),
    "tests/fixtures/justhtml/justhtml-tests/entities.test": (
        1512,
        "b9e5c0572d68e8b39f796fcaa6109ecc3db3c8e0463909e7abcab7fcc0576189",
    ),
    "tests/fixtures/justhtml/justhtml-tests/iframe_srcdoc.dat": (
        169,
        "27f1ec4c45f653230df3432c1c75124c72b095efc977d2f74bc54ff840bafa64",
    ),
    "tests/fixtures/justhtml/justhtml-tests/tokenizer_edge_cases.test": (
        7891,
        "09c3fc08d3d925a0adb7c5a43354dec49170e32991bb4276369c0e06781fe93a",
    ),
    "tests/fixtures/justhtml/justhtml-tests/treebuilder_coverage.dat": (
        3858,
        "3e68d02f2d2ddf1c5c8dd905681e613ffafb08f07ec8267bceb964863e34a421",
    ),
    "tests/fixtures/justhtml/justhtml-tests/xml_coercion.dat": (
        650,
        "c88887f5d4e7782be09ad27c09531ddd40ddae3b2d203a2f645504bfe3265c27",
    ),
    "tests/fixtures/justhtml/justhtml-tests/xml_coercion_coverage.test": (
        328,
        "cbc10430c037150bb95d25c0ed011c4c0c3c7ee08f704f462b6453da63612221",
    ),
    "tests/fixtures/justhtml/linkify-it/LICENSE.txt": (
        1058,
        "95e3f7f0e81e9b4940cdfaa1956aaff5e4dfd2fb1565041e7c78eb9a606f23e3",
    ),
    "tests/fixtures/justhtml/linkify-it/README.md": (
        355,
        "adb5a81e57ce228b417d1f95577f688381bdf3ef8834d40ca7b00767e36f1b55",
    ),
    "tests/fixtures/justhtml/linkify-it/fixtures/links.txt": (
        6492,
        "f3413613c047d2d351b16ebba9c632baa74cfa0d8e253f00483299ed6e2953b9",
    ),
    "tests/fixtures/justhtml/linkify-it/fixtures/not_links.txt": (
        763,
        "857d0168381df03d82acb120ad507accf2e3a9e9c7c520d9dc859d028143d3af",
    ),
}


def error(message: str) -> None:
    print(message, file=sys.stderr)


def tracked_fixture_files() -> set[str]:
    result = subprocess.run(
        ["git", "ls-files", "tests/fixtures/justhtml/**"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return set(result.stdout.splitlines())


def main(argv: list[str]) -> int:
    if argv:
        error("usage: python3 scripts/check_fixture_manifest.py")
        return 2

    ok = True
    tracked = tracked_fixture_files()
    expected = set(MANIFEST)
    for path in sorted(expected - tracked):
        error(f"fixture manifest entry is not tracked: {path}")
        ok = False
    for path in sorted(tracked - expected):
        error(f"tracked fixture is missing from manifest: {path}")
        ok = False

    for path, (expected_size, expected_sha256) in sorted(MANIFEST.items()):
        file = ROOT / path
        if not file.is_file():
            error(f"fixture manifest entry is missing from disk: {path}")
            ok = False
            continue
        data = file.read_bytes()
        actual_sha256 = hashlib.sha256(data).hexdigest()
        if len(data) != expected_size:
            error(
                f"fixture size changed for {path}: "
                f"{len(data)} != {expected_size}",
            )
            ok = False
        if actual_sha256 != expected_sha256:
            error(
                f"fixture sha256 changed for {path}: "
                f"{actual_sha256} != {expected_sha256}",
            )
            ok = False

    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
