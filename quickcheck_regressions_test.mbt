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

///|
test "regression: escaped markup has invisible Unicode stripped like other text" {
  // Found by "any policy's output conforms to that policy, before and after a
  // reparse". With `Escape` handling, the text the sanitizer makes from a
  // disallowed tag, and the source of a tag cut off by end of input, skipped
  // the `strip_invisible_unicode` pass every other text node gets, so bidi
  // overrides and zero-width characters survived a policy that removes them.
  let policy = @html_parser.SanitizationPolicy(
    ["p"],
    disallowed_tag_handling=Escape,
  )
  let escaped_tag = @html_parser.parse_fragment(
    "<p>a<x title=\"\u{202E}evil\">b\u{200B}c</x></p>",
  )
  let clean = @html_parser.sanitize_dom(escaped_tag.root, policy~)
  assert_eq(
    @html_parser.to_html(clean, pretty=false),
    "<p>a&lt;x title=\"evil\"&gt;bc&lt;/x&gt;</p>",
  )
  let cut_off = @html_parser.parse_fragment("<p>a</p><x title=\"\u{202E}")
  let clean = @html_parser.sanitize_dom(cut_off.root, policy~)
  assert_eq(@html_parser.to_html(clean, pretty=false), "<p>a</p>&lt;x title=\"")
  // Turning stripping off keeps them, as before.
  let keep = @html_parser.SanitizationPolicy(
    ["p"],
    disallowed_tag_handling=Escape,
    strip_invisible_unicode=false,
  )
  let cut_off = @html_parser.parse_fragment("<x title=\"\u{202E}")
  let clean = @html_parser.sanitize_dom(cut_off.root, policy=keep)
  assert_eq(@html_parser.to_html(clean, pretty=false), "&lt;x title=\"\u{202E}")
}

///|
test "regression: an nth-child argument past the range of Int matches nothing" {
  // Found by "nth-child agrees with the an+b formula". The argument was parsed
  // into an `Int` without a bound, so 2^32 + 1 wrapped around to 1 and
  // selected the first item. Browsers match nothing for these.
  let root = @html_parser.parse_fragment(
      "<ul><li>1</li><li>2</li><li>3</li></ul>",
    ).root
  for
    selector in [
      "li:nth-child(4294967297)", "li:nth-child(2n+4294967297)", "li:nth-child(4294967296n+1)",
      "li:nth-child(-4294967299n+99999999999)", "li:nth-of-type(4294967298)",
    ] {
    assert_eq(@html_parser.query(root, selector).length(), 0)
  }
  // In-range arguments are unchanged, including a large negative offset,
  // which used to overflow `index - b`.
  let texts = (selector : String) => {
    @html_parser.query(root, selector).map(node => node.text())
  }
  assert_eq(texts("li:nth-child(2)"), ["2"])
  assert_eq(texts("li:nth-child(n-2147483647)"), ["1", "2", "3"])
  assert_eq(texts("li:nth-child(-n+2147483647)"), ["1", "2", "3"])
  // -2147483648 is still an `Int`; 2147483648 is not
  assert_eq(texts("li:nth-child(-2147483648n+1)"), ["1"])
  assert_eq(texts("li:nth-child(n-2147483648)"), ["1", "2", "3"])
  assert_eq(texts("li:nth-child(2147483647n+2)"), ["2"])
  assert_eq(texts("li:nth-child(2147483648n+1)"), [])
  assert_eq(texts("li:nth-child(n+2147483648)"), [])
  assert_eq(texts("li:nth-child(n-2147483649)"), [])
}

///|
test "regression: a link port past the range of Int is rejected" {
  // Found by "linkify accepts exactly the valid port numbers". 2^32 + 80
  // wrapped around to port 80 and was linkified.
  assert_eq(
    @html_parser.find_links("see http://example.com:4294967376/x now").length(),
    0,
  )
  assert_eq(
    @html_parser.find_links("see http://example.com:65535/x now").length(),
    1,
  )
}
