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
    if !self.close_open_template_content_section() {
      match self.template_content_mode() {
        "row" | "table-body" => {
          // A caption after row or cell content acts as an end tag with
          // nothing in scope: parse error, ignore. With an open section
          // the in-table-body rules close it and the caption inserts.
          self.error_at("unexpected-start-tag", start)
          return true
        }
        _ => ()
      }
    }
    let node = self.node_with_origin(@dom.element("caption", attrs~), start)
    self.current_node().append_child(node)
    self.stack.push(node)
    self.push_active_formatting_marker()
    self.disable_current_template_table_context_mode()
    return true
  }
  if (name == "col" || name == "colgroup") &&
    !self.close_open_template_content_section() &&
    (
      self.template_content_mode() == "row" ||
      self.template_content_mode() == "table-body"
    ) {
    self.error_at("unexpected-start-tag", start)
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
    if !self.close_open_template_content_section() {
      match self.template_content_mode() {
        "row" | "table-body" => {
          // A section start tag after row or cell content acts as an end
          // tag that finds nothing in scope: parse error, ignore. With
          // an open section the in-table-body rules close it first and
          // the new section inserts after it.
          self.error_at("unexpected-start-tag", start)
          return true
        }
        _ => ()
      }
    }
    let node = self.node_with_origin(@dom.element(name, attrs~), start)
    self.current_node().append_child(node)
    self.stack.push(node)
    self.disable_current_template_table_context_mode()
    return true
  }
  if name == "tr" {
    match self.template_content_mode() {
      "row" => {
        // In-row tr acts as </tr> with no row in scope: ignore.
        self.error_at("unexpected-start-tag", start)
        return true
      }
      "table" => {
        // In-table tr synthesizes a table body section.
        let section = @dom.element("tbody")
        self.current_node().append_child(section)
        self.stack.push(section)
        let row = self.node_with_origin(@dom.element("tr"), start)
        section.append_child(row)
        self.stack.push(row)
        self.disable_current_template_table_context_mode()
        return true
      }
      _ => {
        // In-template and in-table-body insert a bare row.
        let row = self.node_with_origin(@dom.element("tr", attrs~), start)
        self.current_node().append_child(row)
        self.stack.push(row)
        self.disable_current_template_table_context_mode()
        return true
      }
    }
  }
  if name == "td" || name == "th" {
    let mode = self.template_content_mode()
    if mode == "table" {
      // In-table cell synthesizes a section and a row.
      let section = @dom.element("tbody")
      self.current_node().append_child(section)
      self.stack.push(section)
      let row = @dom.element("tr")
      section.append_child(row)
      self.stack.push(row)
    } else if mode == "table-body" {
      // In-table-body cell synthesizes a bare row.
      self.error_at("unexpected-cell-in-table-body", start)
      let row = @dom.element("tr")
      self.current_node().append_child(row)
      self.stack.push(row)
    }
    let cell = self.node_with_origin(@dom.element(name, attrs~), start)
    self.current_node().append_child(cell)
    self.stack.push(cell)
    self.push_active_formatting_marker()
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
    self.record_template_content_close(name)
    self.enable_template_table_context_mode()
    return true
  }
  if template_table_context_section_end_tag_reports_unexpected(name) &&
    self.close_open_element(name) {
    self.error_at("unexpected-end-tag", start)
    self.record_template_content_close(name)
    self.enable_template_table_context_mode()
    return true
  }
  false
}

///|
fn Parser::record_template_content_close(self : Parser, name : String) -> Unit {
  match name {
    "td" | "th" => self.set_template_content_mode("row")
    "tr" => self.set_template_content_mode("table-body")
    "tbody" | "tfoot" | "thead" | "caption" | "colgroup" =>
      self.set_template_content_mode("table")
    _ => ()
  }
}

///|
/// Flow content (anything but a cell or an in-head element) arriving while
/// the current node is a bare template-content row is foster-parented into
/// the row's parent — the row stays open for later cells, mirroring the
/// in-row anything-else handling without a real table.
fn Parser::bare_template_row_fosters(self : Parser, name : StringView) -> Bool {
  if name == "td" ||
    name == "th" ||
    name == "tr" ||
    name == "template" ||
    name == "script" ||
    name == "style" ||
    name == "caption" ||
    name == "col" ||
    name == "colgroup" ||
    name == "tbody" ||
    name == "tfoot" ||
    name == "thead" ||
    name == "table" {
    // Cells, in-head elements, and table-structural tags are not flow
    // content; they take the row/table-body structural handling.
    return false
  }
  if !self.in_template_content_without_inner_table() {
    return false
  }
  let len = self.stack.length()
  if len < 2 {
    return false
  }
  let last = self.stack[len - 1]
  let below = self.stack[len - 2]
  last.kind == Element &&
  (
    last.name == "tr" ||
    last.name == "tbody" ||
    last.name == "tfoot" ||
    last.name == "thead"
  ) &&
  (last.ns is None || last.ns is Some("html")) &&
  below.kind == Element &&
  below.name == "template"
}

///|
/// Closes an open table section (and any open row) sitting above the
/// current template on the stack, recording table mode. Returns true when
/// a section was open: the in-table-body rules close it and let the
/// caption or column group insert after it instead of being ignored.
fn Parser::close_open_template_content_section(self : Parser) -> Bool {
  let template_index = self.last_open_template_index()
  if template_index < 0 {
    return false
  }
  let mut section_index = -1
  let mut index = self.stack.length()
  while index > template_index + 1 {
    index -= 1
    let node = self.stack[index]
    if node.kind == Element &&
      (node.name == "tbody" || node.name == "tfoot" || node.name == "thead") &&
      (node.ns is None || node.ns is Some("html")) {
      section_index = index
      break
    }
  }
  if section_index < 0 {
    return false
  }
  while self.stack.length() > section_index {
    ignore(self.stack.pop())
  }
  self.set_template_content_mode("table")
  true
}

///|
/// Prepares a bare template-content row for an incoming start tag: cells
/// clear the stack back to the row (popping fostered flow elements), and
/// table-structural tags close the row (acting as </tr>) so the mode
/// handler can gate or reprocess them.
fn Parser::prepare_bare_template_row_start(
  self : Parser,
  name : StringView,
) -> Unit {
  if !self.in_template_content_without_inner_table() {
    return
  }
  let template_index = self.last_open_template_index()
  let mut row_index = -1
  let mut index = self.stack.length()
  while index > template_index + 1 {
    index -= 1
    let node = self.stack[index]
    if node.kind == Element &&
      node.name == "tr" &&
      (node.ns is None || node.ns is Some("html")) {
      row_index = index
      break
    }
  }
  if row_index < 0 {
    return
  }
  if name == "td" || name == "th" {
    let mut popped_cell = false
    while self.stack.length() > row_index + 1 {
      match self.stack.pop() {
        Some(node) =>
          if node.kind == Element &&
            (node.name == "td" || node.name == "th") &&
            (node.ns is None || node.ns is Some("html")) {
            popped_cell = true
          }
        None => ()
      }
    }
    if popped_cell {
      // The implied close of the previous cell clears its formatting
      // marker, so stale formatting does not reconstruct into the next
      // cell.
      self.clear_active_formatting_to_marker()
    }
    return
  }
  if name == "tr" ||
    name == "caption" ||
    name == "col" ||
    name == "colgroup" ||
    name == "tbody" ||
    name == "tfoot" ||
    name == "thead" ||
    name == "table" {
    let mut popped_cell = false
    while self.stack.length() > row_index {
      match self.stack.pop() {
        Some(node) =>
          if node.kind == Element &&
            (node.name == "td" || node.name == "th") &&
            (node.ns is None || node.ns is Some("html")) {
            popped_cell = true
          }
        None => ()
      }
    }
    if popped_cell {
      // Closing the row through an open cell also clears the cell's
      // formatting marker.
      self.clear_active_formatting_to_marker()
    }
    // A select popped with the row no longer holds the parser in select
    // mode.
    self.reset_select_insertion_mode()
    self.set_template_content_mode("table-body")
    self.enable_template_table_context_mode()
  }
}

///|
/// True when the current node can host the template content's table
/// machinery: the template itself or an open table-structure element.
/// Inside flow content (e.g. a div) the in-body rules apply instead and
/// stray table-structural start tags are ignored.
fn Parser::template_content_at_structural_position(self : Parser) -> Bool {
  if self.template_content_mode() == "body" {
    return false
  }
  let current = self.current_node()
  if current.kind != Element {
    return false
  }
  match current.name {
    "template" | "tr" | "tbody" | "tfoot" | "thead" | "caption" | "td" | "th" =>
      current.ns is None || current.ns is Some("html")
    _ => false
  }
}

///|
/// Flow content inserted directly at the template content top switches
/// the template's mode to in-body: later table-structural start tags are
/// then ignored per the in-body rules instead of synthesizing structure.
/// The in-head elements (template, script, style) leave the mode alone.
fn Parser::record_template_content_flow_insert(
  self : Parser,
  name : StringView,
) -> Unit {
  if name == "template" ||
    name == "script" ||
    name == "style" ||
    name == "base" ||
    name == "basefont" ||
    name == "bgsound" ||
    name == "link" ||
    name == "meta" ||
    name == "noframes" ||
    name == "title" ||
    name == "col" ||
    name == "colgroup" ||
    name == "caption" ||
    name == "tbody" ||
    name == "tfoot" ||
    name == "thead" ||
    name == "tr" ||
    name == "td" ||
    name == "th" {
    return
  }
  if !self.in_template_content_without_inner_table() {
    return
  }
  if self.template_content_mode() != "" {
    // Only the initial in-template mode flips to in-body; established
    // table modes (row, table-body, table) persist through flow content.
    return
  }
  let current = self.current_node()
  if current.kind == Element &&
    current.name == "template" &&
    (current.ns is None || current.ns is Some("html")) {
    self.set_template_content_mode("body")
  }
}
