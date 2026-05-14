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
