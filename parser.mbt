///|
priv struct Parser {
  input : StringView
  scripting_enabled : Bool
  xml_coercion : Bool
  mut pos : Int
  errors : Array[ParseError]
  root : Node
  stack : Array[Node]
  mut form_element : Node?
  mut frameset_ok : Bool
  mut before_html_phase : Bool
  mut after_frameset : Bool
  mut after_frameset_ignored_depth : Int
  foster_parented_start_error_nodes : Array[Node]
  mut fragment_context_table : Node?
  mut fragment_context_table_section : Node?
  mut fragment_context_table_row : Node?
  mut fragment_context_table_cell : Node?
  mut fragment_context_caption : Bool
  mut fragment_context_colgroup : Bool
  mut fragment_context_html : Bool
  mut fragment_context_html_root : Node?
  mut fragment_context_foreign : Node?
  mut template_column_group_mode : Bool
  mut template_table_context_mode : Bool
  mut template_detached_column_group_mode : Bool
}

///|
fn Parser::new(
  input : StringView,
  root : Node,
  scripting_enabled~ : Bool,
  xml_coercion~ : Bool,
) -> Parser {
  let input = strip_leading_bom(input)
  Parser::{
    input,
    scripting_enabled,
    xml_coercion,
    pos: 0,
    errors: [],
    root,
    stack: [root],
    form_element: None,
    frameset_ok: root.kind == Document,
    before_html_phase: root.kind == Document,
    after_frameset: false,
    after_frameset_ignored_depth: 0,
    foster_parented_start_error_nodes: [],
    fragment_context_table: None,
    fragment_context_table_section: None,
    fragment_context_table_row: None,
    fragment_context_table_cell: None,
    fragment_context_caption: false,
    fragment_context_colgroup: false,
    fragment_context_html: false,
    fragment_context_html_root: None,
    fragment_context_foreign: None,
    template_column_group_mode: false,
    template_table_context_mode: false,
    template_detached_column_group_mode: false,
  }
}

///|
fn Parser::current(self : Parser) -> Char? {
  self.input.get_char(self.pos)
}

///|
fn Parser::is_eof(self : Parser) -> Bool {
  self.pos >= self.input.length()
}

///|
fn Parser::advance_char(self : Parser) -> Char? {
  match self.current() {
    Some(ch) => {
      self.pos += ch.utf16_len()
      Some(ch)
    }
    None => None
  }
}

///|
fn Parser::starts_with(self : Parser, prefix : StringView) -> Bool {
  let end = self.pos + prefix.length()
  match self.input.get_view(start=self.pos, end~) {
    Some(view) => view == prefix
    None => false
  }
}

///|
fn Parser::skip_ascii_whitespace(self : Parser) -> Unit {
  while !self.is_eof() {
    match self.current() {
      Some(ch) if ch.is_ascii_whitespace() => ignore(self.advance_char())
      _ => return
    }
  }
}

///|
fn Parser::current_node(self : Parser) -> Node {
  match self.stack.last() {
    Some(node) => node
    None => self.root
  }
}

///|
fn Parser::append_text(self : Parser, raw : StringView, start : Int) -> Unit {
  if raw.is_empty() {
    return
  }
  let mut cleaned = if self.current_node_uses_foreign_content_for_text() {
    self.clean_foreign_content_text(raw, start)
  } else {
    self.remove_null_characters(raw, start)
  }
  if cleaned.is_empty() {
    return
  }
  if text_has_non_ascii_whitespace(cleaned) {
    self.before_html_phase = false
  }
  if self.current_is_disabled_head_noscript() &&
    text_has_non_ascii_whitespace(cleaned) {
    let whitespace = leading_ascii_whitespace(cleaned)
    self.error_at("unexpected-start-tag", start + whitespace.length())
    ignore(self.stack.pop())
    if !whitespace.is_empty() {
      let data = if self.xml_coercion {
        coerce_text_for_xml(whitespace[:])
      } else {
        whitespace
      }
      self.current_node().append_child(text(data))
    }
    if self.current_is_document_head() {
      ignore(self.stack.pop())
    }
    match cleaned[:].get_view(start=whitespace.length(), end=cleaned.length()) {
      Some(rest) => cleaned = rest.to_owned()
      None => return
    }
  }
  if self.current_is_document_head() && text_has_non_ascii_whitespace(cleaned) {
    ignore(self.stack.pop())
  }
  if self.uses_document_frameset_rules() &&
    (self.after_frameset || self.has_open_element("frameset")) {
    let whitespace = ascii_whitespace_chars_only(cleaned)
    if self.after_frameset &&
      self.after_frameset_ignored_depth == 0 &&
      whitespace.length() != cleaned.length() {
      self.error_at("unexpected-token-after-frameset", start)
    }
    if !whitespace.is_empty() {
      self.current_node().append_child(text(whitespace))
    }
    return
  }
  if self.uses_document_frameset_rules() &&
    text_has_non_ascii_whitespace(cleaned) {
    self.frameset_ok = false
  }
  if self.handle_template_column_group_text(cleaned, start) {
    return
  }
  if self.handle_fragment_context_colgroup_text(cleaned, start) {
    return
  }
  if self.handle_column_group_text(cleaned, start) {
    return
  }
  if self.foster_parent_table_text(cleaned, start) {
    return
  }
  if self.foster_parent_template_table_text(cleaned, start) {
    return
  }
  if self.template_table_context_mode && text_has_non_ascii_whitespace(cleaned) {
    ignore(self.report_foster_parenting_character_errors(cleaned, start))
  }
  self.report_foster_parented_table_context_text(cleaned, start)
  let decoded_result = decode_entities_with_errors(cleaned, in_attribute=false)
  for error in decoded_result.errors {
    self.error_at(error.code, start + error.offset)
  }
  let decoded = decoded_result.data
  let data = if self.xml_coercion {
    coerce_text_for_xml(decoded[:])
  } else {
    decoded
  }
  self.current_node().append_child(text(data))
}

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
    match value.get_char(pos) {
      Some(ch) => {
        if !ch.is_ascii_whitespace() {
          self.error_at("foster-parenting-character", start + pos)
          count += 1
        }
        pos += ch.utf16_len()
      }
      None => break
    }
  }
  count
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
  ignore(self.report_foster_parenting_character_errors(cleaned, start))
  let fostered = text(decode_entities(cleaned, in_attribute=false))
  if self.table_index_is_fragment_context_table(table_index) {
    self.current_node().append_child(fostered)
    return true
  }
  let table = self.stack[table_index]
  match table.parent {
    Some(parent) => parent.insert_child_before(fostered, table)
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
  if template_index < 0 {
    return false
  }
  ignore(self.report_foster_parenting_character_errors(cleaned, start))
  self.stack[template_index].append_child(
    text(decode_entities(cleaned, in_attribute=false)),
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
) -> Bool {
  if !self.current_is_table_or_section_context() {
    return false
  }
  if name == "input" && input_attrs_type_is_hidden(attrs) {
    self.error_at("unexpected-hidden-input-in-table", start)
    self.current_node().append_child(element(name, attrs~))
    return true
  }
  if name == "form" {
    self.error_at("unexpected-form-in-table", start)
    if self.form_element is None {
      let node = element(name, attrs~)
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
  start : Int,
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
  self.error_at("unexpected-start-tag-implies-end-tag", start)
  ignore(self.close_open_element("table"))
  true
}

///|
fn Parser::report_unexpected_table_body_cell_start(
  self : Parser,
  name : String,
  start : Int,
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
    self.error_at("unexpected-cell-in-table-body", start)
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
  node : Node,
  table_index : Int,
) -> Unit {
  let table = self.stack[table_index]
  match table.parent {
    Some(parent) => parent.insert_child_before(node, table)
    None => self.root.append_child(node)
  }
}

///|
fn Parser::append_start_tag_node(
  self : Parser,
  node : Node,
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
  target : Node,
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
          text(decode_entities(whitespace[:], in_attribute=false)),
        )
      }
      ignore(self.pop_current_element_if_name("colgroup"))
      let non_whitespace = cleaned[whitespace.length():]
      let non_whitespace_start = start + whitespace.length()
      if in_template_table_context {
        self.template_table_context_mode = true
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
      .append_child(text(decode_entities(non_whitespace, in_attribute=false)))
    } else {
      current.append_child(text(decode_entities(cleaned, in_attribute=false)))
      ignore(self.pop_current_element_if_name("colgroup"))
      if in_template_table_context {
        self.template_table_context_mode = true
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
    .append_child(text(decode_entities(whitespace[:], in_attribute=false)))
  }
  true
}

///|
fn Parser::handle_template_column_group_text(
  self : Parser,
  cleaned : StringView,
  start : Int,
) -> Bool {
  if !self.template_column_group_mode {
    return false
  }
  if !self.in_template_content_without_inner_table() {
    self.template_column_group_mode = false
    return false
  }
  let whitespace = leading_ascii_whitespace(cleaned)
  if !whitespace.is_empty() {
    self
    .current_node()
    .append_child(text(decode_entities(whitespace[:], in_attribute=false)))
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
  if !self.template_column_group_mode {
    return false
  }
  if !self.in_template_content_without_inner_table() {
    self.template_column_group_mode = false
    return false
  }
  if name == "html" || name == "template" {
    return false
  }
  if name == "col" {
    self.current_node().append_child(element("col", attrs~))
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
  if !self.template_table_context_mode {
    return false
  }
  if name == "table" {
    self.error_at("unexpected-start-tag-implies-end-tag", start)
    self.error_at("unexpected-end-tag", start)
    return true
  }
  if name == "caption" {
    let node = element("caption", attrs~)
    self.current_node().append_child(node)
    self.stack.push(node)
    self.template_table_context_mode = false
    return true
  }
  if name == "col" {
    let colgroup = element("colgroup")
    self.current_node().append_child(colgroup)
    colgroup.append_child(element("col", attrs~))
    self.stack.push(colgroup)
    self.template_table_context_mode = false
    self.template_detached_column_group_mode = !self.in_template_content_without_inner_table()
    return true
  }
  if name == "colgroup" {
    let node = element("colgroup", attrs~)
    self.current_node().append_child(node)
    self.stack.push(node)
    self.template_table_context_mode = false
    self.template_detached_column_group_mode = !self.in_template_content_without_inner_table()
    return true
  }
  if name == "tbody" || name == "tfoot" || name == "thead" {
    let node = element(name, attrs~)
    self.current_node().append_child(node)
    self.stack.push(node)
    self.template_table_context_mode = false
    return true
  }
  if name == "tr" || name == "td" || name == "th" {
    let section = element("tbody")
    self.current_node().append_child(section)
    self.stack.push(section)
    if name == "td" || name == "th" {
      self.error_at("unexpected-cell-in-table-body", start)
    }
    let row = element("tr")
    section.append_child(row)
    self.stack.push(row)
    if name == "td" || name == "th" {
      let cell = element(name, attrs~)
      row.append_child(cell)
      self.stack.push(cell)
    }
    self.template_table_context_mode = false
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
  if !self.template_table_context_mode {
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
  if !self.template_column_group_mode {
    return false
  }
  if !self.in_template_content_without_inner_table() {
    self.template_column_group_mode = false
    return false
  }
  if name == "template" {
    self.template_column_group_mode = false
    return false
  }
  if name == "col" || name == "colgroup" {
    self.error_at("unexpected-end-tag", start)
    return true
  }
  self.template_column_group_mode = false
  self.template_table_context_mode = true
  let template_index = self.last_open_template_index()
  if template_index >= 0 {
    while self.stack.length() > template_index {
      ignore(self.stack.pop())
    }
  }
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
    self.current_node().append_child(element("col", attrs~))
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
  start : Int,
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
    self.error_at("unexpected-start-tag-implies-end-tag", start)
    ignore(self.close_open_element("caption"))
    self.template_table_context_mode = true
    return true
  }
  if caption_index <= table_index {
    return false
  }
  self.error_at("unexpected-start-tag-implies-end-tag", start)
  ignore(self.close_open_element("caption"))
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
        ignore(self.close_open_element("caption"))
        self.template_table_context_mode = true
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
        ignore(self.close_open_element("caption"))
        true
      }
      "tbody" | "tfoot" | "thead" => {
        self.error_at("unexpected-end-tag", start)
        true
      }
      "table" => {
        ignore(self.close_open_element("caption"))
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
  if self.template_table_context_mode &&
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
fn Parser::handle_table_end_tag(self : Parser, name : String) -> Bool {
  name == "table" && self.close_open_element("table")
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
    self.template_table_context_mode = true
    return true
  }
  if template_table_context_section_end_tag_reports_unexpected(name) &&
    self.close_open_element(name) {
    self.error_at("unexpected-end-tag", start)
    self.template_table_context_mode = true
    return true
  }
  false
}

///|
fn Parser::handle_template_end_tag(
  self : Parser,
  name : String,
  start : Int,
) -> Bool {
  if name != "template" {
    return false
  }
  let template_index = self.last_open_template_index()
  if template_index < 0 {
    self.error_at("unexpected-end-tag", start)
    return true
  }
  self.template_column_group_mode = false
  self.template_table_context_mode = false
  self.template_detached_column_group_mode = false
  while self.stack.length() > template_index {
    ignore(self.stack.pop())
  }
  true
}

///|
fn Parser::insert_body_mode_node(self : Parser, node : Node) -> Unit {
  let table_index = self.table_context_without_cell_or_caption()
  if table_index >= 0 {
    let current = self.current_node()
    if current.kind == Element && is_table_start_foster_target(current.name) {
      if self.table_index_is_fragment_context_table(table_index) {
        current.append_child(node)
        return
      }
      self.insert_node_before_open_table(node, table_index)
      return
    }
  }
  self.current_node().append_child(node)
}

///|
fn text_has_non_ascii_whitespace(value : StringView) -> Bool {
  for ch in value {
    if !ch.is_ascii_whitespace() {
      return true
    }
  }
  false
}

///|
fn ascii_whitespace_chars_only(value : StringView) -> String {
  let out = StringBuilder::new(size_hint=value.length())
  for ch in value {
    if ch.is_ascii_whitespace() {
      out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn Parser::remove_null_characters(
  self : Parser,
  raw : StringView,
  start : Int,
) -> String {
  let out = StringBuilder::new(size_hint=raw.length())
  let mut pos = 0
  while pos < raw.length() {
    match raw.get_char(pos) {
      Some('\u{0000}') => {
        self.error_at("unexpected-null-character", start + pos)
        pos += 1
      }
      Some(ch) => {
        out.write_char(ch)
        pos += ch.utf16_len()
      }
      None => break
    }
  }
  out.to_string()
}

///|
fn Parser::replace_null_characters(
  self : Parser,
  raw : StringView,
  start : Int,
) -> String {
  let out = StringBuilder::new(size_hint=raw.length())
  let mut pos = 0
  while pos < raw.length() {
    match raw.get_char(pos) {
      Some('\u{0000}') => {
        self.error_at("unexpected-null-character", start + pos)
        out.write_char('\u{FFFD}')
        pos += 1
      }
      Some(ch) => {
        out.write_char(ch)
        pos += ch.utf16_len()
      }
      None => break
    }
  }
  out.to_string()
}

///|
fn Parser::error_at(self : Parser, code : String, pos : Int) -> Unit {
  self.errors.push(self.make_error_at(code, pos))
}

///|
fn Parser::make_error_at(self : Parser, code : String, pos : Int) -> ParseError {
  let (line, column) = line_col_at(self.input, pos)
  ParseError::new(code, line~, column~)
}

///|
fn Parser::report_current_noncharacter(self : Parser) -> Unit {
  match self.current() {
    Some(ch) if is_xml_noncharacter(ch) =>
      self.error_at("noncharacter-in-input-stream", self.pos)
    _ => ()
  }
}

///|
fn Parser::parse_all(self : Parser) -> Unit {
  while !self.is_eof() {
    let start = self.pos
    match self.current() {
      Some('<') =>
        if self.starts_with("<!--") {
          self.parse_comment()
        } else if self.starts_with("</") {
          self.parse_end_tag()
        } else if starts_with_case_insensitive(
            self.input,
            self.pos,
            "<!doctype",
          ) {
          self.parse_doctype()
        } else if self.starts_with("<!") {
          self.parse_markup_declaration()
        } else {
          self.parse_start_tag_or_text()
        }
      Some(_) => {
        while !self.is_eof() && !self.starts_with("<") {
          self.report_current_noncharacter()
          ignore(self.advance_char())
        }
        match self.input.get_view(start~, end=self.pos) {
          Some(view) => self.append_text(view, start)
          None => ()
        }
      }
      None => ()
    }
  }
}

///|
fn view_starts_with_at(
  input : StringView,
  pos : Int,
  prefix : StringView,
) -> Bool {
  let end = pos + prefix.length()
  match input.get_view(start=pos, end~) {
    Some(view) => view == prefix
    None => false
  }
}

///|
fn find_markup_close(input : StringView, start : Int) -> Int? {
  let mut pos = start
  while pos < input.length() {
    match input.get_char(pos) {
      Some('>') => return Some(pos)
      Some(ch) => pos += ch.utf16_len()
      None => break
    }
  }
  None
}

///|
fn find_comment_close(input : StringView, start : Int) -> Int? {
  let scan = scan_comment_data(input, start + "<!--".length())
  if scan.eof {
    None
  } else {
    Some(scan.end)
  }
}

///|
fn Parser::report_initial_doctype_error(self : Parser) -> ParseError? {
  let mut pos = 0
  let mut defer_doctype = false
  while pos < self.input.length() {
    match self.input.get_char(pos) {
      Some(ch) if ch.is_ascii_whitespace() => pos += ch.utf16_len()
      Some('<') if view_starts_with_at(self.input, pos, "<!--") =>
        match find_comment_close(self.input, pos) {
          Some(end) => pos = end
          None =>
            return Some(self.make_error_at_eof("expected-doctype-but-got-eof"))
        }
      Some('<') if starts_with_case_insensitive(self.input, pos, "<!doctype") =>
        return None
      Some('<') if view_starts_with_at(self.input, pos, "<!") => {
        defer_doctype = true
        match find_markup_close(self.input, pos) {
          Some(close) => pos = close + 1
          None =>
            return Some(self.make_error_at_eof("expected-doctype-but-got-eof"))
        }
      }
      Some('<') if view_starts_with_at(self.input, pos, "</") =>
        match find_markup_close(self.input, pos) {
          Some(close) => {
            let malformed = match self.input.get_char(pos + 2) {
              Some(ch) if ch == '>' || !is_tag_name_start(ch) => true
              _ => false
            }
            if malformed {
              defer_doctype = true
              pos = close + 1
            } else {
              let error = self.make_error_at(
                "expected-doctype-but-got-end-tag", close,
              )
              if defer_doctype {
                return Some(error)
              }
              self.errors.push(error)
              return None
            }
          }
          None =>
            return Some(self.make_error_at_eof("expected-doctype-but-got-eof"))
        }
      Some('<') =>
        match self.input.get_char(pos + 1) {
          Some(ch) if is_tag_name_start(ch) =>
            match find_markup_close(self.input, pos) {
              Some(close) => {
                let error = self.make_error_at(
                  "expected-doctype-but-got-start-tag", close,
                )
                if defer_doctype {
                  return Some(error)
                }
                self.errors.push(error)
                return None
              }
              None =>
                return Some(
                  self.make_error_at_eof("expected-doctype-but-got-eof"),
                )
            }
          Some('?') => {
            defer_doctype = true
            match find_markup_close(self.input, pos) {
              Some(close) => pos = close + 1
              None =>
                return Some(
                  self.make_error_at_eof("expected-doctype-but-got-eof"),
                )
            }
          }
          _ => {
            let error = self.make_error_at(
              "expected-doctype-but-got-chars", pos,
            )
            if defer_doctype {
              return Some(error)
            }
            self.errors.push(error)
            return None
          }
        }
      Some(_) => {
        let error = self.make_error_at("expected-doctype-but-got-chars", pos)
        if defer_doctype {
          return Some(error)
        }
        self.errors.push(error)
        return None
      }
      None => ()
    }
  }
  let error = self.make_error_at_eof("expected-doctype-but-got-eof")
  if defer_doctype {
    Some(error)
  } else {
    self.errors.push(error)
    None
  }
}

///|
fn Parser::eof_error_pos(self : Parser) -> Int {
  eof_error_pos(self.input)
}

///|
fn eof_error_pos(input : StringView) -> Int {
  let mut pos = 0
  let mut last = 0
  let mut last_char : Char? = None
  while pos < input.length() {
    last = pos
    match input.get_char(pos) {
      Some(ch) => {
        last_char = Some(ch)
        pos += ch.utf16_len()
      }
      None => break
    }
  }
  match last_char {
    Some('\r') | Some('\n') => input.length()
    Some(_) => last
    None => 0
  }
}

///|
fn Parser::error_at_eof(self : Parser, code : String) -> Unit {
  self.errors.push(self.make_error_at_eof(code))
}

///|
fn Parser::make_error_at_eof(self : Parser, code : String) -> ParseError {
  if self.input.is_empty() {
    ParseError::new(code, line=1, column=0)
  } else {
    self.make_error_at(code, self.eof_error_pos())
  }
}

///|
fn eof_allows_unclosed_element(name : StringView) -> Bool {
  match name {
    "body"
    | "dd"
    | "dt"
    | "head"
    | "html"
    | "li"
    | "optgroup"
    | "option"
    | "p"
    | "rb"
    | "rp"
    | "rt"
    | "rtc"
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
fn Parser::report_eof_tree_errors(self : Parser) -> Unit {
  let table_index = self.last_open_table_index()
  let caption_index = self.last_stack_index_of("caption")
  if table_index >= 0 && caption_index > table_index {
    self.error_at("expected-closing-tag-but-got-eof", self.eof_error_pos())
    return
  }
  if table_index >= 0 {
    self.error_at("eof-in-table", self.eof_error_pos())
    return
  }
  for node in self.stack {
    if node.kind == Element && !eof_allows_unclosed_element(node.name) {
      self.error_at("expected-closing-tag-but-got-eof", self.eof_error_pos())
      return
    }
  }
}

///|
fn Parser::parse_comment(self : Parser) -> Unit {
  self.pos += 4
  let scan = scan_comment_data(self.input, self.pos)
  for error in scan.errors {
    self.error_at(error.code, error.offset)
  }
  self.pos = scan.end
  let data = if self.xml_coercion {
    coerce_comment_for_xml(scan.data[:])
  } else {
    scan.data
  }
  self.current_node().append_child(comment(data))
}

///|
fn Parser::parse_bogus_comment(self : Parser) -> Unit {
  let data_start = self.pos
  while !self.is_eof() && self.current() != Some('>') {
    ignore(self.advance_char())
  }
  match self.input.get_view(start=data_start, end=self.pos) {
    Some(view) => {
      let data = normalize_bogus_comment_data(view)
      let data = if self.xml_coercion {
        coerce_comment_for_xml(data[:])
      } else {
        data
      }
      self.current_node().append_child(comment(data))
    }
    None => ()
  }
  if self.current() == Some('>') {
    ignore(self.advance_char())
  }
}

///|
fn Parser::parse_markup_declaration(self : Parser) -> Unit {
  self.pos += 2
  if self.starts_with("[CDATA[") {
    if self.current_node_is_foreign_namespace() {
      self.parse_foreign_cdata_section()
      return
    }
    self.error_at("cdata-in-html-content", self.pos + "[CDATA[".length() - 1)
  } else {
    self.error_at("incorrectly-opened-comment", self.pos - 1)
  }
  self.parse_bogus_comment()
}

///|
fn Parser::parse_foreign_cdata_section(self : Parser) -> Unit {
  self.pos += "[CDATA[".length()
  let start = self.pos
  while !self.is_eof() && !self.starts_with("]]>") {
    ignore(self.advance_char())
  }
  match self.input.get_view(start~, end=self.pos) {
    Some(view) => {
      let cleaned = if self.current_node_uses_foreign_content_for_text() {
        self.clean_foreign_content_text(view, start)
      } else {
        self.remove_null_characters(view, start)
      }
      if !cleaned.is_empty() {
        let data = if self.xml_coercion {
          coerce_text_for_xml(cleaned[:])
        } else {
          cleaned
        }
        self.current_node().append_child(text(data))
      }
    }
    None => ()
  }
  if self.starts_with("]]>") {
    self.pos += 3
  }
}

///|
fn Parser::parse_doctype(self : Parser) -> Unit {
  self.pos += "<!doctype".length()
  let missing_before_name = match self.current() {
    Some('>') | None => None
    Some(ch) if ch.is_ascii_whitespace() => {
      self.skip_ascii_whitespace()
      None
    }
    _ => Some(self.pos)
  }
  let name_start = self.pos
  while !self.is_eof() {
    match self.current() {
      Some('>') => break
      Some(ch) if ch.is_ascii_whitespace() => break
      Some(_) => ignore(self.advance_char())
      None => ()
    }
  }
  let (name, name_errors) = parse_lower_name_value_replacing_nulls(
    self.input,
    name_start,
    self.pos,
  )
  let ids_start = self.pos
  while !self.is_eof() && !self.starts_with(">") {
    ignore(self.advance_char())
  }
  let external = match self.input.get_view(start=ids_start, end=self.pos) {
    Some(view) => parse_doctype_external(view, self.starts_with(">"))
    None =>
      DoctypeExternalParse::{
        public_id: None,
        system_id: None,
        errors: [],
        force_quirks: false,
      }
  }
  let public_id = external.public_id
  let system_id = external.system_id
  let has_external_error = !external.errors.is_empty()
  let eof_doctype = name != "" && !has_external_error && !self.starts_with(">")
  let error_pos = if self.starts_with(">") {
    self.pos
  } else {
    self.eof_error_pos()
  }
  let force_quirks = name == "" || external.force_quirks || eof_doctype
  match missing_before_name {
    Some(pos) => self.error_at("missing-whitespace-before-doctype-name", pos)
    None => ()
  }
  for error in name_errors {
    self.error_at(error.code, error.offset)
  }
  if name == "" {
    if self.starts_with(">") {
      self.error_at("expected-doctype-name-but-got-right-bracket", error_pos)
    } else {
      self.error_at_eof("eof-in-doctype")
    }
  } else {
    for error in external.errors {
      self.error_at(error.code, ids_start + error.offset)
    }
  }
  if eof_doctype {
    self.error_at_eof("eof-in-doctype")
  }
  if self.starts_with(">") {
    self.pos += 1
  }
  if self.root.kind == Fragment {
    self.error_at("unexpected-doctype", error_pos)
    return
  }
  if !self.document_doctype_is_initial() {
    self.error_at("unexpected-doctype", error_pos)
    return
  }
  if !is_known_doctype(name, public_id, system_id) {
    self.error_at("unknown-doctype", error_pos)
  }
  self.root.append_child(
    make_node(
      Doctype,
      "#doctype",
      None,
      {},
      name,
      public_id,
      system_id,
      force_quirks,
      [],
    ),
  )
}

///|
fn Parser::parse_end_tag(self : Parser) -> Unit {
  let start = self.pos
  self.pos += 2
  match self.current() {
    Some('>') => {
      self.error_at("empty-end-tag", self.pos)
      ignore(self.advance_char())
      return
    }
    Some(ch) if !is_tag_name_start(ch) => {
      self.error_at("invalid-first-character-of-tag-name", self.pos)
      self.parse_bogus_comment()
      return
    }
    None => {
      self.error_at_eof("eof-before-tag-name")
      self.current_node().append_child(text("</"))
      return
    }
    _ => ()
  }
  let name_start = self.pos
  while !self.is_eof() {
    match self.current() {
      Some('>') => break
      Some('/') => break
      Some(ch) if ch.is_ascii_whitespace() => break
      Some(_) => ignore(self.advance_char())
      None => ()
    }
  }
  let (name, name_errors) = parse_lower_name_value_replacing_nulls(
    self.input,
    name_start,
    self.pos,
  )
  for error in name_errors {
    self.error_at(error.code, error.offset)
  }
  if name == "" {
    self.error_at("missing-end-tag-name", start)
  }
  let attrs : Map[String, String?] = {}
  let mut closed = false
  while !self.is_eof() {
    self.skip_ascii_whitespace()
    match self.current() {
      Some('>') => {
        ignore(self.advance_char())
        closed = true
        break
      }
      Some('/') => {
        ignore(self.advance_char())
        if self.current() == Some('>') {
          ignore(self.advance_char())
          closed = true
          break
        } else {
          self.error_at("unexpected-character-after-solidus-in-tag", self.pos)
        }
      }
      Some(_) => self.parse_attribute(attrs)
      None => ()
    }
  }
  if !closed {
    self.error_at_eof("eof-in-tag")
    return
  }
  if self.handle_before_html_end_tag(name, self.pos - 1) {
    return
  }
  if self.handle_foreign_content_end_tag(name, start) {
    return
  }
  if self.handle_document_frameset_end_tag(name, start) {
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
  if self.handle_table_end_tag(name) {
    return
  }
  self.report_table_context_end_tag_voodoo(name, start)
  if name == "br" {
    self.error_at("unexpected-end-tag", start)
    self.close_open_p_element()
    self.insert_body_mode_node(element("br"))
    return
  }
  if name == "p" {
    if !self.close_open_element("p") {
      self.error_at("unexpected-end-tag", start)
      self.insert_body_mode_node(element("p"))
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
  if self.handle_template_end_tag(name, start) {
    return
  }
  if self.fragment_end_tag_is_ignored(name) {
    return
  }
  if self.handle_select_end_tag(name, start) {
    return
  }
  if name == "ruby" {
    self.close_ruby_end_tag(start)
    return
  }
  if name != "" {
    self.pop_until(name, start)
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
fn Parser::fragment_end_tag_is_ignored(
  self : Parser,
  name : StringView,
) -> Bool {
  if !self.is_fragment_parser() {
    return false
  }
  match name {
    "html" => true
    "body" => !self.has_open_element("select")
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
      self.insert_body_mode_node(element("br"))
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
  start : Int,
) -> Bool {
  if self.is_fragment_parser() && !self.fragment_context_html {
    return false
  }
  if self.after_frameset {
    if name == "frameset" {
      self.error_at("unexpected-token-after-frameset", start)
    } else if self.after_frameset_ignored_depth > 0 {
      self.error_at("unexpected-token-in-frameset", start)
      self.after_frameset_ignored_depth -= 1
    } else {
      self.error_at("unexpected-token-after-frameset", start)
      self.error_at("unexpected-token-in-frameset", start)
    }
    return true
  }
  if !self.has_open_element("frameset") {
    return false
  }
  if name == "frameset" {
    ignore(self.close_open_element("frameset"))
    if !self.has_open_element("frameset") {
      self.after_frameset = true
    }
  } else {
    self.error_at("unexpected-token-in-frameset", start)
  }
  true
}

///|
fn Parser::pop_until(self : Parser, name : String, pos : Int) -> Unit {
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
    match self.stack.pop() {
      Some(node) if node.kind == Element && names_match_end_tag(node, name) =>
        break
      Some(_) => ()
      None => break
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
    match self.stack.pop() {
      Some(node) if node.kind == Element && node.name == name => break
      Some(_) => ()
      None => break
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
    return true
  }
  ignore(self.stack.pop())
  false
}

///|
fn Parser::open_html_element(self : Parser) -> Node? {
  for node in self.stack {
    if node.kind == Element && node.name == "html" {
      return Some(node)
    }
  }
  document_html_element(self.root)
}

///|
fn Parser::stack_contains_node(self : Parser, target : Node) -> Bool {
  for node in self.stack {
    if physical_equal(node, target) {
      return true
    }
  }
  false
}

///|
fn Parser::handle_repeated_document_html_start_tag(
  self : Parser,
  name : StringView,
  attrs : Map[String, String?],
  start : Int,
) -> Bool {
  if self.is_fragment_parser() ||
    self.has_open_element("select") ||
    name != "html" {
    return false
  }
  match self.open_html_element() {
    Some(html) => {
      self.error_at("unexpected-start-tag", start)
      merge_missing_attrs_from_map(html, attrs)
      if !self.stack_contains_node(html) {
        self.stack.push(html)
      }
      true
    }
    None => false
  }
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
fn Parser::remove_open_node(self : Parser, target : Node) -> Bool {
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
fn html_fragment_child_is_before_head(child : Node) -> Bool {
  child.kind == Comment || is_whitespace_text_node(child)
}

///|
fn html_fragment_child_is_before_body(child : Node) -> Bool {
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
fn html_fragment_children_are_before_head(html : Node) -> Bool {
  for child in html.children {
    if !html_fragment_child_is_before_head(child) {
      return false
    }
  }
  true
}

///|
fn html_fragment_children_are_before_body(html : Node) -> Bool {
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
) -> Unit {
  match self.fragment_context_html_root {
    Some(html) => html.append_child(element("body", attrs~))
    None => ()
  }
}

///|
fn Parser::insert_empty_html_fragment_body_marker(self : Parser) -> Unit {
  let attrs : Map[String, String?] = {}
  self.insert_html_fragment_body_marker(attrs)
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
      if self.current_node_allows_html_fragment_body() {
        false
      } else {
        self.error_at("unexpected-start-tag", start)
        self.frameset_ok = false
        self.insert_html_fragment_body_marker(attrs)
        true
      }
    "html" =>
      if self.current_node_allows_html_fragment_body() {
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
  if self.has_open_element("select") && (name == "body" || name == "head") {
    "unexpected-start-tag-in-select"
  } else {
    "unexpected-start-tag"
  }
}

///|
fn is_default_scope_terminator(name : StringView) -> Bool {
  match name {
    "applet"
    | "caption"
    | "html"
    | "marquee"
    | "object"
    | "table"
    | "td"
    | "template"
    | "th" => true
    _ => false
  }
}

///|
fn Parser::has_open_element_in_default_scope(
  self : Parser,
  name : String,
) -> Bool {
  let mut index = self.stack.length()
  while index > 0 {
    index -= 1
    let node = self.stack[index]
    if node.kind == Element {
      if node.name == name {
        return true
      }
      if is_default_scope_terminator(node.name) {
        return false
      }
    }
  }
  false
}

///|
fn is_list_item_scope_terminator(name : StringView) -> Bool {
  match name {
    "applet"
    | "caption"
    | "html"
    | "marquee"
    | "object"
    | "ol"
    | "table"
    | "td"
    | "template"
    | "th"
    | "ul" => true
    _ => false
  }
}

///|
fn Parser::close_open_list_item(self : Parser) -> Unit {
  let mut index = self.stack.length()
  while index > 0 {
    index -= 1
    let node = self.stack[index]
    if node.kind == Element {
      if node.name == "li" {
        ignore(self.close_open_element("li"))
        return
      }
      if is_list_item_scope_terminator(node.name) {
        return
      }
    }
  }
}

///|
fn is_definition_scope_terminator(name : StringView) -> Bool {
  match name {
    "applet"
    | "caption"
    | "dl"
    | "html"
    | "marquee"
    | "object"
    | "table"
    | "td"
    | "template"
    | "th" => true
    _ => false
  }
}

///|
fn Parser::close_open_definition_item_name(
  self : Parser,
  name : String,
) -> Unit {
  let mut index = self.stack.length()
  while index > 0 {
    index -= 1
    let node = self.stack[index]
    if node.kind == Element {
      if node.name == name {
        ignore(self.close_open_element(name))
        return
      }
      if is_definition_scope_terminator(node.name) {
        return
      }
    }
  }
}

///|
fn Parser::close_open_p_element(self : Parser) -> Unit {
  ignore(self.close_open_element("p"))
}

///|
fn Parser::close_open_definition_item(self : Parser, name : String) -> Unit {
  if name == "dd" {
    self.close_open_definition_item_name("dd")
    self.close_open_definition_item_name("dt")
  } else {
    self.close_open_definition_item_name("dt")
    self.close_open_definition_item_name("dd")
  }
}

///|
fn Parser::has_open_element(self : Parser, name : String) -> Bool {
  for node in self.stack {
    if node.kind == Element && node.name == name {
      return true
    }
  }
  false
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
fn Parser::close_open_select_item(self : Parser, name : String) -> Unit {
  self.close_current_element_if_name("option")
  if name == "optgroup" && self.has_open_element("select") {
    self.close_current_element_if_name("optgroup")
  }
}

///|
fn Parser::handle_select_end_tag(
  self : Parser,
  name : String,
  start : Int,
) -> Bool {
  match name {
    "optgroup" =>
      if self.has_open_element("select") {
        ignore(self.pop_current_element_if_name("option"))
        if !self.pop_current_element_if_name("optgroup") {
          self.error_at("unexpected-end-tag-in-select", start)
        }
        true
      } else {
        false
      }
    "option" =>
      if self.has_open_element("select") {
        if !self.pop_current_element_if_name("option") {
          self.error_at("unexpected-end-tag-in-select", start)
        }
        true
      } else {
        false
      }
    "select" =>
      if self.has_open_element("select") {
        ignore(self.close_open_element("select"))
        true
      } else {
        false
      }
    _ if select_common_element_start_reports_in_select(name) &&
      self.has_open_element("select") => {
      self.error_at("unexpected-end-tag-in-select", start)
      self.close_open_select_common_element(name)
      true
    }
    "menuitem" =>
      if self.has_open_element("select") {
        self.error_at("unexpected-end-tag", start)
        true
      } else {
        false
      }
    _ => false
  }
}

///|
fn select_common_element_start_reports_in_select(name : StringView) -> Bool {
  match name {
    "button" | "datalist" | "div" | "p" | "selectedcontent" | "span" => true
    _ => false
  }
}

///|
fn select_ignored_start_reports_in_select(name : StringView) -> Bool {
  match name {
    "aside" => true
    _ => false
  }
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
fn Parser::last_stack_index_of_node(self : Parser, target : Node) -> Int {
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
fn Parser::close_open_select_common_element(
  self : Parser,
  name : String,
) -> Unit {
  let select_index = self.last_stack_index_of("select")
  let target_index = self.last_stack_index_of(name)
  if target_index > select_index {
    while self.stack.length() > target_index {
      ignore(self.stack.pop())
    }
  }
}

///|
fn Parser::insert_element_without_push(
  self : Parser,
  name : StringView,
  attrs : Map[String, String?],
) -> Unit {
  self.current_node().append_child(element(name, attrs~))
}

///|
fn Parser::insert_element_maybe_push(
  self : Parser,
  name : StringView,
  attrs : Map[String, String?],
  push : Bool,
) -> Unit {
  let node = element(name, attrs~)
  self.current_node().append_child(node)
  if push {
    self.stack.push(node)
  }
}

///|
fn Parser::handle_select_special_start_tag(
  self : Parser,
  name : String,
  attrs : Map[String, String?],
  self_closing : Bool,
  start : Int,
) -> Bool {
  if !self.has_open_element("select") {
    return false
  }
  if name == "plaintext" {
    self.error_at("unexpected-start-tag-in-select", start)
    let node = element(name, attrs~)
    self.current_node().append_child(node)
    self.consume_special_element_content(node, name)
    ignore(self.close_open_element("select"))
    return true
  }
  if name == "hr" {
    self.error_at("unexpected-start-tag-in-select", start)
    ignore(self.pop_current_element_if_name("option"))
    ignore(self.pop_current_element_if_name("optgroup"))
    self.insert_element_without_push("hr", attrs)
    return true
  }
  if name == "br" || name == "img" {
    self.error_at("unexpected-start-tag-in-select", start)
    self.insert_element_without_push(name, attrs)
    return true
  }
  if name == "menuitem" {
    self.error_at("unexpected-start-tag-in-select", start)
    self.insert_element_maybe_push(name, attrs, !self_closing)
    return true
  }
  if select_common_element_start_reports_in_select(name) {
    self.error_at("unexpected-start-tag-in-select", start)
    self.insert_element_maybe_push(name, attrs, !self_closing)
    return true
  }
  if select_ignored_start_reports_in_select(name) {
    self.error_at("unexpected-start-tag-in-select", start)
    return true
  }
  false
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
fn Parser::document_start_tag_preserves_frameset_ok(
  self : Parser,
  name : StringView,
) -> Bool {
  (self.is_fragment_parser() && !self.fragment_context_html) ||
  name == "html" ||
  name == "head" ||
  name == "frameset" ||
  is_document_head_element_name(name)
}

///|
fn Parser::insert_empty_frameset_child(
  self : Parser,
  name : StringView,
  attrs : Map[String, String?],
) -> Unit {
  self.current_node().append_child(element(name, attrs~))
}

///|
fn Parser::handle_document_frameset_start_tag(
  self : Parser,
  name : String,
  attrs : Map[String, String?],
  self_closing : Bool,
  start : Int,
) -> Bool {
  if self.is_fragment_parser() && !self.fragment_context_html {
    return false
  }
  if self.after_frameset {
    if name == "noframes" {
      return false
    }
    self.error_at("unexpected-token-after-frameset", start)
    self.error_at("unexpected-token-in-frameset", start)
    if !self_closing && !is_void_element(name) {
      self.after_frameset_ignored_depth += 1
    }
    return true
  }
  if self.has_open_element("frameset") {
    match name {
      "frameset" => {
        self.insert_element_maybe_push(name, attrs, true)
        true
      }
      "frame" => {
        self.insert_empty_frameset_child(name, attrs)
        true
      }
      "noframes" => false
      _ => {
        self.error_at("unexpected-token-in-frameset", start)
        true
      }
    }
  } else if name == "frameset" {
    if !self.frameset_ok {
      self.error_at("unexpected-start-tag-ignored", start)
      true
    } else {
      self.insert_element_maybe_push(name, attrs, true)
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
    match self.stack.pop() {
      Some(node) if node.kind == Element && is_heading_element_name(node.name) =>
        break
      Some(_) => ()
      None => break
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
fn current_node_is_ruby_annotation(node : Node) -> Bool {
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
    Some(ch) if is_tag_name_start(ch) => {
      let name_start = self.pos
      while !self.is_eof() {
        match self.current() {
          Some(ch) if !is_tag_name_end(ch) => ignore(self.advance_char())
          _ => break
        }
      }
      let (name, name_errors) = parse_lower_name_value_replacing_nulls(
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
        match self.current() {
          Some('>') => {
            ignore(self.advance_char())
            closed = true
            break
          }
          Some('/') => {
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
          Some(_) => self.parse_attribute(attrs)
          None => ()
        }
      }
      if !closed {
        self.error_at_eof("eof-in-tag")
        return
      }
      self.before_html_phase = false
      if self.handle_foreign_content_start_tag(name, attrs, self_closing, start) {
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
      if self.handle_repeated_document_html_start_tag(name, attrs, start) {
        return
      }
      if self.has_open_element("select") && name == "frame" {
        self.error_at("unexpected-start-tag-in-select", start)
        return
      }
      if self.handle_select_special_start_tag(name, attrs, self_closing, start) {
        return
      }
      if self.handle_document_frameset_start_tag(
          name, attrs, self_closing, start,
        ) {
        return
      }
      if !self.is_fragment_parser() && name == "frame" {
        self.error_at("unexpected-start-tag-ignored", start)
        return
      }
      if self.handle_template_table_context_start_tag(name, attrs, start) {
        return
      }
      self.report_template_table_context_fostered_start(name, start)
      let in_template_table_context = self.in_template_content_without_inner_table()
      if name == "col" && in_template_table_context {
        let current = self.current_node()
        if current.kind == Element && current.name == "template" {
          self.template_column_group_mode = true
        }
      }
      if self.handle_template_column_group_start_tag(name, attrs, start) {
        return
      }
      if self.handle_fragment_context_colgroup_start_tag(name, attrs, start) {
        return
      }
      if self.has_open_element("select") &&
        select_start_tag_reprocesses_in_body(name) {
        self.error_at("unexpected-start-tag-in-select", start)
        ignore(self.close_open_element("select"))
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
      if self.close_current_caption_for_start(name, start) &&
        self.handle_template_table_context_start_tag(name, attrs, start) {
        return
      }
      self.close_current_column_group_for_start(name, start)
      if self.handle_table_context_hidden_input_or_form_start(
          name, attrs, start,
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
      if self.handle_fragment_context_table_start_tag(name, start) {
        return
      }
      ignore(self.handle_nested_table_start_tag(name, start))
      if !closed_table_cell {
        self.report_unexpected_table_body_cell_start(name, start)
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
      if name == "select" && self.has_open_element("select") {
        self.error_at("unexpected-select-in-select", start)
        ignore(self.close_open_element("select"))
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
      if !self.document_start_tag_preserves_frameset_ok(name) {
        self.frameset_ok = false
      }
      let node_ns = self.start_tag_namespace(name)
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
      let node = element(adjusted_name, attrs=adjusted_attrs, ns=node_ns)
      if adjusted_name == "form" {
        self.form_element = Some(node)
      }
      self.append_start_tag_node(node, adjusted_name, start)
      let self_closes_tree = if node_ns == "html" {
        self_closing && is_void_element(adjusted_name)
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
        !is_void_element(adjusted_name) &&
        !inserts_empty_nonvoid {
        self.stack.push(node)
        if node_ns == "html" && start_tag_ignores_initial_lf(adjusted_name) {
          self.skip_one_initial_lf()
        }
      }
    }
    _ =>
      if self.current() is None {
        self.error_at_eof("eof-before-tag-name")
        self.current_node().append_child(text("<"))
      } else if self.current() == Some('?') {
        self.error_at("unexpected-question-mark-instead-of-tag-name", self.pos)
        self.parse_bogus_comment()
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
  match self.input.get_view(start~, end=self.pos) {
    Some(view) => self.append_text(view, start)
    None => ()
  }
}

///|
fn Parser::parse_attribute(self : Parser, attrs : Map[String, String?]) -> Unit {
  let name_start = self.pos
  if self.current() == Some('=') {
    self.error_at("unexpected-equals-sign-before-attribute-name", self.pos)
    ignore(self.advance_char())
  }
  while !self.is_eof() {
    match self.current() {
      Some(ch) if ch.is_ascii_whitespace() ||
        ch == '=' ||
        ch == '/' ||
        ch == '>' => break
      Some('<') | Some('"') | Some('\'') => {
        self.error_at("unexpected-character-in-attribute-name", self.pos)
        ignore(self.advance_char())
      }
      Some(_) => ignore(self.advance_char())
      None => ()
    }
  }
  let (name, name_errors) = parse_lower_name_value_replacing_nulls(
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
        match self.current() {
          Some(ch) if ch.is_ascii_whitespace() || ch == '>' => break
          Some('\u{0000}') => {
            self.error_at("unexpected-null-character", self.pos)
            ignore(self.advance_char())
          }
          Some('"') | Some('\'') | Some('<') | Some('=') | Some('`') => {
            self.error_at(
              "unexpected-character-in-unquoted-attribute-value",
              self.pos,
            )
            ignore(self.advance_char())
          }
          Some(_) => ignore(self.advance_char())
          None => ()
        }
      }
      match self.input.get_view(start~, end=self.pos) {
        Some(view) => {
          let decoded = decode_attribute_value_with_errors(view)
          for error in decoded.errors {
            self.error_at(error.code, self.pos)
          }
          decoded.data
        }
        None => ""
      }
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
  let raw = self.input.get_view(start~, end=self.pos)
  if self.current() == Some(quote) {
    ignore(self.advance_char())
    match self.current() {
      Some(ch) if !ch.is_ascii_whitespace() && ch != '>' && ch != '/' =>
        self.error_at("missing-whitespace-between-attributes", self.pos)
      _ => ()
    }
  }
  match raw {
    Some(view) => {
      let decoded = decode_attribute_value_with_errors(view)
      for error in decoded.errors {
        self.error_at(error.code, self.pos)
      }
      decoded.data
    }
    None => ""
  }
}

///|
fn is_tag_name_start(ch : Char) -> Bool {
  ch.is_ascii_alphabetic()
}

///|
fn is_tag_name_end(ch : Char) -> Bool {
  ch.is_ascii_whitespace() || ch == '/' || ch == '>'
}

///|
fn Parser::is_special_text_element(self : Parser, name : StringView) -> Bool {
  if name == "noscript" {
    self.scripting_enabled
  } else {
    is_special_text_element(name)
  }
}

///|
fn is_special_text_element(name : StringView) -> Bool {
  match name {
    "iframe"
    | "noembed"
    | "noframes"
    | "noscript"
    | "plaintext"
    | "script"
    | "style"
    | "title"
    | "textarea"
    | "xmp" => true
    _ => false
  }
}

///|
fn special_text_decodes_entities(name : StringView) -> Bool {
  match name {
    "title" | "textarea" => true
    _ => false
  }
}

///|
fn special_text_eof_error_code(name : StringView) -> String {
  match name {
    "noframes" | "script" | "style" | "title" | "xmp" =>
      "expected-named-closing-tag-but-got-eof"
    _ => "expected-closing-tag-but-got-eof"
  }
}

///|
fn Parser::error_at_special_text_eof(self : Parser, name : StringView) -> Unit {
  self.error_at(special_text_eof_error_code(name), self.eof_error_pos())
}

///|
fn Parser::decoded_special_text(
  self : Parser,
  name : StringView,
  raw : StringView,
  start : Int,
  error_pos : Int,
) -> String {
  let (raw, offset) = if name == "textarea" {
    strip_one_initial_lf_with_offset(raw)
  } else {
    (raw, 0)
  }
  let raw = self.replace_null_characters(raw, start + offset)
  let data = if special_text_decodes_entities(name) {
    let decoded = decode_entities_with_errors(raw, in_attribute=false)
    for error in decoded.errors {
      self.error_at(error.code, error_pos)
    }
    decoded.data
  } else {
    normalize_newlines(raw)
  }
  if self.xml_coercion {
    coerce_text_for_xml(data[:])
  } else {
    data
  }
}

///|
fn strip_one_initial_lf_with_offset(input : StringView) -> (StringView, Int) {
  match input.get_char(0) {
    Some('\r') =>
      if input.get_char(1) == Some('\n') {
        (input[2:], 2)
      } else {
        (input[1:], 1)
      }
    Some('\n') => (input[1:], 1)
    _ => (input, 0)
  }
}

///|
fn Parser::skip_one_initial_lf(self : Parser) -> Unit {
  match self.current() {
    Some('\r') => {
      self.pos += 1
      if self.current() == Some('\n') {
        self.pos += 1
      }
    }
    Some('\n') => self.pos += 1
    _ => ()
  }
}

///|
fn start_tag_ignores_initial_lf(name : StringView) -> Bool {
  match name {
    "pre" | "listing" => true
    _ => false
  }
}

///|
fn parse_quoted_doctype_value_at(
  input : StringView,
  start : Int,
  errors : Array[DoctypeExternalError],
) -> (String?, Int, Bool) {
  match input.get_char(start) {
    Some('"') | Some('\'') as quote_opt => {
      guard quote_opt is Some(quote)
      let mut pos = start + quote.utf16_len()
      let value_start = pos
      while pos < input.length() && input.get_char(pos) != Some(quote) {
        match input.get_char(pos) {
          Some(ch) => pos += ch.utf16_len()
          None => break
        }
      }
      let mut closed = false
      let value = Some(normalize_doctype_value(input, value_start, pos, errors))
      if input.get_char(pos) == Some(quote) {
        pos += quote.utf16_len()
        closed = true
      }
      (value, pos, closed)
    }
    _ => (None, start, false)
  }
}

///|
fn skip_ascii_whitespace_in_view(input : StringView, start : Int) -> Int {
  let mut pos = start
  while pos < input.length() {
    match input.get_char(pos) {
      Some(ch) if ch.is_ascii_whitespace() => pos += ch.utf16_len()
      _ => break
    }
  }
  pos
}

///|
fn view_has_prefix_case_insensitive_at(
  input : StringView,
  start : Int,
  prefix : StringView,
) -> Bool {
  let end = start + prefix.length()
  if end > input.length() {
    false
  } else {
    match input.get_view(start~, end~) {
      Some(view) => view.compare_ignore_ascii_case(prefix) == 0
      None => false
    }
  }
}

///|
fn normalize_doctype_value(
  input : StringView,
  start : Int,
  end : Int,
  errors : Array[DoctypeExternalError],
) -> String {
  let out = StringBuilder::new(size_hint=end - start)
  let mut pos = start
  while pos < end {
    match input.get_char(pos) {
      Some('\u{0000}') => {
        push_doctype_external_error(errors, "unexpected-null-character", pos)
        out.write_char('\u{FFFD}')
        pos += 1
      }
      Some('\r') => {
        out.write_char('\n')
        pos += 1
        if pos < end && input.get_char(pos) == Some('\n') {
          pos += 1
        }
      }
      Some(ch) => {
        out.write_char(ch)
        pos += ch.utf16_len()
      }
      None => break
    }
  }
  out.to_string()
}

///|
fn parse_lower_name_value_replacing_nulls(
  input : StringView,
  start : Int,
  end : Int,
) -> (String, Array[DoctypeExternalError]) {
  let errors : Array[DoctypeExternalError] = []
  if start >= end {
    return ("", errors)
  }
  let out = StringBuilder::new(size_hint=end - start)
  let mut pos = start
  while pos < end {
    match input.get_char(pos) {
      Some('\u{0000}') => {
        push_doctype_external_error(errors, "unexpected-null-character", pos)
        out.write_char('\u{FFFD}')
        pos += 1
      }
      Some(ch) => {
        if ch.is_ascii_uppercase() {
          out.write_char(ch.to_ascii_lowercase())
        } else {
          out.write_char(ch)
        }
        pos += ch.utf16_len()
      }
      None => break
    }
  }
  (out.to_string(), errors)
}

///|
fn view_last_char_offset(input : StringView) -> Int {
  let mut last = 0
  let mut pos = 0
  while pos < input.length() {
    last = pos
    match input.get_char(pos) {
      Some(ch) => pos += ch.utf16_len()
      None => break
    }
  }
  last
}

///|
priv struct DoctypeExternalError {
  code : String
  offset : Int
}

///|
priv struct DoctypeExternalParse {
  public_id : String?
  system_id : String?
  errors : Array[DoctypeExternalError]
  force_quirks : Bool
}

///|
fn push_doctype_external_error(
  errors : Array[DoctypeExternalError],
  code : String,
  offset : Int,
) -> Unit {
  errors.push(DoctypeExternalError::{ code, offset })
}

///|
fn doctype_after_system_identifier(
  input : StringView,
  after_system : Int,
  closed : Bool,
  errors : Array[DoctypeExternalError],
) -> Bool {
  let next = skip_ascii_whitespace_in_view(input, after_system)
  if next >= input.length() {
    if closed {
      false
    } else {
      push_doctype_external_error(
        errors,
        "eof-in-doctype",
        view_last_char_offset(input),
      )
      true
    }
  } else {
    push_doctype_external_error(
      errors, "unexpected-character-after-doctype-system-identifier", next,
    )
    false
  }
}

///|
fn parse_doctype_system_identifier_at(
  input : StringView,
  quote_pos : Int,
  closed : Bool,
  errors : Array[DoctypeExternalError],
) -> (String?, Bool) {
  let (system_id, after_system, system_closed) = parse_quoted_doctype_value_at(
    input, quote_pos, errors,
  )
  if !system_closed {
    if closed {
      push_doctype_external_error(
        errors,
        "abrupt-doctype-system-identifier",
        input.length(),
      )
    } else {
      push_doctype_external_error(
        errors,
        "eof-in-doctype-system-identifier",
        view_last_char_offset(input),
      )
    }
    (system_id, true)
  } else {
    (
      system_id,
      doctype_after_system_identifier(input, after_system, closed, errors),
    )
  }
}

///|
fn parse_doctype_system_after_keyword(
  input : StringView,
  after_keyword : Int,
  closed : Bool,
  errors : Array[DoctypeExternalError],
) -> (String?, Bool) {
  match input.get_char(after_keyword) {
    None =>
      if closed {
        push_doctype_external_error(
          errors,
          "missing-doctype-system-identifier",
          input.length(),
        )
        (None, true)
      } else {
        push_doctype_external_error(
          errors,
          "missing-quote-before-doctype-system-identifier",
          after_keyword - 1,
        )
        (None, true)
      }
    Some(ch) if ch.is_ascii_whitespace() => {
      let id_pos = skip_ascii_whitespace_in_view(input, after_keyword)
      if id_pos >= input.length() {
        push_doctype_external_error(
          errors,
          "missing-doctype-system-identifier",
          if closed {
            input.length()
          } else {
            view_last_char_offset(input)
          },
        )
        (None, true)
      } else {
        match input.get_char(id_pos) {
          Some('"') | Some('\'') =>
            parse_doctype_system_identifier_at(input, id_pos, closed, errors)
          _ => {
            push_doctype_external_error(
              errors, "missing-quote-before-doctype-system-identifier", id_pos,
            )
            (None, true)
          }
        }
      }
    }
    Some('"') | Some('\'') => {
      push_doctype_external_error(
        errors, "missing-whitespace-after-doctype-public-identifier", after_keyword,
      )
      parse_doctype_system_identifier_at(input, after_keyword, closed, errors)
    }
    _ => {
      push_doctype_external_error(
        errors, "unexpected-character-after-doctype-system-keyword", after_keyword,
      )
      (None, true)
    }
  }
}

///|
fn parse_doctype_after_public_identifier(
  input : StringView,
  after_public : Int,
  closed : Bool,
  errors : Array[DoctypeExternalError],
) -> (String?, Bool) {
  match input.get_char(after_public) {
    None =>
      if closed {
        (None, false)
      } else {
        push_doctype_external_error(
          errors,
          "missing-whitespace-between-doctype-public-and-system-identifiers",
          view_last_char_offset(input),
        )
        (None, true)
      }
    Some(ch) if ch.is_ascii_whitespace() => {
      let system_pos = skip_ascii_whitespace_in_view(input, after_public)
      if system_pos >= input.length() {
        if closed {
          (None, false)
        } else {
          push_doctype_external_error(
            errors,
            "missing-quote-before-doctype-system-identifier",
            view_last_char_offset(input),
          )
          (None, true)
        }
      } else {
        match input.get_char(system_pos) {
          Some('"') | Some('\'') =>
            parse_doctype_system_identifier_at(
              input, system_pos, closed, errors,
            )
          _ => {
            push_doctype_external_error(
              errors, "missing-quote-before-doctype-system-identifier", system_pos,
            )
            (None, true)
          }
        }
      }
    }
    Some('"') | Some('\'') => {
      push_doctype_external_error(
        errors, "missing-whitespace-between-doctype-public-and-system-identifiers",
        after_public,
      )
      parse_doctype_system_identifier_at(input, after_public, closed, errors)
    }
    _ => {
      push_doctype_external_error(
        errors, "unexpected-character-after-doctype-public-identifier", after_public,
      )
      (None, true)
    }
  }
}

///|
fn parse_doctype_public_after_keyword(
  input : StringView,
  after_keyword : Int,
  closed : Bool,
  errors : Array[DoctypeExternalError],
) -> (String?, String?, Bool) {
  let mut force_quirks = false
  let public_pos = match input.get_char(after_keyword) {
    None =>
      if closed {
        push_doctype_external_error(
          errors,
          "missing-doctype-public-identifier",
          input.length(),
        )
        force_quirks = true
        None
      } else {
        push_doctype_external_error(
          errors,
          "missing-quote-before-doctype-public-identifier",
          after_keyword - 1,
        )
        force_quirks = true
        None
      }
    Some(ch) if ch.is_ascii_whitespace() => {
      let id_pos = skip_ascii_whitespace_in_view(input, after_keyword)
      if id_pos >= input.length() {
        push_doctype_external_error(
          errors,
          "missing-doctype-public-identifier",
          if closed {
            input.length()
          } else {
            view_last_char_offset(input)
          },
        )
        force_quirks = true
        None
      } else {
        match input.get_char(id_pos) {
          Some('"') | Some('\'') => Some(id_pos)
          _ => {
            push_doctype_external_error(
              errors, "missing-quote-before-doctype-public-identifier", id_pos,
            )
            force_quirks = true
            None
          }
        }
      }
    }
    Some('"') | Some('\'') => {
      push_doctype_external_error(
        errors, "missing-whitespace-before-doctype-public-identifier", after_keyword,
      )
      Some(after_keyword)
    }
    _ => {
      push_doctype_external_error(
        errors, "unexpected-character-after-doctype-public-keyword", after_keyword,
      )
      force_quirks = true
      None
    }
  }
  match public_pos {
    None => (None, None, force_quirks)
    Some(pos) => {
      let (public_id, after_public, public_closed) = parse_quoted_doctype_value_at(
        input, pos, errors,
      )
      if !public_closed {
        if closed {
          push_doctype_external_error(
            errors,
            "abrupt-doctype-public-identifier",
            input.length(),
          )
        } else {
          push_doctype_external_error(
            errors,
            "eof-in-doctype-public-identifier",
            view_last_char_offset(input),
          )
        }
        (public_id, None, true)
      } else {
        let (system_id, system_force_quirks) = parse_doctype_after_public_identifier(
          input, after_public, closed, errors,
        )
        (public_id, system_id, force_quirks || system_force_quirks)
      }
    }
  }
}

///|
fn parse_doctype_external(
  input : StringView,
  closed : Bool,
) -> DoctypeExternalParse {
  let errors : Array[DoctypeExternalError] = []
  let mut public_id : String? = None
  let mut system_id : String? = None
  let mut force_quirks = false
  match input.get_char(0) {
    Some(ch) if ch.is_ascii_whitespace() => {
      let start = ch.utf16_len()
      if view_has_prefix_case_insensitive_at(input, start, "public") {
        let (parsed_public, parsed_system, force) = parse_doctype_public_after_keyword(
          input,
          start + 6,
          closed,
          errors,
        )
        public_id = parsed_public
        system_id = parsed_system
        force_quirks = force
      } else if view_has_prefix_case_insensitive_at(input, start, "system") {
        let (parsed_system, force) = parse_doctype_system_after_keyword(
          input,
          start + 6,
          closed,
          errors,
        )
        system_id = parsed_system
        force_quirks = force
      } else {
        let unexpected = skip_ascii_whitespace_in_view(input, start)
        if unexpected < input.length() {
          push_doctype_external_error(
            errors, "missing-whitespace-after-doctype-name", unexpected,
          )
          force_quirks = true
        }
      }
    }
    _ => ()
  }
  DoctypeExternalParse::{ public_id, system_id, errors, force_quirks }
}

///|
fn is_known_doctype(
  name : StringView,
  public_id : String?,
  system_id : String?,
) -> Bool {
  if name != "html" {
    return false
  }
  match (public_id, system_id) {
    (None, None) => true
    (None, Some("about:legacy-compat")) => true
    (Some("-//W3C//DTD HTML 4.0//EN"), None) => true
    (
      Some("-//W3C//DTD HTML 4.0//EN"),
      Some("http://www.w3.org/TR/REC-html40/strict.dtd"),
    ) => true
    (Some("-//W3C//DTD HTML 4.01//EN"), None) => true
    (
      Some("-//W3C//DTD HTML 4.01//EN"),
      Some("http://www.w3.org/TR/html4/strict.dtd"),
    ) => true
    (
      Some("-//W3C//DTD XHTML 1.0 Strict//EN"),
      Some("http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"),
    ) => true
    (
      Some("-//W3C//DTD XHTML 1.1//EN"),
      Some("http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd"),
    ) => true
    _ => false
  }
}

///|
fn find_matching_end_tag(
  input : StringView,
  start : Int,
  name : StringView,
) -> Int? {
  let needle = "</" + name.to_owned()
  let mut pos = start
  while pos < input.length() {
    if starts_with_case_insensitive(input, pos, needle) {
      let after_name = pos + needle.length()
      match input.get_char(after_name) {
        Some('>') => return Some(pos)
        Some('/') => return Some(pos)
        Some(ch) if ch.is_ascii_whitespace() => return Some(pos)
        _ => ()
      }
    }
    match input.get_char(pos) {
      Some(ch) => pos += ch.utf16_len()
      None => break
    }
  }
  None
}

///|
fn matching_end_tag_error_pos(input : StringView, start : Int) -> Int {
  let mut pos = start
  while pos < input.length() {
    match input.get_char(pos) {
      Some('>') => return pos
      Some(ch) => pos += ch.utf16_len()
      None => break
    }
  }
  eof_error_pos(input)
}

///|
fn Parser::skip_matching_end_tag(self : Parser) -> Unit {
  self.pos += 2
  while !self.is_eof() {
    match self.current() {
      Some('>') => break
      Some(_) => ignore(self.advance_char())
      None => ()
    }
  }
  if self.current() == Some('>') {
    ignore(self.advance_char())
  }
}

///|
fn Parser::consume_special_element_content(
  self : Parser,
  parent : Node,
  name : String,
) -> Unit {
  let content_start = self.pos
  if name == "plaintext" {
    match self.input.get_view(start=content_start, end=self.input.length()) {
      Some(view) =>
        parent.append_child(
          text(
            self.decoded_special_text(
              name,
              view,
              content_start,
              eof_error_pos(self.input),
            ),
          ),
        )
      None => ()
    }
    self.error_at_special_text_eof(name)
    self.pos = self.input.length()
    return
  }
  if name == "script" {
    let scan = scan_script_text(self.input, self.pos)
    for error in scan.errors {
      self.error_at(error.code, error.offset)
    }
    if !scan.data.is_empty() {
      let data = if self.xml_coercion {
        coerce_text_for_xml(scan.data[:])
      } else {
        scan.data
      }
      parent.append_child(text(data))
    }
    match scan.end_start {
      Some(end_start) => {
        self.pos = end_start
        self.skip_matching_end_tag()
      }
      None => {
        self.error_at_special_text_eof(name)
        self.pos = self.input.length()
      }
    }
    return
  }
  match find_matching_end_tag(self.input, self.pos, name) {
    Some(end_start) => {
      let error_pos = matching_end_tag_error_pos(self.input, end_start)
      match self.input.get_view(start=content_start, end=end_start) {
        Some(view) =>
          parent.append_child(
            text(
              self.decoded_special_text(name, view, content_start, error_pos),
            ),
          )
        None => ()
      }
      self.pos = end_start
      self.skip_matching_end_tag()
    }
    None => {
      let error_pos = eof_error_pos(self.input)
      match self.input.get_view(start=content_start, end=self.input.length()) {
        Some(view) =>
          parent.append_child(
            text(
              self.decoded_special_text(name, view, content_start, error_pos),
            ),
          )
        None => ()
      }
      self.error_at_special_text_eof(name)
      self.pos = self.input.length()
    }
  }
}

///|
fn is_fragment_raw_text_context(name : StringView) -> Bool {
  match name {
    "style" | "textarea" | "title" => true
    _ => false
  }
}

///|
fn is_fragment_plain_text_context(name : StringView) -> Bool {
  match name {
    "plaintext" | "script" => true
    _ => false
  }
}

///|
fn is_fragment_table_section_context(name : StringView) -> Bool {
  match name {
    "tbody" | "thead" | "tfoot" => true
    _ => false
  }
}

///|
fn Parser::append_fragment_context_text(
  self : Parser,
  raw : StringView,
  start : Int,
) -> Unit {
  if raw.is_empty() {
    return
  }
  let raw = self.replace_null_characters(raw, start)
  let data = normalize_newlines(raw)
  let data = if self.xml_coercion { coerce_text_for_xml(data[:]) } else { data }
  self.root.append_child(text(data))
}

///|
fn unwrap_fragment_context_element(parent : Node, wrapper : Node) -> Unit {
  let original = parent.children.copy()
  parent.children.clear()
  for child in original {
    if physical_equal(child, wrapper) {
      let children = wrapper.children.copy()
      wrapper.children.clear()
      wrapper.parent = None
      for grandchild in children {
        parent.append_child(grandchild)
      }
    } else {
      parent.append_child(child)
    }
  }
}

///|
fn Parser::parse_table_fragment_context(self : Parser) -> Unit {
  let table = element("table")
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
  let table = element("table")
  let section = element(name)
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
  let table = element("table")
  let section = element("tbody")
  let row = element("tr")
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
  let table = element("table")
  let section = element("tbody")
  let row = element("tr")
  let cell = element(name)
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

///|
fn Parser::parse_html_fragment_context(self : Parser) -> Unit {
  let html = element("html")
  self.fragment_context_html = true
  self.fragment_context_html_root = Some(html)
  self.frameset_ok = true
  self.root.append_child(html)
  self.stack.push(html)
  self.parse_all()
  scaffold_existing_html_element(html)
  unwrap_fragment_context_element(self.root, html)
  self.fragment_context_html_root = None
  self.fragment_context_html = false
}

///|
fn Parser::parse_fragment_context(
  self : Parser,
  context : FragmentContext,
) -> Bool {
  let context_ns = match context.ns {
    Some("mathml") => "math"
    Some(ns) => ns
    None => "html"
  }
  if context_ns != "html" {
    if is_foreign_namespace(context_ns) {
      self.parse_foreign_fragment_context(context, context_ns)
      return true
    }
    return false
  }
  let name = context.tag_name
  if is_fragment_plain_text_context(name) {
    match self.input.get_view(start=0, end=self.input.length()) {
      Some(view) => self.append_fragment_context_text(view, 0)
      None => ()
    }
    self.pos = self.input.length()
    return true
  }
  if is_fragment_raw_text_context(name) {
    match find_matching_end_tag(self.input, 0, name) {
      Some(end_start) => {
        match self.input.get_view(start=0, end=end_start) {
          Some(view) => self.append_fragment_context_text(view, 0)
          None => ()
        }
        self.pos = end_start
        self.skip_matching_end_tag()
        self.error_at("unexpected-end-tag", end_start)
        self.parse_all()
      }
      None => {
        match self.input.get_view(start=0, end=self.input.length()) {
          Some(view) => self.append_fragment_context_text(view, 0)
          None => ()
        }
        self.pos = self.input.length()
      }
    }
    return true
  }
  if name == "html" {
    self.parse_html_fragment_context()
    return true
  }
  if name == "table" {
    self.parse_table_fragment_context()
    return true
  }
  if is_fragment_table_section_context(name) {
    self.parse_table_section_fragment_context(name)
    return true
  }
  if name == "tr" {
    self.parse_table_row_fragment_context()
    return true
  }
  if name == "td" || name == "th" {
    self.parse_table_cell_fragment_context(name)
    return true
  }
  if name == "caption" {
    self.fragment_context_caption = true
    self.parse_all()
    self.fragment_context_caption = false
    return true
  }
  if name == "colgroup" {
    self.fragment_context_colgroup = true
    self.parse_all()
    self.fragment_context_colgroup = false
    return true
  }
  false
}

///|
fn line_col_at(input : StringView, target : Int) -> (Int, Int) {
  if target == input.length() && input_ends_with_newline(input) {
    return eof_line_col(input)
  }
  let mut offset = 0
  let mut line = 1
  let mut col = 1
  while offset < target && offset < input.length() {
    match input.get_char(offset) {
      Some('\r') => {
        line += 1
        col = 1
        offset += 1
        if offset < target && input.get_char(offset) == Some('\n') {
          offset += 1
        }
      }
      Some('\n') => {
        line += 1
        col = 1
        offset += 1
      }
      Some(ch) => {
        col += 1
        offset += ch.utf16_len()
      }
      None => break
    }
  }
  (line, col)
}

///|
fn input_ends_with_newline(input : StringView) -> Bool {
  let mut pos = 0
  let mut last : Char? = None
  while pos < input.length() {
    match input.get_char(pos) {
      Some(ch) => {
        last = Some(ch)
        pos += ch.utf16_len()
      }
      None => break
    }
  }
  match last {
    Some('\r') | Some('\n') => true
    _ => false
  }
}

///|
fn eof_line_col(input : StringView) -> (Int, Int) {
  let mut offset = 0
  let mut line = 1
  let mut col = 0
  while offset < input.length() {
    match input.get_char(offset) {
      Some('\r') => {
        line += 1
        col = 0
        offset += 1
        if offset < input.length() && input.get_char(offset) == Some('\n') {
          offset += 1
        }
      }
      Some('\n') => {
        line += 1
        col = 0
        offset += 1
      }
      Some(ch) => {
        col += 1
        offset += ch.utf16_len()
      }
      None => break
    }
  }
  (line, col)
}

///|
fn strip_leading_bom(input : StringView) -> StringView {
  if input.has_prefix("\u{FEFF}") {
    input[1:]
  } else {
    input
  }
}

///|
fn normalize_newlines(input : StringView) -> String {
  let out = StringBuilder::new(size_hint=input.length())
  let mut pos = 0
  while pos < input.length() {
    match input.get_char(pos) {
      Some('\r') => {
        out.write_char('\n')
        pos += 1
        if input.get_char(pos) == Some('\n') {
          pos += 1
        }
      }
      Some(ch) => {
        out.write_char(ch)
        pos += ch.utf16_len()
      }
      None => break
    }
  }
  out.to_string()
}

///|
fn normalize_bogus_comment_data(input : StringView) -> String {
  let out = StringBuilder::new(size_hint=input.length())
  let mut pos = 0
  while pos < input.length() {
    match input.get_char(pos) {
      Some('\u{0000}') => {
        out.write_char('\u{FFFD}')
        pos += 1
      }
      Some('\r') => {
        out.write_char('\n')
        pos += 1
        if input.get_char(pos) == Some('\n') {
          pos += 1
        }
      }
      Some(ch) => {
        out.write_char(ch)
        pos += ch.utf16_len()
      }
      None => break
    }
  }
  out.to_string()
}

///|
fn write_normalized_char(
  input : StringView,
  pos : Int,
  out : StringBuilder,
) -> Int {
  match input.get_char(pos) {
    Some('\r') => {
      out.write_char('\n')
      let next = pos + 1
      if input.get_char(next) == Some('\n') {
        next + 1
      } else {
        next
      }
    }
    Some(ch) => {
      out.write_char(ch)
      pos + ch.utf16_len()
    }
    None => pos
  }
}

///|
priv struct EntityDecodeError {
  code : String
  offset : Int
}

///|
priv struct EntityDecodeResult {
  data : String
  errors : Array[EntityDecodeError]
}

///|
priv struct EntityConsumeResult {
  value : String
  next : Int
  errors : Array[EntityDecodeError]
}

///|
fn decode_entities(input : StringView, in_attribute~ : Bool) -> String {
  decode_entities_with_errors(input, in_attribute~).data
}

///|
fn decode_entities_with_errors(
  input : StringView,
  in_attribute~ : Bool,
) -> EntityDecodeResult {
  let out = StringBuilder::new(size_hint=input.length())
  let errors : Array[EntityDecodeError] = []
  let mut pos = 0
  while pos < input.length() {
    match input.get_char(pos) {
      Some('&') =>
        match consume_entity_with_errors(input, pos, in_attribute~) {
          Some(consumed) => {
            out.write_string(consumed.value)
            for error in consumed.errors {
              errors.push(error)
            }
            pos = consumed.next
          }
          None => {
            out.write_char('&')
            pos += 1
          }
        }
      Some(_) => pos = write_normalized_char(input, pos, out)
      None => break
    }
  }
  EntityDecodeResult::{ data: out.to_string(), errors }
}

///|
fn decode_attribute_value_with_errors(input : StringView) -> EntityDecodeResult {
  let decoded = decode_entities_with_errors(input, in_attribute=true)
  EntityDecodeResult::{
    data: decoded.data.replace_all(old="\u{0000}", new="\u{FFFD}"),
    errors: decoded.errors,
  }
}

///|
fn starts_with_case_insensitive(
  input : StringView,
  pos : Int,
  prefix : StringView,
) -> Bool {
  let end = pos + prefix.length()
  match input.get_view(start=pos, end~) {
    Some(view) => view.compare_ignore_ascii_case(prefix) == 0
    None => false
  }
}

///|
fn entity_without_semicolon_error(
  input : StringView,
  start : Int,
) -> EntityDecodeError {
  EntityDecodeError::{
    code: "missing-semicolon-after-character-reference",
    offset: named_entity_missing_semicolon_error_offset(input, start),
  }
}

///|
fn named_entity_missing_semicolon_error_offset(
  input : StringView,
  start : Int,
) -> Int {
  let mut pos = start + 1
  let mut last = start
  while pos < input.length() {
    match input.get_char(pos) {
      Some(ch) if ch.is_ascii_alphabetic() || (ch >= '0' && ch <= '9') => {
        last = pos
        pos += ch.utf16_len()
      }
      Some(';') => return pos
      _ => return last
    }
  }
  last
}

///|
fn consume_entity_with_errors(
  input : StringView,
  start : Int,
  in_attribute~ : Bool,
) -> EntityConsumeResult? {
  let rest = input[start:]
  if rest.has_prefix("&amp;") {
    Some(EntityConsumeResult::{ value: "&", next: start + 5, errors: [] })
  } else if rest.has_prefix("&amp") &&
    !legacy_entity_blocked_in_attribute(input, start + 4, in_attribute~) {
    Some(EntityConsumeResult::{
      value: "&",
      next: start + 4,
      errors: [entity_without_semicolon_error(input, start)],
    })
  } else if rest.has_prefix("&lt;") {
    Some(EntityConsumeResult::{ value: "<", next: start + 4, errors: [] })
  } else if rest.has_prefix("&lt") &&
    !legacy_entity_blocked_in_attribute(input, start + 3, in_attribute~) {
    Some(EntityConsumeResult::{
      value: "<",
      next: start + 3,
      errors: [entity_without_semicolon_error(input, start)],
    })
  } else if rest.has_prefix("&gt;") {
    Some(EntityConsumeResult::{ value: ">", next: start + 4, errors: [] })
  } else if rest.has_prefix("&gt") &&
    !legacy_entity_blocked_in_attribute(input, start + 3, in_attribute~) {
    Some(EntityConsumeResult::{
      value: ">",
      next: start + 3,
      errors: [entity_without_semicolon_error(input, start)],
    })
  } else if rest.has_prefix("&quot;") {
    Some(EntityConsumeResult::{ value: "\"", next: start + 6, errors: [] })
  } else if rest.has_prefix("&apos;") {
    Some(EntityConsumeResult::{ value: "'", next: start + 6, errors: [] })
  } else if rest.has_prefix("&nbsp;") {
    Some(EntityConsumeResult::{ value: " ", next: start + 6, errors: [] })
  } else if rest.has_prefix("&not;") {
    Some(EntityConsumeResult::{ value: "¬", next: start + 5, errors: [] })
  } else if rest.has_prefix("&not") &&
    !legacy_entity_blocked_in_attribute(input, start + 4, in_attribute~) {
    Some(EntityConsumeResult::{
      value: "¬",
      next: start + 4,
      errors: [entity_without_semicolon_error(input, start)],
    })
  } else if rest.has_prefix("&#") {
    consume_numeric_entity(input, start)
  } else {
    None
  }
}

///|
fn legacy_entity_blocked_in_attribute(
  input : StringView,
  next : Int,
  in_attribute~ : Bool,
) -> Bool {
  if !in_attribute {
    return false
  }
  match input.get_char(next) {
    Some(ch) if ch.is_ascii_alphabetic() || (ch >= '0' && ch <= '9') => true
    Some('=') => true
    _ => false
  }
}

///|
fn consume_numeric_entity(
  input : StringView,
  start : Int,
) -> EntityConsumeResult? {
  let mut pos = start + 2
  let mut base = 10
  if pos < input.length() {
    match input.get_char(pos) {
      Some('x') | Some('X') => {
        base = 16
        pos += 1
      }
      _ => ()
    }
  }
  let digits_start = pos
  let mut value = 0
  while pos < input.length() {
    match input.get_char(pos) {
      Some(ch) => {
        let digit = digit_value(ch)
        if digit < 0 || digit >= base {
          break
        }
        value = value * base + digit
        pos += ch.utf16_len()
      }
      None => break
    }
  }
  if pos == digits_start {
    return None
  }
  let errors : Array[EntityDecodeError] = []
  let mut error_offset = pos - 1
  if pos < input.length() && input.get_char(pos) == Some(';') {
    pos += 1
    error_offset = pos - 1
  } else {
    errors.push(EntityDecodeError::{
      code: "missing-semicolon-after-character-reference",
      offset: error_offset,
    })
  }
  if numeric_reference_can_report_character_error(value) {
    if is_character_reference_control(value) {
      errors.push(EntityDecodeError::{
        code: "control-character-reference",
        offset: error_offset,
      })
    }
    if is_xml_noncharacter_code(value) {
      errors.push(EntityDecodeError::{
        code: "noncharacter-character-reference",
        offset: error_offset,
      })
    }
  }
  match html_numeric_entity_replacement(value).to_char() {
    Some(ch) =>
      Some(EntityConsumeResult::{ value: ch.to_string(), next: pos, errors })
    None => Some(EntityConsumeResult::{ value: "\u{FFFD}", next: pos, errors })
  }
}

///|
fn numeric_reference_can_report_character_error(value : Int) -> Bool {
  value >= 0 && value <= 0x10FFFF && !(value >= 0xD800 && value <= 0xDFFF)
}

///|
fn is_character_reference_control(value : Int) -> Bool {
  (value >= 0x00 && value <= 0x1F) || (value >= 0x7F && value <= 0x9F)
}

///|
fn is_xml_noncharacter_code(code : Int) -> Bool {
  if code >= 0xFDD0 && code <= 0xFDEF {
    return true
  }
  let low = code % 0x10000
  low == 0xFFFE || low == 0xFFFF
}

///|
fn html_numeric_entity_replacement(value : Int) -> Int {
  match value {
    0 => 0xFFFD
    0x80 => 0x20AC
    0x82 => 0x201A
    0x83 => 0x0192
    0x84 => 0x201E
    0x85 => 0x2026
    0x86 => 0x2020
    0x87 => 0x2021
    0x88 => 0x02C6
    0x89 => 0x2030
    0x8A => 0x0160
    0x8B => 0x2039
    0x8C => 0x0152
    0x8E => 0x017D
    0x91 => 0x2018
    0x92 => 0x2019
    0x93 => 0x201C
    0x94 => 0x201D
    0x95 => 0x2022
    0x96 => 0x2013
    0x97 => 0x2014
    0x98 => 0x02DC
    0x99 => 0x2122
    0x9A => 0x0161
    0x9B => 0x203A
    0x9C => 0x0153
    0x9E => 0x017E
    0x9F => 0x0178
    _ => value
  }
}

///|
fn digit_value(ch : Char) -> Int {
  if ch >= '0' && ch <= '9' {
    ch.to_int() - ('0' : Int)
  } else if ch >= 'a' && ch <= 'f' {
    ch.to_int() - ('a' : Int) + 10
  } else if ch >= 'A' && ch <= 'F' {
    ch.to_int() - ('A' : Int) + 10
  } else {
    -1
  }
}

///|
pub fn parse(
  html : StringView,
  sanitize? : Bool = true,
  collect_errors? : Bool = false,
  strict? : Bool = false,
  scripting_enabled? : Bool = true,
  xml_coercion? : Bool = false,
) -> ParsedHtml raise HtmlError {
  ignore(sanitize)
  let root = document()
  let parser = Parser::new(html, root, scripting_enabled~, xml_coercion~)
  let deferred_initial_doctype_error = parser.report_initial_doctype_error()
  parser.parse_all()
  match deferred_initial_doctype_error {
    Some(error) => parser.errors.push(error)
    None => ()
  }
  parser.report_eof_tree_errors()
  scaffold_document(root)
  normalize_tables(root)
  populate_selectedcontent(root)
  let errors = if collect_errors || strict { parser.errors } else { [] }
  if strict && !parser.errors.is_empty() {
    raise HtmlError::StrictMode(parser.errors[0])
  }
  ParsedHtml::{ root, errors, encoding: None }
}

///|
fn document_html_element(root : Node) -> Node? {
  for child in root.children {
    if child.kind == Element && child.name == "html" {
      return Some(child)
    }
  }
  None
}

///|
fn is_document_head_element_name(name : StringView) -> Bool {
  match name {
    "base"
    | "basefont"
    | "bgsound"
    | "link"
    | "meta"
    | "noframes"
    | "noscript"
    | "script"
    | "style"
    | "template"
    | "title" => true
    _ => false
  }
}

///|
fn is_whitespace_text_node(node : Node) -> Bool {
  if node.kind != Text {
    return false
  }
  for ch in node.data {
    if !ch.is_ascii_whitespace() {
      return false
    }
  }
  true
}

///|
fn append_children_to(target : Node, children : Array[Node]) -> Unit {
  for child in children {
    target.append_child(child)
  }
}

///|
fn push_children_reverse(stack : Array[Node], node : Node) -> Unit {
  let mut index = node.children.length()
  while index > 0 {
    index -= 1
    stack.push(node.children[index])
  }
}

///|
fn find_elements_by_name(root : Node, name : String) -> Array[Node] {
  let found : Array[Node] = []
  let stack : Array[Node] = [root]
  while !stack.is_empty() {
    match stack.pop() {
      Some(node) => {
        if node.kind == Element && node.name == name {
          found.push(node)
        }
        push_children_reverse(stack, node)
      }
      None => ()
    }
  }
  found
}

///|
fn find_first_element_by_name(root : Node, name : String) -> Node? {
  let stack : Array[Node] = [root]
  while !stack.is_empty() {
    match stack.pop() {
      Some(node) => {
        if node.kind == Element && node.name == name {
          return Some(node)
        }
        push_children_reverse(stack, node)
      }
      None => ()
    }
  }
  None
}

///|
fn selected_option_in(options : Array[Node]) -> Node? {
  for option in options {
    if option.attrs.contains("selected") {
      return Some(option)
    }
  }
  options.get(0)
}

///|
fn append_cloned_children(source : Node, target : Node) -> Unit {
  for child in source.children {
    target.append_child(child.clone_node(deep=true))
  }
}

///|
fn populate_selectedcontent(root : Node) -> Unit {
  let selects = find_elements_by_name(root, "select")
  for select in selects {
    match find_first_element_by_name(select, "selectedcontent") {
      Some(selectedcontent) => {
        let options = find_elements_by_name(select, "option")
        match selected_option_in(options) {
          Some(option) => append_cloned_children(option, selectedcontent)
          None => ()
        }
      }
      None => ()
    }
  }
}

///|
fn text_node_without_leading_ascii_whitespace(node : Node) -> Node? {
  let view = node.data[:]
  let mut start = 0
  while start < view.length() {
    match view.get_char(start) {
      Some(ch) if ch.is_ascii_whitespace() => start += ch.utf16_len()
      _ => break
    }
  }
  if start == 0 {
    Some(node)
  } else if start >= view.length() {
    None
  } else {
    match view.get_view(start~, end=view.length()) {
      Some(rest) => Some(text(rest))
      None => None
    }
  }
}

///|
fn merge_missing_attrs(target : Node, source : Node) -> Unit {
  merge_missing_attrs_from_map(target, source.attrs)
}

///|
fn merge_missing_attrs_from_map(
  target : Node,
  attrs : Map[String, String?],
) -> Unit {
  for name, value in attrs {
    if !target.attrs.contains(name) {
      target.attrs[name] = value
    }
  }
}

///|
fn append_body_node_contents(
  body_node : Node,
  source : Node,
  body_children : Array[Node],
) -> Unit {
  merge_missing_attrs(body_node, source)
  let existing = source.children.copy()
  source.children.clear()
  for child in existing {
    if child.kind == Element && child.name == "body" {
      append_body_node_contents(body_node, child, body_children)
    } else {
      body_children.push(child)
    }
  }
}

///|
fn append_html_node_contents(
  html_node : Node,
  source : Node,
  html_children : Array[Node],
) -> Unit {
  merge_missing_attrs(html_node, source)
  let existing = source.children.copy()
  source.children.clear()
  for child in existing {
    if child.kind == Element && child.name == "html" {
      append_html_node_contents(html_node, child, html_children)
    } else {
      html_children.push(child)
    }
  }
}

///|
fn Parser::document_doctype_is_initial(self : Parser) -> Bool {
  for child in self.root.children {
    if child.kind == Comment {
      ()
    } else if child.kind == Text && is_whitespace_text_node(child) {
      ()
    } else {
      return false
    }
  }
  true
}

///|
fn absorb_root_html_siblings(root : Node, html : Node) -> Unit {
  let original = root.children.copy()
  root.children.clear()
  let mut saw_html = false
  for child in original {
    if child.kind == Element && child.name == "html" {
      if saw_html {
        append_html_node_contents(html, child, html.children)
      } else {
        root.append_child(child)
        saw_html = true
      }
    } else {
      root.append_child(child)
    }
  }
}

///|
fn scaffold_existing_html_element(html : Node) -> Unit {
  let raw_original = html.children.copy()
  html.children.clear()
  let original : Array[Node] = []
  for child in raw_original {
    if child.kind == Element && child.name == "html" {
      append_html_node_contents(html, child, original)
    } else {
      original.push(child)
    }
  }
  let mut head : Node? = None
  let mut body : Node? = None
  let mut frameset : Node? = None
  let before_head_children : Array[Node] = []
  let between_head_body_children : Array[Node] = []
  let head_children : Array[Node] = []
  let body_children : Array[Node] = []
  let after_frameset_children : Array[Node] = []
  let mut body_started = false
  for child in original {
    if child.kind == Comment &&
      !body_started &&
      head is None &&
      head_children.is_empty() {
      before_head_children.push(child)
    } else if child.kind == Comment && !body_started && head is Some(_) {
      between_head_body_children.push(child)
    } else if child.kind == Element &&
      child.name == "head" &&
      head is None &&
      !body_started {
      head = Some(child)
    } else if child.kind == Element && child.name == "body" && body is None {
      body = Some(child)
      body_started = true
      append_body_node_contents(child, child, body_children)
    } else if child.kind == Element && child.name == "body" {
      match body {
        Some(body_node) =>
          append_body_node_contents(body_node, child, body_children)
        None => body_children.push(child)
      }
      body_started = true
    } else if child.kind == Element &&
      child.name == "frameset" &&
      body is None &&
      frameset is None &&
      !body_started {
      frameset = Some(child)
      body_started = true
    } else if frameset is Some(_) && body is None {
      after_frameset_children.push(child)
    } else if child.kind == Element && child.name == "head" {
      let existing = child.children.copy()
      for grandchild in existing {
        body_children.push(grandchild)
      }
    } else if child.kind == Element &&
      is_document_head_element_name(child.name) &&
      !body_started {
      head_children.push(child)
    } else if child.kind == Comment && !body_started {
      head_children.push(child)
    } else if is_whitespace_text_node(child) && !body_started {
      ()
    } else if child.kind == Text && !body_started {
      body_started = true
      match text_node_without_leading_ascii_whitespace(child) {
        Some(stripped) => body_children.push(stripped)
        None => ()
      }
    } else {
      body_started = true
      body_children.push(child)
    }
  }
  let head_node = head.unwrap_or(element("head"))
  append_children_to(html, before_head_children)
  html.append_child(head_node)
  append_children_to(head_node, head_children)
  append_children_to(html, between_head_body_children)
  match frameset {
    Some(frameset_node) if body is None && body_children.is_empty() => {
      html.append_child(frameset_node)
      append_children_to(html, after_frameset_children)
    }
    _ => {
      let body_node = body.unwrap_or(element("body"))
      append_children_to(body_node, body_children)
      html.append_child(body_node)
    }
  }
}

///|
fn scaffold_document(root : Node) -> Unit {
  match document_html_element(root) {
    Some(html) => {
      absorb_root_html_siblings(root, html)
      scaffold_existing_html_element(html)
      return
    }
    None => ()
  }
  let original = root.children.copy()
  root.children.clear()
  let mut head : Node? = None
  let mut body : Node? = None
  let mut frameset : Node? = None
  let head_children : Array[Node] = []
  let body_children : Array[Node] = []
  let after_frameset_children : Array[Node] = []
  let mut body_started = false
  for child in original {
    if child.kind == Doctype {
      root.append_child(child)
    } else if child.kind == Element &&
      child.name == "head" &&
      head is None &&
      !body_started {
      head = Some(child)
    } else if child.kind == Element && child.name == "body" && body is None {
      body = Some(child)
      body_started = true
      append_body_node_contents(child, child, body_children)
    } else if child.kind == Element && child.name == "body" {
      match body {
        Some(body_node) =>
          append_body_node_contents(body_node, child, body_children)
        None => body_children.push(child)
      }
      body_started = true
    } else if child.kind == Element &&
      child.name == "frameset" &&
      body is None &&
      frameset is None &&
      !body_started {
      frameset = Some(child)
      body_started = true
    } else if frameset is Some(_) && body is None {
      after_frameset_children.push(child)
    } else if child.kind == Comment && !body_started && head_children.is_empty() {
      root.append_child(child)
    } else if child.kind == Element && child.name == "head" {
      let existing = child.children.copy()
      for grandchild in existing {
        body_children.push(grandchild)
      }
    } else if child.kind == Element &&
      is_document_head_element_name(child.name) &&
      !body_started {
      head_children.push(child)
    } else if child.kind == Comment && !body_started {
      head_children.push(child)
    } else if is_whitespace_text_node(child) && !body_started {
      ()
    } else {
      body_started = true
      body_children.push(child)
    }
  }
  let html = element("html")
  let head_node = head.unwrap_or(element("head"))
  html.append_child(head_node)
  append_children_to(head_node, head_children)
  match frameset {
    Some(frameset_node) if body is None && body_children.is_empty() => {
      html.append_child(frameset_node)
      append_children_to(html, after_frameset_children)
    }
    _ => {
      let body_node = body.unwrap_or(element("body"))
      append_children_to(body_node, body_children)
      html.append_child(body_node)
    }
  }
  root.append_child(html)
}

///|
pub fn parse_fragment(
  html : StringView,
  context? : FragmentContext,
  sanitize? : Bool = true,
  collect_errors? : Bool = false,
  strict? : Bool = false,
  scripting_enabled? : Bool = true,
  xml_coercion? : Bool = false,
) -> ParsedHtml raise HtmlError {
  ignore(sanitize)
  let root = fragment()
  let parser = Parser::new(html, root, scripting_enabled~, xml_coercion~)
  match context {
    Some(fragment_context) =>
      if !parser.parse_fragment_context(fragment_context) {
        parser.parse_all()
      }
    None => parser.parse_all()
  }
  parser.report_eof_tree_errors()
  normalize_tables(root)
  populate_selectedcontent(root)
  let errors = if collect_errors || strict { parser.errors } else { [] }
  if strict && !parser.errors.is_empty() {
    raise HtmlError::StrictMode(parser.errors[0])
  }
  ParsedHtml::{ root, errors, encoding: None }
}

///|
fn has_utf16le_bom(input : BytesView) -> Bool {
  input.length() >= 2 && input[0] == b'\xff' && input[1] == b'\xfe'
}

///|
fn has_utf16be_bom(input : BytesView) -> Bool {
  input.length() >= 2 && input[0] == b'\xfe' && input[1] == b'\xff'
}

///|
fn has_utf8_bom(input : BytesView) -> Bool {
  input.length() >= 3 &&
  input[0] == b'\xef' &&
  input[1] == b'\xbb' &&
  input[2] == b'\xbf'
}

///|
fn decode_utf16le_lossy(input : BytesView) -> String {
  @utf16.decode_lossy(input, ignore_bom=true)
}

///|
fn decode_utf16be_lossy(input : BytesView) -> String {
  @utf16.decode_lossy(input, ignore_bom=true, endianness=Big)
}

///|
fn decode_utf16_lossy(input : BytesView) -> String {
  if has_utf16be_bom(input) {
    decode_utf16be_lossy(input)
  } else {
    decode_utf16le_lossy(input)
  }
}

///|
fn decode_windows1252_lossy(input : BytesView) -> String {
  let out = StringBuilder::new(size_hint=input.length())
  for index in 0..<input.length() {
    let value = input[index].to_int()
    let code = if value >= 0x80 && value <= 0x9F {
      html_numeric_entity_replacement(value)
    } else {
      value
    }
    match code.to_char() {
      Some(ch) => out.write_char(ch)
      None => out.write_char('\u{FFFD}')
    }
  }
  out.to_string()
}

///|
fn iso88592_code_point(value : Int) -> Int {
  match value {
    0xA0 => 0x00A0
    0xA1 => 0x0104
    0xA2 => 0x02D8
    0xA3 => 0x0141
    0xA4 => 0x00A4
    0xA5 => 0x013D
    0xA6 => 0x015A
    0xA7 => 0x00A7
    0xA8 => 0x00A8
    0xA9 => 0x0160
    0xAA => 0x015E
    0xAB => 0x0164
    0xAC => 0x0179
    0xAD => 0x00AD
    0xAE => 0x017D
    0xAF => 0x017B
    0xB0 => 0x00B0
    0xB1 => 0x0105
    0xB2 => 0x02DB
    0xB3 => 0x0142
    0xB4 => 0x00B4
    0xB5 => 0x013E
    0xB6 => 0x015B
    0xB7 => 0x02C7
    0xB8 => 0x00B8
    0xB9 => 0x0161
    0xBA => 0x015F
    0xBB => 0x0165
    0xBC => 0x017A
    0xBD => 0x02DD
    0xBE => 0x017E
    0xBF => 0x017C
    0xC0 => 0x0154
    0xC1 => 0x00C1
    0xC2 => 0x00C2
    0xC3 => 0x0102
    0xC4 => 0x00C4
    0xC5 => 0x0139
    0xC6 => 0x0106
    0xC7 => 0x00C7
    0xC8 => 0x010C
    0xC9 => 0x00C9
    0xCA => 0x0118
    0xCB => 0x00CB
    0xCC => 0x011A
    0xCD => 0x00CD
    0xCE => 0x00CE
    0xCF => 0x010E
    0xD0 => 0x0110
    0xD1 => 0x0143
    0xD2 => 0x0147
    0xD3 => 0x00D3
    0xD4 => 0x00D4
    0xD5 => 0x0150
    0xD6 => 0x00D6
    0xD7 => 0x00D7
    0xD8 => 0x0158
    0xD9 => 0x016E
    0xDA => 0x00DA
    0xDB => 0x0170
    0xDC => 0x00DC
    0xDD => 0x00DD
    0xDE => 0x0162
    0xDF => 0x00DF
    0xE0 => 0x0155
    0xE1 => 0x00E1
    0xE2 => 0x00E2
    0xE3 => 0x0103
    0xE4 => 0x00E4
    0xE5 => 0x013A
    0xE6 => 0x0107
    0xE7 => 0x00E7
    0xE8 => 0x010D
    0xE9 => 0x00E9
    0xEA => 0x0119
    0xEB => 0x00EB
    0xEC => 0x011B
    0xED => 0x00ED
    0xEE => 0x00EE
    0xEF => 0x010F
    0xF0 => 0x0111
    0xF1 => 0x0144
    0xF2 => 0x0148
    0xF3 => 0x00F3
    0xF4 => 0x00F4
    0xF5 => 0x0151
    0xF6 => 0x00F6
    0xF7 => 0x00F7
    0xF8 => 0x0159
    0xF9 => 0x016F
    0xFA => 0x00FA
    0xFB => 0x0171
    0xFC => 0x00FC
    0xFD => 0x00FD
    0xFE => 0x0163
    0xFF => 0x02D9
    _ => value
  }
}

///|
fn decode_iso88592_lossy(input : BytesView) -> String {
  let out = StringBuilder::new(size_hint=input.length())
  for index in 0..<input.length() {
    match iso88592_code_point(input[index].to_int()).to_char() {
      Some(ch) => out.write_char(ch)
      None => out.write_char('\u{FFFD}')
    }
  }
  out.to_string()
}

///|
fn is_ascii_whitespace_byte(byte : Byte) -> Bool {
  match byte.to_int() {
    0x09 | 0x0A | 0x0C | 0x0D | 0x20 => true
    _ => false
  }
}

///|
fn ascii_lower_value(value : Int) -> Int {
  if value >= 0x41 && value <= 0x5A {
    value + 0x20
  } else {
    value
  }
}

///|
fn is_ascii_alpha_byte(byte : Byte) -> Bool {
  let value = ascii_lower_value(byte.to_int())
  value >= 0x61 && value <= 0x7A
}

///|
fn skip_ascii_whitespace_bytes(input : BytesView, pos : Int) -> Int {
  let mut pos = pos
  while pos < input.length() && is_ascii_whitespace_byte(input[pos]) {
    pos += 1
  }
  pos
}

///|
fn ascii_lower_bytes(input : BytesView, start : Int, end : Int) -> String {
  let out = StringBuilder::new(size_hint=end - start)
  for index in start..<end {
    let value = input[index].to_int()
    if value < 0x80 {
      match ascii_lower_value(value).to_char() {
        Some(ch) => out.write_char(ch)
        None => ()
      }
    }
  }
  out.to_string()
}

///|
fn strip_ascii_whitespace_bytes(
  input : BytesView,
  start : Int,
  end : Int,
) -> (Int, Int) {
  let mut start = start
  let mut end = end
  while start < end && is_ascii_whitespace_byte(input[start]) {
    start += 1
  }
  while end > start && is_ascii_whitespace_byte(input[end - 1]) {
    end -= 1
  }
  (start, end)
}

///|
fn ascii_lower_content_bytes(
  input : BytesView,
  start : Int,
  end : Int,
) -> String {
  let out = StringBuilder::new(size_hint=end - start)
  for index in start..<end {
    let value = if is_ascii_whitespace_byte(input[index]) {
      0x20
    } else {
      ascii_lower_value(input[index].to_int())
    }
    if value < 0x80 {
      match value.to_char() {
        Some(ch) => out.write_char(ch)
        None => ()
      }
    }
  }
  out.to_string()
}

///|
fn byte_range_ascii_lower_eq(
  input : BytesView,
  start : Int,
  end : Int,
  expected : StringView,
) -> Bool {
  ascii_lower_bytes(input, start, end)[:] == expected
}

///|
fn normalize_supported_html_encoding_label(label : StringView) -> String? {
  let label = label.trim().to_lower()
  if label.is_empty() {
    return None
  }
  match label {
    "utf-8" | "utf8" => Some("utf-8")
    "utf-7" | "utf7" | "x-utf-7" => Some("windows-1252")
    "iso-8859-1"
    | "iso8859-1"
    | "latin1"
    | "latin-1"
    | "l1"
    | "cp819"
    | "ibm819" => Some("windows-1252")
    "windows-1252" | "windows1252" | "cp1252" | "x-cp1252" =>
      Some("windows-1252")
    "iso-8859-2" | "iso8859-2" | "latin2" | "latin-2" => Some("iso-8859-2")
    "utf-16" | "utf16" => Some("utf-16")
    "utf-16le" | "utf16le" => Some("utf-16le")
    "utf-16be" | "utf16be" => Some("utf-16be")
    _ => None
  }
}

///|
fn normalize_meta_html_encoding_label(label : StringView) -> String? {
  match normalize_supported_html_encoding_label(label) {
    Some("utf-16") | Some("utf-16le") | Some("utf-16be") => Some("utf-8")
    other => other
  }
}

///|
fn extract_charset_from_content_bytes(
  input : BytesView,
  start : Int,
  end : Int,
) -> String? {
  let content = ascii_lower_content_bytes(input, start, end)
  guard content.find("charset") is Some(found) else { return None }
  let mut pos = found + "charset".length()
  while pos < content.length() {
    guard content.get_char(pos) is Some(ch) else { return None }
    if !ch.is_ascii_whitespace() {
      break
    }
    pos += ch.utf16_len()
  }
  guard content.get_char(pos) is Some('=') else { return None }
  pos += 1
  while pos < content.length() {
    guard content.get_char(pos) is Some(ch) else { return None }
    if !ch.is_ascii_whitespace() {
      break
    }
    pos += ch.utf16_len()
  }
  if pos >= content.length() {
    return None
  }
  let mut quote : Char? = None
  match content.get_char(pos) {
    Some('"') => {
      quote = Some('"')
      pos += 1
    }
    Some('\'') => {
      quote = Some('\'')
      pos += 1
    }
    _ => ()
  }
  let value_start = pos
  while pos < content.length() {
    guard content.get_char(pos) is Some(ch) else { return None }
    match quote {
      Some(expected) =>
        if ch == expected {
          guard content.get_view(start=value_start, end=pos) is Some(label) else {
            return None
          }
          return normalize_meta_html_encoding_label(label)
        }
      None =>
        if ch.is_ascii_whitespace() || ch == ';' {
          guard content.get_view(start=value_start, end=pos) is Some(label) else {
            return None
          }
          return normalize_meta_html_encoding_label(label)
        }
    }
    pos += ch.utf16_len()
  }
  match quote {
    Some(_) => None
    None => {
      guard content.get_view(start=value_start, end=pos) is Some(label) else {
        return None
      }
      normalize_meta_html_encoding_label(label)
    }
  }
}

///|
fn decode_supported_html_encoding(
  input : BytesView,
  encoding : String,
) -> (String, String) {
  match encoding {
    "utf-8" => (@utf8.decode_lossy(input, ignore_bom=true), "utf-8")
    "windows-1252" => (decode_windows1252_lossy(input), "windows-1252")
    "iso-8859-2" => (decode_iso88592_lossy(input), "iso-8859-2")
    "utf-16" => (decode_utf16_lossy(input), "utf-16")
    "utf-16le" => (decode_utf16le_lossy(input), "utf-16le")
    "utf-16be" => (decode_utf16be_lossy(input), "utf-16be")
    _ => (decode_windows1252_lossy(input), "windows-1252")
  }
}

///|
fn starts_html_comment_at(input : BytesView, pos : Int) -> Bool {
  pos + 3 < input.length() &&
  input[pos] == b'<' &&
  input[pos + 1] == b'!' &&
  input[pos + 2] == b'-' &&
  input[pos + 3] == b'-'
}

///|
fn find_html_comment_end(input : BytesView, pos : Int, limit : Int) -> Int? {
  let mut pos = pos
  while pos + 2 < limit {
    if input[pos] == b'-' && input[pos + 1] == b'-' && input[pos + 2] == b'>' {
      return Some(pos + 3)
    }
    pos += 1
  }
  None
}

///|
fn skip_byte_tag(input : BytesView, pos : Int, limit : Int) -> Int {
  let mut pos = pos
  let mut quote : Byte? = None
  while pos < limit {
    let byte = input[pos]
    match quote {
      Some(expected) => if byte == expected { quote = None }
      None =>
        if byte == b'"' || byte == b'\'' {
          quote = Some(byte)
        } else if byte == b'>' {
          return pos + 1
        }
    }
    pos += 1
  }
  limit
}

///|
fn parse_meta_tag_declared_encoding(
  input : BytesView,
  tag_start : Int,
  pos : Int,
  limit : Int,
) -> (String?, Int) {
  let mut pos = pos
  let mut charset : (Int, Int)? = None
  let mut http_equiv : (Int, Int)? = None
  let mut content : (Int, Int)? = None
  while pos < limit {
    let byte = input[pos]
    if byte == b'>' {
      match charset {
        Some((start, end)) => {
          let label = ascii_lower_bytes(input, start, end)
          match normalize_meta_html_encoding_label(label[:]) {
            Some(encoding) => return (Some(encoding), pos + 1)
            None => ()
          }
        }
        None => ()
      }
      match (http_equiv, content) {
        (Some((http_start, http_end)), Some((content_start, content_end))) => {
          if byte_range_ascii_lower_eq(
              input, http_start, http_end, "content-type",
            ) {
            return (
              extract_charset_from_content_bytes(
                input, content_start, content_end,
              ),
              pos + 1,
            )
          }
          return (None, pos + 1)
        }
        _ => return (None, pos + 1)
      }
    }
    if byte == b'<' {
      return (None, tag_start + 1)
    }
    if is_ascii_whitespace_byte(byte) || byte == b'/' {
      pos += 1
      continue
    }
    let name_start = pos
    while pos < limit {
      let value = input[pos].to_int()
      if is_ascii_whitespace_byte(input[pos]) ||
        value == 0x3D ||
        value == 0x3E ||
        value == 0x2F ||
        value == 0x3C {
        break
      }
      pos += 1
    }
    let attr_name = ascii_lower_bytes(input, name_start, pos)
    pos = skip_ascii_whitespace_bytes(input, pos)
    let mut value_range : (Int, Int)? = None
    if pos < limit && input[pos] == b'=' {
      pos += 1
      pos = skip_ascii_whitespace_bytes(input, pos)
      if pos >= limit {
        return (None, tag_start + 1)
      }
      if input[pos] == b'"' || input[pos] == b'\'' {
        let quote = input[pos]
        pos += 1
        let value_start = pos
        while pos < limit && input[pos] != quote {
          pos += 1
        }
        if pos >= limit {
          return (None, tag_start + 1)
        }
        value_range = Some((value_start, pos))
        pos += 1
      } else {
        let value_start = pos
        while pos < limit {
          let value = input[pos].to_int()
          if is_ascii_whitespace_byte(input[pos]) ||
            value == 0x3E ||
            value == 0x3C {
            break
          }
          pos += 1
        }
        value_range = Some((value_start, pos))
      }
    }
    if attr_name == "charset" {
      match value_range {
        Some((start, end)) => {
          let (start, end) = strip_ascii_whitespace_bytes(input, start, end)
          if start < end {
            charset = Some((start, end))
          }
        }
        None => ()
      }
    } else if attr_name == "http-equiv" {
      match value_range {
        Some((start, end)) => {
          let (start, end) = strip_ascii_whitespace_bytes(input, start, end)
          if start < end {
            http_equiv = Some((start, end))
          }
        }
        None => ()
      }
    } else if attr_name == "content" {
      match value_range {
        Some((start, end)) => {
          let (start, end) = strip_ascii_whitespace_bytes(input, start, end)
          if start < end {
            content = Some((start, end))
          }
        }
        None => ()
      }
    }
  }
  (None, tag_start + 1)
}

///|
fn prescan_meta_charset(input : BytesView) -> String? {
  let scan_limit = if input.length() < 65536 { input.length() } else { 65536 }
  let mut pos = 0
  let mut non_comment = 0
  while pos < scan_limit && non_comment < 1024 {
    if input[pos] != b'<' {
      pos += 1
      non_comment += 1
      continue
    }
    if starts_html_comment_at(input, pos) {
      match find_html_comment_end(input, pos + 4, scan_limit) {
        Some(next) => {
          pos = next
          continue
        }
        None => return None
      }
    }
    let mut tag_pos = pos + 1
    if tag_pos < scan_limit && input[tag_pos] == b'/' {
      let next = skip_byte_tag(input, pos, scan_limit)
      non_comment += next - pos
      pos = next
      continue
    }
    if tag_pos >= scan_limit || !is_ascii_alpha_byte(input[tag_pos]) {
      pos += 1
      non_comment += 1
      continue
    }
    let name_start = tag_pos
    while tag_pos < scan_limit && is_ascii_alpha_byte(input[tag_pos]) {
      tag_pos += 1
    }
    let tag_name = ascii_lower_bytes(input, name_start, tag_pos)
    if tag_name != "meta" {
      let next = skip_byte_tag(input, pos, scan_limit)
      non_comment += next - pos
      pos = next
      continue
    }
    let (encoding, next) = parse_meta_tag_declared_encoding(
      input, pos, tag_pos, scan_limit,
    )
    match encoding {
      Some(_) => return encoding
      None => {
        non_comment += next - pos
        pos = next
      }
    }
  }
  None
}

///|
fn decode_html_bytes(input : BytesView, encoding : String?) -> (String, String) {
  match encoding {
    Some(label) => {
      let trimmed = label[:].trim()
      if trimmed.is_empty() {
        decode_html_bytes(input, None)
      } else {
        match normalize_supported_html_encoding_label(trimmed) {
          Some(encoding) => decode_supported_html_encoding(input, encoding)
          None => decode_html_bytes(input, None)
        }
      }
    }
    None =>
      if has_utf16le_bom(input) {
        (decode_utf16le_lossy(input), "utf-16le")
      } else if has_utf16be_bom(input) {
        (decode_utf16be_lossy(input), "utf-16be")
      } else if has_utf8_bom(input) {
        (@utf8.decode_lossy(input, ignore_bom=true), "utf-8")
      } else {
        match prescan_meta_charset(input) {
          Some(encoding) => decode_supported_html_encoding(input, encoding)
          None => (decode_windows1252_lossy(input), "windows-1252")
        }
      }
  }
}

///|
pub fn parse_bytes(
  input : BytesView,
  encoding? : String,
  sanitize? : Bool = true,
  collect_errors? : Bool = false,
  strict? : Bool = false,
  scripting_enabled? : Bool = true,
  xml_coercion? : Bool = false,
) -> ParsedHtml raise HtmlError {
  let (decoded, detected_encoding) = decode_html_bytes(input, encoding)
  let parsed = parse(
    decoded,
    sanitize~,
    collect_errors~,
    strict~,
    scripting_enabled~,
    xml_coercion~,
  )
  ParsedHtml::{
    root: parsed.root,
    errors: parsed.errors,
    encoding: Some(detected_encoding),
  }
}

///|
pub fn ParsedHtml::to_html(
  self : ParsedHtml,
  pretty? : Bool = true,
  indent_size? : Int = 2,
  context? : HtmlContext = Html,
  quote? : Char = '"',
) -> String {
  self.root.to_html(pretty~, indent_size~, context~, quote~)
}

///|
pub fn ParsedHtml::to_text(
  self : ParsedHtml,
  separator? : String = " ",
  strip? : Bool = true,
  separator_blocks_only? : Bool = false,
) -> String {
  self.root.to_text(separator~, strip~, separator_blocks_only~)
}

///|
pub fn ParsedHtml::query(
  self : ParsedHtml,
  selector : StringView,
) -> Array[Node] {
  self.root.query(selector)
}

///|
pub fn ParsedHtml::query_one(self : ParsedHtml, selector : StringView) -> Node? {
  self.root.query_one(selector)
}
