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
test "document head helpers tolerate detached parser stacks" {
  let document_parser = Parser::new(
    "",
    @dom.document(children=[@dom.element("html")]),
    scripting_enabled=true,
    xml_coercion=false,
  )
  assert_true(document_parser.document_has_element_child())
  let head = @dom.element("head")
  let head_parser = Parser::new(
    "",
    head,
    scripting_enabled=true,
    xml_coercion=false,
  )
  assert_eq(head_parser.current_is_document_head(), false)
  let shell = @dom.fragment()
  shell.append_child(head)
  head_parser.stack.clear()
  assert_true(head_parser.current_is_document_head())
  assert_eq(head_parser.close_current_document_head_for_start("p", 0), false)
  assert_eq(head_parser.stack.length(), 0)

  let noscript_parser = Parser::new(
    "",
    @dom.fragment(),
    scripting_enabled=false,
    xml_coercion=false,
  )
  let body = @dom.element("body")
  let noscript = @dom.element("noscript")
  noscript_parser.stack.push(body)
  noscript_parser.stack.push(noscript)
  noscript_parser.pop_disabled_head_noscript_for_reprocess()
  guard noscript_parser.stack.last() is Some(last) else {
    fail("expected non-head parent to remain after noscript pop")
  }
  assert_true(physical_equal(last, body))
}

///|
test "document frameset helpers preserve reprocess state" {
  let explicit_html = @dom.element("html", children=[
    @dom.element("head"),
    @dom.element("body"),
  ])
  let explicit_root = @dom.document(children=[explicit_html])
  let blocked = Parser::new(
    "",
    explicit_root,
    scripting_enabled=true,
    xml_coercion=false,
  )
  assert_eq(blocked.prepare_document_frameset_replacement(), false)
  assert_true(
    blocked.handle_document_frameset_start_tag("frameset", {}, false, 0, 9),
  )
  assert_eq(blocked.errors.length(), 1)
  assert_eq(blocked.errors[0].code, "unexpected-start-tag-ignored")
  assert_eq(
    @ser.to_html(explicit_root, pretty=false),
    "<html><head></head><body></body></html>",
  )
  let html = @dom.element("html")
  let frameset = @dom.element("frameset")
  html.append_child(frameset)
  let root = @dom.document(children=[html])
  let parser = Parser::new("", root, scripting_enabled=true, xml_coercion=false)
  parser.stack.clear()
  parser.stack.push(root)
  parser.stack.push(html)
  parser.stack.push(frameset)
  parser.frameset_reprocesses_in_body_mode = true
  assert_true(
    parser.handle_document_frameset_start_tag(
      "html",
      { "lang": Some("en") },
      false,
      0,
      5,
    ),
  )
  assert_eq(parser.errors.length(), 1)
  assert_eq(parser.errors[0].code, "unexpected-start-tag")
  guard html.attrs["lang"] is Some("en") else {
    fail("expected reprocessed html attrs to merge onto root html")
  }
  assert_eq(
    parser.handle_document_frameset_start_tag("p", {}, false, 6, 8),
    false,
  )
  assert_eq(parser.errors.length(), 1)
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
