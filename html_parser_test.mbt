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
    "<!DOCTYPE html><html><head></head><body><p id=\"x\" class=\"intro lead\">Hi &amp; bye<!--ok--></p></body></html>",
  )
  assert_eq(doc.errors.length(), 0)
  assert_eq(doc.to_text(separator="", strip=false), "Hi & bye")
}

///|
test "parser and tokenizer preserve doctype external ids" {
  let source = "<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01//EN\" \"http://www.w3.org/TR/html4/strict.dtd\">"
  let doc = @html_parser.parse(source)
  assert_eq(
    doc.to_html(pretty=false),
    "<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01//EN\" \"http://www.w3.org/TR/html4/strict.dtd\"><html><head></head><body></body></html>",
  )
  let tokens = @html_parser.tokenize(source)
  guard tokens.tokens[0] is @html_parser.HtmlToken::DoctypeToken(info) else {
    fail("expected doctype token")
  }
  assert_eq(info.name, "html")
  guard info.public_id is Some("-//W3C//DTD HTML 4.01//EN") else {
    fail("expected public id")
  }
  guard info.system_id is Some("http://www.w3.org/TR/html4/strict.dtd") else {
    fail("expected system id")
  }
  let system = @html_parser.tokenize(
    "<!DOCTYPE html SYSTEM \"about:legacy-compat\">",
  )
  guard system.tokens[0] is @html_parser.HtmlToken::DoctypeToken(system_info) else {
    fail("expected system doctype")
  }
  guard system_info.public_id is None else { fail("expected no public id") }
  guard system_info.system_id is Some("about:legacy-compat") else {
    fail("expected system id")
  }
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
  assert_eq(
    doc.to_html(pretty=false),
    "<html><head></head><body><p>bytes</p></body></html>",
  )
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

///|
test "tokenize handles selected bogus comment fixture cases" {
  let processing = @html_parser.tokenize("<?foo>")
  guard processing.tokens[0] is @html_parser.HtmlToken::CommentToken("?foo") else {
    fail("expected bogus comment")
  }
  let invalid_end = @html_parser.tokenize("</?", collect_errors=true)
  guard invalid_end.tokens[0] is @html_parser.HtmlToken::CommentToken("?") else {
    fail("expected invalid end tag as bogus comment")
  }
  assert_eq(invalid_end.errors.length(), 1)
  assert_eq(invalid_end.errors[0].code, "invalid-first-character-of-tag-name")
}

///|
test "tokenize reports selected EOF and null fixture errors" {
  let lt = @html_parser.tokenize("<", collect_errors=true)
  guard lt.tokens[0] is @html_parser.HtmlToken::Characters("<") else {
    fail("expected literal <")
  }
  assert_eq(lt.errors[0].code, "eof-before-tag-name")
  guard lt.errors[0].column is Some(2) else {
    fail("expected EOF after < at column 2")
  }
  let end_open = @html_parser.tokenize("</", collect_errors=true)
  guard end_open.tokens[0] is @html_parser.HtmlToken::Characters("</") else {
    fail("expected literal </")
  }
  assert_eq(end_open.errors[0].code, "eof-before-tag-name")
  guard end_open.errors[0].column is Some(3) else {
    fail("expected EOF after </ at column 3")
  }
  let nul_text = @html_parser.tokenize("a\u{0000}b", collect_errors=true)
  guard nul_text.tokens[0] is @html_parser.HtmlToken::Characters("a\u{0000}b") else {
    fail("expected null-preserving text")
  }
  assert_eq(nul_text.errors[0].code, "unexpected-null-character")
  guard nul_text.errors[0].column is Some(2) else {
    fail("expected null text at column 2")
  }
  let nul_attr = @html_parser.tokenize(
    "<div foo=\"a\u{0000}b\">",
    collect_errors=true,
  )
  guard nul_attr.tokens[0] is @html_parser.HtmlToken::Tag(tag) else {
    fail("expected div tag")
  }
  guard tag.attrs["foo"] is Some("a\u{FFFD}b") else {
    fail("expected replacement char in attr")
  }
  assert_eq(nul_attr.errors[0].code, "unexpected-null-character")
}

///|
test "tokenize reports missing attribute value fixture errors" {
  let simple = @html_parser.tokenize("<div attr>", collect_errors=true)
  guard simple.tokens[0] is @html_parser.HtmlToken::Tag(tag) else {
    fail("expected div tag")
  }
  guard tag.attrs["attr"] is Some("") else { fail("expected empty attr value") }
  assert_eq(simple.errors[0].code, "missing-attribute-value")
  guard simple.errors[0].column is Some(10) else {
    fail("expected missing value at column 10")
  }
  let crlf = @html_parser.tokenize("<div attr\r\n>", collect_errors=true)
  assert_eq(crlf.errors[0].code, "missing-attribute-value")
  guard crlf.errors[0].line is Some(2) else {
    fail("expected CRLF normalized line")
  }
  guard crlf.errors[0].column is Some(1) else {
    fail("expected CRLF normalized column")
  }
}

///|
test "tokenize reports attribute name fixture errors" {
  let equals = @html_parser.tokenize("<div\r=abc>", collect_errors=true)
  guard equals.tokens[0] is @html_parser.HtmlToken::Tag(eq_tag) else {
    fail("expected div tag")
  }
  guard eq_tag.attrs["=abc"] is Some("") else { fail("expected =abc attr") }
  assert_eq(equals.errors.length(), 2)
  assert_eq(
    equals.errors[0].code,
    "unexpected-equals-sign-before-attribute-name",
  )
  guard equals.errors[0].line is Some(2) else {
    fail("expected equals error on line 2")
  }
  guard equals.errors[0].column is Some(1) else {
    fail("expected equals error at column 1")
  }
  assert_eq(equals.errors[1].code, "missing-attribute-value")
  let invalid_char = @html_parser.tokenize("<div a<b>", collect_errors=true)
  guard invalid_char.tokens[0] is @html_parser.HtmlToken::Tag(bad_tag) else {
    fail("expected div tag")
  }
  guard bad_tag.attrs["a<b"] is Some("") else { fail("expected a<b attr") }
  assert_eq(invalid_char.errors.length(), 2)
  assert_eq(
    invalid_char.errors[0].code,
    "unexpected-character-in-attribute-name",
  )
  guard invalid_char.errors[0].column is Some(7) else {
    fail("expected bad attr char at column 7")
  }
  assert_eq(invalid_char.errors[1].code, "missing-attribute-value")
}

///|
test "tokenize recovers invalid self closing start tag fixture case" {
  let result = @html_parser.tokenize("<div /a>", collect_errors=true)
  guard result.tokens[0] is @html_parser.HtmlToken::Tag(tag) else {
    fail("expected div tag")
  }
  assert_eq(tag.name, "div")
  assert_eq(tag.self_closing, false)
  guard tag.attrs["a"] is Some("") else { fail("expected recovered a attr") }
  assert_eq(result.errors.length(), 2)
  assert_eq(
    result.errors[0].code,
    "unexpected-character-in-self-closing-start-tag",
  )
  guard result.errors[0].column is Some(7) else {
    fail("expected invalid self closing char at column 7")
  }
  assert_eq(result.errors[1].code, "missing-attribute-value")
  guard result.errors[1].column is Some(8) else {
    fail("expected missing attr value at column 8")
  }
}

///|
test "tokenize normalizes BOM and CRLF edge cases" {
  let bom = @html_parser.tokenize("\u{FEFF}<div>")
  guard bom.tokens[0] is @html_parser.HtmlToken::Tag(tag) else {
    fail("expected div start tag")
  }
  assert_eq(tag.name, "div")
  let text = @html_parser.tokenize("abc\r\ndef\rghi")
  guard text.tokens[0] is @html_parser.HtmlToken::Characters(data) else {
    fail("expected character token")
  }
  assert_eq(data, "abc\ndef\nghi")
  let comment = @html_parser.tokenize("<!-- a\rb -->")
  guard comment.tokens[0] is @html_parser.HtmlToken::CommentToken(data) else {
    fail("expected comment")
  }
  assert_eq(data, " a\nb ")
  let attr = @html_parser.tokenize("<div title=\"a\rb\">")
  guard attr.tokens[0] is @html_parser.HtmlToken::Tag(attr_tag) else {
    fail("expected attr tag")
  }
  guard attr_tag.attrs["title"] is Some("a\nb") else {
    fail("expected normalized attr")
  }
}

///|
test "parser normalizes leading BOM and CRLF in text comment and attr" {
  let doc = @html_parser.parse_fragment(
    "\u{FEFF}<p title='a\rb'>a\r\nb<!--x\ry--></p>",
  )
  assert_eq(doc.to_html(pretty=false), "<p title=\"a\nb\">a\nb<!--x\ny--></p>")
  assert_eq(doc.to_text(separator="", strip=false), "a\nb")
}

///|
test "parser treats script style title textarea content as text" {
  let doc = @html_parser.parse_fragment(
    "<script><!--a--<b</script><title>a &lt; b</title>",
  )
  assert_eq(
    doc.to_html(pretty=false),
    "<script><!--a--<b</script><title>a &lt; b</title>",
  )
  assert_eq(doc.query("b").length(), 0)
  assert_eq(doc.to_text(separator="|", strip=false), "<!--a--<b|a < b")
}

///|
test "tokenize preserves rawtext and rcdata element contents" {
  let script = @html_parser.tokenize("<script><!--a--<b</script>")
  assert_eq(script.tokens.length(), 4)
  guard script.tokens[1] is @html_parser.HtmlToken::Characters("<!--a--<b") else {
    fail("expected raw script text")
  }
  guard script.tokens[2] is @html_parser.HtmlToken::Tag(end_script) else {
    fail("expected script end")
  }
  assert_true(end_script.kind is @html_parser.TagKind::EndTag)
  assert_eq(end_script.name, "script")
  let textarea = @html_parser.tokenize("<textarea>a &lt; b</textarea>")
  guard textarea.tokens[1] is @html_parser.HtmlToken::Characters("a < b") else {
    fail("expected decoded textarea text")
  }
}
