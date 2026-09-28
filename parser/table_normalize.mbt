///|
fn is_table_section_name(name : StringView) -> Bool {
  name is ("tbody" | "thead" | "tfoot")
}

///|
fn is_table_cell_name(name : StringView) -> Bool {
  name is ("td" | "th")
}

///|
/// True when `node` is an element whose `append_child` stores children in
/// its own child list (an HTML `template` redirects into its contents).
fn table_normalize_target_is_plain(node : @dom.Node) -> Bool {
  node.kind == Element &&
  !(node.name == "template" && (node.ns is None || node.ns is Some("html")))
}

///|
/// Append a freshly created implicit wrapper (`tbody`, `tr`, or `colgroup`)
/// to `target`.
///
/// Equivalent to `target.append_child(wrapper)` for a new parentless,
/// childless wrapper, but skips its ancestor walk (which is O(depth) and made
/// normalizing deeply nested tables quadratic).
fn attach_table_wrapper(target : @dom.Node, wrapper : @dom.Node) -> Unit {
  append_new_node(target, wrapper)
}

///|
/// Re-attach `child`, an original child of `container` (a table or table
/// section whose child list is being rebuilt), to `target`, which is
/// `container` itself or an implicit wrapper/section inside it.
///
/// Equivalent to `target.append_child(child)`: `child` still points at
/// `container` as its parent but is no longer in its child list, so
/// detaching it only clears the parent pointer, and `child` cannot be an
/// ancestor of `target` (it is a separate subtree of `container`). The fast
/// path skips the O(depth) ancestor walk; anything unexpected falls back to
/// `append_child`.
fn reattach_table_child(
  container : @dom.Node,
  target : @dom.Node,
  child : @dom.Node,
) -> Unit {
  if child.parent is Some(parent) &&
    physical_equal(parent, container) &&
    container.template_contents is None &&
    !physical_equal(child, target) &&
    table_normalize_target_is_plain(target) &&
    table_target_is_within(target, container, child) &&
    !container.children.iter().any(node => physical_equal(node, child)) {
    child.parent = Some(target)
    target.children.push(child)
  } else {
    target.append_child(child)
  }
}

///|
/// True when `target` is `container` or reaches it within two parent steps
/// (a wrapper or section, or a row inside one) without passing `child`.
fn table_target_is_within(
  target : @dom.Node,
  container : @dom.Node,
  child : @dom.Node,
) -> Bool {
  let mut current = target
  for _ in 0..<3 {
    if physical_equal(current, container) {
      return true
    }
    if physical_equal(current, child) {
      return false
    }
    match current.parent {
      Some(parent) => current = parent
      None => return false
    }
  }
  false
}

///|
/// Progress of one table section while `normalize_tables` rebuilds its
/// child list: `current_row` is the implicit row still open for bare cells.
priv struct TableSectionNormalization {
  section : @dom.Node
  mut current_row : @dom.Node?
}

///|
/// Place one (already normalized) original child of a table section:
/// bare cells are gathered into an implicit row.
fn TableSectionNormalization::place(
  self : TableSectionNormalization,
  child : @dom.Node,
) -> Unit {
  let section = self.section
  if child.kind == Element && is_table_cell_name(child.name) {
    let row = match self.current_row {
      Some(row) => row
      None => {
        let row = @dom.element("tr")
        attach_table_wrapper(section, row)
        self.current_row = Some(row)
        row
      }
    }
    reattach_table_child(section, row, child)
  } else {
    reattach_table_child(section, section, child)
    self.current_row = None
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
      attach_table_wrapper(table, body)
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
      attach_table_wrapper(table, colgroup)
      (colgroup, Some(colgroup))
    }
  }
}

///|
/// Progress of one table while `normalize_tables` rebuilds its child list.
/// The fields are the implicit wrappers that are still open for the next
/// original child.
priv struct TableNormalization {
  table : @dom.Node
  mut current_body : @dom.Node?
  mut current_row : @dom.Node?
  mut current_colgroup : @dom.Node?
  mut in_implicit_section : Bool
}

///|
/// Place one (already normalized) original child of a table: columns go
/// into an implicit colgroup, rows and bare cells into an implicit tbody
/// (and row), and everything else stays a direct table child.
fn TableNormalization::place(
  self : TableNormalization,
  child : @dom.Node,
) -> Unit {
  let table = self.table
  if child.kind == Element && child.name == "col" {
    let (colgroup, next_colgroup) = table_implicit_colgroup(
      table,
      self.current_colgroup,
    )
    self.current_colgroup = next_colgroup
    reattach_table_child(table, colgroup, child)
    self.current_body = None
    self.current_row = None
  } else if child.kind == Text &&
    self.current_colgroup is Some(colgroup) &&
    !text_has_non_ascii_whitespace(child.data) {
    reattach_table_child(table, colgroup, child)
    self.current_body = None
    self.current_row = None
  } else if child.kind == Element && child.name == "tr" {
    let (body, next_body) = table_implicit_body(table, self.current_body)
    self.current_body = next_body
    reattach_table_child(table, body, child)
    self.current_row = None
    self.current_colgroup = None
    self.in_implicit_section = true
  } else if child.kind == Element && is_table_cell_name(child.name) {
    let (body, next_body) = table_implicit_body(table, self.current_body)
    self.current_body = next_body
    let row = match self.current_row {
      Some(row) => row
      None => {
        let row = @dom.element("tr")
        attach_table_wrapper(body, row)
        self.current_row = Some(row)
        row
      }
    }
    reattach_table_child(table, row, child)
    self.current_colgroup = None
    self.in_implicit_section = true
  } else {
    if child.kind == Comment &&
      self.in_implicit_section &&
      self.current_row is Some(row) {
      // A comment between bare cells stays in the still-open implicit
      // row; the next cell continues it.
      reattach_table_child(table, row, child)
      return
    }
    if (
        child.kind == Comment ||
        (child.kind == Text && is_whitespace_text_node(child))
      ) &&
      self.in_implicit_section &&
      table.children.length() > 0 {
      // Whitespace while an implicit row group is still open stays
      // inside it (the in-table-body insertion point); after an
      // explicitly closed section it remains a table child.
      let last = table.children[table.children.length() - 1]
      if last.kind == Element && is_table_section_name(last.name) {
        // The implicit row group stays open: a following row joins it
        // rather than starting a new one.
        reattach_table_child(table, last, child)
        self.current_body = Some(last)
        self.current_row = None
        self.current_colgroup = None
        return
      }
    }
    reattach_table_child(table, table, child)
    self.current_body = None
    self.current_row = None
    self.current_colgroup = None
    self.in_implicit_section = false
  }
}

///|
/// One pending step of the explicit-stack `normalize_tables` walk.
priv enum TableNormalizeTask {
  /// Normalize this node and its subtree (template contents first).
  Visit(@dom.Node)
  /// Normalize this node's own children; its template contents are done.
  VisitChildren(@dom.Node)
  /// Place a normalized original child back into its table.
  PlaceInTable(TableNormalization, @dom.Node)
  /// Place a normalized original child back into its table section.
  PlaceInSection(TableSectionNormalization, @dom.Node)
}

///|
/// Push `Visit` (and, when `place` is given, a placement step after each
/// visit) for `children` so they pop in document order.
fn push_table_normalize_children(
  tasks : Array[TableNormalizeTask],
  children : Array[@dom.Node],
  place? : (@dom.Node) -> TableNormalizeTask,
) -> Unit {
  let mut index = children.length()
  while index > 0 {
    index -= 1
    let child = children[index]
    if place is Some(place) {
      tasks.push(place(child))
    }
    tasks.push(Visit(child))
  }
}

///|
/// Wrap bare table rows, cells, and columns in their implied row groups,
/// rows, and column groups throughout `root` (including template contents).
///
/// Uses an explicit work stack so arbitrarily deep trees do not overflow the
/// call stack. The step order matches a recursive walk exactly: a node's
/// template contents are normalized before its children, and each original
/// child of a table or table section is fully normalized before it is placed
/// back into its (possibly implicit) wrapper.
fn normalize_tables(root : @dom.Node) -> Unit {
  let tasks : Array[TableNormalizeTask] = [Visit(root)]
  while tasks.pop() is Some(task) {
    match task {
      Visit(node) =>
        match node.template_contents {
          Some(contents) => {
            tasks.push(VisitChildren(node))
            tasks.push(Visit(contents))
          }
          None => tasks.push(VisitChildren(node))
        }
      VisitChildren(node) => {
        let html_ns = node.ns is None || node.ns is Some("html")
        match node.kind {
          Element if html_ns && node.name == "table" => {
            let original = node.children.copy()
            node.children.clear()
            let state : TableNormalization = {
              table: node,
              current_body: None,
              current_row: None,
              current_colgroup: None,
              in_implicit_section: false,
            }
            push_table_normalize_children(tasks, original, place=child => {
              PlaceInTable(state, child)
            })
          }
          Element if html_ns && is_table_section_name(node.name) => {
            let original = node.children.copy()
            node.children.clear()
            let state : TableSectionNormalization = {
              section: node,
              current_row: None,
            }
            push_table_normalize_children(tasks, original, place=child => {
              PlaceInSection(state, child)
            })
          }
          _ => push_table_normalize_children(tasks, node.children)
        }
      }
      PlaceInTable(state, child) => state.place(child)
      PlaceInSection(state, child) => state.place(child)
    }
  }
}
