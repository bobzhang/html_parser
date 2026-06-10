///|
/// True when the top of the stack is the given synthetic fragment-context
/// node, allowing only foreign (SVG/MathML) elements above it. At a foreign
/// integration point the HTML insertion mode is still the fragment
/// context's table mode, so table-structure start tags that would be
/// ignored at the context boundary must also be ignored there. Any open
/// HTML element above the boundary (a real cell, table, or block) routes
/// the token to the regular table machinery instead.
fn Parser::stack_at_fragment_boundary(
  self : Parser,
  boundary : @dom.Node,
) -> Bool {
  let mut index = self.stack.length()
  while index > 0 {
    index -= 1
    let node = self.stack[index]
    if physical_equal(node, boundary) {
      return true
    }
    if node.kind == Element &&
      (node.ns is Some("svg") || node.ns is Some("math")) {
      continue
    }
    return false
  }
  false
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
    Some(section) =>
      if self.stack_at_fragment_boundary(section) {
        self.error_at("unexpected-start-tag", start)
        true
      } else {
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
    Some(row) =>
      if self.stack_at_fragment_boundary(row) {
        self.error_at("unexpected-start-tag-implies-end-tag", start)
        true
      } else {
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
    Some(cell) =>
      if self.stack_at_fragment_boundary(cell) {
        self.error_at("unexpected-start-tag-in-cell-fragment", start)
        true
      } else {
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
