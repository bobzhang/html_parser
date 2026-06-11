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
fn normalize_table_section(section : @dom.Node) -> Unit {
  let original = section.children.copy()
  section.children.clear()
  let mut current_row : @dom.Node? = None
  for child in original {
    normalize_tables(child)
    if child.kind == Element && is_table_cell_name(child.name) {
      let row = match current_row {
        Some(row) => row
        None => {
          let row = @dom.element("tr")
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
fn table_implicit_body(
  table : @dom.Node,
  current_body : @dom.Node?,
) -> (@dom.Node, @dom.Node?) {
  match current_body {
    Some(body) => (body, current_body)
    None => {
      let body = @dom.element("tbody")
      table.append_child(body)
      (body, Some(body))
    }
  }
}

///|
fn table_implicit_colgroup(
  table : @dom.Node,
  current_colgroup : @dom.Node?,
) -> (@dom.Node, @dom.Node?) {
  match current_colgroup {
    Some(colgroup) => (colgroup, current_colgroup)
    None => {
      let colgroup = @dom.element("colgroup")
      table.append_child(colgroup)
      (colgroup, Some(colgroup))
    }
  }
}

///|
fn normalize_table(table : @dom.Node) -> Unit {
  let original = table.children.copy()
  table.children.clear()
  let mut current_body : @dom.Node? = None
  let mut current_row : @dom.Node? = None
  let mut current_colgroup : @dom.Node? = None
  let mut in_implicit_section = false
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
      in_implicit_section = true
    } else if child.kind == Element && is_table_cell_name(child.name) {
      let (body, next_body) = table_implicit_body(table, current_body)
      current_body = next_body
      let row = match current_row {
        Some(row) => row
        None => {
          let row = @dom.element("tr")
          body.append_child(row)
          current_row = Some(row)
          row
        }
      }
      row.append_child(child)
      current_colgroup = None
      in_implicit_section = true
    } else {
      if child.kind == Comment &&
        in_implicit_section &&
        current_row is Some(row) {
        // A comment between bare cells stays in the still-open implicit
        // row; the next cell continues it.
        row.append_child(child)
        continue
      }
      if (
          child.kind == Comment ||
          (child.kind == Text && is_whitespace_text_node(child))
        ) &&
        in_implicit_section &&
        table.children.length() > 0 {
        // Whitespace while an implicit row group is still open stays
        // inside it (the in-table-body insertion point); after an
        // explicitly closed section it remains a table child.
        let last = table.children[table.children.length() - 1]
        if last.kind == Element && is_table_section_name(last.name) {
          // The implicit row group stays open: a following row joins it
          // rather than starting a new one.
          last.append_child(child)
          current_body = Some(last)
          current_row = None
          current_colgroup = None
          continue
        }
      }
      table.append_child(child)
      current_body = None
      current_row = None
      current_colgroup = None
      in_implicit_section = false
    }
  }
}

///|
fn normalize_tables(node : @dom.Node) -> Unit {
  match node.template_contents {
    Some(contents) => normalize_tables(contents)
    None => ()
  }
  let html_ns = node.ns is None || node.ns is Some("html")
  match node.kind {
    Element if html_ns && node.name == "table" => normalize_table(node)
    Element if html_ns && is_table_section_name(node.name) =>
      normalize_table_section(node)
    _ =>
      for child in node.children {
        normalize_tables(child)
      }
  }
}
