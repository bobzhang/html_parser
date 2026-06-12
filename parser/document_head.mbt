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
    ignore(self.pop_open_element())
    let duplicate = @dom.element("head")
    self.current_node().append_child(duplicate)
    self.push_open_element(duplicate)
    self.duplicate_head_element = Some(duplicate)
    return true
  }
  match self.pop_open_element() {
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
  self.push_open_element(duplicate)
  self.duplicate_head_element = Some(duplicate)
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
      ignore(self.pop_open_element())
      self.duplicate_head_element = None
      true
    }
    _ => false
  }
}
