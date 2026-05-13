///|
fn active_formatting_element_name(name : StringView) -> Bool {
  match name {
    "a"
    | "b"
    | "big"
    | "code"
    | "em"
    | "font"
    | "i"
    | "nobr"
    | "s"
    | "small"
    | "strike"
    | "strong"
    | "tt"
    | "u" => true
    _ => false
  }
}

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
fn Parser::prepare_active_formatting_start(
  self : Parser,
  name : StringView,
  start : Int,
) -> Unit {
  if name == "a" && self.active_formatting_index(name) >= 0 {
    self.error_at("unexpected-start-tag-implies-end-tag", start)
    self.adoption_agency(name, start)
    self.remove_last_active_formatting_by_name(name)
    self.remove_last_open_element_by_name(name)
  } else if name == "nobr" && self.has_open_element_in_default_scope("nobr") {
    self.adoption_agency(name, start)
    self.remove_last_active_formatting_by_name(name)
    self.remove_last_open_element_by_name(name)
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

///|
fn Parser::close_open_caption_element(self : Parser) -> Unit {
  ignore(self.close_open_element("caption"))
  self.clear_active_formatting_to_marker()
}

///|
fn applet_like_element_name(name : StringView) -> Bool {
  match name {
    "applet" | "marquee" | "object" => true
    _ => false
  }
}

///|
fn active_formatting_marker_element_name(name : StringView) -> Bool {
  match name {
    "caption" | "template" => true
    _ => applet_like_element_name(name)
  }
}

///|
fn Parser::handle_applet_like_end_tag(
  self : Parser,
  name : String,
  pos : Int,
) -> Bool {
  if !applet_like_element_name(name) {
    return false
  }
  if !self.has_open_element_in_default_scope(name) {
    self.error_at("unexpected-end-tag", pos)
    return true
  }
  while self.stack.length() > 1 {
    match self.stack.pop() {
      Some(node) if node.kind == Element && node.name == name => break
      _ => ()
    }
  }
  self.clear_active_formatting_to_marker()
  true
}

///|
fn Parser::reconstruct_active_formatting_elements(self : Parser) -> Unit {
  if self.active_formatting.is_empty() {
    return
  }
  let last_index = self.active_formatting.length() - 1
  if self.active_formatting[last_index].marker ||
    self.stack_contains_node(self.active_formatting[last_index].node) {
    return
  }
  let mut index = last_index
  while index > 0 {
    let previous = self.active_formatting[index - 1]
    if previous.marker || self.stack_contains_node(previous.node) {
      break
    }
    index -= 1
  }
  while index < self.active_formatting.length() {
    let entry = self.active_formatting[index]
    let node = @dom.element(entry.name, attrs=entry.attrs.copy(), ns=entry.ns)
    copy_node_origin_from(node, entry.node)
    self.current_node().append_child(node)
    self.stack.push(node)
    self.active_formatting[index] = {
      marker: false,
      name: entry.name,
      ns: entry.ns,
      attrs: entry.attrs,
      node,
    }
    index += 1
  }
}
