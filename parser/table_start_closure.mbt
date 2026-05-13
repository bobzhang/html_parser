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
