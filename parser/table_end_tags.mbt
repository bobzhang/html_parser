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
fn Parser::handle_table_end_tag(
  self : Parser,
  name : String,
  tag_close_pos : Int,
) -> Bool {
  if name != "table" {
    return false
  }
  let table_index = self.last_open_table_index()
  let cell_index = self.last_open_html_table_cell_index()
  let closes_open_cell = table_index >= 0 && cell_index > table_index
  if !self.close_open_element("table") {
    return false
  }
  if closes_open_cell {
    // Closing the table implicitly ends the open cell, which clears the
    // active formatting list up to the cell's marker.
    self.clear_active_formatting_to_marker()
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
  if !table_structural_end_tag_can_close(name) {
    return false
  }
  let table_index = self.last_open_table_index()
  let cell_index = self.last_open_html_table_cell_index()
  let had_open_cell = cell_index > table_index && table_index >= 0
  if !self.close_open_element(name) {
    if had_open_cell && (name == "tbody" || name == "tr") {
      // The row always has a virtual ancestor, and a bare cell's section
      // is a virtual tbody (synthesized after parsing); an explicit
      // thead/tfoot section means </tbody> finds nothing in scope.
      let mut explicit_section = false
      if name == "tbody" {
        let mut index = cell_index
        while index > table_index {
          index -= 1
          let node = self.stack[index]
          if node.kind == Element &&
            (node.name == "thead" || node.name == "tfoot") &&
            (node.ns is None || node.ns is Some("html")) {
            explicit_section = true
            break
          }
        }
      }
      if !explicit_section {
        while self.stack.length() > table_index + 1 {
          ignore(self.stack.pop())
        }
        self.clear_active_formatting_to_marker()
        return true
      }
    }
    return false
  }
  if name == "td" || name == "th" || name == "caption" || had_open_cell {
    // Ending a cell or caption — explicitly or implicitly through a
    // row/section end tag — clears the active formatting list up to the
    // marker pushed when the cell opened.
    self.clear_active_formatting_to_marker()
  }
  if self.in_template_content_without_inner_table() {
    self.record_template_content_close(name)
    self.enable_template_table_context_mode()
  }
  true
}
