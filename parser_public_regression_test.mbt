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
test "parser cursor advances by unicode character length" {
  let doc = @html_parser.parse_fragment("<p>😀 &lt; ok</p>")
  assert_eq(doc.to_html(pretty=false), "<p>😀 &lt; ok</p>")
  assert_eq(doc.to_text(separator="", strip=false), "😀 < ok")
}

///|
test "parser closes current heading before another heading start" {
  let fragment = @html_parser.parse_fragment("<p>intro<h1>head<h2>next")
  assert_eq(
    fragment.to_html(pretty=false),
    "<p>intro</p><h1>head</h1><h2>next</h2>",
  )
  let nested_block = @html_parser.parse_fragment("<h1>head<div>body</div>")
  assert_eq(nested_block.to_html(pretty=false), "<h1>head<div>body</div></h1>")
}

///|
test "parser ignores self closing slash on non void html elements" {
  let div = @html_parser.parse_fragment("<div/>x")
  assert_eq(div.to_html(pretty=false), "<div>x</div>")
  let paragraph = @html_parser.parse_fragment("<p/>x")
  assert_eq(paragraph.to_html(pretty=false), "<p>x</p>")
  let script = @html_parser.parse_fragment("<script/>x</script>")
  assert_eq(script.to_html(pretty=false), "<script>x</script>")
  let voids = @html_parser.parse_fragment("<br/>x<img/>")
  assert_eq(voids.to_html(pretty=false), "<br>x<img>")
}

///|
test "parser closes open paragraphs before paragraph and block starts" {
  let fragment = @html_parser.parse_fragment("<p>one<p>two<div>three</div>")
  assert_eq(
    fragment.to_html(pretty=false),
    "<p>one</p><p>two</p><div>three</div>",
  )
  let doc = @html_parser.parse("<p>one<div>two</div>")
  assert_eq(
    doc.to_html(pretty=false),
    "<html><head></head><body><p>one</p><div>two</div></body></html>",
  )
}

///|
test "parser tracks simple element and text origins when requested" {
  let doc = @html_parser.parse_fragment("<p>hi</p>", track_node_locations=true)
  guard doc.query_one("p") is Some(paragraph) else {
    fail("expected parsed paragraph")
  }
  assert_node_origin(paragraph, 0, 1, 1)
  let children = paragraph.children()
  assert_eq(children.length(), 1)
  assert_eq(children[0].data(), "hi")
  assert_node_origin(children[0], 3, 1, 4)
  let multiline = @html_parser.parse_fragment(
    "lead\n<p>x</p>",
    track_node_locations=true,
  )
  guard multiline.query_one("p") is Some(multiline_p) else {
    fail("expected multiline paragraph")
  }
  assert_node_origin(multiline_p, 5, 2, 1)
  let multiline_children = multiline_p.children()
  assert_eq(multiline_children.length(), 1)
  assert_node_origin(multiline_children[0], 8, 2, 4)
}

///|
test "parser tracks comment and doctype origins when requested" {
  let fragment = @html_parser.parse_fragment(
    "<!--x--><p><!--y--></p>",
    track_node_locations=true,
  )
  let root_children = fragment.root.children()
  assert_eq(root_children.length(), 2)
  assert_true(root_children[0].kind() is Comment)
  assert_node_origin(root_children[0], 0, 1, 1)
  guard fragment.query_one("p") is Some(paragraph) else {
    fail("expected parsed paragraph")
  }
  assert_node_origin(paragraph, 8, 1, 9)
  let paragraph_children = paragraph.children()
  assert_eq(paragraph_children.length(), 1)
  assert_true(paragraph_children[0].kind() is Comment)
  assert_node_origin(paragraph_children[0], 11, 1, 12)
  let doc = @html_parser.parse(
    "<!doctype html><p>x</p>",
    track_node_locations=true,
  )
  let doc_children = doc.root.children()
  assert_true(doc_children[0].kind() is Doctype)
  assert_node_origin(doc_children[0], 0, 1, 1)
}

///|
test "parse_bytes forwards node origin tracking" {
  let doc = @html_parser.parse_bytes(b"<p>x</p>", track_node_locations=true)
  guard doc.query_one("p") is Some(paragraph) else {
    fail("expected parsed paragraph")
  }
  assert_node_origin(paragraph, 0, 1, 1)
  let children = paragraph.children()
  assert_eq(children.length(), 1)
  assert_node_origin(children[0], 3, 1, 4)
}

///|
test "public parser source locations and scripting mode stay stable" {
  let located = @html_parser.parse_fragment(
    "lead\n<p id=x>Hi</p>",
    track_node_locations=true,
  )
  guard located.query_one("p") is Some(paragraph) else {
    fail("expected parsed paragraph")
  }
  guard paragraph.origin_offset() is Some(5) else {
    fail("expected paragraph origin offset")
  }
  guard paragraph.origin_line() is Some(2) else {
    fail("expected paragraph origin line")
  }
  guard paragraph.origin_col() is Some(1) else {
    fail("expected paragraph origin column")
  }
  let children = paragraph.children()
  assert_eq(children.length(), 1)
  guard children[0].origin_location() is Some((2, 9)) else {
    fail("expected text child origin location")
  }

  let enabled = @html_parser.parse_fragment(
    "<noscript><b>Hi</b></noscript>",
    scripting_enabled=true,
  )
  assert_eq(
    enabled.to_html(pretty=false),
    "<noscript>&lt;b&gt;Hi&lt;/b&gt;</noscript>",
  )
  assert_eq(enabled.query("b").length(), 0)
  let disabled = @html_parser.parse_fragment(
    "<noscript><b>Hi</b></noscript>",
    scripting_enabled=false,
  )
  assert_eq(disabled.to_html(pretty=false), "<noscript><b>Hi</b></noscript>")
  assert_eq(disabled.query("b").length(), 1)
}

///|
test "parser honors scripting enabled for noscript text mode" {
  let enabled = @html_parser.parse_fragment(
    "<noscript><b>Hi</b></noscript>",
    scripting_enabled=true,
  )
  assert_eq(
    enabled.to_html(pretty=false),
    "<noscript>&lt;b&gt;Hi&lt;/b&gt;</noscript>",
  )
  assert_eq(enabled.query("b").length(), 0)
  let disabled = @html_parser.parse_fragment(
    "<noscript><b>Hi</b></noscript>",
    scripting_enabled=false,
  )
  assert_eq(disabled.to_html(pretty=false), "<noscript><b>Hi</b></noscript>")
  assert_eq(disabled.query("b").length(), 1)
}

///|
test "parser handles disabled scripting noscript in head" {
  let doctype = @html_parser.parse(
    "<head><noscript><!DOCTYPE html></noscript>",
    collect_errors=true,
    scripting_enabled=false,
  )
  assert_eq(
    doctype.to_html(pretty=false),
    "<html><head><noscript></noscript></head><body></body></html>",
  )
  assert_eq(doctype.errors.length(), 2)
  assert_eq(doctype.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(doctype.errors[1].code, "unexpected-doctype")
  let stray_end = @html_parser.parse(
    "<head><noscript></p></noscript>",
    collect_errors=true,
    scripting_enabled=false,
  )
  assert_eq(
    stray_end.to_html(pretty=false),
    "<html><head><noscript></noscript></head><body></body></html>",
  )
  assert_eq(stray_end.errors.length(), 2)
  assert_eq(stray_end.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(stray_end.errors[1].code, "unexpected-end-tag")
  let stray_head = @html_parser.parse(
    "<head><noscript><head></noscript>",
    collect_errors=true,
    scripting_enabled=false,
  )
  assert_eq(
    stray_head.to_html(pretty=false),
    "<html><head><noscript></noscript></head><body></body></html>",
  )
  assert_eq(stray_head.errors.length(), 2)
  assert_eq(stray_head.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(stray_head.errors[1].code, "unexpected-start-tag")
  let stray_br = @html_parser.parse(
    "<head><noscript></br>x",
    collect_errors=true,
    scripting_enabled=false,
  )
  assert_eq(
    stray_br.to_html(pretty=false),
    "<html><head><noscript></noscript></head><body><br>x</body></html>",
  )
  assert_eq(stray_br.errors.length(), 3)
  assert_eq(stray_br.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(stray_br.errors[1].code, "unexpected-end-tag")
  assert_eq(stray_br.errors[2].code, "unexpected-end-tag")
  let paragraph = @html_parser.parse(
    "<head><noscript><p>x</noscript>",
    collect_errors=true,
    scripting_enabled=false,
  )
  assert_eq(
    paragraph.to_html(pretty=false),
    "<html><head><noscript></noscript></head><body><p>x</p></body></html>",
  )
  assert_eq(paragraph.errors.length(), 3)
  assert_eq(paragraph.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(paragraph.errors[1].code, "unexpected-start-tag")
  assert_eq(paragraph.errors[2].code, "unexpected-end-tag")
  let text = @html_parser.parse(
    "<head><noscript>x</noscript>",
    collect_errors=true,
    scripting_enabled=false,
  )
  assert_eq(
    text.to_html(pretty=false),
    "<html><head><noscript></noscript></head><body>x</body></html>",
  )
  assert_eq(text.errors.length(), 3)
  assert_eq(text.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(text.errors[1].code, "unexpected-start-tag")
  assert_eq(text.errors[2].code, "unexpected-end-tag")
  let leading_space = @html_parser.parse(
    "<head><noscript> x</noscript>",
    collect_errors=true,
    scripting_enabled=false,
  )
  assert_eq(
    leading_space.to_html(pretty=false),
    "<html><head><noscript></noscript> </head><body>x</body></html>",
  )
  assert_eq(leading_space.errors.length(), 3)
  assert_eq(leading_space.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(leading_space.errors[1].code, "unexpected-start-tag")
  assert_eq(leading_space.errors[2].code, "unexpected-end-tag")
  let coerced_leading_space = @html_parser.parse(
    "<head><noscript>\u{000C} x</noscript>",
    collect_errors=true,
    scripting_enabled=false,
    xml_coercion=true,
  )
  assert_eq(
    coerced_leading_space.to_html(pretty=false),
    "<html><head><noscript></noscript>  </head><body>x</body></html>",
  )
  assert_eq(coerced_leading_space.errors.length(), 3)
  assert_eq(
    coerced_leading_space.errors[0].code,
    "expected-doctype-but-got-start-tag",
  )
  assert_eq(coerced_leading_space.errors[1].code, "unexpected-start-tag")
  assert_eq(coerced_leading_space.errors[2].code, "unexpected-end-tag")
  let allowed = @html_parser.parse(
    "<head><noscript><link rel=x></noscript><p>y",
    collect_errors=true,
    scripting_enabled=false,
  )
  assert_eq(
    allowed.to_html(pretty=false),
    "<html><head><noscript><link rel=\"x\"></noscript></head><body><p>y</p></body></html>",
  )
  assert_eq(allowed.errors.length(), 1)
  assert_eq(allowed.errors[0].code, "expected-doctype-but-got-start-tag")
}

///|
test "parser matches end tags before self closing solidus" {
  let div = @html_parser.parse_fragment("<div>x</div/>y", collect_errors=true)
  assert_eq(div.to_html(pretty=false), "<div>x</div>y")
  assert_eq(div.errors.length(), 0)
  let script = @html_parser.tokenize("<script>x</script/>after")
  guard script.tokens[1] is Characters("x") else {
    fail("expected script text before slash end tag")
  }
  guard script.tokens[2] is Tag(end_script) else {
    fail("expected script end tag before slash")
  }
  assert_true(end_script.kind is EndTag)
  assert_eq(end_script.name, "script")
  assert_eq(end_script.self_closing, true)
  guard script.tokens[3] is Characters("after") else {
    fail("expected text after slash end tag")
  }
}

///|
test "parser recovers malformed ordinary end tags" {
  let solidus = @html_parser.parse_fragment(
    "<div>x</div/foo>y",
    collect_errors=true,
  )
  assert_eq(solidus.to_html(pretty=false), "<div>x</div>y")
  assert_eq(solidus.errors.length(), 1)
  assert_eq(solidus.errors[0].code, "unexpected-character-after-solidus-in-tag")
  guard solidus.errors[0].column is Some(13) else {
    fail("expected ordinary end-tag bad solidus at recovered attr")
  }
  let eof = @html_parser.parse_fragment("<div>x</div/foo", collect_errors=true)
  assert_eq(eof.to_html(pretty=false), "<div>x</div>")
  assert_eq(eof.errors.length(), 3)
  assert_eq(eof.errors[0].code, "unexpected-character-after-solidus-in-tag")
  assert_eq(eof.errors[1].code, "eof-in-tag")
  assert_eq(eof.errors[2].code, "expected-closing-tag-but-got-eof")
  guard eof.errors[1].column is Some(15) else {
    fail("expected EOF in malformed ordinary end tag at final name char")
  }
  guard eof.errors[2].column is Some(15) else {
    fail("expected tree EOF after malformed ordinary end tag")
  }
  let null_name = @html_parser.parse_fragment(
    "<div>x</d\u{0000}iv>y",
    collect_errors=true,
  )
  assert_eq(null_name.to_html(pretty=false), "<div>xy</div>")
  assert_eq(null_name.errors.length(), 3)
  assert_eq(null_name.errors[0].code, "unexpected-null-character")
  assert_eq(null_name.errors[1].code, "unexpected-end-tag")
  assert_eq(null_name.errors[2].code, "expected-closing-tag-but-got-eof")
  guard null_name.errors[0].column is Some(10) else {
    fail("expected null in ordinary end tag at column 10")
  }
  guard null_name.errors[1].column is Some(13) else {
    fail("expected mismatched null end tag at the tag close")
  }
  guard null_name.errors[2].column is Some(14) else {
    fail("expected EOF for still-open element after null end tag")
  }
}

///|
test "parser replaces nulls in bogus comment data" {
  let question = @html_parser.parse_fragment(
    "<?a\u{0000}b>",
    collect_errors=true,
  )
  assert_eq(question.to_html(pretty=false), "<!--?a\u{FFFD}b-->")
  assert_eq(question.errors.length(), 1)
  assert_eq(
    question.errors[0].code,
    "unexpected-question-mark-instead-of-tag-name",
  )
  let declaration = @html_parser.parse_fragment(
    "<!a\u{0000}b>",
    collect_errors=true,
  )
  assert_eq(declaration.to_html(pretty=false), "<!--a\u{FFFD}b-->")
  assert_eq(declaration.errors.length(), 1)
  assert_eq(declaration.errors[0].code, "incorrectly-opened-comment")
}

///|
test "parser reports abrupt closing of empty comments" {
  let simple = @html_parser.parse_fragment("<!-->", collect_errors=true)
  assert_eq(simple.to_html(pretty=false), "<!---->")
  assert_eq(simple.errors.length(), 1)
  assert_eq(simple.errors[0].code, "abrupt-closing-of-empty-comment")
  guard simple.errors[0].column is Some(5) else {
    fail("expected abrupt empty comment at >")
  }
  let dash = @html_parser.parse_fragment("<!--->", collect_errors=true)
  assert_eq(dash.to_html(pretty=false), "<!---->")
  assert_eq(dash.errors.length(), 1)
  assert_eq(dash.errors[0].code, "abrupt-closing-of-empty-comment")
  guard dash.errors[0].column is Some(6) else {
    fail("expected abrupt empty dash comment at >")
  }
}

///|
test "parser reports incorrectly closed comments" {
  let bang = @html_parser.parse_fragment("<!--x--!>", collect_errors=true)
  assert_eq(bang.to_html(pretty=false), "<!--x-->")
  assert_eq(bang.errors.length(), 1)
  assert_eq(bang.errors[0].code, "incorrectly-closed-comment")
  guard bang.errors[0].column is Some(9) else {
    fail("expected bang close error at >")
  }
  let text = @html_parser.parse_fragment("<!--x--y-->", collect_errors=true)
  assert_eq(text.to_html(pretty=false), "<!--x- -y-->")
  assert_eq(text.errors.length(), 1)
  assert_eq(text.errors[0].code, "incorrectly-closed-comment")
  guard text.errors[0].column is Some(8) else {
    fail("expected comment close error at reconsumed text")
  }
}

///|
test "parser reports missing attribute value after equals only" {
  let bare = @html_parser.parse_fragment("<div attr>", collect_errors=true)
  assert_eq(bare.to_html(pretty=false), "<div attr></div>")
  assert_eq(bare.errors.length(), 1)
  assert_eq(bare.errors[0].code, "expected-closing-tag-but-got-eof")
  let missing = @html_parser.parse_fragment("<div attr=>", collect_errors=true)
  assert_eq(missing.to_html(pretty=false), "<div attr></div>")
  assert_eq(missing.errors.length(), 2)
  assert_eq(missing.errors[0].code, "missing-attribute-value")
  assert_eq(missing.errors[1].code, "expected-closing-tag-but-got-eof")
  guard missing.errors[0].column is Some(11) else {
    fail("expected missing value at column 11")
  }
}

///|
test "parser keeps first duplicate attribute value" {
  let doc = @html_parser.parse_fragment(
    "<p id=first id=second class=a class=b>text</p>",
    collect_errors=true,
  )
  assert_eq(doc.to_html(pretty=false), "<p id=\"first\" class=\"a\">text</p>")
  assert_eq(doc.errors.length(), 2)
  assert_eq(doc.errors[0].code, "duplicate-attribute")
  assert_eq(doc.errors[1].code, "duplicate-attribute")
}

///|
test "parser reports attribute name fixture errors" {
  let equals = @html_parser.parse_fragment("<div =abc>", collect_errors=true)
  guard equals.query_one("div") is Some(eq_node) else { fail("expected div") }
  assert_true(eq_node.attrs().contains("=abc"))
  assert_eq(equals.errors.length(), 2)
  assert_eq(
    equals.errors[0].code,
    "unexpected-equals-sign-before-attribute-name",
  )
  assert_eq(equals.errors[1].code, "expected-closing-tag-but-got-eof")
  guard equals.errors[0].column is Some(6) else {
    fail("expected equals attr error at column 6")
  }
  let bad_char = @html_parser.parse_fragment("<div a\"b>", collect_errors=true)
  guard bad_char.query_one("div") is Some(bad_node) else {
    fail("expected div")
  }
  assert_true(bad_node.attrs().contains("a\"b"))
  assert_eq(bad_char.errors.length(), 2)
  assert_eq(bad_char.errors[0].code, "unexpected-character-in-attribute-name")
  assert_eq(bad_char.errors[1].code, "expected-closing-tag-but-got-eof")
  guard bad_char.errors[0].column is Some(7) else {
    fail("expected quote attr error at column 7")
  }
}

///|
test "parser reports unquoted attribute value fixture errors" {
  let less = @html_parser.parse_fragment("<div a=b<c>", collect_errors=true)
  assert_eq(less.to_html(pretty=false), "<div a=\"b&lt;c\"></div>")
  assert_eq(less.errors.length(), 2)
  assert_eq(
    less.errors[0].code,
    "unexpected-character-in-unquoted-attribute-value",
  )
  assert_eq(less.errors[1].code, "expected-closing-tag-but-got-eof")
  guard less.errors[0].column is Some(9) else {
    fail("expected unquoted attr value error at column 9")
  }
  let numeric = @html_parser.parse_fragment(
    "<p title=&#x80>x</p>",
    collect_errors=true,
  )
  assert_eq(numeric.to_html(pretty=false), "<p title=\"\u{20AC}\">x</p>")
  assert_eq(numeric.errors.length(), 2)
  assert_eq(
    numeric.errors[0].code,
    "missing-semicolon-after-character-reference",
  )
  assert_eq(numeric.errors[1].code, "control-character-reference")
  assert_eq(numeric.errors[0].category, "tokenizer")
  assert_eq(numeric.errors[1].category, "tokenizer")
  guard numeric.errors[0].column is Some(15) else {
    fail("expected unquoted attr entity error at tag close")
  }
  guard numeric.errors[1].column is Some(15) else {
    fail("expected unquoted attr control error at tag close")
  }
  guard numeric.query_one("p") is Some(paragraph) else {
    fail("expected parsed paragraph")
  }
  guard paragraph.attrs()["title"] is Some("\u{20AC}") else {
    fail("expected decoded unquoted attribute value")
  }
}

///|
test "parser reports missing whitespace after quoted attribute value" {
  let result = @html_parser.parse_fragment(
    "<div a=\"b\"c=d>",
    collect_errors=true,
  )
  assert_eq(result.to_html(pretty=false), "<div a=\"b\" c=\"d\"></div>")
  assert_eq(result.errors.length(), 2)
  assert_eq(result.errors[0].code, "missing-whitespace-between-attributes")
  assert_eq(result.errors[1].code, "expected-closing-tag-but-got-eof")
  guard result.errors[0].column is Some(11) else {
    fail("expected missing whitespace at adjacent attr name")
  }
}

///|
test "parser recovers invalid self closing start tag fixture case" {
  let fragment = @html_parser.parse_fragment("<div /a>", collect_errors=true)
  assert_eq(fragment.to_html(pretty=false), "<div a></div>")
  assert_eq(fragment.errors.length(), 2)
  assert_eq(
    fragment.errors[0].code,
    "unexpected-character-after-solidus-in-tag",
  )
  assert_eq(fragment.errors[1].code, "expected-closing-tag-but-got-eof")
}

///|
test "parser start tag solidus does not skip following whitespace" {
  let fragment = @html_parser.parse_fragment("<div/ >", collect_errors=true)
  assert_eq(fragment.to_html(pretty=false), "<div></div>")
  assert_eq(fragment.errors.length(), 2)
  assert_eq(
    fragment.errors[0].code,
    "unexpected-character-after-solidus-in-tag",
  )
  assert_eq(fragment.errors[1].code, "expected-closing-tag-but-got-eof")
  guard fragment.errors[0].column is Some(6) else {
    fail("expected parser whitespace after solidus at column 6")
  }
}

///|
test "parser reports CRLF comment EOF before missing doctype EOF" {
  let parsed_crlf_eof = @html_parser.parse("<!----!\r\n", collect_errors=true)
  assert_eq(parsed_crlf_eof.errors.length(), 2)
  assert_eq(parsed_crlf_eof.errors[0].code, "eof-in-comment")
  assert_eq(parsed_crlf_eof.errors[1].code, "expected-doctype-but-got-eof")
  guard parsed_crlf_eof.errors[0].column is Some(0) else {
    fail("expected parser comment EOF error at column 0")
  }
  guard parsed_crlf_eof.errors[1].column is Some(0) else {
    fail("expected parser doctype EOF error at column 0")
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
test "parser handles null characters in text attributes and text modes" {
  let text = @html_parser.parse_fragment("a\u{0000}b", collect_errors=true)
  assert_eq(text.to_html(pretty=false), "ab")
  assert_eq(text.to_text(separator="", strip=false), "ab")
  assert_eq(text.errors.length(), 1)
  assert_eq(text.errors[0].code, "unexpected-null-character")
  guard text.errors[0].column is Some(2) else {
    fail("expected text null at column 2")
  }
  let attr = @html_parser.parse_fragment(
    "<div title=\"a\u{0000}b\">x</div>",
    collect_errors=true,
  )
  assert_eq(attr.to_html(pretty=false), "<div title=\"a�b\">x</div>")
  assert_eq(attr.errors.length(), 1)
  assert_eq(attr.errors[0].code, "unexpected-null-character")
  let unquoted_attr = @html_parser.parse_fragment(
    "<div title=a\u{0000}b>x</div>",
    collect_errors=true,
  )
  assert_eq(unquoted_attr.to_html(pretty=false), "<div title=\"a�b\">x</div>")
  assert_eq(unquoted_attr.errors.length(), 1)
  assert_eq(unquoted_attr.errors[0].code, "unexpected-null-character")
  let attr_name = @html_parser.parse_fragment(
    "<div a\u{0000}b='c'>x</div>",
    collect_errors=true,
  )
  let attr_name_children = attr_name.root.children()
  assert_eq(attr_name_children.length(), 1)
  assert_eq(attr_name_children[0].name(), "div")
  guard attr_name_children[0].attrs()["a\u{FFFD}b"] is Some("c") else {
    fail("expected parser replacement char in attr name")
  }
  assert_eq(attr_name.to_text(separator="", strip=false), "x")
  assert_eq(attr_name.errors.length(), 1)
  assert_eq(attr_name.errors[0].code, "unexpected-null-character")
  let tag_name = @html_parser.parse_fragment(
    "<a\u{0000}b id=x>y</a\u{0000}b>",
    collect_errors=true,
  )
  let tag_name_children = tag_name.root.children()
  assert_eq(tag_name_children.length(), 1)
  assert_eq(tag_name_children[0].name(), "a\u{FFFD}b")
  guard tag_name_children[0].attrs()["id"] is Some("x") else {
    fail("expected attr on null-mutated start tag")
  }
  assert_eq(tag_name_children[0].text(), "y")
  assert_eq(tag_name.to_text(separator="", strip=false), "y")
  assert_eq(tag_name.errors.length(), 2)
  assert_eq(tag_name.errors[0].code, "unexpected-null-character")
  assert_eq(tag_name.errors[1].code, "unexpected-null-character")
  let raw = @html_parser.parse_fragment(
    "<script>a\u{0000}b</script><title>a\u{0000}b</title>",
    collect_errors=true,
  )
  assert_eq(
    raw.to_html(pretty=false),
    "<script>a�b</script><title>a�b</title>",
  )
  assert_eq(raw.errors.length(), 2)
  assert_eq(raw.errors[0].code, "unexpected-null-character")
  assert_eq(raw.errors[1].code, "unexpected-null-character")
  let textarea = @html_parser.parse_fragment(
    "<textarea>\n\u{0000}b</textarea>",
    collect_errors=true,
  )
  assert_eq(textarea.to_html(pretty=false), "<textarea>�b</textarea>")
  assert_eq(textarea.errors[0].code, "unexpected-null-character")
}

///|
test "parser reports noncharacters in input stream" {
  let fragment = @html_parser.parse_fragment(
    "ab\u{FDD0}cd",
    collect_errors=true,
  )
  assert_eq(fragment.to_html(pretty=false), "ab\u{FDD0}cd")
  assert_eq(fragment.errors.length(), 1)
  assert_eq(fragment.errors[0].code, "noncharacter-in-input-stream")
  let invalid_fragment = @html_parser.parse_fragment(
    "<\u{FDD0}",
    collect_errors=true,
  )
  assert_eq(invalid_fragment.to_html(pretty=false), "&lt;\u{FDD0}")
  assert_eq(invalid_fragment.errors.length(), 3)
  assert_eq(invalid_fragment.errors[0].code, "noncharacter-in-input-stream")
  assert_eq(
    invalid_fragment.errors[1].code,
    "invalid-first-character-of-tag-name",
  )
  assert_eq(invalid_fragment.errors[2].code, "noncharacter-in-input-stream")
  let invalid_entity = @html_parser.parse_fragment(
    "<&notit",
    collect_errors=true,
  )
  assert_eq(invalid_entity.to_html(pretty=false), "&lt;¬it")
  assert_eq(invalid_entity.errors.length(), 2)
  assert_eq(
    invalid_entity.errors[0].code,
    "invalid-first-character-of-tag-name",
  )
  assert_eq(
    invalid_entity.errors[1].code,
    "missing-semicolon-after-character-reference",
  )
  let invalid_xml = @html_parser.parse_fragment(
    "<\u{000C}\u{FDD0}&lt;",
    collect_errors=true,
    xml_coercion=true,
  )
  assert_eq(invalid_xml.to_html(pretty=false), "&lt; �&lt;")
  assert_eq(invalid_xml.errors.length(), 2)
  assert_eq(invalid_xml.errors[0].code, "invalid-first-character-of-tag-name")
  assert_eq(invalid_xml.errors[1].code, "noncharacter-in-input-stream")
}

///|
test "parser treats script style title textarea content as text" {
  let doc = @html_parser.parse_fragment(
    "<script><!--a--<b</script><title>a &lt; b</title>",
  )
  assert_eq(
    doc.to_html(pretty=false),
    "<script><!--a--<<b</script><title>a &lt; b</title>",
  )
  assert_eq(doc.query("b").length(), 0)
  assert_eq(doc.to_text(separator="|", strip=false), "<!--a--<<b|a < b")
  let escaped_end = @html_parser.parse_fragment("<script><!--a--</script>")
  assert_eq(escaped_end.to_html(pretty=false), "<script><!--a--<</script>")
  let comment_end = @html_parser.parse_fragment("<script><!--a--></script>")
  assert_eq(comment_end.to_html(pretty=false), "<script><!--a--></script>")
  let raw_after_comment = @html_parser.parse_fragment(
    "<script><!--a-->x--</script>",
  )
  assert_eq(
    raw_after_comment.to_html(pretty=false),
    "<script><!--a-->x--</script>",
  )
  let double_escaped = @html_parser.parse_fragment(
    "<script><!--<script>x</script>y</script>",
  )
  assert_eq(
    double_escaped.to_text(separator="|", strip=false),
    "<!--<script>x</script>y",
  )
  let dash_dash_less_than = @html_parser.parse_fragment(
    "<script><!----<x</script>",
  )
  assert_eq(
    dash_dash_less_than.to_html(pretty=false),
    "<script><!----<<x</script>",
  )
  let double_escaped_dash = @html_parser.parse_fragment(
    "<script><!--<script>---x</script>tail</script>",
  )
  assert_eq(
    double_escaped_dash.to_html(pretty=false),
    "<script><!--<script>---x&lt;/script>tail</script>",
  )
  let non_script_double_escape_end = @html_parser.parse_fragment(
    "<script><!--<script></style x</script>tail</script>",
  )
  assert_eq(
    non_script_double_escape_end.to_html(pretty=false),
    "<script><!--<script></style x&lt;/script>tail</script>",
  )
}

///|
test "parser ignores one initial newline in pre listing and textarea" {
  let pre = @html_parser.parse_fragment(
    "<pre>\r\nline</pre><listing>\nitem</listing>",
  )
  assert_eq(pre.to_html(pretty=false), "<pre>line</pre><listing>item</listing>")
  let pre_cr = @html_parser.parse_fragment("<pre>\rline</pre>")
  assert_eq(pre_cr.to_html(pretty=false), "<pre>line</pre>")
  let listing_cr = @html_parser.parse_fragment("<listing>\rline</listing>")
  assert_eq(listing_cr.to_html(pretty=false), "<listing>line</listing>")
  let textarea = @html_parser.parse_fragment("<textarea>\nline</textarea>")
  assert_eq(textarea.to_html(pretty=false), "<textarea>line</textarea>")
  let textarea_cr = @html_parser.parse_fragment("<textarea>\rline</textarea>")
  assert_eq(textarea_cr.to_html(pretty=false), "<textarea>line</textarea>")
  let textarea_crlf = @html_parser.parse_fragment(
    "<textarea>\r\nline</textarea>",
  )
  assert_eq(textarea_crlf.to_html(pretty=false), "<textarea>line</textarea>")
  let title = @html_parser.parse_fragment("<title>\nline</title>")
  assert_eq(title.to_html(pretty=false), "<title>\nline</title>")
  let title_cr = @html_parser.parse_fragment("<title>\rline</title>")
  assert_eq(title_cr.to_html(pretty=false), "<title>\nline</title>")
}

///|
test "parser treats xmp and plaintext content as text" {
  let xmp = @html_parser.parse_fragment("<xmp><b>x</b></xmp>after")
  assert_eq(xmp.to_html(pretty=false), "<xmp>&lt;b&gt;x&lt;/b&gt;</xmp>after")
  assert_eq(xmp.query("b").length(), 0)
  let plaintext = @html_parser.parse_fragment(
    "<plaintext><b>x</b></plaintext>after",
    collect_errors=true,
  )
  assert_eq(
    plaintext.to_html(pretty=false),
    "<plaintext>&lt;b&gt;x&lt;/b&gt;&lt;/plaintext&gt;after</plaintext>",
  )
  assert_eq(plaintext.errors[0].code, "expected-closing-tag-but-got-eof")
}

///|
fn assert_script_fragment_eof(
  source : StringView,
  expected_html : String,
  expected_column : Int,
) -> Unit raise {
  let doc = @html_parser.parse_fragment(source, collect_errors=true)
  assert_eq(doc.to_html(pretty=false), expected_html)
  assert_eq(doc.errors.length(), 1)
  assert_eq(doc.errors[0].code, "expected-named-closing-tag-but-got-eof")
  guard doc.errors[0].line is Some(line) else {
    fail("expected script EOF line")
  }
  assert_eq(line, 1)
  guard doc.errors[0].column is Some(column) else {
    fail("expected script EOF column")
  }
  assert_eq(column, expected_column)
}

///|
test "parser reports special text EOF like tree builder" {
  let script = @html_parser.parse_fragment("<script>x", collect_errors=true)
  assert_eq(script.to_html(pretty=false), "<script>x</script>")
  assert_eq(script.errors.length(), 1)
  assert_eq(script.errors[0].code, "expected-named-closing-tag-but-got-eof")
  guard script.errors[0].column is Some(9) else {
    fail("expected script EOF at final text column")
  }
  let textarea = @html_parser.parse_fragment(
    "<textarea>\nx",
    collect_errors=true,
  )
  assert_eq(textarea.to_html(pretty=false), "<textarea>x</textarea>")
  assert_eq(textarea.errors.length(), 1)
  assert_eq(textarea.errors[0].code, "expected-closing-tag-but-got-eof")
  guard textarea.errors[0].line is Some(2) else {
    fail("expected textarea EOF on second line")
  }
  guard textarea.errors[0].column is Some(1) else {
    fail("expected textarea EOF at final text column")
  }
  let xmp = @html_parser.parse_fragment("<xmp>x", collect_errors=true)
  assert_eq(xmp.errors[0].code, "expected-named-closing-tag-but-got-eof")
  let iframe = @html_parser.parse_fragment("<iframe>x", collect_errors=true)
  assert_eq(iframe.errors[0].code, "expected-closing-tag-but-got-eof")
  assert_script_fragment_eof("<script><!--", "<script><!--</script>", 12)
  assert_script_fragment_eof("<script><!---", "<script><!---</script>", 13)
  assert_script_fragment_eof("<script><!--a--", "<script><!--a--</script>", 15)
  assert_script_fragment_eof(
    "<script><!--<script>x", "<script><!--<script>x</script>", 21,
  )
  assert_script_fragment_eof(
    "<script><!--<script>--", "<script><!--<script>--</script>", 22,
  )
  assert_script_fragment_eof(
    "<script><!--<script>--<", "<script><!--<script>--<</script>", 23,
  )
}

///|
test "parser matches malformed special text end tags after solidus" {
  let title = @html_parser.parse(
    "<title>a</title/foo><p>b",
    collect_errors=true,
  )
  assert_eq(
    title.to_html(pretty=false),
    "<html><head><title>a</title></head><body><p>b</p></body></html>",
  )
  assert_eq(title.errors.length(), 2)
  assert_eq(title.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(title.errors[1].code, "unexpected-character-after-solidus-in-tag")
  guard title.errors[1].column is Some(17) else {
    fail("expected title solidus recovery at column 17")
  }
  let title_attr = @html_parser.parse(
    "<title>a</title foo><p>b",
    collect_errors=true,
  )
  assert_eq(
    title_attr.to_html(pretty=false),
    "<html><head><title>a</title></head><body><p>b</p></body></html>",
  )
  assert_eq(title_attr.errors.length(), 1)
  assert_eq(title_attr.errors[0].code, "expected-doctype-but-got-start-tag")
  let title_self_closing = @html_parser.parse(
    "<title>a</title/><p>b",
    collect_errors=true,
  )
  assert_eq(
    title_self_closing.to_html(pretty=false),
    "<html><head><title>a</title></head><body><p>b</p></body></html>",
  )
  assert_eq(title_self_closing.errors.length(), 1)
  assert_eq(
    title_self_closing.errors[0].code,
    "expected-doctype-but-got-start-tag",
  )
  let title_eof = @html_parser.parse("<title>a</title/foo", collect_errors=true)
  assert_eq(
    title_eof.to_html(pretty=false),
    "<html><head><title>a</title></head><body></body></html>",
  )
  assert_eq(title_eof.errors.length(), 4)
  assert_eq(title_eof.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(
    title_eof.errors[1].code,
    "unexpected-character-after-solidus-in-tag",
  )
  assert_eq(title_eof.errors[2].code, "eof-in-tag")
  assert_eq(title_eof.errors[3].code, "expected-named-closing-tag-but-got-eof")
  guard title_eof.errors[2].column is Some(19) else {
    fail("expected title EOF-in-tag at column 19")
  }
  guard title_eof.errors[3].column is Some(19) else {
    fail("expected title tree-builder EOF at column 19")
  }
  let textarea = @html_parser.parse(
    "<textarea>a</textarea/foo><p>b",
    collect_errors=true,
  )
  assert_eq(
    textarea.to_html(pretty=false),
    "<html><head></head><body><textarea>a</textarea><p>b</p></body></html>",
  )
  assert_eq(textarea.errors.length(), 2)
  assert_eq(textarea.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(
    textarea.errors[1].code,
    "unexpected-character-after-solidus-in-tag",
  )
  guard textarea.errors[1].column is Some(23) else {
    fail("expected textarea solidus recovery at column 23")
  }
  let style = @html_parser.parse(
    "<style>a</style/foo><p>b",
    collect_errors=true,
  )
  assert_eq(
    style.to_html(pretty=false),
    "<html><head><style>a</style></head><body><p>b</p></body></html>",
  )
  assert_eq(style.errors.length(), 2)
  assert_eq(style.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(style.errors[1].code, "unexpected-character-after-solidus-in-tag")
  guard style.errors[1].column is Some(17) else {
    fail("expected style solidus recovery at column 17")
  }
  let xmp = @html_parser.parse("<xmp>a</xmp/foo><p>b", collect_errors=true)
  assert_eq(
    xmp.to_html(pretty=false),
    "<html><head></head><body><xmp>a</xmp><p>b</p></body></html>",
  )
  assert_eq(xmp.errors.length(), 2)
  assert_eq(xmp.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(xmp.errors[1].code, "unexpected-character-after-solidus-in-tag")
  guard xmp.errors[1].column is Some(13) else {
    fail("expected xmp solidus recovery at column 13")
  }
  let script = @html_parser.parse(
    "<script>a</script/foo><p>b",
    collect_errors=true,
  )
  assert_eq(
    script.to_html(pretty=false),
    "<html><head><script>a</script></head><body><p>b</p></body></html>",
  )
  assert_eq(script.errors.length(), 2)
  assert_eq(script.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(script.errors[1].code, "unexpected-character-after-solidus-in-tag")
  guard script.errors[1].column is Some(19) else {
    fail("expected script solidus recovery at column 19")
  }
  let script_eof = @html_parser.parse(
    "<script>a</script/foo",
    collect_errors=true,
  )
  assert_eq(
    script_eof.to_html(pretty=false),
    "<html><head><script>a</script></head><body></body></html>",
  )
  assert_eq(script_eof.errors.length(), 4)
  assert_eq(script_eof.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(
    script_eof.errors[1].code,
    "unexpected-character-after-solidus-in-tag",
  )
  assert_eq(script_eof.errors[2].code, "eof-in-tag")
  assert_eq(script_eof.errors[3].code, "expected-named-closing-tag-but-got-eof")
  guard script_eof.errors[2].column is Some(21) else {
    fail("expected script EOF-in-tag at column 21")
  }
  guard script_eof.errors[3].column is Some(21) else {
    fail("expected script tree-builder EOF at column 21")
  }
}

///|
test "parser treats similarly named special end tags as text" {
  let title = @html_parser.parse(
    "<title>a</titlex></title><p>b",
    collect_errors=true,
  )
  assert_eq(
    title.to_html(pretty=false),
    "<html><head><title>a&lt;/titlex&gt;</title></head><body><p>b</p></body></html>",
  )
  assert_eq(title.errors.length(), 1)
  assert_eq(title.errors[0].code, "expected-doctype-but-got-start-tag")
  let textarea = @html_parser.parse(
    "<textarea>a</textareax></textarea><p>b",
    collect_errors=true,
  )
  assert_eq(
    textarea.to_html(pretty=false),
    "<html><head></head><body><textarea>a&lt;/textareax&gt;</textarea><p>b</p></body></html>",
  )
  assert_eq(textarea.errors.length(), 1)
  assert_eq(textarea.errors[0].code, "expected-doctype-but-got-start-tag")
  let xmp = @html_parser.parse("<xmp>a</xmpx></xmp><p>b", collect_errors=true)
  assert_eq(
    xmp.to_html(pretty=false),
    "<html><head></head><body><xmp>a&lt;/xmpx&gt;</xmp><p>b</p></body></html>",
  )
  assert_eq(xmp.errors.length(), 1)
  assert_eq(xmp.errors[0].code, "expected-doctype-but-got-start-tag")
}

///|
test "tree builder finishes deeply nested parsed HTML without recursion" {
  let html = repeat_for_test("<div>", 1200) +
    "x" +
    repeat_for_test("</div>", 1200)
  let doc = @html_parser.parse(html)
  assert_eq(doc.to_text(separator="", strip=false), "x")
  guard doc.query_one("div") is Some(first_div) else {
    fail("expected parsed deep div")
  }
  assert_eq(first_div.to_text(separator="", strip=false), "x")
}
