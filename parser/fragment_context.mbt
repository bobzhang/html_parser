///|
fn is_fragment_raw_text_context(name : StringView) -> Bool {
  match name {
    "style" | "textarea" | "title" => true
    _ => false
  }
}

///|
fn is_fragment_plain_text_context(name : StringView) -> Bool {
  match name {
    "plaintext" | "script" => true
    _ => false
  }
}

///|
fn Parser::append_fragment_context_text(
  self : Parser,
  raw : StringView,
  start : Int,
) -> Unit {
  if raw.is_empty() {
    return
  }
  let raw = self.replace_null_characters(raw, start)
  let data = normalize_newlines(raw)
  let data = normalize_tree_builder_text(data)
  let data = if self.xml_coercion { coerce_text_for_xml(data) } else { data }
  self.root.append_child(self.text_at(data, start))
}

///|
fn unwrap_fragment_context_element(
  parent : @dom.Node,
  wrapper : @dom.Node,
) -> Unit {
  let original = parent.children.copy()
  parent.children.clear()
  for child in original {
    if physical_equal(child, wrapper) {
      let children = wrapper.children.copy()
      wrapper.children.clear()
      wrapper.parent = None
      for grandchild in children {
        parent.append_child(grandchild)
      }
    } else {
      parent.append_child(child)
    }
  }
}

///|
fn Parser::parse_html_fragment_context(self : Parser) -> Unit {
  let html = @dom.element("html")
  self.fragment_context_html = true
  self.fragment_context_html_root = Some(html)
  self.fragment_context_html_after_body = false
  self.frameset_ok = true
  self.root.append_child(html)
  self.stack.push(html)
  self.parse_all()
  scaffold_existing_html_element(html, self.foster_parented_texts, [])
  unwrap_fragment_context_element(self.root, html)
  self.fragment_context_html_root = None
  self.fragment_context_html_after_body = false
  self.fragment_context_html = false
}

///|
fn Parser::parse_fragment_context(
  self : Parser,
  context : FragmentContext,
) -> Bool {
  let context_ns = match context.ns {
    Some("mathml") => "math"
    Some(ns) => ns
    None => "html"
  }
  if context_ns != "html" {
    if is_foreign_namespace(context_ns) {
      self.parse_foreign_fragment_context(context, context_ns)
      return true
    }
    return false
  }
  let name = context.tag_name
  if is_fragment_plain_text_context(name) {
    self.append_fragment_context_text(self.input[0:self.input.length()], 0)
    self.pos = self.input.length()
    return true
  }
  if is_fragment_raw_text_context(name) {
    match @tok.find_matching_end_tag(self.input, 0, name) {
      Some(end_start) => {
        self.append_fragment_context_text(self.input[0:end_start], 0)
        self.pos = end_start
        self.skip_matching_end_tag()
        self.error_at("unexpected-end-tag", end_start)
        self.parse_all()
      }
      None => {
        self.append_fragment_context_text(self.input[0:self.input.length()], 0)
        self.pos = self.input.length()
      }
    }
    return true
  }
  if name == "html" {
    self.parse_html_fragment_context()
    return true
  }
  if name == "table" {
    self.parse_table_fragment_context()
    return true
  }
  if is_fragment_table_section_context(name) {
    self.parse_table_section_fragment_context(name)
    return true
  }
  if name == "tr" {
    self.parse_table_row_fragment_context()
    return true
  }
  if name == "td" || name == "th" {
    self.parse_table_cell_fragment_context(name)
    return true
  }
  if name == "caption" {
    self.fragment_context_caption = true
    self.parse_all()
    self.fragment_context_caption = false
    return true
  }
  if name == "colgroup" {
    self.fragment_context_colgroup = true
    self.parse_all()
    self.fragment_context_colgroup = false
    return true
  }
  false
}
