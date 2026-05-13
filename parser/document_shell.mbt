///|
fn Parser::current_is_disabled_head_noscript(self : Parser) -> Bool {
  if self.scripting_enabled {
    return false
  }
  let current = self.current_node()
  if !(current.kind == Element && current.name == "noscript") {
    return false
  }
  for node in self.stack {
    if physical_equal(node, current) {
      return false
    }
    if node.kind == Element && node.name == "head" {
      return true
    }
  }
  false
}

///|
fn disabled_head_noscript_allows_start(name : StringView) -> Bool {
  match name {
    "basefont" | "bgsound" | "link" | "meta" | "noframes" | "style" => true
    _ => false
  }
}

///|
fn Parser::current_is_document_head(self : Parser) -> Bool {
  let current = self.current_node()
  if !(current.kind == Element && current.name == "head") {
    return false
  }
  match current.parent {
    Some(parent) =>
      parent.kind == Document ||
      parent.kind == Fragment ||
      (parent.kind == Element && parent.name == "html")
    None => false
  }
}

///|
fn Parser::close_current_document_head_for_start(
  self : Parser,
  name : StringView,
  start : Int,
) -> Bool {
  if !self.current_is_document_head() {
    return false
  }
  if is_document_head_element_name(name) {
    return false
  }
  if name == "head" {
    self.error_at("unexpected-start-tag", start)
    ignore(self.stack.pop())
    let duplicate = @dom.element("head")
    self.current_node().append_child(duplicate)
    self.stack.push(duplicate)
    self.duplicate_head_element = Some(duplicate)
    return true
  }
  match self.stack.pop() {
    Some(node) =>
      if self.duplicate_head_element is Some(duplicate) &&
        physical_equal(node, duplicate) {
        self.duplicate_head_element = None
      }
    None => ()
  }
  false
}

///|
fn node_has_direct_element_child(node : @dom.Node, name : String) -> Bool {
  for child in node.children {
    if child.kind == Element && child.name == name {
      return true
    }
  }
  false
}

///|
fn Parser::document_head_exists(self : Parser) -> Bool {
  if node_has_direct_element_child(self.root, "head") {
    return true
  }
  match document_html_element(self.root) {
    Some(html) => node_has_direct_element_child(html, "head")
    None => false
  }
}

///|
fn Parser::document_head_start_is_late(self : Parser) -> Bool {
  self.document_head_exists() ||
  !self.frameset_ok ||
  self.after_frameset ||
  self.has_open_element("body") ||
  self.has_open_element("frameset")
}

///|
fn Parser::handle_late_document_head_start_tag(
  self : Parser,
  name : StringView,
  start : Int,
) -> Bool {
  if self.is_fragment_parser() || name != "head" {
    return false
  }
  if !self.document_head_start_is_late() {
    return false
  }
  self.error_at("unexpected-start-tag", start)
  let duplicate = @dom.element("head")
  match self.open_html_element() {
    Some(html) => html.append_child(duplicate)
    None => self.root.append_child(duplicate)
  }
  self.stack.push(duplicate)
  self.duplicate_head_element = Some(duplicate)
  true
}

///|
fn Parser::handle_repeated_document_html_start_tag(
  self : Parser,
  name : StringView,
  attrs : Map[String, String?],
  start : Int,
) -> Bool {
  if self.is_fragment_parser() ||
    self.in_select_insertion_mode() ||
    name != "html" {
    return false
  }
  match self.open_html_element() {
    Some(html) => {
      self.error_at("unexpected-start-tag", start)
      merge_missing_attrs_from_map(html, attrs)
      self.repeated_document_html_shell = true
      if !self.stack_contains_node(html) {
        self.stack.push(html)
      }
      true
    }
    None => false
  }
}

///|
fn Parser::report_body_start_after_repeated_document_html(
  self : Parser,
  name : StringView,
  start : Int,
) -> Unit {
  if !self.repeated_document_html_shell || name != "body" {
    return
  }
  self.error_at("unexpected-start-tag", start)
  self.repeated_document_html_shell = false
}

///|
fn Parser::pop_disabled_head_noscript_for_reprocess(self : Parser) -> Unit {
  ignore(self.stack.pop())
  match self.stack.last() {
    Some(node) if node.kind == Element && node.name == "head" =>
      ignore(self.stack.pop())
    _ => ()
  }
}

///|
fn Parser::handle_disabled_head_noscript_start_tag(
  self : Parser,
  name : StringView,
  start : Int,
) -> Bool {
  if !self.current_is_disabled_head_noscript() {
    return false
  }
  if disabled_head_noscript_allows_start(name) {
    return false
  }
  if name == "head" || name == "noscript" {
    self.error_at("unexpected-start-tag", start)
    return true
  }
  self.error_at("unexpected-start-tag", start)
  self.pop_disabled_head_noscript_for_reprocess()
  false
}

///|
fn Parser::handle_disabled_head_noscript_end_tag(
  self : Parser,
  name : StringView,
  start : Int,
) -> Bool {
  if !self.current_is_disabled_head_noscript() {
    return false
  }
  if name == "noscript" {
    ignore(self.stack.pop())
    return true
  }
  self.error_at("unexpected-end-tag", start)
  if name == "br" {
    self.pop_disabled_head_noscript_for_reprocess()
    return false
  }
  true
}

///|
fn Parser::handle_duplicate_head_end_tag(
  self : Parser,
  name : String,
  start : Int,
) -> Bool {
  if name != "head" {
    return false
  }
  match (self.stack.last(), self.duplicate_head_element) {
    (Some(current), Some(duplicate)) if physical_equal(current, duplicate) => {
      self.error_at("unexpected-end-tag", start)
      ignore(self.stack.pop())
      self.duplicate_head_element = None
      true
    }
    _ => false
  }
}

///|
fn Parser::is_fragment_parser(self : Parser) -> Bool {
  self.root.kind == Fragment
}

///|
fn Parser::handle_document_after_body_html_end_tag(
  self : Parser,
  name : StringView,
  start : Int,
) -> Bool {
  if self.is_fragment_parser() ||
    !self.document_after_body ||
    name != "html" ||
    self.has_open_element("html") {
    return false
  }
  self.error_at("unexpected-token-after-body", start)
  true
}

///|
fn Parser::handle_document_body_or_html_end_tag(
  self : Parser,
  name : String,
  pos : Int,
) -> Bool {
  if self.is_fragment_parser() || (name != "body" && name != "html") {
    return false
  }
  if !self.has_open_element(name) {
    if name == "body" && self.has_open_element("html") {
      return true
    }
    return false
  }
  self.pop_until(name, pos)
  self.document_after_body = true
  true
}

///|
fn Parser::fragment_end_tag_is_ignored(
  self : Parser,
  name : StringView,
) -> Bool {
  if !self.is_fragment_parser() {
    return false
  }
  match name {
    "html" => {
      if self.fragment_context_html {
        self.fragment_context_html_after_body = true
      }
      true
    }
    "body" => !self.in_select_insertion_mode()
    _ => false
  }
}

///|
fn Parser::document_has_element_child(self : Parser) -> Bool {
  for child in self.root.children {
    if child.kind == Element {
      return true
    }
  }
  false
}

///|
fn Parser::handle_before_html_end_tag(
  self : Parser,
  name : StringView,
  start : Int,
  error_pos : Int,
) -> Bool {
  if !self.before_html_phase ||
    self.is_fragment_parser() ||
    self.document_has_element_child() {
    return false
  }
  self.before_html_phase = false
  match name {
    "html" | "head" | "body" => true
    "br" => {
      self.error_at("unexpected-end-tag", error_pos)
      self.insert_body_mode_node(
        self.node_with_origin(@dom.element("br"), start),
      )
      true
    }
    _ => {
      self.error_at("unexpected-end-tag-before-html", error_pos)
      true
    }
  }
}
