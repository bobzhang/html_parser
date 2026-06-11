///|
fn Parser::current_is_disabled_head_noscript(self : Parser) -> Bool {
  if self.scripting_enabled {
    return false
  }
  let current = self.current_node()
  if !(current.kind == Element && current.name == "noscript") {
    return false
  }
  let mut below_is_shell = true
  for node in self.stack {
    if physical_equal(node, current) {
      break
    }
    if node.kind == Element && node.name == "head" {
      return true
    }
    if !(node.kind == Document || (node.kind == Element && node.name == "html")) {
      below_is_shell = false
    }
  }
  // A noscript sitting directly at the document shell is in the implied
  // head while no body content has started.
  below_is_shell && !document_children_contain_body_content(self.root)
}

///|
fn disabled_head_noscript_allows_start(name : StringView) -> Bool {
  match name {
    "basefont" | "bgsound" | "link" | "meta" | "noframes" | "style" => true
    _ => false
  }
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
