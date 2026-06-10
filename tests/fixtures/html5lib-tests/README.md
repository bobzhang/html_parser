# Vendored html5lib-tests fixtures

This directory vendors the `tree-construction` corpus from the official
[html5lib-tests](https://github.com/html5lib/html5lib-tests) repository, the
de-facto HTML5 parsing conformance suite shared across browser engines and
parser implementations.

- Upstream repository: https://github.com/html5lib/html5lib-tests
- Vendored commit: `9fb614afaa42ce8787840f057b32084308e76549`
- Vendored subset: `tree-construction/` (verbatim copy, including
  `scripted/`) plus the upstream `LICENSE` (MIT).

## Running the suite

```sh
moon run --target native cmd/html5lib_conformance
```

The runner walks every `.dat` file, parses each case with the public
`@html_parser.parse` / `@html_parser.parse_fragment` API, and compares the
tree against the expected output (tree comparison only, mirroring the
JustHTML reference harness). `#script-on` cases that embed a `<script>` tag
are skipped because scripts never execute.

## Expected failures

`expected-failures.txt` lists the cases that currently fail, one
`file.dat:case-index` per line. CI runs the suite via
`scripts/check_ci.mbtx check-html5lib-conformance` and fails on drift in
either direction:

- a case fails that is not in the manifest (regression), or
- a case in the manifest now passes (stale entry — remove it so the
  conformance score can only ratchet upward).

After a parser change, regenerate the manifest with:

```sh
moon run --target native cmd/html5lib_conformance -- --update-expected
```

and review the diff: removed lines are conformance wins, added lines are
regressions that need justification.

## Refreshing the corpus

```sh
git clone https://github.com/html5lib/html5lib-tests.git /tmp/html5lib-tests
rm -rf tests/fixtures/html5lib-tests/tree-construction
cp -R /tmp/html5lib-tests/tree-construction tests/fixtures/html5lib-tests/tree-construction
cp /tmp/html5lib-tests/LICENSE tests/fixtures/html5lib-tests/LICENSE
```

Then update the pinned commit above, regenerate `expected-failures.txt`, and
refresh the fixture manifest entries in `scripts/check_ci.mbtx` (the
`check-fixture-manifest` step prints any mismatching size/sha256).
