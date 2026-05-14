// Whitebox tests run within the package scope.
// Use them to validate internal helpers or invariants.
// Keep them focused; public behavior belongs in `_test.mbt`.

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
