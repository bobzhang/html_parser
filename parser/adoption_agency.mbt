///|
fn Parser::active_formatting_index_by_node(
  self : Parser,
  target : @dom.Node,
) -> Int {
  let mut index = self.active_formatting.length()
  while index > 0 {
    index -= 1
    let entry = self.active_formatting[index]
    if !entry.marker && physical_equal(entry.node, target) {
      return index
    }
  }
  -1
}

///|
fn Parser::stack_index_by_node(self : Parser, target : @dom.Node) -> Int {
  let mut index = 0
  while index < self.stack.length() {
    if physical_equal(self.stack[index], target) {
      return index
    }
    index += 1
  }
  -1
}

///|
fn Parser::adoption_agency(
  self : Parser,
  subject : StringView,
  pos : Int,
) -> Unit {
  let subject_name = subject.to_owned()
  match self.stack.last() {
    Some(current) if current.kind == Element &&
      current.name == subject_name &&
      self.active_formatting_index(subject) < 0 => {
      ignore(self.close_open_element(subject_name))
      return
    }
    _ => ()
  }
  for _ in 0..<8 {
    let formatting_index = self.active_formatting_index(subject)
    if formatting_index < 0 {
      self.error_at("adoption-agency-1.3", pos)
      return
    }
    let formatting_element = self.active_formatting[formatting_index].node
    let formatting_open_index = self.stack_index_by_node(formatting_element)
    if formatting_open_index < 0 {
      self.error_at("adoption-agency-1.3", pos)
      self.remove_active_formatting_index(formatting_index)
      return
    }
    if !self.has_open_element_in_default_scope(formatting_element.name) {
      self.error_at("adoption-agency-1.3", pos)
      return
    }
    match self.stack.last() {
      Some(current) if !physical_equal(current, formatting_element) =>
        self.error_at("adoption-agency-1.3", pos)
      _ => ()
    }
    let mut furthest_block_index = -1
    let mut index = formatting_open_index + 1
    while index < self.stack.length() {
      let candidate = self.stack[index]
      if candidate.kind == Element &&
        (
          (
            (candidate.ns is None || candidate.ns is Some("html")) &&
            is_special_element_for_any_other_end_tag(candidate.name)
          ) ||
          is_foreign_special_element(candidate)
        ) {
        furthest_block_index = index
        break
      }
      index += 1
    }
    if furthest_block_index < 0 {
      while self.stack.length() > 1 {
        match self.pop_open_element() {
          Some(node) if physical_equal(node, formatting_element) => break
          _ => ()
        }
      }
      self.remove_active_formatting_index(formatting_index)
      return
    }
    let furthest_block = self.stack[furthest_block_index]
    let mut bookmark = formatting_index + 1
    let mut last_node = furthest_block
    let mut node_index = furthest_block_index
    let mut inner_loop_counter = 0
    while true {
      inner_loop_counter += 1
      node_index -= 1
      let node = self.stack[node_index]
      if physical_equal(node, formatting_element) {
        break
      }
      let mut node_formatting_index = self.active_formatting_index_by_node(node)
      if inner_loop_counter > 3 && node_formatting_index >= 0 {
        self.remove_active_formatting_index(node_formatting_index)
        if node_formatting_index < bookmark {
          bookmark -= 1
        }
        node_formatting_index = -1
      }
      if node_formatting_index < 0 {
        ignore(self.remove_open_element_at(node_index))
        continue
      }
      let entry = self.active_formatting[node_formatting_index]
      let new_node = element_from_formatting_entry(entry)
      self.active_formatting[node_formatting_index] = formatting_entry_with_node(
        entry, new_node,
      )
      self.replace_open_element_at(node_index, new_node)
      if physical_equal(last_node, furthest_block) {
        bookmark = node_formatting_index + 1
      }
      new_node.append_child(last_node)
      last_node = new_node
    }
    let common_ancestor = self.stack[formatting_open_index - 1]
    self.adoption_insert_into_common_ancestor(common_ancestor, last_node)
    let entry = self.active_formatting[formatting_index]
    let new_formatting_element = element_from_formatting_entry(entry)
    self.active_formatting[formatting_index] = formatting_entry_with_node(
      entry, new_formatting_element,
    )
    let moved_children = furthest_block.children.copy()
    for child in moved_children {
      new_formatting_element.append_child(child)
    }
    furthest_block.append_child(new_formatting_element)
    let replacement_entry = self.active_formatting[formatting_index]
    self.remove_active_formatting_index(formatting_index)
    bookmark -= 1
    self.active_formatting.insert(bookmark, replacement_entry)
    ignore(self.remove_open_node(formatting_element))
    let furthest_index = self.stack_index_by_node(furthest_block)
    self.insert_open_element_at(furthest_index + 1, new_formatting_element)
  }
}

///|
/// Step 14 of the adoption agency algorithm inserts into the common
/// ancestor using the appropriate place for inserting a node: when the
/// common ancestor is a table element, the node is foster-parented before
/// the open table instead of appended inside it.
fn Parser::adoption_insert_into_common_ancestor(
  self : Parser,
  common_ancestor : @dom.Node,
  node : @dom.Node,
) -> Unit {
  if common_ancestor.kind == Element &&
    is_table_start_foster_target(common_ancestor.name) {
    let table_index = self.last_open_table_index()
    if table_index >= 0 {
      if self.table_index_is_fragment_context_table(table_index) {
        self.current_node().append_child(node)
      } else {
        self.insert_node_before_open_table(node, table_index)
        self.forced_body_nodes.push(node)
      }
      return
    }
  }
  common_ancestor.append_child(node)
}
