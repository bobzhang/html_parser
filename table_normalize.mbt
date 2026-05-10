///|
fn is_table_section_name(name : StringView) -> Bool {
  match name {
    "tbody" | "thead" | "tfoot" => true
    _ => false
  }
}

///|
fn is_table_cell_name(name : StringView) -> Bool {
  match name {
    "td" | "th" => true
    _ => false
  }
}

///|
fn normalize_table_section(section : Node) -> Unit {
  let original = section.children.copy()
  section.children.clear()
  let mut current_row : Node? = None
  for child in original {
    normalize_tables(child)
    if child.kind == Element && is_table_cell_name(child.name) {
      let row = match current_row {
        Some(row) => row
        None => {
          let row = element("tr")
          section.append_child(row)
          current_row = Some(row)
          row
        }
      }
      row.append_child(child)
    } else {
      section.append_child(child)
      current_row = None
    }
  }
}

///|
fn table_implicit_body(table : Node, current_body : Node?) -> (Node, Node?) {
  match current_body {
    Some(body) => (body, current_body)
    None => {
      let body = element("tbody")
      table.append_child(body)
      (body, Some(body))
    }
  }
}

///|
fn table_implicit_colgroup(
  table : Node,
  current_colgroup : Node?,
) -> (Node, Node?) {
  match current_colgroup {
    Some(colgroup) => (colgroup, current_colgroup)
    None => {
      let colgroup = element("colgroup")
      table.append_child(colgroup)
      (colgroup, Some(colgroup))
    }
  }
}

///|
fn normalize_table(table : Node) -> Unit {
  let original = table.children.copy()
  table.children.clear()
  let mut current_body : Node? = None
  let mut current_row : Node? = None
  let mut current_colgroup : Node? = None
  for child in original {
    normalize_tables(child)
    if child.kind == Element && child.name == "col" {
      let (colgroup, next_colgroup) = table_implicit_colgroup(
        table, current_colgroup,
      )
      current_colgroup = next_colgroup
      colgroup.append_child(child)
      current_body = None
      current_row = None
    } else if child.kind == Text &&
      current_colgroup is Some(colgroup) &&
      !text_has_non_ascii_whitespace(child.data) {
      colgroup.append_child(child)
      current_body = None
      current_row = None
    } else if child.kind == Element && child.name == "tr" {
      let (body, next_body) = table_implicit_body(table, current_body)
      current_body = next_body
      body.append_child(child)
      current_row = None
      current_colgroup = None
    } else if child.kind == Element && is_table_cell_name(child.name) {
      let (body, next_body) = table_implicit_body(table, current_body)
      current_body = next_body
      let row = match current_row {
        Some(row) => row
        None => {
          let row = element("tr")
          body.append_child(row)
          current_row = Some(row)
          row
        }
      }
      row.append_child(child)
      current_colgroup = None
    } else {
      table.append_child(child)
      current_body = None
      current_row = None
      current_colgroup = None
    }
  }
}

///|
fn normalize_tables(node : Node) -> Unit {
  match node.kind {
    Element if node.name == "table" => normalize_table(node)
    Element if is_table_section_name(node.name) => normalize_table_section(node)
    _ =>
      for child in node.children {
        normalize_tables(child)
      }
  }
}
