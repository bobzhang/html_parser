///|
fn Parser::pop_until(
  self : Parser,
  name : String,
  pos : Int,
  source_end_tag? : String,
) -> Unit {
  let mut found = false
  for node in self.stack {
    if node.kind == Element && names_match_end_tag(node, name) {
      found = true
    }
  }
  if !found {
    self.error_at("unexpected-end-tag", pos)
    return
  }
  while self.stack.length() > 1 {
    match self.stack.last() {
      Some(node) if node.kind == Element &&
        node.name != name &&
        is_implied_end_tag_name(node.name) => ignore(self.stack.pop())
      _ => break
    }
  }
  match self.stack.last() {
    Some(node) if node.kind == Element && names_match_end_tag(node, name) => ()
    _ => self.error_at("end-tag-too-early", pos)
  }
  while self.stack.length() > 1 {
    let node = self.stack.pop().unwrap()
    if node.kind == Element && names_match_end_tag(node, name) {
      match source_end_tag {
        Some(raw) => set_node_source_end_tag(node, raw)
        None => ()
      }
      break
    }
  }
}

///|
fn is_implied_end_tag_name(name : StringView) -> Bool {
  match name {
    "dd"
    | "dt"
    | "li"
    | "option"
    | "optgroup"
    | "p"
    | "rb"
    | "rp"
    | "rt"
    | "rtc" => true
    _ => false
  }
}

///|
fn Parser::generate_implied_end_tags(self : Parser, exclude : String?) -> Unit {
  while self.stack.length() > 1 {
    match self.stack.last() {
      Some(node) if node.kind == Element &&
        is_implied_end_tag_name(node.name) &&
        !(exclude is Some(excluded) && node.name == excluded) =>
        ignore(self.stack.pop())
      _ => break
    }
  }
}

///|
fn Parser::close_open_element(self : Parser, name : String) -> Bool {
  let mut found = false
  for node in self.stack {
    if node.kind == Element && node.name == name {
      found = true
    }
  }
  if !found {
    return false
  }
  while self.stack.length() > 1 {
    let node = self.stack.pop().unwrap()
    if node.kind == Element && node.name == name {
      break
    }
  }
  true
}

///|
fn Parser::pop_current_element_if_name(self : Parser, name : String) -> Bool {
  match self.stack.last() {
    Some(node) if node.kind == Element && node.name == name => {
      ignore(self.stack.pop())
      true
    }
    _ => false
  }
}

///|
fn Parser::close_current_element_if_name(self : Parser, name : String) -> Unit {
  ignore(self.pop_current_element_if_name(name))
}

///|
fn Parser::last_stack_index_of(self : Parser, name : String) -> Int {
  let mut index = self.stack.length()
  while index > 0 {
    index -= 1
    let node = self.stack[index]
    if node.kind == Element && node.name == name {
      return index
    }
  }
  -1
}

///|
fn Parser::last_stack_index_of_node(self : Parser, target : @dom.Node) -> Int {
  let mut index = self.stack.length()
  while index > 0 {
    index -= 1
    if physical_equal(self.stack[index], target) {
      return index
    }
  }
  -1
}

///|
fn Parser::insert_element_without_push(
  self : Parser,
  name : StringView,
  attrs : Map[String, String?],
  start? : Int,
) -> Unit {
  let node = match start {
    Some(offset) => self.node_with_origin(@dom.element(name, attrs~), offset)
    None => @dom.element(name, attrs~)
  }
  self.current_node().append_child(node)
}

///|
fn Parser::insert_element_maybe_push(
  self : Parser,
  name : StringView,
  attrs : Map[String, String?],
  push : Bool,
  start? : Int,
) -> Unit {
  let node = match start {
    Some(offset) => self.node_with_origin(@dom.element(name, attrs~), offset)
    None => @dom.element(name, attrs~)
  }
  self.current_node().append_child(node)
  if push {
    self.stack.push(node)
  }
}
