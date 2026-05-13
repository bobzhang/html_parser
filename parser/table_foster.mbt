///|
fn is_table_text_foster_target(name : StringView) -> Bool {
  match name {
    "table" | "tbody" | "tfoot" | "thead" | "tr" => true
    _ => false
  }
}

///|
fn is_table_start_foster_target(name : StringView) -> Bool {
  match name {
    "table" | "tbody" | "tfoot" | "thead" | "tr" => true
    _ => false
  }
}

///|
fn Parser::report_foster_parenting_character_errors(
  self : Parser,
  value : StringView,
  start : Int,
) -> Int {
  let mut count = 0
  let mut pos = 0
  while pos < value.length() {
    let ch = value.get_char(pos).unwrap()
    if !ch.is_ascii_whitespace() {
      self.error_at("foster-parenting-character", start + pos)
      count += 1
    }
    pos += ch.utf16_len()
  }
  count
}

///|
fn Parser::foster_parent_table_text_with_formatting(
  self : Parser,
  cleaned : StringView,
  start : Int,
  table_index : Int,
  formatting_index : Int,
) -> Bool {
  let entry = self.active_formatting[formatting_index]
  let node = element_from_formatting_entry(entry)
  node.append_child(
    self.text_at(@tok.decode_entities(cleaned, in_attribute=false), start),
  )
  if self.table_index_is_fragment_context_table(table_index) {
    self.current_node().append_child(node)
  } else {
    self.insert_node_before_open_table(node, table_index)
  }
  self.active_formatting[formatting_index] = formatting_entry_with_node(
    entry, node,
  )
  self.pending_table_view_implied_end_tag = true
  true
}

///|
fn Parser::foster_parent_table_text(
  self : Parser,
  cleaned : StringView,
  start : Int,
) -> Bool {
  if !text_has_non_ascii_whitespace(cleaned) {
    return false
  }
  let table_index = self.last_open_table_index()
  if table_index < 0 || self.table_text_is_inside_cell_or_caption(table_index) {
    return false
  }
  let current = self.current_node()
  if current.kind != Element || !is_table_text_foster_target(current.name) {
    return false
  }
  let formatting_index = self.active_formatting_orphan_anchor_index()
  if formatting_index >= 0 {
    return self.foster_parent_table_text_with_formatting(
      cleaned, start, table_index, formatting_index,
    )
  }
  ignore(self.report_foster_parenting_character_errors(cleaned, start))
  let fostered = self.text_at(
    @tok.decode_entities(cleaned, in_attribute=false),
    start,
  )
  if self.table_index_is_fragment_context_table(table_index) {
    self.current_node().append_child(fostered)
    return true
  }
  let table = self.stack[table_index]
  match table.parent {
    Some(parent) => parent.insert_before(fostered, Some(table))
    None => self.root.append_child(fostered)
  }
  true
}

///|
fn Parser::foster_parent_template_table_text(
  self : Parser,
  cleaned : StringView,
  start : Int,
) -> Bool {
  if !self.in_template_content_without_inner_table() ||
    !text_has_non_ascii_whitespace(cleaned) {
    return false
  }
  let current = self.current_node()
  if current.kind != Element || !is_table_text_foster_target(current.name) {
    return false
  }
  let template_index = self.last_open_template_index()
  ignore(self.report_foster_parenting_character_errors(cleaned, start))
  self.stack[template_index].append_child(
    self.text_at(@tok.decode_entities(cleaned, in_attribute=false), start),
  )
  true
}

///|
fn Parser::table_index_is_fragment_context_table(
  self : Parser,
  table_index : Int,
) -> Bool {
  if table_index < 0 {
    return false
  }
  match self.fragment_context_table {
    Some(table) => physical_equal(self.stack[table_index], table)
    None => false
  }
}

///|
fn Parser::report_foster_parented_table_context_text(
  self : Parser,
  cleaned : StringView,
  start : Int,
) -> Unit {
  if !text_has_non_ascii_whitespace(cleaned) {
    return
  }
  let table_index = self.table_context_without_cell_or_caption()
  if table_index < 0 {
    return
  }
  let current = self.current_node()
  if current.kind == Element && is_table_text_foster_target(current.name) {
    return
  }
  ignore(self.report_foster_parenting_character_errors(cleaned, start))
}

///|
fn Parser::table_start_foster_mode(self : Parser, name : StringView) -> Int {
  if name == "style" || name == "script" {
    return 0
  }
  if is_table_internal_start_name(name) {
    return 0
  }
  let table_index = self.table_context_without_cell_or_caption()
  if table_index < 0 {
    return 0
  }
  let current = self.current_node()
  if current.kind != Element || !is_table_start_foster_target(current.name) {
    return 0
  }
  if current.name == "tr" {
    1
  } else {
    2
  }
}

///|
fn Parser::insert_node_before_open_table(
  self : Parser,
  node : @dom.Node,
  table_index : Int,
) -> Unit {
  let table = self.stack[table_index]
  match table.parent {
    Some(parent) => parent.insert_before(node, Some(table))
    None => self.root.append_child(node)
  }
}

///|
fn Parser::append_start_tag_node(
  self : Parser,
  node : @dom.Node,
  name : StringView,
  start : Int,
) -> Unit {
  let foster_mode = self.table_start_foster_mode(name)
  if foster_mode == 0 {
    self.current_node().append_child(node)
    return
  }
  if foster_mode == 2 {
    self.error_at("foster-parenting-start-tag", start)
    self.foster_parented_start_error_nodes.push(node)
  }
  let table_index = self.last_open_table_index()
  if self.table_index_is_fragment_context_table(table_index) {
    self.current_node().append_child(node)
    return
  }
  self.insert_node_before_open_table(node, self.last_open_table_index())
}

///|
fn Parser::remove_foster_parented_start_error_node(
  self : Parser,
  target : @dom.Node,
) -> Bool {
  let mut index = 0
  while index < self.foster_parented_start_error_nodes.length() {
    if physical_equal(self.foster_parented_start_error_nodes[index], target) {
      ignore(self.foster_parented_start_error_nodes.remove(index))
      return true
    }
    index += 1
  }
  false
}

///|
fn Parser::handle_foster_parented_end_tag(
  self : Parser,
  name : String,
  start : Int,
) -> Bool {
  let table_index = self.table_context_without_cell_or_caption()
  if table_index < 0 {
    return false
  }
  let target_index = self.last_stack_index_of(name)
  if target_index <= table_index {
    return false
  }
  let target = self.stack[target_index]
  if self.remove_foster_parented_start_error_node(target) {
    self.error_at("unexpected-end-tag-implies-table-voodoo", start)
  }
  self.pop_until(name, start)
  true
}
