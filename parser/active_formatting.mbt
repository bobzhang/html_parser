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
