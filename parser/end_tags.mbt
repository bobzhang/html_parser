///|
fn Parser::parse_end_tag(self : Parser) -> Unit {
  let start = self.pos
  self.pos += 2
  match self.current() {
    Some('>') => {
      self.error_at("empty-end-tag", self.pos)
      ignore(self.advance_char())
      self.append_sanitize_escape_source_text(start, self.pos)
      return
    }
    Some(ch) if !@tok.is_tag_name_start(ch) => {
      self.error_at("invalid-first-character-of-tag-name", self.pos)
      self.parse_bogus_comment(start)
      self.append_sanitize_escape_source_text(start, self.pos)
      return
    }
    None => {
      self.error_at_eof("eof-before-tag-name")
      self.current_node().append_child(self.text_at("</", start))
      return
    }
    _ => ()
  }
  let name_start = self.pos
  while !self.is_eof() {
    let ch = self.current().unwrap()
    if ch == '>' || ch == '/' || ch.is_ascii_whitespace() {
      break
    } else {
      ignore(self.advance_char())
    }
  }
  let (name, name_errors) = @tok.parse_lower_name_value_replacing_nulls(
    self.input,
    name_start,
    self.pos,
  )
  for error in name_errors {
    self.error_at(error.code, error.offset)
  }
  let attrs : Map[String, String?] = {}
  let mut noncanonical_end_tag = false
  let mut closed = false
  while !self.is_eof() {
    self.skip_ascii_whitespace()
    let ch = self.current().unwrap()
    match ch {
      '>' => {
        ignore(self.advance_char())
        closed = true
        break
      }
      '/' => {
        ignore(self.advance_char())
        noncanonical_end_tag = true
        if self.current() == Some('>') {
          ignore(self.advance_char())
          closed = true
          break
        } else {
          self.error_at("unexpected-character-after-solidus-in-tag", self.pos)
        }
      }
      _ => {
        noncanonical_end_tag = true
        self.parse_attribute(attrs)
      }
    }
  }
  if !closed {
    self.error_at_eof("eof-in-tag")
    if noncanonical_end_tag || name == "" {
      self.append_sanitize_escape_source_text(start, self.pos)
    }
    return
  }
  let tag_close_pos = self.pos - 1
  if noncanonical_end_tag {
    self.append_sanitize_escape_source_text(start, self.pos)
  }
  self.flush_deferred_initial_doctype_error()
  if self.handle_before_html_end_tag(name, start, self.pos - 1) {
    return
  }
  if self.handle_foreign_content_end_tag(name, start) {
    return
  }
  if self.handle_document_frameset_end_tag(name, tag_close_pos) {
    return
  }
  if self.handle_template_detached_column_group_end_tag(name, start) {
    return
  }
  if self.handle_template_column_group_end_tag(name, start) {
    return
  }
  if self.handle_fragment_context_colgroup_end_tag(name, start) {
    return
  }
  if self.handle_fragment_context_table_wrapper_end_tag(name, start) {
    return
  }
  if self.handle_foster_parented_end_tag(name, start) {
    return
  }
  if self.handle_disabled_head_noscript_end_tag(name, start) {
    return
  }
  if self.handle_duplicate_head_end_tag(name, start) {
    return
  }
  self.close_current_column_group_for_end(name)
  if self.handle_caption_end_tag(name, start) {
    return
  }
  if self.handle_fragment_context_table_end_tag(name, start) {
    return
  }
  if self.handle_table_context_ignored_end_tag(name, start) {
    return
  }
  if self.handle_template_table_context_end_tag(name, start) {
    return
  }
  if self.handle_table_structural_end_tag(name) {
    return
  }
  if self.handle_table_end_tag(name, tag_close_pos) {
    return
  }
  if name == "br" && self.in_table_body_mode_context() {
    self.error_at("unexpected-end-tag", start)
    self.report_table_context_end_tag_voodoo(name, tag_close_pos)
    self.close_open_p_element()
    self.insert_body_mode_node(self.node_with_origin(@dom.element("br"), start))
    return
  }
  self.report_table_context_end_tag_voodoo(name, start)
  if name == "br" {
    self.error_at("unexpected-end-tag", tag_close_pos)
    self.close_open_p_element()
    self.insert_body_mode_node(self.node_with_origin(@dom.element("br"), start))
    return
  }
  if self.handle_select_end_tag(name, tag_close_pos) {
    return
  }
  if active_formatting_element_name(name) {
    self.adoption_agency(name, tag_close_pos)
    return
  }
  if name == "p" {
    if !self.close_open_element("p") {
      self.error_at("unexpected-end-tag", tag_close_pos)
      self.insert_body_mode_node(
        self.node_with_origin(@dom.element("p"), start),
      )
    }
    return
  }
  if is_heading_element_name(name) {
    self.close_open_heading_element(name, start)
    return
  }
  if name == "form" {
    self.report_form_end_tag_table_voodoo(name, start)
    self.handle_form_end_tag(start)
    return
  }
  if self.handle_applet_like_end_tag(name, tag_close_pos) {
    return
  }
  if self.handle_template_end_tag(
      name,
      tag_close_pos,
      source_end_tag=self.source_tag_slice(start, tag_close_pos),
    ) {
    return
  }
  if self.fragment_end_tag_is_ignored(name) {
    return
  }
  if name == "ruby" {
    self.close_ruby_end_tag(start)
    return
  }
  if self.handle_document_after_body_html_end_tag(name, start) {
    return
  }
  if self.handle_document_body_or_html_end_tag(name, tag_close_pos) {
    return
  }
  if name != "" {
    self.pop_until(
      name,
      tag_close_pos,
      source_end_tag=self.source_tag_slice(start, tag_close_pos),
    )
  }
}

///|
fn is_special_element_for_any_other_end_tag(name : StringView) -> Bool {
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
fn Parser::close_ruby_end_tag(self : Parser, start : Int) -> Unit {
  let mut index = self.stack.length()
  while index > 1 {
    index -= 1
    let node = self.stack[index]
    if node.kind == Element && node.name == "ruby" {
      if index != self.stack.length() - 1 {
        self.error_at("end-tag-too-early", start)
      }
      while self.stack.length() > index {
        ignore(self.stack.pop())
      }
      return
    }
    if node.kind == Element &&
      is_special_element_for_any_other_end_tag(node.name) {
      self.error_at("unexpected-end-tag", start)
      return
    }
  }
  self.error_at("unexpected-end-tag", start)
}

///|
fn Parser::handle_form_end_tag(self : Parser, start : Int) -> Unit {
  match self.form_element {
    Some(node) => {
      let removed = self.remove_open_node(node)
      self.form_element = None
      if !removed {
        self.error_at("unexpected-end-tag", start)
      }
    }
    None => self.error_at("unexpected-end-tag", start)
  }
}
