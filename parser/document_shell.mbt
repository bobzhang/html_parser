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
  self.document_after_html = true
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
  for node in self.stack {
    if node.kind == Element && is_foreign_special_element(node) {
      // Inside a foreign integration point body/html are not in scope:
      // the end tag is ignored without entering the after-body modes.
      self.error_at("unexpected-end-tag", pos)
      return true
    }
  }
  if !self.has_open_element(name) {
    if name == "body" && self.has_open_element("html") {
      // A stray </body> with an explicit html element still runs the
      // after-head transition through body into after-body.
      self.document_after_body = true
      return true
    }
    if self.has_open_element("template") {
      // In-template end tags other than </template> are ignored and must
      // not advance the outer document's insertion mode.
      return false
    }
    // A stray </body> or </html> still switches the document into the
    // after-body modes: later tokens reprocess using the in-body rules,
    // so subsequent top-level content belongs to the body. The spec's
    // reprocessing chain pops an open head on the way there.
    if self.current_is_document_head() {
      ignore(self.stack.pop())
    }
    self.error_at("unexpected-end-tag", pos)
    self.document_after_body = true
    if name == "html" {
      self.document_after_html = true
    }
    return true
  }
  self.pop_until(name, pos)
  self.document_after_body = true
  if name == "html" {
    self.document_after_html = true
  }
  true
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
    "html" | "body" => {
      // The spec's reprocessing chain for a stray </body> or </html> at
      // the document start ends in the after-body modes; later tokens
      // reprocess using the in-body rules.
      self.document_after_body = true
      if name == "html" {
        self.document_after_html = true
      }
      true
    }
    "head" => true
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

///|
/// Records a node inserted at the document top level after the body was
/// closed. The after-body insertion modes reprocess such tokens with the
/// in-body rules, so the scaffolder must place these nodes in the body
/// rather than the head.
fn Parser::mark_forced_body_node(self : Parser, node : @dom.Node) -> Unit {
  if self.is_fragment_parser() {
    // An html fragment that re-entered body mode after a stray </html>
    // records top-level nodes as body content for scaffolding.
    if self.fragment_context_html &&
      self.fragment_context_html_entered_body &&
      !self.fragment_context_html_after_body &&
      !self.in_frameset_document() {
      match node.parent {
        Some(parent) =>
          if parent.kind == Element && parent.name == "html" {
            self.forced_body_nodes.push(node)
          }
        None => ()
      }
    }
    return
  }
  if !self.document_after_body && !self.document_entered_body {
    return
  }
  if !self.document_after_body &&
    !document_children_contain_body_content(self.root) {
    // Purely entered-body marking (after the after-body flags cleared)
    // only applies once real body content exists; until then a frameset
    // may still replace the body and head-phase tags keep their normal
    // placement.
    return
  }
  let current = self.current_node()
  if current.kind == Document ||
    (current.kind == Element && current.name == "html") {
    self.forced_body_nodes.push(node)
    // A non-whitespace token in the after-body modes switches back to
    // in-body before reprocessing, so later comments use normal insertion
    // again. Whitespace is processed without leaving after-body, and
    // frameset documents never reprocess in body (after-after-frameset
    // accepts noframes/whitespace/comments and ignores everything else).
    if self.document_after_body &&
      !self.in_frameset_document() &&
      (
        node.kind == Element ||
        (node.kind == Text && text_has_non_ascii_whitespace(node.data))
      ) {
      self.document_entered_body = true
      self.document_after_body = false
      self.document_after_html = false
    }
  }
}

///|
/// Routes a comment parsed after the body (or after </html>) to its
/// spec-mandated insertion point: after-body comments become the last
/// child of the html element, after-after-body comments attach to the
/// document itself. Returns false when normal insertion applies.
fn Parser::append_after_body_comment(self : Parser, node : @dom.Node) -> Bool {
  if self.is_fragment_parser() {
    // An html-context fragment that saw </html> places later comments
    // after the body, mirroring the after-body rules.
    if self.fragment_context_html &&
      self.fragment_context_html_after_body &&
      !self.has_open_element("template") {
      match self.fragment_context_html_root {
        Some(html) => {
          html.append_child(node)
          self.after_html_comments.push(node)
          return true
        }
        None => ()
      }
    }
    return false
  }
  if !self.document_after_body || self.has_open_element("template") {
    return false
  }
  if self.document_after_html {
    self.root.append_child(node)
    self.after_html_comments.push(node)
    return true
  }
  match document_html_element(self.root) {
    Some(html) => html.append_child(node)
    None => self.root.append_child(node)
  }
  self.after_body_comments.push(node)
  true
}

///|
fn Parser::in_frameset_document(self : Parser) -> Bool {
  self.after_frameset ||
  self.detached_frameset_mode ||
  self.has_open_element("frameset")
}

///|
/// A token other than </body>/</html> seen in the after-body modes is the
/// "anything else" case: switch back to in-body before reprocessing, so
/// later comments use normal insertion again. Frameset documents never
/// reprocess in body.
fn Parser::leave_after_body_for_token(self : Parser, name : String) -> Unit {
  self.end_tag_was_after_body = false
  if !self.document_after_body ||
    self.is_fragment_parser() ||
    self.in_frameset_document() ||
    name == "body" ||
    name == "html" {
    return
  }
  // Handlers later in the dispatch (the stray </p> recovery) still need
  // to know the token arrived in the after-body modes.
  self.end_tag_was_after_body = true
  self.document_entered_body = true
  self.document_after_body = false
  self.document_after_html = false
}

///|
/// True when a stray </p> arrives before body content has started in a
/// document parse (the before-head/in-head/after-head modes), where the
/// in-body act-as-<p> recovery does not apply.
fn Parser::stray_p_end_tag_is_ignored(self : Parser) -> Bool {
  if self.is_fragment_parser() {
    return false
  }
  if self.document_after_body ||
    self.end_tag_was_after_body ||
    self.document_entered_body {
    // After-body "anything else" tokens reprocess in body (and the
    // parser stays in body afterwards), where the act-as-<p> recovery
    // applies.
    return false
  }
  if self.current_is_document_head() {
    return true
  }
  let current = self.current_node()
  if !(current.kind == Document ||
    (current.kind == Element && current.name == "html")) {
    return false
  }
  !document_children_contain_body_content(self.root)
}

///|
fn document_children_contain_body_content(root : @dom.Node) -> Bool {
  for child in root.children {
    match child.kind {
      Element =>
        if child.name == "html" {
          if document_children_contain_body_content(child) {
            return true
          }
        } else if child.name != "head" &&
          !is_document_head_element_name(child.name) {
          return true
        }
      Text => if !is_whitespace_text_node(child) { return true }
      _ => ()
    }
  }
  false
}

///|
/// Merges attributes from ignored late <body> start tags into the
/// scaffolded body element, without overwriting existing attributes.
fn Parser::apply_pending_document_body_attrs(self : Parser) -> Unit {
  if self.pending_document_body_attrs.is_empty() {
    return
  }
  match document_html_element(self.root) {
    Some(html) =>
      for child in html.children {
        if child.kind == Element && child.name == "body" {
          for attr_name, attr_value in self.pending_document_body_attrs {
            if !child.attrs.contains(attr_name) {
              child.attrs[attr_name] = attr_value
            }
          }
          return
        }
      }
    None => ()
  }
}

///|
/// True when the document already holds an element or non-whitespace text
/// at the top level: a subsequent <html> start tag is no longer the
/// document's structural html element.
fn document_has_any_content(root : @dom.Node) -> Bool {
  for child in root.children {
    match child.kind {
      Element => return true
      Text => if !is_whitespace_text_node(child) { return true }
      _ => ()
    }
  }
  false
}

///|
/// A comment arriving at the top level after parsing has returned to
/// in-body (a non-whitespace token followed </html>) belongs in the body:
/// mark it so the scaffolder moves it there.
fn Parser::mark_entered_body_comment(self : Parser, node : @dom.Node) -> Unit {
  if self.is_fragment_parser() {
    if self.fragment_context_html &&
      self.fragment_context_html_entered_body &&
      !self.fragment_context_html_after_body &&
      !self.in_frameset_document() {
      match node.parent {
        Some(parent) =>
          if parent.kind == Element && parent.name == "html" {
            self.forced_body_nodes.push(node)
          }
        None => ()
      }
    }
    return
  }
  if !self.document_entered_body ||
    self.document_after_body ||
    self.in_frameset_document() ||
    !document_children_contain_body_content(self.root) {
    // Until real body content has appeared a frameset may yet replace
    // the body: leave the comment where normal insertion put it.
    return
  }
  match node.parent {
    Some(parent) =>
      if parent.kind == Document ||
        (parent.kind == Element && parent.name == "html") {
        self.forced_body_nodes.push(node)
      }
    None => ()
  }
}
