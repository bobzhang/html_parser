// Whitebox regressions for parser insertion helper origin and stack behavior.

///|
test "parser insertion helpers keep omitted origins optional" {
  let parser = Parser(
    "",
    @dom.fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  parser.insert_element_without_push("hr", {})
  parser.insert_element_maybe_push("span", { "id": Some("x") }, true)
  assert_eq(parser.root.children.length(), 2)
  let hr = parser.root.children[0]
  let span = parser.root.children[1]
  assert_eq(hr.name, "hr")
  assert_true(hr.origin_offset() is None)
  assert_eq(span.name, "span")
  guard span.attrs["id"] is Some("x") else {
    fail("expected helper-inserted attrs")
  }
  assert_true(span.origin_offset() is None)
  guard parser.stack.last() is Some(last) else {
    fail("expected pushed helper node")
  }
  assert_true(physical_equal(last, span))
  assert_true(parser.has_open_html_element("span"))
}
