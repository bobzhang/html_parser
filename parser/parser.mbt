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

///|
fn Parser::handle_column_group_text(
  self : Parser,
  cleaned : StringView,
  start : Int,
) -> Bool {
  let has_non_whitespace = text_has_non_ascii_whitespace(cleaned)
  let current = self.current_node()
  if current.kind == Element && current.name == "colgroup" {
    let in_template_table_context = self.in_template_content_without_inner_table()
    self.error_at("unexpected-characters-in-column-group", start)
    if has_non_whitespace {
      let whitespace = leading_ascii_whitespace(cleaned)
      if !whitespace.is_empty() {
        current.append_child(
          @dom.text(decode_entities_for_tree_text(whitespace)),
        )
      }
      ignore(self.pop_current_element_if_name("colgroup"))
      let non_whitespace = cleaned[whitespace.length():]
      let non_whitespace_start = start + whitespace.length()
      if in_template_table_context {
        self.enable_template_table_context_mode()
        ignore(
          self.report_foster_parenting_character_errors(
            non_whitespace, non_whitespace_start,
          ),
        )
      }
      if self.foster_parent_table_text(non_whitespace, non_whitespace_start) {
        return true
      }
      self
      .current_node()
      .append_child(@dom.text(decode_entities_for_tree_text(non_whitespace)))
    } else {
      current.append_child(@dom.text(decode_entities_for_tree_text(cleaned)))
      ignore(self.pop_current_element_if_name("colgroup"))
      if in_template_table_context {
        self.enable_template_table_context_mode()
      }
    }
    return true
  }
  if self.current_table_last_child_is_col() {
    self.error_at("unexpected-characters-in-column-group", start)
    if has_non_whitespace {
      if self.foster_parent_table_text(cleaned, start) {
        return true
      }
    }
  }
  false
}

///|
fn leading_ascii_whitespace(value : StringView) -> String {
  let out = StringBuilder::new(size_hint=value.length())
  for ch in value {
    if ch.is_ascii_whitespace() {
      out.write_char(ch)
    } else {
      break
    }
  }
  out.to_string()
}

///|
fn Parser::handle_fragment_context_colgroup_text(
  self : Parser,
  cleaned : StringView,
  start : Int,
) -> Bool {
  if !self.fragment_context_colgroup {
    return false
  }
  self.error_at("unexpected-characters-in-column-group", start)
  let whitespace = leading_ascii_whitespace(cleaned)
  if !whitespace.is_empty() {
    self
    .current_node()
    .append_child(@dom.text(decode_entities_for_tree_text(whitespace)))
  }
  true
}

///|
fn Parser::handle_template_column_group_text(
  self : Parser,
  cleaned : StringView,
  start : Int,
) -> Bool {
  if !self.template_column_group_mode_active() {
    return false
  }
  if !self.in_template_content_without_inner_table() {
    self.disable_current_template_column_group_mode()
    return false
  }
  let whitespace = leading_ascii_whitespace(cleaned)
  if !whitespace.is_empty() {
    self
    .current_node()
    .append_child(@dom.text(decode_entities_for_tree_text(whitespace)))
  }
  self.error_at("unexpected-characters-in-template-column-group", start)
  true
}

///|
fn Parser::handle_template_column_group_start_tag(
  self : Parser,
  name : String,
  attrs : Map[String, String?],
  start : Int,
) -> Bool {
  if !self.template_column_group_mode_active() {
    return false
  }
  if !self.in_template_content_without_inner_table() {
    self.disable_current_template_column_group_mode()
    return false
  }
  if name == "html" || name == "template" {
    return false
  }
  if name == "col" {
    self
    .current_node()
    .append_child(self.node_with_origin(@dom.element("col", attrs~), start))
    return true
  }
  if name == "colgroup" {
    self.error_at("unexpected-start-tag-implies-end-tag", start)
  } else {
    self.error_at("unexpected-start-tag-in-template-column-group", start)
  }
  true
}

///|
fn Parser::handle_template_table_context_start_tag(
  self : Parser,
  name : String,
  attrs : Map[String, String?],
  start : Int,
) -> Bool {
  if !self.template_table_context_mode_active() {
    return false
  }
  if name == "table" {
    self.error_at("unexpected-start-tag-implies-end-tag", start)
    self.error_at("unexpected-end-tag", start)
    return true
  }
  if name == "caption" {
    let node = self.node_with_origin(@dom.element("caption", attrs~), start)
    self.current_node().append_child(node)
    self.stack.push(node)
    self.push_active_formatting_marker()
    self.disable_current_template_table_context_mode()
    return true
  }
  if name == "col" {
    let colgroup = @dom.element("colgroup")
    self.current_node().append_child(colgroup)
    colgroup.append_child(
      self.node_with_origin(@dom.element("col", attrs~), start),
    )
    self.stack.push(colgroup)
    self.disable_current_template_table_context_mode()
    self.template_detached_column_group_mode = !self.in_template_content_without_inner_table()
    return true
  }
  if name == "colgroup" {
    let node = self.node_with_origin(@dom.element("colgroup", attrs~), start)
    self.current_node().append_child(node)
    self.stack.push(node)
    self.disable_current_template_table_context_mode()
    self.template_detached_column_group_mode = !self.in_template_content_without_inner_table()
    return true
  }
  if name == "tbody" || name == "tfoot" || name == "thead" {
    let node = self.node_with_origin(@dom.element(name, attrs~), start)
    self.current_node().append_child(node)
    self.stack.push(node)
    self.disable_current_template_table_context_mode()
    return true
  }
  if name == "tr" || name == "td" || name == "th" {
    let section = @dom.element("tbody")
    self.current_node().append_child(section)
    self.stack.push(section)
    if name == "td" || name == "th" {
      self.error_at("unexpected-cell-in-table-body", start)
    }
    let row = if name == "tr" {
      self.node_with_origin(@dom.element("tr"), start)
    } else {
      @dom.element("tr")
    }
    section.append_child(row)
    self.stack.push(row)
    if name == "td" || name == "th" {
      let cell = self.node_with_origin(@dom.element(name, attrs~), start)
      row.append_child(cell)
      self.stack.push(cell)
    }
    self.disable_current_template_table_context_mode()
    return true
  }
  false
}

///|
fn Parser::report_template_table_context_fostered_start(
  self : Parser,
  name : StringView,
  start : Int,
) -> Unit {
  if !self.template_table_context_mode_active() {
    return
  }
  match name {
    "html" | "script" | "style" | "template" => ()
    _ => self.error_at("foster-parenting-start-tag", start)
  }
}

///|
fn Parser::handle_template_column_group_end_tag(
  self : Parser,
  name : String,
  start : Int,
) -> Bool {
  if !self.template_column_group_mode_active() {
    return false
  }
  if !self.in_template_content_without_inner_table() {
    self.disable_current_template_column_group_mode()
    return false
  }
  if name == "template" {
    self.disable_current_template_column_group_mode()
    return false
  }
  if name == "col" || name == "colgroup" {
    self.error_at("unexpected-end-tag", start)
    return true
  }
  self.disable_current_template_column_group_mode()
  let template_index = self.last_open_template_index()
  if template_index >= 0 {
    while self.stack.length() > template_index {
      ignore(self.stack.pop())
    }
  }
  self.enable_template_table_context_mode()
  false
}

///|
fn Parser::handle_template_detached_column_group_end_tag(
  self : Parser,
  name : String,
  start : Int,
) -> Bool {
  if !self.template_detached_column_group_mode {
    return false
  }
  if name == "template" {
    ignore(self.pop_current_element_if_name("colgroup"))
    self.template_detached_column_group_mode = false
    return true
  }
  if name == "colgroup" {
    self.error_at("unexpected-end-tag-implies-table-voodoo", start)
    ignore(self.pop_current_element_if_name("colgroup"))
    self.template_detached_column_group_mode = false
    return true
  }
  if name == "col" {
    self.error_at("unexpected-end-tag", start)
    return true
  }
  false
}

///|
fn Parser::handle_fragment_context_colgroup_start_tag(
  self : Parser,
  name : String,
  attrs : Map[String, String?],
  start : Int,
) -> Bool {
  if !self.fragment_context_colgroup {
    return false
  }
  if name == "col" {
    self
    .current_node()
    .append_child(self.node_with_origin(@dom.element("col", attrs~), start))
    return true
  }
  if name == "colgroup" {
    self.error_at("unexpected-start-tag-implies-end-tag", start)
  } else {
    self.error_at("unexpected-start-tag-in-column-group", start)
  }
  true
}

///|
fn Parser::handle_fragment_context_colgroup_end_tag(
  self : Parser,
  name : String,
  start : Int,
) -> Bool {
  if !self.fragment_context_colgroup {
    return false
  }
  if name == "col" || name == "colgroup" {
    self.error_at("unexpected-end-tag", start)
    return true
  }
  if table_context_end_tag_uses_table_voodoo(name) {
    self.error_at("unexpected-end-tag-implies-table-voodoo", start)
  }
  false
}

///|
fn Parser::close_current_column_group_for_start(
  self : Parser,
  name : String,
  start : Int,
) -> Unit {
  if name == "col" {
    return
  }
  match self.stack.last() {
    Some(node) if node.kind == Element && node.name == "colgroup" => {
      if name == "colgroup" {
        self.error_at("unexpected-start-tag-implies-end-tag", start)
      }
      ignore(self.stack.pop())
    }
    _ => ()
  }
}

///|
fn Parser::close_current_column_group_for_end(
  self : Parser,
  name : String,
) -> Unit {
  if name == "col" || name == "colgroup" {
    return
  }
  match self.stack.last() {
    Some(node) if node.kind == Element && node.name == "colgroup" =>
      ignore(self.stack.pop())
    _ => ()
  }
}

///|
fn caption_start_closes_current_caption(name : StringView) -> Bool {
  match name {
    "caption"
    | "col"
    | "colgroup"
    | "table"
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
fn Parser::close_current_caption_for_start(
  self : Parser,
  name : String,
  tag_close_pos : Int,
) -> Bool {
  if !caption_start_closes_current_caption(name) {
    return false
  }
  let table_index = self.last_open_table_index()
  let caption_index = self.last_stack_index_of("caption")
  if table_index < 0 {
    let template_index = self.last_open_template_index()
    if template_index < 0 || caption_index <= template_index {
      return false
    }
    self.error_at("unexpected-start-tag-implies-end-tag", tag_close_pos)
    self.close_open_caption_element()
    self.enable_template_table_context_mode()
    return true
  }
  if caption_index <= table_index {
    return false
  }
  self.error_at("unexpected-start-tag-implies-end-tag", tag_close_pos)
  self.close_open_caption_element()
  true
}

///|
fn Parser::handle_caption_end_tag(
  self : Parser,
  name : String,
  start : Int,
) -> Bool {
  let table_index = self.last_open_table_index()
  let caption_index = self.last_stack_index_of("caption")
  if table_index < 0 {
    let template_index = self.last_open_template_index()
    if template_index < 0 || caption_index <= template_index {
      return false
    }
    match name {
      "caption" => {
        self.close_open_caption_element()
        self.enable_template_table_context_mode()
        true
      }
      "tbody" | "tfoot" | "thead" => {
        self.error_at("unexpected-end-tag", start)
        true
      }
      _ => false
    }
  } else if caption_index <= table_index {
    return false
  } else {
    match name {
      "caption" => {
        self.close_open_caption_element()
        true
      }
      "tbody" | "tfoot" | "thead" => {
        self.error_at("unexpected-end-tag", start)
        true
      }
      "table" => {
        self.close_open_caption_element()
        false
      }
      _ => false
    }
  }
}

///|
fn fragment_context_caption_structural_start(name : StringView) -> Bool {
  match name {
    "caption"
    | "col"
    | "colgroup"
    | "table"
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
fn Parser::handle_fragment_context_caption_start_tag(
  self : Parser,
  name : String,
  start : Int,
) -> Bool {
  if !self.fragment_context_caption ||
    !fragment_context_caption_structural_start(name) {
    return false
  }
  self.error_at("unexpected-start-tag-implies-end-tag", start)
  self.error_at("unexpected-end-tag", start)
  if name == "table" {
    self.fragment_context_caption = false
    return false
  }
  true
}

///|
fn table_context_end_tag_uses_table_voodoo(name : StringView) -> Bool {
  match name {
    "body"
    | "caption"
    | "col"
    | "colgroup"
    | "form"
    | "html"
    | "table"
    | "tbody"
    | "td"
    | "tfoot"
    | "th"
    | "thead"
    | "tr" => false
    _ => true
  }
}

///|
fn table_context_end_tag_is_ignored(name : StringView) -> Bool {
  match name {
    "body"
    | "caption"
    | "col"
    | "colgroup"
    | "html"
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
fn Parser::in_table_body_mode_context(self : Parser) -> Bool {
  let table_index = self.table_context_without_cell_or_caption()
  if table_index < 0 {
    return false
  }
  let current = self.current_node()
  current.kind == Element && is_table_start_foster_target(current.name)
}

///|
fn Parser::report_table_context_end_tag_voodoo(
  self : Parser,
  name : String,
  start : Int,
) -> Unit {
  if self.template_table_context_mode_active() &&
    table_context_end_tag_uses_table_voodoo(name) {
    self.error_at("unexpected-end-tag-implies-table-voodoo", start)
    return
  }
  if self.in_table_body_mode_context() &&
    table_context_end_tag_uses_table_voodoo(name) {
    self.error_at("unexpected-end-tag-implies-table-voodoo", start)
  }
}

///|
fn Parser::handle_table_context_ignored_end_tag(
  self : Parser,
  name : String,
  start : Int,
) -> Bool {
  if !self.in_table_body_mode_context() ||
    !table_context_end_tag_is_ignored(name) {
    return false
  }
  let table_index = self.table_context_without_cell_or_caption()
  if self.last_stack_index_of(name) > table_index {
    return false
  }
  self.error_at("unexpected-end-tag", start)
  true
}

///|
fn Parser::handle_fragment_context_table_start_tag(
  self : Parser,
  name : String,
  start : Int,
) -> Bool {
  if name != "table" {
    return false
  }
  let table_index = self.table_context_without_cell_or_caption()
  if !self.table_index_is_fragment_context_table(table_index) {
    return false
  }
  let current = self.current_node()
  if current.kind == Element && is_table_start_foster_target(current.name) {
    self.error_at("unexpected-start-tag-implies-end-tag", start)
    self.error_at("unexpected-end-tag", start)
    return true
  }
  false
}

///|
fn fragment_context_table_section_ignores_start(name : StringView) -> Bool {
  match name {
    "caption" | "col" | "colgroup" | "table" | "tbody" | "tfoot" | "thead" =>
      true
    _ => false
  }
}

///|
fn Parser::handle_fragment_context_table_section_start_tag(
  self : Parser,
  name : String,
  start : Int,
) -> Bool {
  if !fragment_context_table_section_ignores_start(name) {
    return false
  }
  match self.fragment_context_table_section {
    Some(section) => {
      let current = self.current_node()
      if physical_equal(current, section) {
        self.error_at("unexpected-start-tag", start)
        return true
      }
      false
    }
    None => false
  }
}

///|
fn fragment_context_table_row_ignores_start(name : StringView) -> Bool {
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
fn Parser::handle_fragment_context_table_row_start_tag(
  self : Parser,
  name : String,
  start : Int,
) -> Bool {
  if !fragment_context_table_row_ignores_start(name) {
    return false
  }
  match self.fragment_context_table_row {
    Some(row) => {
      let current = self.current_node()
      if physical_equal(current, row) {
        self.error_at("unexpected-start-tag-implies-end-tag", start)
        return true
      }
      false
    }
    None => false
  }
}

///|
fn fragment_context_table_cell_ignores_start(name : StringView) -> Bool {
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
fn Parser::handle_fragment_context_table_cell_start_tag(
  self : Parser,
  name : String,
  start : Int,
) -> Bool {
  if !fragment_context_table_cell_ignores_start(name) {
    return false
  }
  match self.fragment_context_table_cell {
    Some(cell) => {
      let current = self.current_node()
      if physical_equal(current, cell) {
        self.error_at("unexpected-start-tag-in-cell-fragment", start)
        return true
      }
      false
    }
    None => false
  }
}

///|
fn Parser::handle_fragment_context_table_end_tag(
  self : Parser,
  name : String,
  start : Int,
) -> Bool {
  if name != "table" {
    return false
  }
  let table_index = self.last_open_table_index()
  if !self.table_index_is_fragment_context_table(table_index) {
    return false
  }
  self.error_at("unexpected-end-tag", start)
  true
}

///|
fn Parser::handle_fragment_context_table_wrapper_end_tag(
  self : Parser,
  name : String,
  start : Int,
) -> Bool {
  if name == "td" || name == "th" {
    match self.fragment_context_table_cell {
      Some(cell) if self.last_stack_index_of_node(cell) >= 0 => {
        self.error_at("unexpected-end-tag", start)
        return true
      }
      _ => ()
    }
  }
  if name == "tr" {
    match self.fragment_context_table_row {
      Some(row) if self.last_stack_index_of_node(row) >= 0 => {
        self.error_at("unexpected-end-tag", start)
        return true
      }
      _ => ()
    }
  }
  if is_table_section_name(name) {
    match self.fragment_context_table_section {
      Some(section) if self.last_stack_index_of_node(section) >= 0 => {
        self.error_at("unexpected-end-tag", start)
        return true
      }
      _ => ()
    }
  }
  false
}

///|
fn Parser::handle_table_end_tag(
  self : Parser,
  name : String,
  tag_close_pos : Int,
) -> Bool {
  if name != "table" || !self.close_open_element("table") {
    return false
  }
  if self.pending_table_view_implied_end_tag {
    self.error_at("unexpected-implied-end-tag-in-table-view", tag_close_pos)
    self.pending_table_view_implied_end_tag = false
  }
  true
}

///|
fn table_structural_end_tag_can_close(name : StringView) -> Bool {
  match name {
    "caption" | "colgroup" | "tbody" | "td" | "tfoot" | "th" | "thead" | "tr" =>
      true
    _ => false
  }
}

///|
fn Parser::handle_table_structural_end_tag(
  self : Parser,
  name : String,
) -> Bool {
  table_structural_end_tag_can_close(name) && self.close_open_element(name)
}

///|
fn template_table_context_end_tag_defers_voodoo(name : StringView) -> Bool {
  match name {
    "colgroup" | "tr" => true
    _ => false
  }
}

///|
fn template_table_context_section_end_tag_reports_unexpected(
  name : StringView,
) -> Bool {
  match name {
    "tbody" | "tfoot" | "thead" => true
    _ => false
  }
}

///|
fn Parser::handle_template_table_context_end_tag(
  self : Parser,
  name : String,
  start : Int,
) -> Bool {
  if !self.in_template_content_without_inner_table() {
    return false
  }
  if template_table_context_end_tag_defers_voodoo(name) &&
    self.close_open_element(name) {
    self.enable_template_table_context_mode()
    return true
  }
  if template_table_context_section_end_tag_reports_unexpected(name) &&
    self.close_open_element(name) {
    self.error_at("unexpected-end-tag", start)
    self.enable_template_table_context_mode()
    return true
  }
  false
}

///|
fn Parser::handle_template_end_tag(
  self : Parser,
  name : String,
  error_pos : Int,
  source_end_tag? : String,
) -> Bool {
  if name != "template" {
    return false
  }
  let template_index = self.last_open_template_index()
  if template_index < 0 {
    self.error_at("unexpected-end-tag", error_pos)
    return true
  }
  let template = self.stack[template_index]
  match source_end_tag {
    Some(raw) => set_node_source_end_tag(template, raw)
    None => ()
  }
  self.disable_template_column_group_mode_for_node(template)
  self.disable_template_table_context_mode_for_node(template)
  self.template_detached_column_group_mode = false
  while self.stack.length() > template_index {
    ignore(self.stack.pop())
  }
  self.clear_active_formatting_to_marker()
  true
}

///|
fn Parser::parse_all(self : Parser) -> Unit {
  while !self.is_eof() {
    let start = self.pos
    if self.current().unwrap() == '<' {
      if self.starts_with("<!--") {
        self.parse_comment()
      } else if self.starts_with("</") {
        self.parse_end_tag()
      } else if starts_with_case_insensitive(self.input, self.pos, "<!doctype") {
        self.parse_doctype()
      } else if self.starts_with("<!") {
        self.parse_markup_declaration()
      } else {
        self.parse_start_tag_or_text()
      }
    } else {
      while !self.is_eof() && !self.starts_with("<") {
        self.report_current_noncharacter()
        ignore(self.advance_char())
      }
      let view = self.input[start:self.pos]
      self.flush_deferred_initial_doctype_error()
      self.append_text(view, start)
    }
  }
}

///|
fn Parser::parse_end_tag(self : Parser) -> Unit {
  let start = self.pos
  self.pos += 2
  match self.current() {
    Some('>') => {
      self.error_at("empty-end-tag", self.pos)
      ignore(self.advance_char())
      self.append_sanitize_escape_source_text(start, self.pos)
      return
    }
    Some(ch) if !@tok.is_tag_name_start(ch) => {
      self.error_at("invalid-first-character-of-tag-name", self.pos)
      self.parse_bogus_comment(start)
      self.append_sanitize_escape_source_text(start, self.pos)
      return
    }
    None => {
      self.error_at_eof("eof-before-tag-name")
      self.current_node().append_child(self.text_at("</", start))
      return
    }
    _ => ()
  }
  let name_start = self.pos
  while !self.is_eof() {
    let ch = self.current().unwrap()
    if ch == '>' || ch == '/' || ch.is_ascii_whitespace() {
      break
    } else {
      ignore(self.advance_char())
    }
  }
  let (name, name_errors) = @tok.parse_lower_name_value_replacing_nulls(
    self.input,
    name_start,
    self.pos,
  )
  for error in name_errors {
    self.error_at(error.code, error.offset)
  }
  let attrs : Map[String, String?] = {}
  let mut noncanonical_end_tag = false
  let mut closed = false
  while !self.is_eof() {
    self.skip_ascii_whitespace()
    let ch = self.current().unwrap()
    match ch {
      '>' => {
        ignore(self.advance_char())
        closed = true
        break
      }
      '/' => {
        ignore(self.advance_char())
        noncanonical_end_tag = true
        if self.current() == Some('>') {
          ignore(self.advance_char())
          closed = true
          break
        } else {
          self.error_at("unexpected-character-after-solidus-in-tag", self.pos)
        }
      }
      _ => {
        noncanonical_end_tag = true
        self.parse_attribute(attrs)
      }
    }
  }
  if !closed {
    self.error_at_eof("eof-in-tag")
    if noncanonical_end_tag || name == "" {
      self.append_sanitize_escape_source_text(start, self.pos)
    }
    return
  }
  let tag_close_pos = self.pos - 1
  if noncanonical_end_tag {
    self.append_sanitize_escape_source_text(start, self.pos)
  }
  self.flush_deferred_initial_doctype_error()
  if self.handle_before_html_end_tag(name, start, self.pos - 1) {
    return
  }
  if self.handle_foreign_content_end_tag(name, start) {
    return
  }
  if self.handle_document_frameset_end_tag(name, tag_close_pos) {
    return
  }
  if self.handle_template_detached_column_group_end_tag(name, start) {
    return
  }
  if self.handle_template_column_group_end_tag(name, start) {
    return
  }
  if self.handle_fragment_context_colgroup_end_tag(name, start) {
    return
  }
  if self.handle_fragment_context_table_wrapper_end_tag(name, start) {
    return
  }
  if self.handle_foster_parented_end_tag(name, start) {
    return
  }
  if self.handle_disabled_head_noscript_end_tag(name, start) {
    return
  }
  if self.handle_duplicate_head_end_tag(name, start) {
    return
  }
  self.close_current_column_group_for_end(name)
  if self.handle_caption_end_tag(name, start) {
    return
  }
  if self.handle_fragment_context_table_end_tag(name, start) {
    return
  }
  if self.handle_table_context_ignored_end_tag(name, start) {
    return
  }
  if self.handle_template_table_context_end_tag(name, start) {
    return
  }
  if self.handle_table_structural_end_tag(name) {
    return
  }
  if self.handle_table_end_tag(name, tag_close_pos) {
    return
  }
  if name == "br" && self.in_table_body_mode_context() {
    self.error_at("unexpected-end-tag", start)
    self.report_table_context_end_tag_voodoo(name, tag_close_pos)
    self.close_open_p_element()
    self.insert_body_mode_node(self.node_with_origin(@dom.element("br"), start))
    return
  }
  self.report_table_context_end_tag_voodoo(name, start)
  if name == "br" {
    self.error_at("unexpected-end-tag", tag_close_pos)
    self.close_open_p_element()
    self.insert_body_mode_node(self.node_with_origin(@dom.element("br"), start))
    return
  }
  if self.handle_select_end_tag(name, tag_close_pos) {
    return
  }
  if active_formatting_element_name(name) {
    self.adoption_agency(name, tag_close_pos)
    return
  }
  if name == "p" {
    if !self.close_open_element("p") {
      self.error_at("unexpected-end-tag", tag_close_pos)
      self.insert_body_mode_node(
        self.node_with_origin(@dom.element("p"), start),
      )
    }
    return
  }
  if is_heading_element_name(name) {
    self.close_open_heading_element(name, start)
    return
  }
  if name == "form" {
    self.report_form_end_tag_table_voodoo(name, start)
    self.handle_form_end_tag(start)
    return
  }
  if self.handle_applet_like_end_tag(name, tag_close_pos) {
    return
  }
  if self.handle_template_end_tag(
      name,
      tag_close_pos,
      source_end_tag=self.source_tag_slice(start, tag_close_pos),
    ) {
    return
  }
  if self.fragment_end_tag_is_ignored(name) {
    return
  }
  if name == "ruby" {
    self.close_ruby_end_tag(start)
    return
  }
  if self.handle_document_after_body_html_end_tag(name, start) {
    return
  }
  if self.handle_document_body_or_html_end_tag(name, tag_close_pos) {
    return
  }
  if name != "" {
    self.pop_until(
      name,
      tag_close_pos,
      source_end_tag=self.source_tag_slice(start, tag_close_pos),
    )
  }
}

///|
fn Parser::is_fragment_parser(self : Parser) -> Bool {
  self.root.kind == Fragment
}

///|
fn Parser::uses_document_frameset_rules(self : Parser) -> Bool {
  !self.is_fragment_parser() || self.fragment_context_html
}

///|
fn Parser::handle_document_after_body_html_end_tag(
  self : Parser,
  name : StringView,
  start : Int,
) -> Bool {
  if self.is_fragment_parser() ||
    !self.document_after_body ||
    name != "html" ||
    self.has_open_element("html") {
    return false
  }
  self.error_at("unexpected-token-after-body", start)
  true
}

///|
fn Parser::handle_document_body_or_html_end_tag(
  self : Parser,
  name : String,
  pos : Int,
) -> Bool {
  if self.is_fragment_parser() || (name != "body" && name != "html") {
    return false
  }
  if !self.has_open_element(name) {
    if name == "body" && self.has_open_element("html") {
      return true
    }
    return false
  }
  self.pop_until(name, pos)
  self.document_after_body = true
  true
}

///|
fn Parser::fragment_end_tag_is_ignored(
  self : Parser,
  name : StringView,
) -> Bool {
  if !self.is_fragment_parser() {
    return false
  }
  match name {
    "html" => {
      if self.fragment_context_html {
        self.fragment_context_html_after_body = true
      }
      true
    }
    "body" => !self.in_select_insertion_mode()
    _ => false
  }
}

///|
fn Parser::document_has_element_child(self : Parser) -> Bool {
  for child in self.root.children {
    if child.kind == Element {
      return true
    }
  }
  false
}

///|
fn Parser::handle_before_html_end_tag(
  self : Parser,
  name : StringView,
  start : Int,
  error_pos : Int,
) -> Bool {
  if !self.before_html_phase ||
    self.is_fragment_parser() ||
    self.document_has_element_child() {
    return false
  }
  self.before_html_phase = false
  match name {
    "html" | "head" | "body" => true
    "br" => {
      self.error_at("unexpected-end-tag", error_pos)
      self.insert_body_mode_node(
        self.node_with_origin(@dom.element("br"), start),
      )
      true
    }
    _ => {
      self.error_at("unexpected-end-tag-before-html", error_pos)
      true
    }
  }
}

///|
fn Parser::handle_document_frameset_end_tag(
  self : Parser,
  name : String,
  tag_close_pos : Int,
) -> Bool {
  if self.is_fragment_parser() && !self.fragment_context_html {
    return false
  }
  if self.after_frameset {
    if name == "html" {
      ()
    } else if name == "frameset" {
      self.error_at("unexpected-token-after-frameset", tag_close_pos)
    } else {
      self.error_at("unexpected-token-after-frameset", tag_close_pos)
      self.error_at("unexpected-token-in-frameset", tag_close_pos)
    }
    return true
  }
  if self.detached_frameset_mode {
    if name == "frameset" {
      self.error_at("unexpected-end-tag", tag_close_pos)
    } else {
      self.error_at("unexpected-token-in-frameset", tag_close_pos)
    }
    return true
  }
  if !self.has_open_element("frameset") {
    return false
  }
  if self.frameset_reprocesses_in_body_mode {
    if name != "frameset" {
      return false
    }
    ignore(self.close_open_element("frameset"))
    if !self.has_open_element("frameset") {
      self.frameset_reprocesses_in_body_mode = false
    }
    return true
  }
  if name == "frameset" {
    ignore(self.close_open_element("frameset"))
    if !self.has_open_element("frameset") {
      self.after_frameset = true
    }
  } else {
    self.error_at("unexpected-token-in-frameset", tag_close_pos)
  }
  true
}

///|
fn Parser::pop_until(
  self : Parser,
  name : String,
  pos : Int,
  source_end_tag? : String,
) -> Unit {
  let mut found = false
  for node in self.stack {
    if node.kind == Element && names_match_end_tag(node, name) {
      found = true
    }
  }
  if !found {
    self.error_at("unexpected-end-tag", pos)
    return
  }
  while self.stack.length() > 1 {
    match self.stack.last() {
      Some(node) if node.kind == Element &&
        node.name != name &&
        is_implied_end_tag_name(node.name) => ignore(self.stack.pop())
      _ => break
    }
  }
  match self.stack.last() {
    Some(node) if node.kind == Element && names_match_end_tag(node, name) => ()
    _ => self.error_at("end-tag-too-early", pos)
  }
  while self.stack.length() > 1 {
    let node = self.stack.pop().unwrap()
    if node.kind == Element && names_match_end_tag(node, name) {
      match source_end_tag {
        Some(raw) => set_node_source_end_tag(node, raw)
        None => ()
      }
      break
    }
  }
}

///|
fn is_implied_end_tag_name(name : StringView) -> Bool {
  match name {
    "dd"
    | "dt"
    | "li"
    | "option"
    | "optgroup"
    | "p"
    | "rb"
    | "rp"
    | "rt"
    | "rtc" => true
    _ => false
  }
}

///|
fn Parser::generate_implied_end_tags(self : Parser, exclude : String?) -> Unit {
  while self.stack.length() > 1 {
    match self.stack.last() {
      Some(node) if node.kind == Element &&
        is_implied_end_tag_name(node.name) &&
        !(exclude is Some(excluded) && node.name == excluded) =>
        ignore(self.stack.pop())
      _ => break
    }
  }
}

///|
fn Parser::close_open_element(self : Parser, name : String) -> Bool {
  let mut found = false
  for node in self.stack {
    if node.kind == Element && node.name == name {
      found = true
    }
  }
  if !found {
    return false
  }
  while self.stack.length() > 1 {
    let node = self.stack.pop().unwrap()
    if node.kind == Element && node.name == name {
      break
    }
  }
  true
}

///|
fn Parser::current_is_disabled_head_noscript(self : Parser) -> Bool {
  if self.scripting_enabled {
    return false
  }
  let current = self.current_node()
  if !(current.kind == Element && current.name == "noscript") {
    return false
  }
  for node in self.stack {
    if physical_equal(node, current) {
      return false
    }
    if node.kind == Element && node.name == "head" {
      return true
    }
  }
  false
}

///|
fn disabled_head_noscript_allows_start(name : StringView) -> Bool {
  match name {
    "basefont" | "bgsound" | "link" | "meta" | "noframes" | "style" => true
    _ => false
  }
}

///|
fn Parser::current_is_document_head(self : Parser) -> Bool {
  let current = self.current_node()
  if !(current.kind == Element && current.name == "head") {
    return false
  }
  match current.parent {
    Some(parent) =>
      parent.kind == Document ||
      parent.kind == Fragment ||
      (parent.kind == Element && parent.name == "html")
    None => false
  }
}

///|
fn Parser::close_current_document_head_for_start(
  self : Parser,
  name : StringView,
  start : Int,
) -> Bool {
  if !self.current_is_document_head() {
    return false
  }
  if is_document_head_element_name(name) {
    return false
  }
  if name == "head" {
    self.error_at("unexpected-start-tag", start)
    ignore(self.stack.pop())
    let duplicate = @dom.element("head")
    self.current_node().append_child(duplicate)
    self.stack.push(duplicate)
    self.duplicate_head_element = Some(duplicate)
    return true
  }
  match self.stack.pop() {
    Some(node) =>
      if self.duplicate_head_element is Some(duplicate) &&
        physical_equal(node, duplicate) {
        self.duplicate_head_element = None
      }
    None => ()
  }
  false
}

///|
fn Parser::open_html_element(self : Parser) -> @dom.Node? {
  for node in self.stack {
    if node.kind == Element && node.name == "html" {
      return Some(node)
    }
  }
  document_html_element(self.root)
}

///|
fn Parser::stack_contains_node(self : Parser, target : @dom.Node) -> Bool {
  for node in self.stack {
    if physical_equal(node, target) {
      return true
    }
  }
  false
}

///|
fn active_formatting_element_name(name : StringView) -> Bool {
  match name {
    "a"
    | "b"
    | "big"
    | "code"
    | "em"
    | "font"
    | "i"
    | "nobr"
    | "s"
    | "small"
    | "strike"
    | "strong"
    | "tt"
    | "u" => true
    _ => false
  }
}

///|
fn Parser::append_active_formatting_entry(
  self : Parser,
  node : @dom.Node,
) -> Unit {
  match node.ns {
    Some(ns) =>
      self.active_formatting.push({
        marker: false,
        name: node.name,
        ns,
        attrs: node.attrs.copy(),
        node,
      })
    None => ()
  }
}

///|
fn Parser::active_formatting_index(self : Parser, name : StringView) -> Int {
  let target = name.to_owned()
  let mut index = self.active_formatting.length()
  while index > 0 {
    index -= 1
    let entry = self.active_formatting[index]
    if entry.marker {
      break
    }
    if entry.name == target {
      return index
    }
  }
  -1
}

///|
fn formatting_attrs_equal(
  left : Map[String, String?],
  right : Map[String, String?],
) -> Bool {
  for name, value in left {
    match right.get(name) {
      Some(other) if other == value => ()
      _ => return false
    }
  }
  for name, _ in right {
    if !left.contains(name) {
      return false
    }
  }
  true
}

///|
fn Parser::active_formatting_duplicate_index(
  self : Parser,
  name : StringView,
  attrs : Map[String, String?],
) -> Int {
  let target = name.to_owned()
  let mut first_match = -1
  let mut match_count = 0
  let mut index = 0
  while index < self.active_formatting.length() {
    let entry = self.active_formatting[index]
    if entry.marker {
      first_match = -1
      match_count = 0
    } else if entry.name == target && formatting_attrs_equal(entry.attrs, attrs) {
      if first_match < 0 {
        first_match = index
      }
      match_count += 1
    }
    index += 1
  }
  if match_count >= 3 {
    first_match
  } else {
    -1
  }
}

///|
fn Parser::remove_last_active_formatting_by_name(
  self : Parser,
  name : StringView,
) -> Unit {
  let target = name.to_owned()
  let mut index = self.active_formatting.length()
  while index > 0 {
    index -= 1
    let entry = self.active_formatting[index]
    if entry.marker {
      break
    }
    if entry.name == target {
      self.remove_active_formatting_index(index)
      return
    }
  }
}

///|
fn Parser::remove_last_open_element_by_name(
  self : Parser,
  name : StringView,
) -> Unit {
  let target = name.to_owned()
  let mut index = self.stack.length()
  while index > 0 {
    index -= 1
    let node = self.stack[index]
    if node.kind == Element && node.name == target {
      ignore(self.stack.remove(index))
      return
    }
  }
}

///|
fn Parser::prepare_active_formatting_start(
  self : Parser,
  name : StringView,
  start : Int,
) -> Unit {
  if name == "a" && self.active_formatting_index(name) >= 0 {
    self.error_at("unexpected-start-tag-implies-end-tag", start)
    self.adoption_agency(name, start)
    self.remove_last_active_formatting_by_name(name)
    self.remove_last_open_element_by_name(name)
  } else if name == "nobr" && self.has_open_element_in_default_scope("nobr") {
    self.adoption_agency(name, start)
    self.remove_last_active_formatting_by_name(name)
    self.remove_last_open_element_by_name(name)
  }
}

///|
fn Parser::active_formatting_index_by_node(
  self : Parser,
  target : @dom.Node,
) -> Int {
  let mut index = self.active_formatting.length()
  while index > 0 {
    index -= 1
    let entry = self.active_formatting[index]
    if !entry.marker && physical_equal(entry.node, target) {
      return index
    }
  }
  -1
}

///|
fn Parser::active_formatting_orphan_anchor_index(self : Parser) -> Int {
  let mut index = self.active_formatting.length()
  while index > 0 {
    index -= 1
    let entry = self.active_formatting[index]
    if entry.marker {
      break
    }
    if entry.name == "a" && !self.stack_contains_node(entry.node) {
      return index
    }
  }
  -1
}

///|
fn Parser::stack_index_by_node(self : Parser, target : @dom.Node) -> Int {
  let mut index = 0
  while index < self.stack.length() {
    if physical_equal(self.stack[index], target) {
      return index
    }
    index += 1
  }
  -1
}

///|
fn formatting_entry_with_node(
  entry : FormattingEntry,
  node : @dom.Node,
) -> FormattingEntry {
  {
    marker: false,
    name: entry.name,
    ns: entry.ns,
    attrs: entry.attrs.copy(),
    node,
  }
}

///|
fn element_from_formatting_entry(entry : FormattingEntry) -> @dom.Node {
  let node = @dom.element(entry.name, attrs=entry.attrs.copy(), ns=entry.ns)
  copy_node_origin_from(node, entry.node)
  node
}

///|
fn Parser::remove_active_formatting_index(self : Parser, index : Int) -> Unit {
  ignore(self.active_formatting.remove(index))
}

///|
fn Parser::push_active_formatting_marker(self : Parser) -> Unit {
  self.active_formatting.push({
    marker: true,
    name: "",
    ns: "",
    attrs: {},
    node: self.root,
  })
}

///|
fn Parser::clear_active_formatting_to_marker(self : Parser) -> Unit {
  while !self.active_formatting.is_empty() {
    match self.active_formatting.pop() {
      Some(entry) if entry.marker => return
      _ => ()
    }
  }
}

///|
fn Parser::close_open_caption_element(self : Parser) -> Unit {
  ignore(self.close_open_element("caption"))
  self.clear_active_formatting_to_marker()
}

///|
fn applet_like_element_name(name : StringView) -> Bool {
  match name {
    "applet" | "marquee" | "object" => true
    _ => false
  }
}

///|
fn active_formatting_marker_element_name(name : StringView) -> Bool {
  match name {
    "caption" | "template" => true
    _ => applet_like_element_name(name)
  }
}

///|
fn Parser::handle_applet_like_end_tag(
  self : Parser,
  name : String,
  pos : Int,
) -> Bool {
  if !applet_like_element_name(name) {
    return false
  }
  if !self.has_open_element_in_default_scope(name) {
    self.error_at("unexpected-end-tag", pos)
    return true
  }
  while self.stack.length() > 1 {
    match self.stack.pop() {
      Some(node) if node.kind == Element && node.name == name => break
      _ => ()
    }
  }
  self.clear_active_formatting_to_marker()
  true
}

///|
fn Parser::adoption_agency(
  self : Parser,
  subject : StringView,
  pos : Int,
) -> Unit {
  let subject_name = subject.to_owned()
  match self.stack.last() {
    Some(current) if current.kind == Element &&
      current.name == subject_name &&
      self.active_formatting_index(subject) < 0 => {
      ignore(self.close_open_element(subject_name))
      return
    }
    _ => ()
  }
  for _ in 0..<8 {
    let formatting_index = self.active_formatting_index(subject)
    if formatting_index < 0 {
      self.error_at("adoption-agency-1.3", pos)
      return
    }
    let formatting_element = self.active_formatting[formatting_index].node
    let formatting_open_index = self.stack_index_by_node(formatting_element)
    if formatting_open_index < 0 {
      self.error_at("adoption-agency-1.3", pos)
      self.remove_active_formatting_index(formatting_index)
      return
    }
    if !self.has_open_element_in_default_scope(formatting_element.name) {
      self.error_at("adoption-agency-1.3", pos)
      return
    }
    match self.stack.last() {
      Some(current) if !physical_equal(current, formatting_element) =>
        self.error_at("adoption-agency-1.3", pos)
      _ => ()
    }
    let mut furthest_block_index = -1
    let mut index = formatting_open_index + 1
    while index < self.stack.length() {
      let candidate = self.stack[index]
      if candidate.kind == Element &&
        is_special_element_for_any_other_end_tag(candidate.name) {
        furthest_block_index = index
        break
      }
      index += 1
    }
    if furthest_block_index < 0 {
      while self.stack.length() > 1 {
        match self.stack.pop() {
          Some(node) if physical_equal(node, formatting_element) => break
          _ => ()
        }
      }
      self.remove_active_formatting_index(formatting_index)
      return
    }
    let furthest_block = self.stack[furthest_block_index]
    let mut bookmark = formatting_index + 1
    let mut last_node = furthest_block
    let mut node_index = furthest_block_index
    let mut inner_loop_counter = 0
    while true {
      inner_loop_counter += 1
      node_index -= 1
      let node = self.stack[node_index]
      if physical_equal(node, formatting_element) {
        break
      }
      let mut node_formatting_index = self.active_formatting_index_by_node(node)
      if inner_loop_counter > 3 && node_formatting_index >= 0 {
        self.remove_active_formatting_index(node_formatting_index)
        if node_formatting_index < bookmark {
          bookmark -= 1
        }
        node_formatting_index = -1
      }
      if node_formatting_index < 0 {
        ignore(self.stack.remove(node_index))
        continue
      }
      let entry = self.active_formatting[node_formatting_index]
      let new_node = element_from_formatting_entry(entry)
      self.active_formatting[node_formatting_index] = formatting_entry_with_node(
        entry, new_node,
      )
      self.stack[node_index] = new_node
      if physical_equal(last_node, furthest_block) {
        bookmark = node_formatting_index + 1
      }
      new_node.append_child(last_node)
      last_node = new_node
    }
    let common_ancestor = self.stack[formatting_open_index - 1]
    common_ancestor.append_child(last_node)
    let entry = self.active_formatting[formatting_index]
    let new_formatting_element = element_from_formatting_entry(entry)
    self.active_formatting[formatting_index] = formatting_entry_with_node(
      entry, new_formatting_element,
    )
    let moved_children = furthest_block.children.copy()
    for child in moved_children {
      new_formatting_element.append_child(child)
    }
    furthest_block.append_child(new_formatting_element)
    let replacement_entry = self.active_formatting[formatting_index]
    self.remove_active_formatting_index(formatting_index)
    bookmark -= 1
    self.active_formatting.insert(bookmark, replacement_entry)
    ignore(self.remove_open_node(formatting_element))
    let furthest_index = self.stack_index_by_node(furthest_block)
    self.stack.insert(furthest_index + 1, new_formatting_element)
  }
}

///|
fn Parser::reconstruct_active_formatting_elements(self : Parser) -> Unit {
  if self.active_formatting.is_empty() {
    return
  }
  let last_index = self.active_formatting.length() - 1
  if self.active_formatting[last_index].marker ||
    self.stack_contains_node(self.active_formatting[last_index].node) {
    return
  }
  let mut index = last_index
  while index > 0 {
    let previous = self.active_formatting[index - 1]
    if previous.marker || self.stack_contains_node(previous.node) {
      break
    }
    index -= 1
  }
  while index < self.active_formatting.length() {
    let entry = self.active_formatting[index]
    let node = @dom.element(entry.name, attrs=entry.attrs.copy(), ns=entry.ns)
    copy_node_origin_from(node, entry.node)
    self.current_node().append_child(node)
    self.stack.push(node)
    self.active_formatting[index] = {
      marker: false,
      name: entry.name,
      ns: entry.ns,
      attrs: entry.attrs,
      node,
    }
    index += 1
  }
}

///|
fn node_has_direct_element_child(node : @dom.Node, name : String) -> Bool {
  for child in node.children {
    if child.kind == Element && child.name == name {
      return true
    }
  }
  false
}

///|
fn Parser::document_head_exists(self : Parser) -> Bool {
  if node_has_direct_element_child(self.root, "head") {
    return true
  }
  match document_html_element(self.root) {
    Some(html) => node_has_direct_element_child(html, "head")
    None => false
  }
}

///|
fn Parser::document_head_start_is_late(self : Parser) -> Bool {
  self.document_head_exists() ||
  !self.frameset_ok ||
  self.after_frameset ||
  self.has_open_element("body") ||
  self.has_open_element("frameset")
}

///|
fn Parser::handle_late_document_head_start_tag(
  self : Parser,
  name : StringView,
  start : Int,
) -> Bool {
  if self.is_fragment_parser() || name != "head" {
    return false
  }
  if !self.document_head_start_is_late() {
    return false
  }
  self.error_at("unexpected-start-tag", start)
  let duplicate = @dom.element("head")
  match self.open_html_element() {
    Some(html) => html.append_child(duplicate)
    None => self.root.append_child(duplicate)
  }
  self.stack.push(duplicate)
  self.duplicate_head_element = Some(duplicate)
  true
}

///|
fn Parser::handle_repeated_document_html_start_tag(
  self : Parser,
  name : StringView,
  attrs : Map[String, String?],
  start : Int,
) -> Bool {
  if self.is_fragment_parser() ||
    self.in_select_insertion_mode() ||
    name != "html" {
    return false
  }
  match self.open_html_element() {
    Some(html) => {
      self.error_at("unexpected-start-tag", start)
      merge_missing_attrs_from_map(html, attrs)
      self.repeated_document_html_shell = true
      if !self.stack_contains_node(html) {
        self.stack.push(html)
      }
      true
    }
    None => false
  }
}

///|
fn Parser::report_body_start_after_repeated_document_html(
  self : Parser,
  name : StringView,
  start : Int,
) -> Unit {
  if !self.repeated_document_html_shell || name != "body" {
    return
  }
  self.error_at("unexpected-start-tag", start)
  self.repeated_document_html_shell = false
}

///|
fn Parser::pop_disabled_head_noscript_for_reprocess(self : Parser) -> Unit {
  ignore(self.stack.pop())
  match self.stack.last() {
    Some(node) if node.kind == Element && node.name == "head" =>
      ignore(self.stack.pop())
    _ => ()
  }
}

///|
fn Parser::handle_disabled_head_noscript_start_tag(
  self : Parser,
  name : StringView,
  start : Int,
) -> Bool {
  if !self.current_is_disabled_head_noscript() {
    return false
  }
  if disabled_head_noscript_allows_start(name) {
    return false
  }
  if name == "head" || name == "noscript" {
    self.error_at("unexpected-start-tag", start)
    return true
  }
  self.error_at("unexpected-start-tag", start)
  self.pop_disabled_head_noscript_for_reprocess()
  false
}

///|
fn Parser::handle_disabled_head_noscript_end_tag(
  self : Parser,
  name : StringView,
  start : Int,
) -> Bool {
  if !self.current_is_disabled_head_noscript() {
    return false
  }
  if name == "noscript" {
    ignore(self.stack.pop())
    return true
  }
  self.error_at("unexpected-end-tag", start)
  if name == "br" {
    self.pop_disabled_head_noscript_for_reprocess()
    return false
  }
  true
}

///|
fn Parser::handle_duplicate_head_end_tag(
  self : Parser,
  name : String,
  start : Int,
) -> Bool {
  if name != "head" {
    return false
  }
  match (self.stack.last(), self.duplicate_head_element) {
    (Some(current), Some(duplicate)) if physical_equal(current, duplicate) => {
      self.error_at("unexpected-end-tag", start)
      ignore(self.stack.pop())
      self.duplicate_head_element = None
      true
    }
    _ => false
  }
}

///|
fn is_special_element_for_any_other_end_tag(name : StringView) -> Bool {
  match name {
    "address"
    | "applet"
    | "area"
    | "article"
    | "aside"
    | "base"
    | "basefont"
    | "bgsound"
    | "blockquote"
    | "body"
    | "br"
    | "button"
    | "caption"
    | "center"
    | "col"
    | "colgroup"
    | "dd"
    | "details"
    | "dialog"
    | "dir"
    | "div"
    | "dl"
    | "dt"
    | "embed"
    | "fieldset"
    | "figcaption"
    | "figure"
    | "footer"
    | "form"
    | "frame"
    | "frameset"
    | "h1"
    | "h2"
    | "h3"
    | "h4"
    | "h5"
    | "h6"
    | "head"
    | "header"
    | "hgroup"
    | "hr"
    | "html"
    | "iframe"
    | "img"
    | "input"
    | "keygen"
    | "li"
    | "link"
    | "listing"
    | "main"
    | "marquee"
    | "menu"
    | "menuitem"
    | "meta"
    | "nav"
    | "noembed"
    | "noframes"
    | "noscript"
    | "object"
    | "ol"
    | "p"
    | "param"
    | "plaintext"
    | "pre"
    | "script"
    | "search"
    | "section"
    | "select"
    | "source"
    | "style"
    | "summary"
    | "table"
    | "tbody"
    | "td"
    | "template"
    | "textarea"
    | "tfoot"
    | "th"
    | "thead"
    | "title"
    | "tr"
    | "track"
    | "ul"
    | "wbr" => true
    _ => false
  }
}

///|
fn Parser::close_ruby_end_tag(self : Parser, start : Int) -> Unit {
  let mut index = self.stack.length()
  while index > 1 {
    index -= 1
    let node = self.stack[index]
    if node.kind == Element && node.name == "ruby" {
      if index != self.stack.length() - 1 {
        self.error_at("end-tag-too-early", start)
      }
      while self.stack.length() > index {
        ignore(self.stack.pop())
      }
      return
    }
    if node.kind == Element &&
      is_special_element_for_any_other_end_tag(node.name) {
      self.error_at("unexpected-end-tag", start)
      return
    }
  }
  self.error_at("unexpected-end-tag", start)
}

///|
fn Parser::remove_open_node(self : Parser, target : @dom.Node) -> Bool {
  let mut index = 0
  while index < self.stack.length() {
    if physical_equal(self.stack[index], target) {
      ignore(self.stack.remove(index))
      return true
    }
    index += 1
  }
  false
}

///|
fn Parser::handle_form_end_tag(self : Parser, start : Int) -> Unit {
  match self.form_element {
    Some(node) => {
      let removed = self.remove_open_node(node)
      self.form_element = None
      if !removed {
        self.error_at("unexpected-end-tag", start)
      }
    }
    None => self.error_at("unexpected-end-tag", start)
  }
}

///|
fn fragment_shell_start_is_ignored(name : StringView) -> Bool {
  match name {
    "body" | "head" | "html" => true
    _ => false
  }
}

///|
fn html_fragment_child_is_before_head(child : @dom.Node) -> Bool {
  child.kind == Comment || is_whitespace_text_node(child)
}

///|
fn html_fragment_child_is_before_body(child : @dom.Node) -> Bool {
  if child.kind == Comment || is_whitespace_text_node(child) {
    return true
  }
  if child.kind != Element {
    return false
  }
  child.name == "head" ||
  is_document_head_element_name(child.name) ||
  (child.name == "html" && html_fragment_children_are_before_body(child))
}

///|
fn html_fragment_children_are_before_head(html : @dom.Node) -> Bool {
  for child in html.children {
    if !html_fragment_child_is_before_head(child) {
      return false
    }
  }
  true
}

///|
fn html_fragment_children_are_before_body(html : @dom.Node) -> Bool {
  for child in html.children {
    if !html_fragment_child_is_before_body(child) {
      return false
    }
  }
  true
}

///|
fn Parser::current_node_allows_html_fragment_head(self : Parser) -> Bool {
  let current = self.current_node()
  current.kind == Element &&
  current.name == "html" &&
  html_fragment_children_are_before_head(current)
}

///|
fn Parser::current_node_allows_html_fragment_body(self : Parser) -> Bool {
  let current = self.current_node()
  current.kind == Element &&
  current.name == "html" &&
  html_fragment_children_are_before_body(current)
}

///|
fn Parser::insert_html_fragment_body_marker(
  self : Parser,
  attrs : Map[String, String?],
  start : Int?,
) -> Unit {
  match self.fragment_context_html_root {
    Some(html) => {
      let node = match start {
        Some(offset) =>
          self.node_with_origin(@dom.element("body", attrs~), offset)
        None => @dom.element("body", attrs~)
      }
      html.append_child(node)
    }
    None => ()
  }
}

///|
fn Parser::insert_empty_html_fragment_body_marker(self : Parser) -> Unit {
  let attrs : Map[String, String?] = {}
  self.insert_html_fragment_body_marker(attrs, None)
}

///|
fn Parser::current_node_is_html_element(self : Parser) -> Bool {
  let current = self.current_node()
  current.kind == Element && current.name == "html"
}

///|
fn Parser::handle_html_fragment_shell_start_tag(
  self : Parser,
  name : String,
  attrs : Map[String, String?],
  start : Int,
) -> Bool {
  if name == "html" &&
    (
      self.after_frameset ||
      self.detached_frameset_mode ||
      self.has_open_element("frameset")
    ) {
    return false
  }
  match name {
    "head" =>
      if self.current_node_allows_html_fragment_head() {
        false
      } else {
        self.error_at("unexpected-start-tag", start)
        if self.current_node_is_html_element() {
          self.insert_empty_html_fragment_body_marker()
        }
        true
      }
    "body" =>
      if self.fragment_context_html_after_body {
        self.fragment_context_html_after_body = false
        self.error_at("unexpected-token-after-body", start)
        self.error_at("unexpected-start-tag", start)
        self.frameset_ok = false
        self.insert_html_fragment_body_marker(attrs, Some(start))
        true
      } else if self.current_node_allows_html_fragment_body() {
        false
      } else {
        self.error_at("unexpected-start-tag", start)
        self.frameset_ok = false
        self.insert_html_fragment_body_marker(attrs, Some(start))
        true
      }
    "html" =>
      if self.fragment_context_html_after_body {
        self.fragment_context_html_after_body = false
        self.error_at("unexpected-start-tag", start)
        true
      } else if self.current_node_allows_html_fragment_body() {
        false
      } else {
        self.error_at("unexpected-start-tag", start)
        if self.current_node_is_html_element() {
          self.insert_empty_html_fragment_body_marker()
        }
        true
      }
    _ => false
  }
}

///|
fn Parser::handle_fragment_shell_start_tag(
  self : Parser,
  name : String,
  attrs : Map[String, String?],
  start : Int,
) -> Bool {
  if !self.is_fragment_parser() || !fragment_shell_start_is_ignored(name) {
    return false
  }
  if self.fragment_context_html {
    return self.handle_html_fragment_shell_start_tag(name, attrs, start)
  }
  self.error_at(self.fragment_shell_start_error_code(name), start)
  true
}

///|
fn Parser::fragment_shell_start_error_code(
  self : Parser,
  name : StringView,
) -> String {
  if self.in_select_insertion_mode() && (name == "body" || name == "head") {
    "unexpected-start-tag-in-select"
  } else {
    "unexpected-start-tag"
  }
}

///|
fn Parser::pop_current_element_if_name(self : Parser, name : String) -> Bool {
  match self.stack.last() {
    Some(node) if node.kind == Element && node.name == name => {
      ignore(self.stack.pop())
      true
    }
    _ => false
  }
}

///|
fn Parser::close_current_element_if_name(self : Parser, name : String) -> Unit {
  ignore(self.pop_current_element_if_name(name))
}

///|
fn Parser::last_stack_index_of(self : Parser, name : String) -> Int {
  let mut index = self.stack.length()
  while index > 0 {
    index -= 1
    let node = self.stack[index]
    if node.kind == Element && node.name == name {
      return index
    }
  }
  -1
}

///|
fn Parser::last_open_template_index(self : Parser) -> Int {
  self.last_stack_index_of("template")
}

///|
fn Parser::in_template_content_without_inner_table(self : Parser) -> Bool {
  let template_index = self.last_open_template_index()
  template_index >= 0 && self.last_open_table_index() < template_index
}

///|
fn Parser::current_template_node(self : Parser) -> @dom.Node? {
  let template_index = self.last_open_template_index()
  if template_index >= 0 {
    Some(self.stack[template_index])
  } else {
    None
  }
}

///|
fn node_array_contains_identity(
  nodes : Array[@dom.Node],
  target : @dom.Node,
) -> Bool {
  for node in nodes {
    if physical_equal(node, target) {
      return true
    }
  }
  false
}

///|
fn remove_parser_node_identity(
  nodes : Array[@dom.Node],
  target : @dom.Node,
) -> Unit {
  let mut index = 0
  while index < nodes.length() {
    if physical_equal(nodes[index], target) {
      ignore(nodes.remove(index))
    } else {
      index += 1
    }
  }
}

///|
fn Parser::template_column_group_mode_active(self : Parser) -> Bool {
  match self.current_template_node() {
    Some(template) =>
      node_array_contains_identity(
        self.template_column_group_templates,
        template,
      )
    None => false
  }
}

///|
fn Parser::enable_template_column_group_mode(self : Parser) -> Unit {
  match self.current_template_node() {
    Some(template) =>
      if !node_array_contains_identity(
          self.template_column_group_templates,
          template,
        ) {
        self.template_column_group_templates.push(template)
      }
    None => ()
  }
}

///|
fn Parser::disable_current_template_column_group_mode(self : Parser) -> Unit {
  match self.current_template_node() {
    Some(template) =>
      remove_parser_node_identity(
        self.template_column_group_templates,
        template,
      )
    None => ()
  }
}

///|
fn Parser::disable_template_column_group_mode_for_node(
  self : Parser,
  template : @dom.Node,
) -> Unit {
  remove_parser_node_identity(self.template_column_group_templates, template)
}

///|
fn Parser::template_table_context_mode_active(self : Parser) -> Bool {
  if self.template_table_context_detached_mode &&
    self.last_open_template_index() < 0 {
    return true
  }
  match self.current_template_node() {
    Some(template) =>
      node_array_contains_identity(
        self.template_table_context_templates,
        template,
      )
    None => false
  }
}

///|
fn Parser::enable_template_table_context_mode(self : Parser) -> Unit {
  match self.current_template_node() {
    Some(template) =>
      if !node_array_contains_identity(
          self.template_table_context_templates,
          template,
        ) {
        self.template_table_context_templates.push(template)
      }
    None => self.template_table_context_detached_mode = true
  }
}

///|
fn Parser::disable_current_template_table_context_mode(self : Parser) -> Unit {
  match self.current_template_node() {
    Some(template) =>
      remove_parser_node_identity(
        self.template_table_context_templates,
        template,
      )
    None => self.template_table_context_detached_mode = false
  }
}

///|
fn Parser::disable_template_table_context_mode_for_node(
  self : Parser,
  template : @dom.Node,
) -> Unit {
  remove_parser_node_identity(self.template_table_context_templates, template)
}

///|
fn Parser::clear_detached_template_table_context_for_template_start(
  self : Parser,
  name : StringView,
) -> Unit {
  if name == "template" &&
    self.template_table_context_detached_mode &&
    self.last_open_template_index() < 0 {
    self.template_table_context_detached_mode = false
  }
}

///|
fn Parser::last_stack_index_of_node(self : Parser, target : @dom.Node) -> Int {
  let mut index = self.stack.length()
  while index > 0 {
    index -= 1
    if physical_equal(self.stack[index], target) {
      return index
    }
  }
  -1
}

///|
fn Parser::insert_element_without_push(
  self : Parser,
  name : StringView,
  attrs : Map[String, String?],
  start? : Int,
) -> Unit {
  let node = match start {
    Some(offset) => self.node_with_origin(@dom.element(name, attrs~), offset)
    None => @dom.element(name, attrs~)
  }
  self.current_node().append_child(node)
}

///|
fn Parser::insert_element_maybe_push(
  self : Parser,
  name : StringView,
  attrs : Map[String, String?],
  push : Bool,
  start? : Int,
) -> Unit {
  let node = match start {
    Some(offset) => self.node_with_origin(@dom.element(name, attrs~), offset)
    None => @dom.element(name, attrs~)
  }
  self.current_node().append_child(node)
  if push {
    self.stack.push(node)
  }
}

///|
fn Parser::has_foreign_table_cell_on_stack(self : Parser) -> Bool {
  for node in self.stack {
    if node.kind == Element &&
      (node.name == "td" || node.name == "th") &&
      !(node.ns is Some("html")) {
      return true
    }
  }
  false
}

///|
fn Parser::has_foreign_table_row_on_stack(self : Parser) -> Bool {
  for node in self.stack {
    if node.kind == Element && node.name == "tr" && !(node.ns is Some("html")) {
      return true
    }
  }
  false
}

///|
fn Parser::clear_open_elements_to_root(self : Parser) -> Unit {
  while self.stack.length() > 1 {
    ignore(self.stack.pop())
  }
}

///|
fn Parser::handle_select_reprocessed_foreign_cell_start_tag(
  self : Parser,
  name : String,
  attrs : Map[String, String?],
  start : Int,
  self_closing : Bool,
) -> Bool {
  if name != "td" && name != "th" {
    return false
  }
  if self.has_open_element("table") || !self.has_foreign_table_cell_on_stack() {
    return false
  }
  self.clear_open_elements_to_root()
  let node = self.node_with_origin(@dom.element(name, attrs~), start)
  self.post_body_html_children.push(node)
  if !self_closing {
    self.stack.push(node)
  }
  true
}

///|
fn Parser::handle_recovered_post_body_cell_start_tag(
  self : Parser,
  name : String,
  attrs : Map[String, String?],
  start : Int,
  self_closing : Bool,
) -> Bool {
  if name != "td" && name != "th" {
    return false
  }
  if self.has_open_element("table") ||
    (!self.has_open_element("td") && !self.has_open_element("th")) {
    return false
  }
  self.close_open_table_cell()
  let node = self.node_with_origin(@dom.element(name, attrs~), start)
  self.post_body_html_children.push(node)
  if !self_closing {
    self.stack.push(node)
  }
  true
}

///|
fn Parser::handle_foreign_table_row_recovery_start_tag(
  self : Parser,
  name : String,
  attrs : Map[String, String?],
  start : Int,
  self_closing : Bool,
) -> Bool {
  if name != "tr" {
    return false
  }
  if self.has_open_element("table") || !self.has_foreign_table_row_on_stack() {
    return false
  }
  self.clear_open_elements_to_root()
  let node = self.node_with_origin(@dom.element("tr", attrs~), start)
  self.post_body_html_children.push(node)
  self.foreign_table_row_recovery_mode = !self_closing
  if !self_closing {
    self.stack.push(node)
  }
  true
}

///|
fn Parser::report_foreign_table_row_recovery_text(
  self : Parser,
  value : StringView,
  start : Int,
) -> Unit {
  if !self.foreign_table_row_recovery_mode ||
    !text_has_non_ascii_whitespace(value) {
    return
  }
  let current = self.current_node()
  if current.kind != Element || current.name != "tr" {
    return
  }
  let whitespace = leading_ascii_whitespace(value)
  self.error_at(
    "unexpected-character-implies-table-voodoo",
    start + whitespace.length(),
  )
}

///|
fn select_start_tag_reprocesses_in_body(name : StringView) -> Bool {
  match name {
    "caption"
    | "col"
    | "colgroup"
    | "input"
    | "table"
    | "tbody"
    | "td"
    | "textarea"
    | "tfoot"
    | "th"
    | "thead"
    | "tr" => true
    _ => false
  }
}

///|
fn table_start_tag_is_ignored_outside_table(name : StringView) -> Bool {
  match name {
    "colgroup" | "tbody" | "td" | "tfoot" | "th" | "thead" | "tr" => true
    _ => false
  }
}

///|
fn Parser::col_start_tag_is_ignored_outside_table(
  self : Parser,
  name : StringView,
) -> Bool {
  name == "col" &&
  !self.is_fragment_parser() &&
  !self.has_open_element("table") &&
  !self.in_template_content_without_inner_table()
}

///|
fn document_body_start_tag_preserves_frameset_ok(
  name : StringView,
  attrs : Map[String, String?],
) -> Bool {
  match name {
    "a"
    | "address"
    | "article"
    | "aside"
    | "b"
    | "big"
    | "blockquote"
    | "center"
    | "code"
    | "details"
    | "dialog"
    | "dir"
    | "div"
    | "dl"
    | "em"
    | "fieldset"
    | "figcaption"
    | "figure"
    | "font"
    | "footer"
    | "header"
    | "hgroup"
    | "i"
    | "main"
    | "math"
    | "menu"
    | "nav"
    | "nobr"
    | "ol"
    | "optgroup"
    | "option"
    | "p"
    | "param"
    | "rb"
    | "rp"
    | "rt"
    | "rtc"
    | "s"
    | "search"
    | "section"
    | "small"
    | "source"
    | "strike"
    | "strong"
    | "summary"
    | "svg"
    | "track"
    | "tt"
    | "u"
    | "ul" => true
    "input" => input_attrs_type_is_hidden(attrs)
    _ => false
  }
}

///|
fn Parser::document_start_tag_preserves_frameset_ok(
  self : Parser,
  name : StringView,
  attrs : Map[String, String?],
) -> Bool {
  (self.is_fragment_parser() && !self.fragment_context_html) ||
  name == "html" ||
  name == "head" ||
  name == "frameset" ||
  is_document_head_element_name(name) ||
  document_body_start_tag_preserves_frameset_ok(name, attrs)
}

///|
fn Parser::insert_empty_frameset_child(
  self : Parser,
  name : StringView,
  attrs : Map[String, String?],
  start : Int,
) -> Unit {
  self
  .current_node()
  .append_child(self.node_with_origin(@dom.element(name, attrs~), start))
}

///|
fn detach_removed_frameset_replacement_child(
  parent : @dom.Node,
  child : @dom.Node,
) -> Unit {
  match child.parent {
    Some(current) if physical_equal(current, parent) => child.parent = None
    _ => ()
  }
}

///|
fn child_is_preserved_before_implicit_frameset_body(
  child : @dom.Node,
  saw_head_content : Bool,
) -> (Bool, Bool) {
  match child.kind {
    Doctype | Comment => (true, saw_head_content)
    Element if child.name == "head" || is_document_head_element_name(child.name) =>
      (true, true)
    Text if is_whitespace_text_node(child) =>
      (saw_head_content, saw_head_content)
    _ => (false, saw_head_content)
  }
}

///|
fn replace_implicit_body_children_for_frameset(parent : @dom.Node) -> Unit {
  let original = parent.children.copy()
  parent.children.clear()
  let mut saw_head_content = false
  let mut body_started = false
  for child in original {
    if body_started {
      detach_removed_frameset_replacement_child(parent, child)
      continue
    }
    let (preserve, next_saw_head_content) = child_is_preserved_before_implicit_frameset_body(
      child, saw_head_content,
    )
    saw_head_content = next_saw_head_content
    if preserve {
      parent.append_child(child)
    } else {
      body_started = true
      detach_removed_frameset_replacement_child(parent, child)
    }
  }
}

///|
fn Parser::frameset_replacement_parent(self : Parser) -> @dom.Node {
  match self.open_html_element() {
    Some(html) => html
    None => self.root
  }
}

///|
fn Parser::reset_stack_to_frameset_replacement_parent(
  self : Parser,
  parent : @dom.Node,
) -> Unit {
  self.stack.clear()
  self.stack.push(self.root)
  if !physical_equal(parent, self.root) {
    self.stack.push(parent)
  }
}

///|
fn Parser::prepare_document_frameset_replacement(self : Parser) -> Bool {
  let parent = self.frameset_replacement_parent()
  if node_has_direct_element_child(parent, "body") {
    return false
  }
  replace_implicit_body_children_for_frameset(parent)
  self.reset_stack_to_frameset_replacement_parent(parent)
  true
}

///|
fn Parser::handle_document_frameset_start_tag(
  self : Parser,
  name : String,
  attrs : Map[String, String?],
  _self_closing : Bool,
  start : Int,
  tag_close_pos : Int,
) -> Bool {
  if self.is_fragment_parser() && !self.fragment_context_html {
    return false
  }
  if self.after_frameset {
    if name == "noframes" {
      return false
    }
    if name == "html" {
      self.after_frameset = false
      self.frameset_ok = false
      self.error_at("unexpected-start-tag", tag_close_pos)
      self.merge_document_html_attrs(attrs)
      self.repeated_document_html_shell = true
      return true
    }
    self.error_at("unexpected-token-after-frameset", tag_close_pos)
    self.after_frameset = false
    self.detached_frameset_mode = true
  }
  if self.frameset_reprocesses_in_body_mode && self.has_open_element("frameset") {
    match name {
      "html" => {
        self.error_at("unexpected-start-tag", tag_close_pos)
        self.merge_document_html_attrs(attrs)
        true
      }
      "frame" | "frameset" => {
        self.error_at("unexpected-start-tag-ignored", tag_close_pos)
        true
      }
      _ => false
    }
  } else if self.has_open_element("frameset") || self.detached_frameset_mode {
    match name {
      "frameset" => {
        self.insert_element_maybe_push(name, attrs, true, start~)
        self.detached_frameset_mode = false
        true
      }
      "frame" => {
        self.insert_empty_frameset_child(name, attrs, start)
        true
      }
      "noframes" => false
      "html" =>
        if self.detached_frameset_mode {
          self.detached_frameset_mode = false
          self.frameset_ok = false
          self.error_at("unexpected-start-tag", tag_close_pos)
          self.merge_document_html_attrs(attrs)
          self.repeated_document_html_shell = true
          true
        } else {
          self.error_at("unexpected-start-tag", tag_close_pos)
          self.merge_document_html_attrs(attrs)
          self.frameset_reprocesses_in_body_mode = true
          true
        }
      _ => {
        self.error_at("unexpected-token-in-frameset", tag_close_pos)
        true
      }
    }
  } else if name == "frameset" {
    if !self.frameset_ok {
      self.error_at("unexpected-start-tag-ignored", tag_close_pos)
      true
    } else if !self.prepare_document_frameset_replacement() {
      self.error_at("unexpected-start-tag-ignored", tag_close_pos)
      true
    } else {
      self.insert_element_maybe_push(name, attrs, true, start~)
      true
    }
  } else {
    false
  }
}

///|
fn Parser::close_open_table_cell(self : Parser) -> Unit {
  if self.has_open_element("td") {
    ignore(self.close_open_element("td"))
  } else if self.has_open_element("th") {
    ignore(self.close_open_element("th"))
  }
}

///|
fn is_heading_element_name(name : StringView) -> Bool {
  match name {
    "h1" | "h2" | "h3" | "h4" | "h5" | "h6" => true
    _ => false
  }
}

///|
fn Parser::close_current_heading_element(self : Parser) -> Unit {
  match self.stack.last() {
    Some(node) if node.kind == Element && is_heading_element_name(node.name) =>
      ignore(self.stack.pop())
    _ => ()
  }
}

///|
fn Parser::close_open_heading_element(
  self : Parser,
  name : String,
  pos : Int,
) -> Unit {
  let mut found = false
  for node in self.stack {
    if node.kind == Element && is_heading_element_name(node.name) {
      found = true
    }
  }
  if !found {
    self.error_at("unexpected-end-tag", pos)
    return
  }
  match self.stack.last() {
    Some(node) if node.kind == Element && node.name == name => ()
    _ => self.error_at("end-tag-too-early", pos)
  }
  while self.stack.length() > 1 {
    let node = self.stack.pop().unwrap()
    if node.kind == Element && is_heading_element_name(node.name) {
      break
    }
  }
}

///|
fn start_tag_closes_p(name : StringView) -> Bool {
  match name {
    "address"
    | "article"
    | "aside"
    | "blockquote"
    | "center"
    | "details"
    | "dialog"
    | "dir"
    | "dd"
    | "div"
    | "dl"
    | "dt"
    | "fieldset"
    | "figcaption"
    | "figure"
    | "footer"
    | "form"
    | "h1"
    | "h2"
    | "h3"
    | "h4"
    | "h5"
    | "h6"
    | "header"
    | "hgroup"
    | "hr"
    | "li"
    | "main"
    | "menu"
    | "nav"
    | "ol"
    | "p"
    | "plaintext"
    | "pre"
    | "search"
    | "section"
    | "table"
    | "ul"
    | "xmp" => true
    _ => false
  }
}

///|
fn current_node_is_ruby_annotation(node : @dom.Node) -> Bool {
  node.kind == Element &&
  (
    node.name == "rb" ||
    node.name == "rp" ||
    node.name == "rt" ||
    node.name == "rtc"
  )
}

///|
fn Parser::start_tag_inserts_empty_nonvoid(
  self : Parser,
  name : StringView,
) -> Bool {
  name == "keygen" || (name == "frame" && self.is_fragment_parser())
}

///|
fn Parser::parse_start_tag_or_text(self : Parser) -> Unit {
  let start = self.pos
  self.pos += 1
  match self.current() {
    Some(ch) if @tok.is_tag_name_start(ch) => {
      let name_start = self.pos
      while !self.is_eof() {
        match self.current() {
          Some(ch) if !@tok.is_tag_name_end(ch) => ignore(self.advance_char())
          _ => break
        }
      }
      let (name, name_errors) = @tok.parse_lower_name_value_replacing_nulls(
        self.input,
        name_start,
        self.pos,
      )
      for error in name_errors {
        self.error_at(error.code, error.offset)
      }
      let attrs : Map[String, String?] = {}
      let mut self_closing = false
      let mut closed = false
      while !self.is_eof() {
        self.skip_ascii_whitespace()
        let ch = self.current().unwrap()
        match ch {
          '>' => {
            ignore(self.advance_char())
            closed = true
            break
          }
          '/' => {
            ignore(self.advance_char())
            if self.current() == Some('>') {
              ignore(self.advance_char())
              self_closing = true
              closed = true
              break
            } else {
              self.error_at(
                "unexpected-character-after-solidus-in-tag",
                self.pos,
              )
            }
          }
          _ => self.parse_attribute(attrs)
        }
      }
      if !closed {
        self.error_at_eof("eof-in-tag")
        self.append_sanitize_escape_source_text(start, self.pos)
        return
      }
      let tag_close_pos = self.pos - 1
      self.flush_deferred_initial_doctype_error()
      self.before_html_phase = false
      if self.handle_foreign_content_start_tag(
          name, attrs, self_closing, start, tag_close_pos,
        ) {
        return
      }
      if self.handle_fragment_shell_start_tag(name, attrs, start) {
        return
      }
      if self.handle_disabled_head_noscript_start_tag(name, start) {
        return
      }
      if self.close_current_document_head_for_start(name, start) {
        return
      }
      if self.handle_late_document_head_start_tag(name, start) {
        return
      }
      if self.in_select_insertion_mode() && name == "frame" {
        self.error_at("unexpected-start-tag-in-select", start)
        return
      }
      if self.handle_select_special_start_tag(
          name, attrs, self_closing, start, tag_close_pos,
        ) {
        return
      }
      if self.handle_document_frameset_start_tag(
          name, attrs, self_closing, start, tag_close_pos,
        ) {
        return
      }
      if self.handle_repeated_document_html_start_tag(name, attrs, start) {
        return
      }
      self.report_body_start_after_repeated_document_html(name, start)
      if !self.is_fragment_parser() && name == "frame" {
        self.error_at("unexpected-start-tag-ignored", start)
        return
      }
      if self.handle_template_table_context_start_tag(name, attrs, start) {
        return
      }
      self.report_template_table_context_fostered_start(name, start)
      self.clear_detached_template_table_context_for_template_start(name)
      let in_template_table_context = self.in_template_content_without_inner_table()
      if name == "col" && in_template_table_context {
        let current = self.current_node()
        if current.kind == Element && current.name == "template" {
          self.enable_template_column_group_mode()
        }
      }
      if self.handle_template_column_group_start_tag(name, attrs, start) {
        return
      }
      if self.handle_fragment_context_colgroup_start_tag(name, attrs, start) {
        return
      }
      if self.in_select_insertion_mode() &&
        select_start_tag_reprocesses_in_body(name) {
        self.error_at("unexpected-start-tag-in-select", start)
        ignore(self.close_open_element("select"))
        self.reset_select_insertion_mode()
        if self.handle_select_reprocessed_foreign_cell_start_tag(
            name, attrs, start, self_closing,
          ) {
          return
        }
      }
      if self.handle_foreign_table_row_recovery_start_tag(
          name, attrs, start, self_closing,
        ) {
        return
      }
      if self.handle_recovered_post_body_cell_start_tag(
          name, attrs, start, self_closing,
        ) {
        return
      }
      if self.handle_fragment_context_caption_start_tag(name, start) {
        return
      }
      if !self.has_open_element("table") &&
        !in_template_table_context &&
        name == "caption" {
        self.error_at("unexpected-start-tag", start)
        return
      }
      if !self.has_open_element("table") &&
        !in_template_table_context &&
        table_start_tag_is_ignored_outside_table(name) {
        self.error_at("unexpected-start-tag-ignored", start)
        return
      }
      if self.col_start_tag_is_ignored_outside_table(name) {
        self.error_at("unexpected-start-tag-ignored", start)
        return
      }
      if self.close_current_caption_for_start(name, tag_close_pos) &&
        self.handle_template_table_context_start_tag(name, attrs, start) {
        return
      }
      self.close_current_column_group_for_start(name, start)
      if self.handle_table_context_hidden_input_or_form_start(
          name, attrs, start, tag_close_pos,
        ) {
        return
      }
      if self.handle_fragment_context_table_cell_start_tag(name, start) {
        return
      }
      if self.handle_fragment_context_table_row_start_tag(name, start) {
        return
      }
      if self.handle_fragment_context_table_section_start_tag(name, start) {
        return
      }
      let closed_table_cell = self.close_current_table_cell_for_start(name)
      self.close_current_table_row_for_start(name)
      self.close_current_table_section_for_start(name)
      self.clear_stack_to_table_context_for_start(name)
      if self.handle_fragment_context_table_start_tag(name, start) {
        return
      }
      ignore(self.handle_nested_table_start_tag(name, tag_close_pos))
      if !closed_table_cell {
        self.report_unexpected_table_body_cell_start(name, tag_close_pos)
      }
      if name == "form" && self.form_element is Some(_) {
        self.error_at("unexpected-start-tag", start)
        return
      }
      if name == "rp" || name == "rt" {
        self.generate_implied_end_tags(Some("rtc"))
      } else if (name == "rb" || name == "rtc") &&
        current_node_is_ruby_annotation(self.current_node()) {
        self.generate_implied_end_tags(None)
      }
      if start_tag_closes_p(name) {
        self.close_open_p_element()
      }
      if name == "button" && self.has_open_element_in_default_scope("button") {
        self.error_at("unexpected-start-tag-implies-end-tag", start)
        ignore(self.close_open_element("button"))
      }
      if name == "select" && self.in_select_insertion_mode() {
        self.error_at("unexpected-select-in-select", start)
        ignore(self.close_open_element("select"))
        self.reset_select_insertion_mode()
        return
      }
      if name == "li" {
        self.close_open_list_item()
      } else if name == "dd" || name == "dt" {
        self.close_open_definition_item(name)
      } else if name == "option" || name == "optgroup" {
        self.close_open_select_item(name)
      } else if name == "td" || name == "th" {
        self.close_open_table_cell()
      }
      if is_heading_element_name(name) {
        self.close_current_heading_element()
      }
      if !self.document_start_tag_preserves_frameset_ok(name, attrs) {
        self.frameset_ok = false
      }
      let node_ns = self.start_tag_namespace(name)
      if node_ns == "html" {
        self.prepare_active_formatting_start(name, start)
      }
      if !start_tag_closes_p(name) &&
        !self.table_context_start_skips_active_reconstruction(name) {
        self.reconstruct_active_formatting_elements()
      }
      let adjusted_name = if node_ns == "html" {
        if name == "image" {
          self.error_at("image-start-tag", start)
          "img"
        } else {
          name
        }
      } else {
        adjusted_start_tag_name_for_namespace(node_ns, name)
      }
      let adjusted_attrs = if node_ns == "html" {
        attrs
      } else {
        prepare_foreign_attrs(node_ns, attrs)
      }
      let node = self.node_with_start_tag_source(
        @dom.element(adjusted_name, attrs=adjusted_attrs, ns=node_ns),
        start,
        tag_close_pos,
      )
      if adjusted_name == "form" {
        self.form_element = Some(node)
      }
      self.append_start_tag_node(node, adjusted_name, start)
      if node_ns == "html" && adjusted_name == "select" {
        self.select_insertion_mode = true
      }
      let self_closes_tree = if node_ns == "html" {
        self_closing && @ser.is_void_element(adjusted_name)
      } else {
        self_closing
      }
      let inserts_empty_nonvoid = self.start_tag_inserts_empty_nonvoid(
        adjusted_name,
      )
      if node_ns == "html" &&
        !self_closes_tree &&
        self.is_special_text_element(adjusted_name) {
        self.consume_special_element_content(node, adjusted_name)
      } else if !self_closes_tree &&
        !@ser.is_void_element(adjusted_name) &&
        !inserts_empty_nonvoid {
        self.stack.push(node)
        if node_ns == "html" && active_formatting_element_name(adjusted_name) {
          let duplicate_index = self.active_formatting_duplicate_index(
            adjusted_name,
            node.attrs,
          )
          if duplicate_index >= 0 {
            self.remove_active_formatting_index(duplicate_index)
          }
          self.append_active_formatting_entry(node)
        }
        if node_ns == "html" &&
          active_formatting_marker_element_name(adjusted_name) {
          self.push_active_formatting_marker()
        }
        if node_ns == "html" && start_tag_ignores_initial_lf(adjusted_name) {
          self.skip_one_initial_lf()
        }
      }
    }
    _ =>
      if self.current() is None {
        self.error_at_eof("eof-before-tag-name")
        self.flush_deferred_initial_doctype_error()
        self.current_node().append_child(self.text_at("<", start))
      } else if self.current() == Some('?') {
        self.error_at("unexpected-question-mark-instead-of-tag-name", self.pos)
        self.parse_bogus_comment(start)
        self.append_sanitize_escape_source_text(start, self.pos)
      } else {
        self.report_current_noncharacter()
        self.parse_invalid_tag_open_as_text(start)
      }
  }
}

///|
fn Parser::parse_invalid_tag_open_as_text(self : Parser, start : Int) -> Unit {
  self.error_at("invalid-first-character-of-tag-name", self.pos)
  while !self.is_eof() && !self.starts_with("<") {
    self.report_current_noncharacter()
    ignore(self.advance_char())
  }
  let view = self.input[start:self.pos]
  self.flush_deferred_initial_doctype_error()
  self.append_text(view, start)
}

///|
fn Parser::parse_attribute(self : Parser, attrs : Map[String, String?]) -> Unit {
  let name_start = self.pos
  if self.current() == Some('=') {
    self.error_at("unexpected-equals-sign-before-attribute-name", self.pos)
    ignore(self.advance_char())
  }
  while !self.is_eof() {
    let ch = self.current().unwrap()
    if ch.is_ascii_whitespace() || ch == '=' || ch == '/' || ch == '>' {
      break
    } else {
      match ch {
        '<' | '"' | '\'' => {
          self.error_at("unexpected-character-in-attribute-name", self.pos)
          ignore(self.advance_char())
        }
        _ => ignore(self.advance_char())
      }
    }
  }
  let (name, name_errors) = @tok.parse_lower_name_value_replacing_nulls(
    self.input,
    name_start,
    self.pos,
  )
  for error in name_errors {
    self.error_at(error.code, error.offset)
  }
  if name == "" {
    ignore(self.advance_char())
    return
  }
  let duplicate = attrs.contains(name)
  if duplicate {
    self.error_at("duplicate-attribute", name_start)
  }
  self.skip_ascii_whitespace()
  if self.current() != Some('=') {
    if !duplicate {
      attrs[name] = None
    }
    return
  }
  ignore(self.advance_char())
  self.skip_ascii_whitespace()
  let missing_value = self.current() == Some('>')
  if missing_value {
    self.error_at("missing-attribute-value", self.pos)
  }
  let value = match self.current() {
    Some('"') => self.parse_quoted_attribute_value('"')
    Some('\'') => self.parse_quoted_attribute_value('\'')
    _ => {
      let start = self.pos
      while !self.is_eof() {
        let ch = self.current().unwrap()
        if ch.is_ascii_whitespace() || ch == '>' {
          break
        }
        match ch {
          '\u{0000}' => {
            self.error_at("unexpected-null-character", self.pos)
            ignore(self.advance_char())
          }
          '"' | '\'' | '<' | '=' | '`' => {
            self.error_at(
              "unexpected-character-in-unquoted-attribute-value",
              self.pos,
            )
            ignore(self.advance_char())
          }
          _ => ignore(self.advance_char())
        }
      }
      let view = self.input[start:self.pos]
      let decoded = @tok.decode_attribute_value_with_errors(view)
      for error in decoded.errors {
        self.error_at(error.code, self.pos)
      }
      decoded.data
    }
  }
  if !duplicate {
    attrs[name] = if missing_value { None } else { Some(value) }
  }
}

///|
fn Parser::parse_quoted_attribute_value(self : Parser, quote : Char) -> String {
  ignore(self.advance_char())
  let start = self.pos
  while !self.is_eof() && self.current() != Some(quote) {
    if self.current() == Some('\u{0000}') {
      self.error_at("unexpected-null-character", self.pos)
    }
    ignore(self.advance_char())
  }
  let raw = self.input[start:self.pos]
  if self.current() == Some(quote) {
    ignore(self.advance_char())
    match self.current() {
      Some(ch) if !ch.is_ascii_whitespace() && ch != '>' && ch != '/' =>
        self.error_at("missing-whitespace-between-attributes", self.pos)
      _ => ()
    }
  }
  let decoded = @tok.decode_attribute_value_with_errors(raw)
  for error in decoded.errors {
    self.error_at(error.code, self.pos)
  }
  decoded.data
}
