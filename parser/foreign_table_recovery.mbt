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
    ignore(self.pop_open_element())
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
    self.push_open_element(node)
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
    self.push_open_element(node)
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
    self.push_open_element(node)
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
