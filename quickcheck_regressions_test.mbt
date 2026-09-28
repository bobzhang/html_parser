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
