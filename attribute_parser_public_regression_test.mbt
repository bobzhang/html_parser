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
