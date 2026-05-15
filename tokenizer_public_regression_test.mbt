///|
test "tokenize exposes stable token data structures" {
  let result = @html_parser.tokenize("<p class='x'>Hi<br><!--ok--></p>")
  assert_eq(result.tokens.length(), 6)
  guard result.tokens[0] is Tag(start) else { fail("expected start tag") }
  assert_true(start.kind is StartTag)
  assert_eq(start.name, "p")
  guard start.attrs["class"] is Some("x") else { fail("expected class attr") }
  guard result.tokens[1] is Characters("Hi") else {
    fail("expected text token")
  }
  guard result.tokens[2] is Tag(br) else { fail("expected br tag") }
  assert_eq(br.self_closing, false)
  guard result.tokens[3] is CommentToken("ok") else {
    fail("expected comment token")
  }
  guard result.tokens[5] is Eof else { fail("expected EOF") }
  let explicit = @html_parser.tokenize("<img/>")
  guard explicit.tokens[0] is Tag(img) else { fail("expected img tag") }
  assert_eq(img.self_closing, true)
}

///|
test "tokenize matches upstream coverage gap fixtures" {
  let null_attr_name = @html_parser.tokenize(
    "<div a\u{0000}b='c'>",
    collect_errors=true,
  )
  guard null_attr_name.tokens[0] is Tag(null_attr_name_tag) else {
    fail("expected null attribute name start tag")
  }
  guard null_attr_name_tag.attrs["a\u{FFFD}b"] is Some("c") else {
    fail("expected replacement character in attribute name")
  }
  assert_eq(null_attr_name.errors.length(), 1)
  assert_eq(null_attr_name.errors[0].code, "unexpected-null-character")
  guard null_attr_name.errors[0].column is Some(7) else {
    fail("expected null attribute name error at column 7")
  }
  let null_double = @html_parser.tokenize(
    "<div a=\"b\u{0000}c\">",
    collect_errors=true,
  )
  guard null_double.tokens[0] is Tag(null_double_tag) else {
    fail("expected null double-quoted attribute start tag")
  }
  guard null_double_tag.attrs["a"] is Some("b\u{FFFD}c") else {
    fail("expected replacement character in double-quoted attribute value")
  }
  assert_eq(null_double.errors.length(), 1)
  assert_eq(null_double.errors[0].code, "unexpected-null-character")
  guard null_double.errors[0].column is Some(10) else {
    fail("expected double-quoted attribute null at column 10")
  }
  let null_single = @html_parser.tokenize(
    "<div a='b\u{0000}c'>",
    collect_errors=true,
  )
  guard null_single.tokens[0] is Tag(null_single_tag) else {
    fail("expected null single-quoted attribute start tag")
  }
  guard null_single_tag.attrs["a"] is Some("b\u{FFFD}c") else {
    fail("expected replacement character in single-quoted attribute value")
  }
  assert_eq(null_single.errors.length(), 1)
  assert_eq(null_single.errors[0].code, "unexpected-null-character")
  guard null_single.errors[0].column is Some(10) else {
    fail("expected single-quoted attribute null at column 10")
  }
  let missing_value = @html_parser.tokenize("<div a=>", collect_errors=true)
  guard missing_value.tokens[0] is Tag(missing_tag) else {
    fail("expected missing attribute value start tag")
  }
  guard missing_tag.attrs["a"] is Some("") else {
    fail("expected empty missing attribute value")
  }
  assert_eq(missing_value.errors.length(), 1)
  assert_eq(missing_value.errors[0].code, "missing-attribute-value")
  guard missing_value.errors[0].column is Some(8) else {
    fail("expected missing value at tag close")
  }
  let title_space = @html_parser.tokenize("<title >")
  guard title_space.tokens[0] is Tag(title_space_tag) else {
    fail("expected title start tag after attribute-name whitespace")
  }
  assert_eq(title_space_tag.name, "title")
  assert_eq(title_space_tag.attrs.length(), 0)
  let title_attr = @html_parser.tokenize("<title id>")
  guard title_attr.tokens[0] is Tag(title_attr_tag) else {
    fail("expected title start tag with empty id")
  }
  guard title_attr_tag.attrs["id"] is Some("") else {
    fail("expected empty id attribute")
  }
  let title_slow_attr = @html_parser.tokenize("<title id\\\">")
  guard title_slow_attr.tokens[0] is Tag(title_slow_attr_tag) else {
    fail("expected title start tag with quote in attribute name")
  }
  guard title_slow_attr_tag.attrs["id\\\""] is Some("") else {
    fail("expected backslash and quote in title attribute name")
  }
  let title_after_attr = @html_parser.tokenize("<title id >")
  guard title_after_attr.tokens[0] is Tag(title_after_attr_tag) else {
    fail("expected title start tag after attribute name")
  }
  guard title_after_attr_tag.attrs["id"] is Some("") else {
    fail("expected empty id after whitespace")
  }
  let title_before_value = @html_parser.tokenize("<title id=>")
  guard title_before_value.tokens[0] is Tag(title_before_value_tag) else {
    fail("expected title start tag before missing value")
  }
  guard title_before_value_tag.attrs["id"] is Some("") else {
    fail("expected empty id after equals")
  }
}

///|
test "tokenize preserves raw end tags before tree recovery" {
  let result = @html_parser.tokenize("<p>open</span>")
  assert_eq(result.tokens.length(), 4)
  guard result.tokens[0] is Tag(start) else { fail("expected p start tag") }
  assert_true(start.kind is StartTag)
  assert_eq(start.name, "p")
  guard result.tokens[2] is Tag(end_tag) else {
    fail("expected raw span end tag")
  }
  assert_true(end_tag.kind is EndTag)
  assert_eq(end_tag.name, "span")
}

///|
test "tokenize preserves end tag attributes and self closing solidus" {
  let self_closing = @html_parser.tokenize("</div/>", collect_errors=true)
  guard self_closing.tokens[0] is Tag(tag) else { fail("expected end tag") }
  assert_true(tag.kind is EndTag)
  assert_eq(tag.name, "div")
  assert_eq(tag.self_closing, true)
  assert_eq(self_closing.errors.length(), 0)
  let attrs = @html_parser.tokenize("</div attr=x>", collect_errors=true)
  guard attrs.tokens[0] is Tag(attr_tag) else {
    fail("expected attributed end tag")
  }
  assert_true(attr_tag.kind is EndTag)
  assert_eq(attr_tag.name, "div")
  guard attr_tag.attrs["attr"] is Some("x") else {
    fail("expected end tag attr")
  }
  assert_eq(attr_tag.self_closing, false)
  assert_eq(attrs.errors.length(), 0)
  let null_name = @html_parser.tokenize("</d\u{0000}iv>", collect_errors=true)
  guard null_name.tokens[0] is Tag(null_tag) else {
    fail("expected null-containing end tag")
  }
  assert_true(null_tag.kind is EndTag)
  assert_eq(null_tag.name, "d\u{FFFD}iv")
  assert_eq(null_name.errors.length(), 1)
  assert_eq(null_name.errors[0].code, "unexpected-null-character")
  let bad_solidus = @html_parser.tokenize("</div/ x>", collect_errors=true)
  guard bad_solidus.tokens[0] is Tag(bad_tag) else {
    fail("expected recovered end tag after bad solidus")
  }
  assert_true(bad_tag.kind is EndTag)
  assert_eq(bad_tag.name, "div")
  assert_eq(bad_tag.self_closing, false)
  guard bad_tag.attrs["x"] is Some("") else {
    fail("expected recovered attr after bad end-tag solidus")
  }
  assert_eq(bad_solidus.errors.length(), 1)
  assert_eq(
    bad_solidus.errors[0].code,
    "unexpected-character-after-solidus-in-tag",
  )
}

///|
test "tokenize matches rawtext and rcdata end tags before bad solidus" {
  let title = @html_parser.tokenize(
    "<title>a</title/foo><p>b",
    collect_errors=true,
  )
  guard title.tokens[1] is Characters("a") else {
    fail("expected title text before slash end tag")
  }
  guard title.tokens[2] is Tag(end_title) else {
    fail("expected title end tag before slash attribute")
  }
  assert_true(end_title.kind is EndTag)
  assert_eq(end_title.name, "title")
  guard end_title.attrs["foo"] is Some("") else {
    fail("expected recovered foo attribute on title end tag")
  }
  assert_eq(title.errors.length(), 1)
  assert_eq(title.errors[0].code, "unexpected-character-after-solidus-in-tag")
  guard title.errors[0].column is Some(17) else {
    fail("expected title solidus recovery at column 17")
  }
  let script = @html_parser.tokenize(
    "<script>a</script/foo><p>b",
    collect_errors=true,
  )
  guard script.tokens[1] is Characters("a") else {
    fail("expected script text before slash end tag")
  }
  guard script.tokens[2] is Tag(end_script) else {
    fail("expected script end tag before slash attribute")
  }
  assert_true(end_script.kind is EndTag)
  assert_eq(end_script.name, "script")
  guard end_script.attrs["foo"] is Some("") else {
    fail("expected recovered foo attribute on script end tag")
  }
  assert_eq(script.errors.length(), 1)
  assert_eq(script.errors[0].code, "unexpected-character-after-solidus-in-tag")
  guard script.errors[0].column is Some(19) else {
    fail("expected script solidus recovery at column 19")
  }
}
