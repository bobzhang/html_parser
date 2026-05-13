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
fn is_table_or_section_context(name : StringView) -> Bool {
  match name {
    "table" | "tbody" | "tfoot" | "thead" => true
    _ => false
  }
}

///|
fn is_table_internal_start_name(name : StringView) -> Bool {
  match name {
    "caption"
    | "col"
    | "colgroup"
    | "tbody"
    | "td"
    | "tfoot"
    | "th"
    | "thead"
    | "tr"
    | "table" => true
    _ => false
  }
}

///|
fn Parser::last_open_table_index(self : Parser) -> Int {
  let mut index = self.stack.length()
  while index > 0 {
    index -= 1
    let node = self.stack[index]
    if node.kind == Element && node.name == "table" {
      return index
    }
  }
  -1
}

///|
fn Parser::table_text_is_inside_cell_or_caption(
  self : Parser,
  table_index : Int,
) -> Bool {
  let mut index = table_index + 1
  while index < self.stack.length() {
    let node = self.stack[index]
    if node.kind == Element &&
      (node.name == "td" || node.name == "th" || node.name == "caption") {
      return true
    }
    index += 1
  }
  false
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
fn Parser::current_is_table_or_section_context(self : Parser) -> Bool {
  let table_index = self.table_context_without_cell_or_caption()
  if table_index < 0 {
    return false
  }
  let current = self.current_node()
  current.kind == Element && is_table_or_section_context(current.name)
}

///|
fn input_attrs_type_is_hidden(attrs : Map[String, String?]) -> Bool {
  match attrs.get("type") {
    Some(Some(value)) => value[:].compare_ignore_ascii_case("hidden") == 0
    _ => false
  }
}

///|
fn Parser::handle_table_context_hidden_input_or_form_start(
  self : Parser,
  name : String,
  attrs : Map[String, String?],
  start : Int,
  error_pos : Int,
) -> Bool {
  if !self.current_is_table_or_section_context() {
    return false
  }
  if name == "input" && input_attrs_type_is_hidden(attrs) {
    self.error_at("unexpected-hidden-input-in-table", error_pos)
    self
    .current_node()
    .append_child(self.node_with_origin(@dom.element(name, attrs~), start))
    return true
  }
  if name == "form" {
    self.error_at("unexpected-form-in-table", error_pos)
    if self.form_element is None {
      let node = self.node_with_origin(@dom.element(name, attrs~), start)
      self.form_element = Some(node)
      self.current_node().append_child(node)
    }
    return true
  }
  false
}

///|
fn Parser::handle_nested_table_start_tag(
  self : Parser,
  name : String,
  tag_close_pos : Int,
) -> Bool {
  if name != "table" {
    return false
  }
  let table_index = self.table_context_without_cell_or_caption()
  if table_index < 0 {
    return false
  }
  let current = self.current_node()
  if current.kind != Element || !is_table_start_foster_target(current.name) {
    return false
  }
  self.error_at("unexpected-start-tag-implies-end-tag", tag_close_pos)
  ignore(self.close_open_element("table"))
  true
}

///|
fn Parser::report_unexpected_table_body_cell_start(
  self : Parser,
  name : String,
  tag_close_pos : Int,
) -> Unit {
  let current = self.current_node()
  if (name == "td" || name == "th") &&
    (
      self.current_is_table_or_section_context() ||
      (
        self.in_template_content_without_inner_table() &&
        current.kind == Element &&
        is_table_or_section_context(current.name)
      )
    ) {
    self.error_at("unexpected-cell-in-table-body", tag_close_pos)
  }
}

///|
fn Parser::last_open_table_cell_index(self : Parser) -> Int {
  let td_index = self.last_stack_index_of("td")
  let th_index = self.last_stack_index_of("th")
  if td_index > th_index {
    td_index
  } else {
    th_index
  }
}

///|
fn table_cell_start_closes_current_cell(name : StringView) -> Bool {
  match name {
    "caption"
    | "col"
    | "colgroup"
    | "tbody"
    | "td"
    | "tfoot"
    | "th"
    | "thead"
    | "tr" => true
    _ => false
  }
}

///|
fn Parser::close_current_table_cell_for_start(
  self : Parser,
  name : String,
) -> Bool {
  if !table_cell_start_closes_current_cell(name) {
    return false
  }
  let table_index = self.last_open_table_index()
  let cell_index = self.last_open_table_cell_index()
  if table_index < 0 || cell_index <= table_index {
    return false
  }
  while self.stack.length() > cell_index {
    ignore(self.stack.pop())
  }
  true
}

///|
fn table_row_start_closes_current_row(name : StringView) -> Bool {
  match name {
    "caption"
    | "col"
    | "colgroup"
    | "table"
    | "tbody"
    | "tfoot"
    | "thead"
    | "tr" => true
    _ => false
  }
}

///|
fn Parser::close_current_table_row_for_start(
  self : Parser,
  name : String,
) -> Unit {
  if !table_row_start_closes_current_row(name) {
    return
  }
  let table_index = self.last_open_table_index()
  if table_index < 0 || self.table_text_is_inside_cell_or_caption(table_index) {
    return
  }
  let row_index = self.last_stack_index_of("tr")
  if row_index <= table_index {
    return
  }
  while self.stack.length() > row_index {
    ignore(self.stack.pop())
  }
}

///|
fn table_body_start_closes_current_section(name : StringView) -> Bool {
  match name {
    "caption" | "col" | "colgroup" | "table" | "tbody" | "tfoot" | "thead" =>
      true
    _ => false
  }
}

///|
fn Parser::close_current_table_section_for_start(
  self : Parser,
  name : String,
) -> Unit {
  if !table_body_start_closes_current_section(name) {
    return
  }
  let table_index = self.last_open_table_index()
  if table_index < 0 || self.table_text_is_inside_cell_or_caption(table_index) {
    return
  }
  let mut section_index = -1
  let mut index = self.stack.length()
  while index > 0 {
    index -= 1
    let node = self.stack[index]
    if node.kind == Element && is_table_section_name(node.name) {
      section_index = index
      break
    }
  }
  if section_index <= table_index {
    return
  }
  while self.stack.length() > section_index {
    ignore(self.stack.pop())
  }
}

///|
fn Parser::report_form_end_tag_table_voodoo(
  self : Parser,
  name : String,
  start : Int,
) -> Unit {
  if name == "form" && self.current_is_table_or_section_context() {
    self.error_at("unexpected-end-tag-implies-table-voodoo", start)
  }
}

///|
fn Parser::table_context_without_cell_or_caption(self : Parser) -> Int {
  let table_index = self.last_open_table_index()
  if table_index < 0 || self.table_text_is_inside_cell_or_caption(table_index) {
    -1
  } else {
    table_index
  }
}

///|
fn Parser::last_table_section_index_after(
  self : Parser,
  table_index : Int,
) -> Int {
  let mut index = self.stack.length()
  while index > table_index + 1 {
    index -= 1
    let node = self.stack[index]
    if node.kind == Element && is_table_section_name(node.name) {
      return index
    }
  }
  -1
}

///|
fn Parser::table_context_keep_index_for_start(
  self : Parser,
  name : StringView,
  table_index : Int,
) -> Int {
  match name {
    "col" => {
      let colgroup_index = self.last_stack_index_of("colgroup")
      if colgroup_index > table_index {
        colgroup_index
      } else {
        table_index
      }
    }
    "td" | "th" => {
      let row_index = self.last_stack_index_of("tr")
      if row_index > table_index {
        return row_index
      }
      let section_index = self.last_table_section_index_after(table_index)
      if section_index > table_index {
        return section_index
      }
      table_index
    }
    "tr" => {
      let section_index = self.last_table_section_index_after(table_index)
      if section_index > table_index {
        section_index
      } else {
        table_index
      }
    }
    _ => table_index
  }
}

///|
fn Parser::clear_stack_to_table_context_for_start(
  self : Parser,
  name : StringView,
) -> Unit {
  if !is_table_internal_start_name(name) {
    return
  }
  let table_index = self.table_context_without_cell_or_caption()
  if table_index < 0 {
    return
  }
  let keep_index = self.table_context_keep_index_for_start(name, table_index)
  while self.stack.length() > keep_index + 1 {
    ignore(self.stack.pop())
  }
}

///|
fn Parser::table_context_start_skips_active_reconstruction(
  self : Parser,
  name : StringView,
) -> Bool {
  is_table_internal_start_name(name) &&
  self.table_context_without_cell_or_caption() >= 0
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

///|
fn Parser::current_table_last_child_is_col(self : Parser) -> Bool {
  let current = self.current_node()
  if current.kind != Element || current.name != "table" {
    return false
  }
  match current.children.last() {
    Some(child) => child.kind == Element && child.name == "col"
    None => false
  }
}
