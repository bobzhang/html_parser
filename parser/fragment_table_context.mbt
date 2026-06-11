///|
fn is_fragment_table_section_context(name : StringView) -> Bool {
  match name {
    "tbody" | "thead" | "tfoot" => true
    _ => false
  }
}

///|
fn Parser::parse_table_fragment_context(self : Parser) -> Unit {
  let table = @dom.element("table")
  self.fragment_context_table = Some(table)
  self.root.append_child(table)
  self.stack.push(table)
  self.parse_all()
  normalize_tables(table)
  unwrap_fragment_context_element(self.root, table)
  let table_index = self.last_stack_index_of_node(table)
  let caption_index = self.last_stack_index_of("caption")
  if table_index < 0 || caption_index <= table_index {
    self.stack.clear()
    self.stack.push(self.root)
  }
  self.fragment_context_table = None
}

///|
fn Parser::parse_table_section_fragment_context(
  self : Parser,
  name : String,
) -> Unit {
  let table = @dom.element("table")
  let section = @dom.element(name)
  self.fragment_context_table = Some(table)
  self.fragment_context_table_section = Some(section)
  self.root.append_child(table)
  table.append_child(section)
  self.stack.push(table)
  self.stack.push(section)
  self.parse_all()
  normalize_tables(section)
  unwrap_fragment_context_element(table, section)
  unwrap_fragment_context_element(self.root, table)
  self.stack.clear()
  self.stack.push(self.root)
  self.fragment_context_table_section = None
  self.fragment_context_table = None
}

///|
fn Parser::parse_table_row_fragment_context(self : Parser) -> Unit {
  let table = @dom.element("table")
  let section = @dom.element("tbody")
  let row = @dom.element("tr")
  self.fragment_context_table = Some(table)
  self.fragment_context_table_section = Some(section)
  self.fragment_context_table_row = Some(row)
  self.root.append_child(table)
  table.append_child(section)
  section.append_child(row)
  self.stack.push(table)
  self.stack.push(section)
  self.stack.push(row)
  self.parse_all()
  normalize_tables(row)
  unwrap_fragment_context_element(section, row)
  unwrap_fragment_context_element(table, section)
  unwrap_fragment_context_element(self.root, table)
  self.stack.clear()
  self.stack.push(self.root)
  self.fragment_context_table_row = None
  self.fragment_context_table_section = None
  self.fragment_context_table = None
}

///|
fn Parser::parse_table_cell_fragment_context(
  self : Parser,
  name : String,
) -> Unit {
  let table = @dom.element("table")
  let section = @dom.element("tbody")
  let row = @dom.element("tr")
  let cell = @dom.element(name)
  self.fragment_context_table = Some(table)
  self.fragment_context_table_section = Some(section)
  self.fragment_context_table_row = Some(row)
  self.fragment_context_table_cell = Some(cell)
  self.root.append_child(table)
  table.append_child(section)
  section.append_child(row)
  row.append_child(cell)
  self.stack.push(table)
  self.stack.push(section)
  self.stack.push(row)
  self.stack.push(cell)
  self.push_active_formatting_marker()
  self.parse_all()
  normalize_tables(cell)
  unwrap_fragment_context_element(row, cell)
  unwrap_fragment_context_element(section, row)
  unwrap_fragment_context_element(table, section)
  unwrap_fragment_context_element(self.root, table)
  self.stack.clear()
  self.stack.push(self.root)
  self.fragment_context_table_cell = None
  self.fragment_context_table_row = None
  self.fragment_context_table_section = None
  self.fragment_context_table = None
}
