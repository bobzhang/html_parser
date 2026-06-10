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
    if node.kind == Element &&
      node.name == "template" &&
      (node.ns is None || node.ns is Some("html")) {
      // Template contents are a separate tree: the table machinery must
      // not reach past an open template to a table outside it.
      return -1
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
