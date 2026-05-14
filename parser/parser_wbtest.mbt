// Whitebox tests run within the package scope.
// Use them to validate internal helpers or invariants.
// Keep them focused; public behavior belongs in `_test.mbt`.

///|
test "parser cursor helpers use utf16 offsets and safe fallbacks" {
  let parser = Parser::new(
    "😀",
    @dom.fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  guard parser.advance_char() is Some(first) else {
    fail("expected first character")
  }
  assert_eq(first.to_string(), "😀")
  assert_eq(parser.pos, 2)
  assert_true(parser.advance_char() is None)
  assert_eq(parser.pos, 2)
  let root = parser.root
  ignore(parser.stack.pop())
  assert_true(physical_equal(parser.current_node(), root))
  parser.append_text("", 0)
  assert_eq(root.children.length(), 0)
  let source_parser = Parser::new(
    "<p😀>",
    @dom.fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  assert_eq(source_parser.source_tag_slice(0, 4), "<p😀>")
  source_parser.append_sanitize_escape_source_text(0, 4)
  assert_eq(source_parser.root.children.length(), 1)
  assert_eq(source_parser.root.children[0].data, "<p😀")
  let text_parser = Parser::new(
    "a😀\u{0000}b",
    @dom.fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  assert_eq(text_parser.remove_null_characters("a😀\u{0000}b", 0), "a😀b")
  assert_eq(text_parser.errors.length(), 1)
  assert_eq(
    text_parser.replace_null_characters("x\u{0000}😀", 0),
    "x\u{FFFD}😀",
  )
  assert_eq(text_parser.errors.length(), 2)
  assert_eq(eof_error_pos("a😀"), 1)
  guard text_node_without_leading_ascii_whitespace(@dom.text(" \t😀body"))
    is Some(stripped) else {
    fail("expected stripped text node")
  }
  assert_eq(stripped.data, "😀body")
  let (leading, rest) = split_text_node_leading_ascii_whitespace(
    @dom.text(" \t😀body"),
  )
  guard leading is Some(leading_node) else {
    fail("expected leading whitespace node")
  }
  guard rest is Some(rest_node) else { fail("expected rest text node") }
  assert_eq(leading_node.data, " \t")
  assert_eq(rest_node.data, "😀body")
  assert_eq(normalize_newlines("a\r\n😀\rb"), "a\n😀\nb")
  assert_eq(
    normalize_bogus_comment_data("a\u{0000}\r\n😀"),
    "a\u{FFFD}\n😀",
  )
  let (line, col) = line_col_at("a😀\nb", 4)
  assert_eq(line, 2)
  assert_eq(col, 1)
  let (eof_line, eof_col) = @syn.eof_line_col("a😀\n")
  assert_eq(eof_line, 2)
  assert_eq(eof_col, 0)
}

///|
test "parser insertion helpers keep omitted origins optional" {
  let parser = Parser::new(
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

///|
test "parser private defensive branches keep no-op behavior" {
  let template_parser = Parser::new(
    "",
    @dom.fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  let template = @dom.element("template")
  template_parser.stack.push(template)
  assert_true(template_parser.handle_template_end_tag("template", 0))
  assert_true(template.source_end_tag is None)
  assert_eq(template_parser.stack.length(), 1)

  let attr_parser = Parser::new(
    ">",
    @dom.fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  let attrs : Map[String, String?] = {}
  attr_parser.parse_attribute(attrs)
  assert_eq(attr_parser.pos, 1)
  assert_eq(attrs.length(), 0)
}

///|
test "detached recovery helpers ignore stale parser state" {
  let parser = Parser::new(
    "",
    @dom.fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  let div = @dom.element("div")
  parser.stack.push(div)
  parser.foreign_table_row_recovery_mode = true
  parser.report_foreign_table_row_recovery_text("x", 0)
  assert_eq(parser.errors.length(), 0)

  let parent = @dom.element("frameset")
  let stale = @dom.element("div")
  let child = @dom.element("frame")
  child.parent = Some(stale)
  detach_removed_frameset_replacement_child(parent, child)
  guard child.parent is Some(actual_parent) else {
    fail("expected stale parent link to stay attached")
  }
  assert_true(physical_equal(actual_parent, stale))
}

///|
test "sanitize_dom clears mixed-case style rawtext resource loads" {
  let policy = @san.SanitizationPolicy::new(
    ["style"],
    allowed_attributes={ "style": [] },
    drop_content_tags=[],
  )
  let style = @dom.element("StYlE", children=[
    @dom.text("@import 'https://evil.example/x.css';"),
  ])
  let clean = @san.sanitize_dom(style, policy~)
  assert_eq(@ser.to_html(clean, pretty=false), "<StYlE></StYlE>")
  assert_eq(clean.children.length(), 0)
}
