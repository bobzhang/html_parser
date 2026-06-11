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
    match self.template_content_mode() {
      "row" | "table-body" => {
        // A section start tag after row or cell content acts as an end
        // tag that finds nothing in scope: parse error, ignore.
        self.error_at("unexpected-start-tag", start)
        return true
      }
      _ => ()
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
  last.name == "tr" &&
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
    while self.stack.length() > row_index + 1 {
      ignore(self.stack.pop())
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
    while self.stack.length() > row_index {
      ignore(self.stack.pop())
    }
    self.set_template_content_mode("table-body")
    self.enable_template_table_context_mode()
  }
}
