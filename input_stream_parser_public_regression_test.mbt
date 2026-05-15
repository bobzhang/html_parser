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
