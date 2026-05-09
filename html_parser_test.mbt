///|
test "builder serializes compact HTML" {
  let node = @html_parser.element("p", attrs={ "class": Some("intro") }, children=[
    @html_parser.text("Hello "),
    @html_parser.element("b", children=[@html_parser.text("MoonBit")]),
  ])
  assert_eq(
    node.to_html(pretty=false),
    "<p class=\"intro\">Hello <b>MoonBit</b></p>",
  )
}

///|
test "parser handles nested tags attributes comments and doctype" {
  let doc = @html_parser.parse(
    "<!doctype html><p id='x' class=\"intro lead\">Hi &amp; bye<!--ok--></p>",
    collect_errors=true,
  )
  assert_eq(
    doc.to_html(pretty=false),
    "<!DOCTYPE html><p id=\"x\" class=\"intro lead\">Hi &amp; bye<!--ok--></p>",
  )
  assert_eq(doc.errors.length(), 0)
  assert_eq(doc.to_text(separator="", strip=false), "Hi & bye")
}

///|
test "parser cursor advances by unicode character length" {
  let doc = @html_parser.parse_fragment("<p>😀 &lt; ok</p>")
  assert_eq(doc.to_html(pretty=false), "<p>😀 &lt; ok</p>")
  assert_eq(doc.to_text(separator="", strip=false), "😀 < ok")
}

///|
test "query supports tag class id and tag class selectors" {
  let doc = @html_parser.parse_fragment(
    "<div><p id='first' class='intro lead'>One</p><p>Two</p></div>",
  )
  assert_eq(doc.query("p").length(), 2)
  assert_eq(doc.query(".intro").length(), 1)
  assert_eq(doc.query("#first").length(), 1)
  let first = doc.query_one("p.lead")
  guard first is Some(node) else { fail("expected p.lead") }
  assert_eq(node.to_text(separator="", strip=false), "One")
}

///|
test "collect_errors records malformed markup without raising" {
  let doc = @html_parser.parse_fragment("<p>open</span>", collect_errors=true)
  assert_eq(doc.errors.length(), 1)
  assert_eq(doc.errors[0].code, "unexpected-end-tag")
  assert_eq(doc.to_html(pretty=false), "<p>open</p>")
}

///|
test "strict mode raises on first parse error" {
  let result : Result[@html_parser.ParsedHtml, Error] = try? @html_parser.parse_fragment(
    "<p>open</span>",
    strict=true,
  )
  guard result is Err(_) else { fail("expected strict parse to raise") }
}

///|
test "parse_bytes decodes utf8 and records encoding" {
  let bytes = @utf8.encode("<p>bytes</p>")
  let doc = @html_parser.parse_bytes(bytes)
  assert_eq(doc.to_html(pretty=false), "<p>bytes</p>")
  guard doc.encoding is Some("utf-8") else { fail("expected utf-8 encoding") }
}

///|
test "tokenize exposes stable token data structures" {
  let result = @html_parser.tokenize("<p class='x'>Hi<br><!--ok--></p>")
  assert_eq(result.tokens.length(), 6)
  guard result.tokens[0] is @html_parser.HtmlToken::Tag(start) else {
    fail("expected start tag")
  }
  assert_true(start.kind is @html_parser.TagKind::StartTag)
  assert_eq(start.name, "p")
  guard start.attrs["class"] is Some("x") else { fail("expected class attr") }
  guard result.tokens[1] is @html_parser.HtmlToken::Characters("Hi") else {
    fail("expected text token")
  }
  guard result.tokens[2] is @html_parser.HtmlToken::Tag(br) else {
    fail("expected br tag")
  }
  assert_eq(br.self_closing, false)
  guard result.tokens[3] is @html_parser.HtmlToken::CommentToken("ok") else {
    fail("expected comment token")
  }
  guard result.tokens[5] is @html_parser.HtmlToken::Eof else {
    fail("expected EOF")
  }
  let explicit = @html_parser.tokenize("<img/>")
  guard explicit.tokens[0] is @html_parser.HtmlToken::Tag(img) else {
    fail("expected img tag")
  }
  assert_eq(img.self_closing, true)
}

///|
test "entity decoding covers upstream fixture cases" {
  let numeric = @html_parser.parse_fragment("&#65")
  assert_eq(numeric.to_text(separator="", strip=false), "A")
  let control = @html_parser.parse_fragment("&#x80")
  assert_eq(control.to_text(separator="", strip=false), "\u{20AC}")
  let legacy = @html_parser.parse_fragment("&notit; &not &amp")
  assert_eq(legacy.to_text(separator="", strip=false), "¬it; ¬ &")
}

///|
test "tokenize preserves raw end tags before tree recovery" {
  let result = @html_parser.tokenize("<p>open</span>")
  assert_eq(result.tokens.length(), 4)
  guard result.tokens[0] is @html_parser.HtmlToken::Tag(start) else {
    fail("expected p start tag")
  }
  assert_true(start.kind is @html_parser.TagKind::StartTag)
  assert_eq(start.name, "p")
  guard result.tokens[2] is @html_parser.HtmlToken::Tag(end_tag) else {
    fail("expected raw span end tag")
  }
  assert_true(end_tag.kind is @html_parser.TagKind::EndTag)
  assert_eq(end_tag.name, "span")
}

///|
test "tokenize reports malformed end tag errors when requested" {
  let result = @html_parser.tokenize("</>", collect_errors=true)
  assert_eq(result.tokens.length(), 1)
  assert_eq(result.errors.length(), 1)
  assert_eq(result.errors[0].code, "missing-end-tag-name")
}
