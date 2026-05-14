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
