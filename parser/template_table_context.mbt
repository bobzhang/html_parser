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
