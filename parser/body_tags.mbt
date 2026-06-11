///|
fn table_start_tag_is_ignored_outside_table(name : StringView) -> Bool {
  match name {
    "colgroup" | "tbody" | "td" | "tfoot" | "th" | "thead" | "tr" => true
    _ => false
  }
}

///|
fn Parser::col_start_tag_is_ignored_outside_table(
  self : Parser,
  name : StringView,
) -> Bool {
  name == "col" &&
  !self.is_fragment_parser() &&
  !self.has_open_element("table") &&
  !self.in_template_content_without_inner_table()
}

///|
fn Parser::close_open_table_cell(self : Parser) -> Unit {
  if self.has_open_element("td") {
    ignore(self.close_open_element("td"))
    self.clear_active_formatting_to_marker()
  } else if self.has_open_element("th") {
    ignore(self.close_open_element("th"))
    self.clear_active_formatting_to_marker()
  }
}

///|
fn is_heading_element_name(name : StringView) -> Bool {
  match name {
    "h1" | "h2" | "h3" | "h4" | "h5" | "h6" => true
    _ => false
  }
}

///|
fn Parser::close_current_heading_element(self : Parser) -> Unit {
  match self.stack.last() {
    Some(node) if node.kind == Element && is_heading_element_name(node.name) =>
      ignore(self.stack.pop())
    _ => ()
  }
}

///|
fn Parser::close_open_heading_element(
  self : Parser,
  name : String,
  pos : Int,
) -> Unit {
  let mut found = false
  for node in self.stack {
    if node.kind == Element && is_heading_element_name(node.name) {
      found = true
    }
  }
  if !found {
    self.error_at("unexpected-end-tag", pos)
    return
  }
  match self.stack.last() {
    Some(node) if node.kind == Element && node.name == name => ()
    _ => self.error_at("end-tag-too-early", pos)
  }
  while self.stack.length() > 1 {
    let node = self.stack.pop().unwrap()
    if node.kind == Element && is_heading_element_name(node.name) {
      break
    }
  }
}

///|
fn start_tag_closes_p(name : StringView) -> Bool {
  match name {
    "address"
    | "article"
    | "aside"
    | "blockquote"
    | "center"
    | "details"
    | "dialog"
    | "dir"
    | "dd"
    | "div"
    | "dl"
    | "dt"
    | "fieldset"
    | "figcaption"
    | "figure"
    | "footer"
    | "form"
    | "h1"
    | "h2"
    | "h3"
    | "h4"
    | "h5"
    | "h6"
    | "header"
    | "hgroup"
    | "hr"
    | "li"
    | "listing"
    | "main"
    | "menu"
    | "nav"
    | "ol"
    | "p"
    | "plaintext"
    | "pre"
    | "search"
    | "section"
    | "summary"
    | "table"
    | "ul"
    | "xmp" => true
    _ => false
  }
}

///|
fn current_node_is_ruby_annotation(node : @dom.Node) -> Bool {
  node.kind == Element &&
  (
    node.name == "rb" ||
    node.name == "rp" ||
    node.name == "rt" ||
    node.name == "rtc"
  )
}

///|
fn Parser::start_tag_inserts_empty_nonvoid(
  self : Parser,
  name : StringView,
) -> Bool {
  // basefont and bgsound use the in-head insertion rule: insert the
  // element and immediately pop it, so following content becomes a
  // sibling rather than a child.
  name == "keygen" ||
  name == "basefont" ||
  name == "bgsound" ||
  (name == "frame" && self.is_fragment_parser())
}
