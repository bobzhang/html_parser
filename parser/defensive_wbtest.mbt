// Whitebox regressions for defensive parser no-op branches.

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
test "parser can skip diagnostics when callers discard parse errors" {
  let parser = Parser::new(
    "",
    @dom.fragment(),
    scripting_enabled=true,
    xml_coercion=false,
    collect_errors=false,
  )
  parser.error_at("unexpected-end-tag", 0)
  parser.error_at_eof("expected-closing-tag-but-got-eof")
  parser.deferred_initial_doctype_error = parser.report_initial_doctype_error()
  assert_eq(parser.errors.length(), 0)
  assert_true(parser.deferred_initial_doctype_error is None)
}
