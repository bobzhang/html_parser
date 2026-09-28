///|
/// Regression tests for counterexamples found by the QuickCheck properties in
/// `quickcheck_fuzz_test.mbt` and `quickcheck_sanitizer_test.mbt`.

///|
test "regression: an overlong numeric character reference does not wrap around" {
  // Found by "numeric character references decode per the spec model". The
  // digits were accumulated in an `Int` without a bound, so a long enough
  // reference overflowed and wrapped to an arbitrary valid code point instead
  // of decoding to U+FFFD: 2^32 + 60 came back as `<`.
  for
    source in [
      "&#127753802364682;", "&#4294967356;", "&#x10000003C;", "&#99999999999999999999;",
      "&#x7FFFFFFFFFFFFFFFFFFF;",
    ] {
    assert_eq(
      @html_parser.parse_fragment("a\{source}b").root.text(),
      "a\u{FFFD}b",
    )
    guard @html_parser.parse_fragment("<p title=\"\{source}\">").root.children()
      is [p, ..] else {
      fail("expected a paragraph")
    }
    assert_eq(p.attrs().get("title"), Some(Some("\u{FFFD}")))
    guard @html_parser.tokenize(source).tokens is [Characters(text), ..] else {
      fail("expected a character token")
    }
    assert_eq(text, "\u{FFFD}")
  }
  // The last code point and the first value past it still decode as before.
  assert_eq(
    @html_parser.parse_fragment("&#x10FFFF;&#x110000;").root.text(),
    "\u{10FFFF}\u{FFFD}",
  )
}

///|
/// Return the text of the first `script` element `html` parses to.
fn script_text_of(html : String) -> String raise {
  guard @html_parser.parse(html).query_one("script") is Some(script) else {
    fail("expected a script element")
  }
  script.text()
}

///|
test "regression: a less-than sign after an escaped dash dash is kept once" {
  // Found by "reserializing arbitrary markup settles after one reparse" from
  // `<script><!--a-><!--<--!>`, which gained a `<` on every round trip. In the
  // script data escaped dash dash state the scanner emitted the `<` and then
  // the less-than sign state emitted it again. The expected values match
  // browsers (`DOMParser` in Chromium).
  assert_eq(script_text_of("<script><!--a--<b</script>"), "<!--a--<b")
  assert_eq(script_text_of("<script><!--<!--<x</script>"), "<!--<!--<x")
  assert_eq(script_text_of("<script><!--a--<"), "<!--a--<")
  // The same doubled `<` used to be left in front of the end tag that closes
  // the script.
  let doc = @html_parser.parse_fragment("<script><!--a--</script>x")
  assert_eq(doc.to_html(pretty=false), "<script><!--a--</script>x")
}

///|
test "regression: a comment opener closed at once returns to script data" {
  // `<!--` in script data ends in the escaped *dash dash* state, so `<!-->`
  // is closed immediately and a following `<script>` is plain text, not the
  // start of a double escape that swallows the next `</script>`. Found while
  // minimizing the counterexample above; expected values match browsers.
  let doc = @html_parser.parse("<script><!--><script></script>x</script>y")
  assert_eq(
    script_text_of("<script><!--><script></script>x</script>y"),
    "<!--><script>",
  )
  assert_eq(doc.to_text(separator="", strip=false), "<!--><script>xy")
}

///|
test "regression: a letter after a double-escaped less-than sign stays double escaped" {
  // In the script data double escaped less-than sign state anything but `/`
  // is reconsumed as double-escaped data. The scanner started a new double
  // escape on a letter instead, which fell back to the escaped state, so the
  // next `</script>` ended the script early and the rest leaked into the page.
  // Found while reviewing the scanner's pinned cases against browsers.
  assert_eq(
    script_text_of("<script><!--<script><x</script>z</script>"),
    "<!--<script><x</script>z",
  )
  assert_eq(
    script_text_of("<script><!--<script>--<x</script>tail</script>"),
    "<!--<script>--<x</script>tail",
  )
  let doc = @html_parser.parse("<script><!--<script><x</script>z</script>after")
  assert_eq(doc.root.text(), "<!--<script><x</script>zafter")
}
