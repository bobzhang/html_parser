///|
fn Parser::pop_until(
  self : Parser,
  name : String,
  pos : Int,
  source_end_tag? : String,
) -> Unit {
  if !self.end_tag_target_visible_for_pop(name) {
    self.error_at("unexpected-end-tag", pos)
    return
  }
  if !is_special_element_name(name) &&
    !active_formatting_element_name(name) &&
    self.special_blocks_end_tag(name) {
    // Names with dedicated end-tag rules (div, ul, ...) close through
    // their scope, and formatting end tags use the adoption agency
    // rules; only the any-other-end-tag walk stops at a special element.
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

///|
/// True when an element with this name is on the stack above the nearest
/// open HTML template. Template contents are a separate tree: end tags
/// inside a template must not see (or close) elements outside it.
fn Parser::end_tag_target_visible(self : Parser, name : String) -> Bool {
  let mut index = self.stack.length()
  while index > 0 {
    index -= 1
    let node = self.stack[index]
    if node.kind == Element && node.name == name {
      return true
    }
    if name != "template" &&
      node.kind == Element &&
      node.name == "template" &&
      (node.ns is None || node.ns is Some("html")) {
      return false
    }
  }
  false
}

///|
/// The spec's "special" element category (HTML namespace), used by the
/// any-other-end-tag rule: walking the open-elements stack, a special
/// element encountered before the target means the end tag is ignored.
fn is_special_element_name(name : StringView) -> Bool {
  match name {
    "address"
    | "applet"
    | "area"
    | "article"
    | "aside"
    | "base"
    | "basefont"
    | "bgsound"
    | "blockquote"
    | "body"
    | "br"
    | "button"
    | "caption"
    | "center"
    | "col"
    | "colgroup"
    | "dd"
    | "details"
    | "dialog"
    | "dir"
    | "div"
    | "dl"
    | "dt"
    | "embed"
    | "fieldset"
    | "figcaption"
    | "figure"
    | "footer"
    | "form"
    | "frame"
    | "frameset"
    | "h1"
    | "h2"
    | "h3"
    | "h4"
    | "h5"
    | "h6"
    | "head"
    | "header"
    | "hgroup"
    | "hr"
    | "html"
    | "iframe"
    | "img"
    | "input"
    | "keygen"
    | "li"
    | "link"
    | "listing"
    | "main"
    | "marquee"
    | "menu"
    | "menuitem"
    | "meta"
    | "nav"
    | "noembed"
    | "noframes"
    | "noscript"
    | "object"
    | "ol"
    | "p"
    | "param"
    | "plaintext"
    | "pre"
    | "script"
    | "search"
    | "section"
    | "select"
    | "source"
    | "style"
    | "summary"
    | "table"
    | "tbody"
    | "td"
    | "template"
    | "textarea"
    | "tfoot"
    | "th"
    | "thead"
    | "title"
    | "tr"
    | "track"
    | "ul"
    | "wbr" => true
    _ => false
  }
}

///|
fn Parser::close_open_element(self : Parser, name : String) -> Bool {
  if !self.end_tag_target_visible(name) {
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
fn Parser::open_html_element(self : Parser) -> @dom.Node? {
  for node in self.stack {
    if node.kind == Element && node.name == "html" {
      return Some(node)
    }
  }
  document_html_element(self.root)
}

///|
fn Parser::stack_contains_node(self : Parser, target : @dom.Node) -> Bool {
  for node in self.stack {
    if physical_equal(node, target) {
      return true
    }
  }
  false
}

///|
fn Parser::remove_open_node(self : Parser, target : @dom.Node) -> Bool {
  let mut index = 0
  while index < self.stack.length() {
    if physical_equal(self.stack[index], target) {
      ignore(self.stack.remove(index))
      return true
    }
    index += 1
  }
  false
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

///|
/// Like end_tag_target_visible, but matches the same name rules as
/// pop_until (names_match_end_tag).
fn Parser::end_tag_target_visible_for_pop(self : Parser, name : String) -> Bool {
  let mut index = self.stack.length()
  while index > 0 {
    index -= 1
    let node = self.stack[index]
    if node.kind == Element && names_match_end_tag(node, name) {
      return true
    }
    if name != "template" &&
      node.kind == Element &&
      node.name == "template" &&
      (node.ns is None || node.ns is Some("html")) {
      return false
    }
  }
  false
}

///|
/// Implements the stack walk of the spec's any-other-end-tag rule: when a
/// special element sits above the matching element, the end tag is a parse
/// error and the token is ignored.
fn Parser::special_blocks_end_tag(self : Parser, name : String) -> Bool {
  let mut index = self.stack.length()
  while index > 0 {
    index -= 1
    let node = self.stack[index]
    if node.kind != Element {
      continue
    }
    if names_match_end_tag(node, name) {
      return false
    }
    if (node.ns is None || node.ns is Some("html")) &&
      is_special_element_name(node.name) {
      return true
    }
  }
  false
}
