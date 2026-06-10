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
  if !self.has_open_element(name) {
    if name == "body" && self.has_open_element("html") {
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
  if !self.document_after_body || self.is_fragment_parser() {
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
    let frameset_document = self.after_frameset ||
      self.detached_frameset_mode ||
      self.has_open_element("frameset")
    if !frameset_document &&
      (
        node.kind == Element ||
        (node.kind == Text && text_has_non_ascii_whitespace(node.data))
      ) {
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
  if self.is_fragment_parser() ||
    !self.document_after_body ||
    self.has_open_element("template") {
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
