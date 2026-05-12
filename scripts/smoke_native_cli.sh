#!/usr/bin/env bash
set -euo pipefail

moon run --target native --release --build-only cmd/main

cli="_build/native/release/build/cmd/main/main.exe"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

printf '<article><p>Hi <b>there</b></p><p>Bye</p></article>' \
  | "$cli" - --selector p --format text > "$tmpdir/text.txt"
diff -u <(printf 'Hi there\nBye\n') "$tmpdir/text.txt"

set +e
printf '<p>Hello</p>' \
  | "$cli" - --selector '.does-not-exist' > "$tmpdir/empty.txt"
code=$?
set -e
test "$code" -eq 1
test ! -s "$tmpdir/empty.txt"

"$cli" tests/fixtures/justhtml/data/wikipedia.html \
  --format markdown > "$tmpdir/wikipedia.md"

first_line="$(grep -m1 -v '^[[:space:]]*$' "$tmpdir/wikipedia.md")"
case "$first_line" in
  \<img*) ;;
  *)
    echo "Expected Wikipedia Markdown to start with body image, got: $first_line" >&2
    exit 1
    ;;
esac

grep -F 'The Free Encyclopedia' "$tmpdir/wikipedia.md"
grep -F '(https://en.wikipedia.org/)' "$tmpdir/wikipedia.md"
grep -F '[Wikiquote Free quote compendium](https://www.wikiquote.org/)' "$tmpdir/wikipedia.md"
grep -F '[MediaWiki Free &amp; open wiki software](https://www.mediawiki.org/)' "$tmpdir/wikipedia.md"
grep -F '[Wikisource Free content library](https://www.wikisource.org/)' "$tmpdir/wikipedia.md"
grep -F '[Wikispecies Free species directory](https://species.wikimedia.org/)' "$tmpdir/wikipedia.md"
grep -F '[Wikifunctions Free function library](https://www.wikifunctions.org/)' "$tmpdir/wikipedia.md"
grep -F '[Meta-Wiki Community coordination &amp; documentation](https://meta.wikimedia.org/)' "$tmpdir/wikipedia.md"
