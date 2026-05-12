#!/usr/bin/env python3
"""Check vendored JustHTML fixtures against the local reference checkout."""

from __future__ import annotations

import os
import pathlib
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]
DEFAULT_REFERENCE_ROOT = ROOT / ".repos" / "justhtml"
REFERENCE_ROOT = pathlib.Path(
    os.environ.get("JUSTHTML_REFERENCE_ROOT", str(DEFAULT_REFERENCE_ROOT)),
)
VENDORED_ROOT = ROOT / "tests" / "fixtures" / "justhtml"

FIXTURE_PAIRS = [
    ("LICENSE.justhtml", "LICENSE"),
    ("data/wikipedia.html", "tests/data/wikipedia.html"),
    (
        "justhtml-sanitize-tests/cases.json",
        "tests/justhtml-sanitize-tests/cases.json",
    ),
    (
        "justhtml-tests/branch_coverage.dat",
        "tests/justhtml-tests/branch_coverage.dat",
    ),
    ("justhtml-tests/coverage_gaps.test", "tests/justhtml-tests/coverage_gaps.test"),
    (
        "justhtml-tests/empty_stack_edge_cases.dat",
        "tests/justhtml-tests/empty_stack_edge_cases.dat",
    ),
    ("justhtml-tests/entities.test", "tests/justhtml-tests/entities.test"),
    ("justhtml-tests/iframe_srcdoc.dat", "tests/justhtml-tests/iframe_srcdoc.dat"),
    (
        "justhtml-tests/tokenizer_edge_cases.test",
        "tests/justhtml-tests/tokenizer_edge_cases.test",
    ),
    (
        "justhtml-tests/treebuilder_coverage.dat",
        "tests/justhtml-tests/treebuilder_coverage.dat",
    ),
    ("justhtml-tests/xml_coercion.dat", "tests/justhtml-tests/xml_coercion.dat"),
    (
        "justhtml-tests/xml_coercion_coverage.test",
        "tests/justhtml-tests/xml_coercion_coverage.test",
    ),
    ("linkify-it/LICENSE.txt", "tests/linkify-it/LICENSE.txt"),
    ("linkify-it/README.md", "tests/linkify-it/README.md"),
    ("linkify-it/fixtures/links.txt", "tests/linkify-it/fixtures/links.txt"),
    ("linkify-it/fixtures/not_links.txt", "tests/linkify-it/fixtures/not_links.txt"),
]


def usage() -> None:
    print(
        "usage: python3 scripts/check_fixture_sync.py [--require-reference]",
        file=sys.stderr,
    )


def main() -> int:
    require_reference = False
    if len(sys.argv) > 2:
        usage()
        return 2
    if len(sys.argv) == 2:
        if sys.argv[1] != "--require-reference":
            usage()
            return 2
        require_reference = True

    if not REFERENCE_ROOT.is_dir():
        message = (
            "Skipping fixture sync check because reference checkout is absent: "
            f"{REFERENCE_ROOT}"
        )
        if require_reference:
            print(message, file=sys.stderr)
            return 1
        print(message)
        return 0

    ok = True
    for local_rel, reference_rel in FIXTURE_PAIRS:
        local_path = VENDORED_ROOT / local_rel
        reference_path = REFERENCE_ROOT / reference_rel
        if not local_path.is_file():
            print(f"missing vendored fixture: {local_path}", file=sys.stderr)
            ok = False
            continue
        if not reference_path.is_file():
            print(f"missing reference fixture: {reference_path}", file=sys.stderr)
            ok = False
            continue
        if local_path.read_bytes() != reference_path.read_bytes():
            print(
                f"vendored fixture differs from reference: {local_rel}",
                file=sys.stderr,
            )
            ok = False

    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
