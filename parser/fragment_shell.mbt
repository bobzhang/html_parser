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
      if self.fragment_context_html &&
        !self.in_select_insertion_mode() &&
        !self.current_node_is_foreign_namespace() &&
        !self.has_open_template() {
        // In select mode or foreign content the </html> end tag is
        // simply ignored; it does not move the fragment to the
        // after-body state.
        self.fragment_context_html_after_body = true
      }
      true
    }
    "body" => !self.in_select_insertion_mode()
    _ => false
  }
}

///|
fn fragment_shell_start_is_ignored(name : StringView) -> Bool {
  match name {
    "body" | "head" | "html" => true
    _ => false
  }
}

///|
fn html_fragment_child_is_before_head(child : @dom.Node) -> Bool {
  child.kind == Comment || is_whitespace_text_node(child)
}

///|
fn html_fragment_child_is_before_body(child : @dom.Node) -> Bool {
  if child.kind == Comment || is_whitespace_text_node(child) {
    return true
  }
  if child.kind != Element {
    return false
  }
  child.name == "head" ||
  is_document_head_element_name(child.name) ||
  (child.name == "html" && html_fragment_children_are_before_body(child))
}

///|
fn html_fragment_children_are_before_head(html : @dom.Node) -> Bool {
  for child in html.children {
    if !html_fragment_child_is_before_head(child) {
      return false
    }
  }
  true
}

///|
fn html_fragment_children_are_before_body(html : @dom.Node) -> Bool {
  for child in html.children {
    if !html_fragment_child_is_before_body(child) {
      return false
    }
  }
  true
}

///|
fn Parser::current_node_allows_html_fragment_head(self : Parser) -> Bool {
  let current = self.current_node()
  current.kind == Element &&
  current.name == "html" &&
  html_fragment_children_are_before_head(current)
}

///|
fn Parser::current_node_allows_html_fragment_body(self : Parser) -> Bool {
  let current = self.current_node()
  current.kind == Element &&
  current.name == "html" &&
  html_fragment_children_are_before_body(current)
}

///|
fn Parser::insert_html_fragment_body_marker(
  self : Parser,
  attrs : Map[String, String?],
  start : Int?,
) -> Unit {
  match self.fragment_context_html_root {
    Some(html) => {
      let node = match start {
        Some(offset) =>
          self.node_with_origin(@dom.element("body", attrs~), offset)
        None => @dom.element("body", attrs~)
      }
      html.append_child(node)
    }
    None => ()
  }
}

///|
fn Parser::insert_empty_html_fragment_body_marker(self : Parser) -> Unit {
  let attrs : Map[String, String?] = {}
  self.insert_html_fragment_body_marker(attrs, None)
}

///|
fn Parser::current_node_is_html_element(self : Parser) -> Bool {
  let current = self.current_node()
  current.kind == Element && current.name == "html"
}

///|
fn Parser::handle_html_fragment_shell_start_tag(
  self : Parser,
  name : String,
  attrs : Map[String, String?],
  start : Int,
) -> Bool {
  if name == "html" &&
    (
      self.after_frameset ||
      self.detached_frameset_mode ||
      self.has_open_element("frameset")
    ) {
    return false
  }
  match name {
    "head" =>
      if self.current_node_allows_html_fragment_head() {
        false
      } else {
        self.error_at("unexpected-start-tag", start)
        if self.current_node_is_html_element() {
          self.insert_empty_html_fragment_body_marker()
        }
        true
      }
    "body" =>
      if self.fragment_context_html_after_body {
        self.fragment_context_html_after_body = false
        self.error_at("unexpected-token-after-body", start)
        self.error_at("unexpected-start-tag", start)
        self.frameset_ok = false
        self.insert_html_fragment_body_marker(attrs, Some(start))
        true
      } else if self.current_node_allows_html_fragment_body() {
        false
      } else {
        self.error_at("unexpected-start-tag", start)
        self.frameset_ok = false
        self.insert_html_fragment_body_marker(attrs, Some(start))
        true
      }
    "html" =>
      if self.fragment_context_html_after_body {
        self.fragment_context_html_after_body = false
        self.error_at("unexpected-start-tag", start)
        true
      } else if self.current_node_allows_html_fragment_body() {
        false
      } else {
        self.error_at("unexpected-start-tag", start)
        if self.current_node_is_html_element() {
          self.insert_empty_html_fragment_body_marker()
        }
        true
      }
    _ => false
  }
}

///|
fn Parser::handle_fragment_shell_start_tag(
  self : Parser,
  name : String,
  attrs : Map[String, String?],
  start : Int,
) -> Bool {
  if !self.is_fragment_parser() || !fragment_shell_start_is_ignored(name) {
    return false
  }
  if self.fragment_context_html {
    return self.handle_html_fragment_shell_start_tag(name, attrs, start)
  }
  self.error_at(self.fragment_shell_start_error_code(name), start)
  true
}

///|
fn Parser::fragment_shell_start_error_code(
  self : Parser,
  name : StringView,
) -> String {
  if self.in_select_insertion_mode() && (name == "body" || name == "head") {
    "unexpected-start-tag-in-select"
  } else {
    "unexpected-start-tag"
  }
}
