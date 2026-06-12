///|
fn foreign_breakout_start_name(name : StringView) -> Bool {
  match name {
    "b"
    | "big"
    | "blockquote"
    | "body"
    | "br"
    | "center"
    | "code"
    | "dd"
    | "div"
    | "dl"
    | "dt"
    | "em"
    | "embed"
    | "h1"
    | "h2"
    | "h3"
    | "h4"
    | "h5"
    | "h6"
    | "head"
    | "hr"
    | "i"
    | "img"
    | "li"
    | "listing"
    | "menu"
    | "meta"
    | "nobr"
    | "ol"
    | "p"
    | "pre"
    | "ruby"
    | "s"
    | "small"
    | "span"
    | "strong"
    | "strike"
    | "sub"
    | "sup"
    | "table"
    | "tt"
    | "u"
    | "ul"
    | "var" => true
    _ => false
  }
}

///|
fn foreign_font_has_breakout_attr(attrs : Map[String, String?]) -> Bool {
  attrs.contains("color") || attrs.contains("face") || attrs.contains("size")
}

///|
fn foreign_start_breaks_out(
  name : StringView,
  attrs : Map[String, String?],
) -> Bool {
  foreign_breakout_start_name(name) ||
  (name == "font" && foreign_font_has_breakout_attr(attrs))
}

///|
fn Parser::clean_foreign_content_text(
  self : Parser,
  raw : StringView,
  start : Int,
) -> String {
  if !raw.contains("\u{0000}") {
    return raw.to_owned()
  }
  let out = StringBuilder(size_hint=raw.length())
  let mut offset = 0
  for ch in raw {
    if ch == '\u{0000}' {
      self.error_at("unexpected-null-character", start + offset)
      self.error_at("invalid-codepoint-in-foreign-content", start + offset)
      out.write_char('\u{FFFD}')
    } else {
      out.write_char(ch)
    }
    offset += ch.utf16_len()
  }
  out.to_string()
}

///|
fn Parser::pop_until_html_or_integration_point(self : Parser) -> Unit {
  while self.stack.length() > 1 {
    let current = self.current_node()
    match current.ns {
      Some(ns) if is_foreign_namespace(ns) => {
        if node_is_html_integration_point(current) {
          return
        }
        if self.node_is_foreign_fragment_context(current) {
          return
        }
        ignore(self.stack.pop())
      }
      _ => return
    }
  }
}

///|
fn Parser::handle_foreign_content_start_tag(
  self : Parser,
  name : String,
  attrs : Map[String, String?],
  self_closing : Bool,
  start : Int,
  tag_close_pos : Int,
) -> Bool {
  if !self.current_node_uses_foreign_content_for_start(name) {
    return false
  }
  if foreign_start_breaks_out(name, attrs) {
    self.error_at("unexpected-html-element-in-foreign-content", tag_close_pos)
    self.pop_until_html_or_integration_point()
    return false
  }
  let current = self.current_node()
  let ns = current.ns.unwrap()
  let adjusted_name = adjusted_start_tag_name_for_namespace(ns, name)
  let adjusted_attrs = prepare_foreign_attrs(ns, attrs)
  let node = self.node_with_origin(
    @dom.element(adjusted_name, attrs=adjusted_attrs, ns~),
    start,
  )
  self.current_node().append_child(node)
  if !self_closing {
    self.stack.push(node)
  }
  true
}

///|
fn Parser::handle_foreign_content_end_tag(
  self : Parser,
  name : String,
  start : Int,
) -> Bool {
  let current = self.current_node()
  match current.ns {
    Some(ns) if is_foreign_namespace(ns) => ()
    _ => return false
  }
  if name == "br" || name == "p" {
    self.error_at("unexpected-html-element-in-foreign-content", start)
    self.pop_until_html_or_integration_point()
    return false
  }
  let mut index = self.stack.length()
  let mut first = true
  while index > 0 {
    index -= 1
    let node = self.stack[index]
    if node.kind == Element && names_match_end_tag(node, name) {
      if self.node_is_foreign_fragment_context(node) {
        self.error_at("unexpected-end-tag-in-fragment-context", start)
        return true
      }
      if node_is_html_namespace(node) {
        return false
      }
      while self.stack.length() > index {
        ignore(self.stack.pop())
      }
      return true
    }
    if first {
      self.error_at("unexpected-end-tag", start)
      first = false
    }
    if node_is_html_namespace(node) {
      return false
    }
  }
  true
}

///|
fn Parser::parse_foreign_fragment_context(
  self : Parser,
  context : FragmentContext,
  ns : String,
) -> Unit {
  let name = adjusted_start_tag_name_for_namespace(ns, context.tag_name)
  let wrapper = @dom.element(name, ns~)
  self.fragment_context_foreign = Some(wrapper)
  self.root.append_child(wrapper)
  self.stack.push(wrapper)
  self.parse_all()
  unwrap_fragment_context_element(self.root, wrapper)
  self.fragment_context_foreign = None
}
