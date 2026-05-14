///|
fn Parser::append_active_formatting_entry(
  self : Parser,
  node : @dom.Node,
) -> Unit {
  match node.ns {
    Some(ns) =>
      self.active_formatting.push({
        marker: false,
        name: node.name,
        ns,
        attrs: node.attrs.copy(),
        node,
      })
    None => ()
  }
}

///|
fn Parser::active_formatting_index(self : Parser, name : StringView) -> Int {
  let target = name.to_owned()
  let mut index = self.active_formatting.length()
  while index > 0 {
    index -= 1
    let entry = self.active_formatting[index]
    if entry.marker {
      break
    }
    if entry.name == target {
      return index
    }
  }
  -1
}

///|
fn formatting_attrs_equal(
  left : Map[String, String?],
  right : Map[String, String?],
) -> Bool {
  for name, value in left {
    match right.get(name) {
      Some(other) if other == value => ()
      _ => return false
    }
  }
  for name, _ in right {
    if !left.contains(name) {
      return false
    }
  }
  true
}

///|
fn Parser::active_formatting_duplicate_index(
  self : Parser,
  name : StringView,
  attrs : Map[String, String?],
) -> Int {
  let target = name.to_owned()
  let mut first_match = -1
  let mut match_count = 0
  let mut index = 0
  while index < self.active_formatting.length() {
    let entry = self.active_formatting[index]
    if entry.marker {
      first_match = -1
      match_count = 0
    } else if entry.name == target && formatting_attrs_equal(entry.attrs, attrs) {
      if first_match < 0 {
        first_match = index
      }
      match_count += 1
    }
    index += 1
  }
  if match_count >= 3 {
    first_match
  } else {
    -1
  }
}

///|
fn Parser::remove_last_active_formatting_by_name(
  self : Parser,
  name : StringView,
) -> Unit {
  let target = name.to_owned()
  let mut index = self.active_formatting.length()
  while index > 0 {
    index -= 1
    let entry = self.active_formatting[index]
    if entry.marker {
      break
    }
    if entry.name == target {
      self.remove_active_formatting_index(index)
      return
    }
  }
}

///|
fn Parser::remove_last_open_element_by_name(
  self : Parser,
  name : StringView,
) -> Unit {
  let target = name.to_owned()
  let mut index = self.stack.length()
  while index > 0 {
    index -= 1
    let node = self.stack[index]
    if node.kind == Element && node.name == target {
      ignore(self.stack.remove(index))
      return
    }
  }
}

///|
fn Parser::active_formatting_orphan_anchor_index(self : Parser) -> Int {
  let mut index = self.active_formatting.length()
  while index > 0 {
    index -= 1
    let entry = self.active_formatting[index]
    if entry.marker {
      break
    }
    if entry.name == "a" && !self.stack_contains_node(entry.node) {
      return index
    }
  }
  -1
}

///|
fn formatting_entry_with_node(
  entry : FormattingEntry,
  node : @dom.Node,
) -> FormattingEntry {
  {
    marker: false,
    name: entry.name,
    ns: entry.ns,
    attrs: entry.attrs.copy(),
    node,
  }
}

///|
fn element_from_formatting_entry(entry : FormattingEntry) -> @dom.Node {
  let node = @dom.element(entry.name, attrs=entry.attrs.copy(), ns=entry.ns)
  copy_node_origin_from(node, entry.node)
  node
}

///|
fn Parser::remove_active_formatting_index(self : Parser, index : Int) -> Unit {
  ignore(self.active_formatting.remove(index))
}

///|
fn Parser::push_active_formatting_marker(self : Parser) -> Unit {
  self.active_formatting.push({
    marker: true,
    name: "",
    ns: "",
    attrs: {},
    node: self.root,
  })
}

///|
fn Parser::clear_active_formatting_to_marker(self : Parser) -> Unit {
  while !self.active_formatting.is_empty() {
    match self.active_formatting.pop() {
      Some(entry) if entry.marker => return
      _ => ()
    }
  }
}
