// Whitebox regressions for document head, noscript, and frameset modes.

///|
test "document head helpers tolerate detached parser stacks" {
  let document_parser = Parser(
    "",
    @dom.document(children=[@dom.element("html")]),
    scripting_enabled=true,
    xml_coercion=false,
  )
  assert_true(document_parser.document_has_element_child())
  let head = @dom.element("head")
  let head_parser = Parser("", head, scripting_enabled=true, xml_coercion=false)
  assert_eq(head_parser.current_is_document_head(), false)
  let shell = @dom.fragment()
  shell.append_child(head)
  head_parser.stack.clear()
  assert_true(head_parser.current_is_document_head())
  assert_eq(head_parser.close_current_document_head_for_start("p", 0), false)
  assert_eq(head_parser.stack.length(), 0)

  let noscript_parser = Parser(
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
  let blocked = Parser(
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
  let parser = Parser("", root, scripting_enabled=true, xml_coercion=false)
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
