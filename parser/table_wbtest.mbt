// Whitebox regressions for parser table and template-table helper state.

///|
test "table foster helpers handle detached helper state" {
  let root = @dom.fragment()
  let parser = Parser("", root, scripting_enabled=true, xml_coercion=false)
  let table = @dom.element("table")
  let tbody = @dom.element("tbody")
  parser.clear_open_elements()
  parser.push_open_element(root)
  parser.push_open_element(table)
  parser.push_open_element(tbody)
  assert_true(parser.foster_parent_table_text("x", 0))
  assert_eq(@ser.to_html(root, pretty=false), "x")
  assert_eq(parser.errors.length(), 1)
  assert_eq(parser.errors[0].code, "foster-parenting-character")
  parser.report_foster_parented_table_context_text("z", 1)
  assert_eq(parser.errors.length(), 1)
  parser.insert_node_before_open_table(@dom.text("y"), 1)
  assert_eq(@ser.to_html(root, pretty=false), "xy")

  let blocked = Parser(
    "",
    @dom.fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  let blocked_table = @dom.element("table")
  let div = @dom.element("div")
  blocked.clear_open_elements()
  blocked.push_open_element(blocked.root)
  blocked.push_open_element(blocked_table)
  blocked.push_open_element(div)
  assert_eq(blocked.handle_nested_table_start_tag("table", 0), false)
  assert_eq(blocked.table_start_foster_mode("p"), 0)

  let open_section = Parser(
    "",
    @dom.fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  let section_table = @dom.element("table")
  let section = @dom.element("tbody")
  open_section.push_open_element(section_table)
  open_section.push_open_element(section)
  assert_eq(
    open_section.handle_table_context_ignored_end_tag("tbody", 0),
    false,
  )
  assert_true(open_section.handle_table_structural_end_tag("tbody"))
  guard open_section.stack.last() is Some(last) else {
    fail("expected table to remain open after row-group close")
  }
  assert_true(physical_equal(last, section_table))
}

///|
fn stale_template_column_group_parser() -> (Parser, @dom.Node) {
  let parser = Parser(
    "",
    @dom.fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  let template = @dom.element("template")
  let table = @dom.element("table")
  parser.root.append_child(template)
  template.append_child(table)
  parser.push_open_element(template)
  parser.enable_template_column_group_mode()
  parser.push_open_element(table)
  (parser, table)
}

///|
test "template column group mode drops stale inner table state" {
  let (text_parser, text_table) = stale_template_column_group_parser()
  assert_true(text_parser.template_column_group_mode_active())
  assert_eq(text_parser.handle_template_column_group_text("x", 0), false)
  assert_eq(text_parser.template_column_group_mode_active(), false)
  assert_eq(text_parser.errors.length(), 0)
  assert_eq(text_table.children.length(), 0)

  let (start_parser, start_table) = stale_template_column_group_parser()
  assert_eq(
    start_parser.handle_template_column_group_start_tag("col", {}, 0),
    false,
  )
  assert_eq(start_parser.template_column_group_mode_active(), false)
  assert_eq(start_table.children.length(), 0)

  let (end_parser, end_table) = stale_template_column_group_parser()
  assert_eq(end_parser.handle_template_column_group_end_tag("tbody", 0), false)
  assert_eq(end_parser.template_column_group_mode_active(), false)
  assert_eq(end_table.children.length(), 0)

  let detached = Parser(
    "",
    @dom.fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  detached.enable_template_column_group_mode()
  detached.disable_current_template_column_group_mode()
  assert_eq(detached.template_column_group_templates.length(), 0)
}
