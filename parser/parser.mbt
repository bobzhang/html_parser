///|
fn Parser::handle_template_end_tag(
  self : Parser,
  name : String,
  error_pos : Int,
  source_end_tag? : String,
) -> Bool {
  if name != "template" {
    return false
  }
  let template_index = self.last_open_template_index()
  if template_index < 0 {
    self.error_at("unexpected-end-tag", error_pos)
    return true
  }
  let template = self.stack[template_index]
  match source_end_tag {
    Some(raw) => set_node_source_end_tag(template, raw)
    None => ()
  }
  self.disable_template_column_group_mode_for_node(template)
  self.disable_template_table_context_mode_for_node(template)
  self.template_detached_column_group_mode = false
  while self.stack.length() > template_index {
    ignore(self.stack.pop())
  }
  self.clear_active_formatting_to_marker()
  true
}

///|
fn Parser::parse_all(self : Parser) -> Unit {
  while !self.is_eof() {
    let start = self.pos
    if self.current().unwrap() == '<' {
      if self.starts_with("<!--") {
        self.parse_comment()
      } else if self.starts_with("</") {
        self.parse_end_tag()
      } else if starts_with_case_insensitive(self.input, self.pos, "<!doctype") {
        self.parse_doctype()
      } else if self.starts_with("<!") {
        self.parse_markup_declaration()
      } else {
        self.parse_start_tag_or_text()
      }
    } else {
      while !self.is_eof() && !self.starts_with("<") {
        self.report_current_noncharacter()
        ignore(self.advance_char())
      }
      let view = self.input[start:self.pos]
      self.flush_deferred_initial_doctype_error()
      self.append_text(view, start)
    }
  }
}

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
fn Parser::open_html_element(self : Parser) -> @dom.Node? {
  for node in self.stack {
    if node.kind == Element && node.name == "html" {
      return Some(node)
    }
  }
  document_html_element(self.root)
}

///|
fn Parser::stack_contains_node(self : Parser, target : @dom.Node) -> Bool {
  for node in self.stack {
    if physical_equal(node, target) {
      return true
    }
  }
  false
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
fn Parser::remove_open_node(self : Parser, target : @dom.Node) -> Bool {
  let mut index = 0
  while index < self.stack.length() {
    if physical_equal(self.stack[index], target) {
      ignore(self.stack.remove(index))
      return true
    }
    index += 1
  }
  false
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

///|
fn Parser::has_foreign_table_cell_on_stack(self : Parser) -> Bool {
  for node in self.stack {
    if node.kind == Element &&
      (node.name == "td" || node.name == "th") &&
      !(node.ns is Some("html")) {
      return true
    }
  }
  false
}

///|
fn Parser::has_foreign_table_row_on_stack(self : Parser) -> Bool {
  for node in self.stack {
    if node.kind == Element && node.name == "tr" && !(node.ns is Some("html")) {
      return true
    }
  }
  false
}

///|
fn Parser::clear_open_elements_to_root(self : Parser) -> Unit {
  while self.stack.length() > 1 {
    ignore(self.stack.pop())
  }
}

///|
fn Parser::handle_select_reprocessed_foreign_cell_start_tag(
  self : Parser,
  name : String,
  attrs : Map[String, String?],
  start : Int,
  self_closing : Bool,
) -> Bool {
  if name != "td" && name != "th" {
    return false
  }
  if self.has_open_element("table") || !self.has_foreign_table_cell_on_stack() {
    return false
  }
  self.clear_open_elements_to_root()
  let node = self.node_with_origin(@dom.element(name, attrs~), start)
  self.post_body_html_children.push(node)
  if !self_closing {
    self.stack.push(node)
  }
  true
}

///|
fn Parser::handle_recovered_post_body_cell_start_tag(
  self : Parser,
  name : String,
  attrs : Map[String, String?],
  start : Int,
  self_closing : Bool,
) -> Bool {
  if name != "td" && name != "th" {
    return false
  }
  if self.has_open_element("table") ||
    (!self.has_open_element("td") && !self.has_open_element("th")) {
    return false
  }
  self.close_open_table_cell()
  let node = self.node_with_origin(@dom.element(name, attrs~), start)
  self.post_body_html_children.push(node)
  if !self_closing {
    self.stack.push(node)
  }
  true
}

///|
fn Parser::handle_foreign_table_row_recovery_start_tag(
  self : Parser,
  name : String,
  attrs : Map[String, String?],
  start : Int,
  self_closing : Bool,
) -> Bool {
  if name != "tr" {
    return false
  }
  if self.has_open_element("table") || !self.has_foreign_table_row_on_stack() {
    return false
  }
  self.clear_open_elements_to_root()
  let node = self.node_with_origin(@dom.element("tr", attrs~), start)
  self.post_body_html_children.push(node)
  self.foreign_table_row_recovery_mode = !self_closing
  if !self_closing {
    self.stack.push(node)
  }
  true
}

///|
fn Parser::report_foreign_table_row_recovery_text(
  self : Parser,
  value : StringView,
  start : Int,
) -> Unit {
  if !self.foreign_table_row_recovery_mode ||
    !text_has_non_ascii_whitespace(value) {
    return
  }
  let current = self.current_node()
  if current.kind != Element || current.name != "tr" {
    return
  }
  let whitespace = leading_ascii_whitespace(value)
  self.error_at(
    "unexpected-character-implies-table-voodoo",
    start + whitespace.length(),
  )
}

///|
fn select_start_tag_reprocesses_in_body(name : StringView) -> Bool {
  match name {
    "caption"
    | "col"
    | "colgroup"
    | "input"
    | "table"
    | "tbody"
    | "td"
    | "textarea"
    | "tfoot"
    | "th"
    | "thead"
    | "tr" => true
    _ => false
  }
}

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
  } else if self.has_open_element("th") {
    ignore(self.close_open_element("th"))
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
    | "main"
    | "menu"
    | "nav"
    | "ol"
    | "p"
    | "plaintext"
    | "pre"
    | "search"
    | "section"
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
  name == "keygen" || (name == "frame" && self.is_fragment_parser())
}

///|
fn Parser::parse_start_tag_or_text(self : Parser) -> Unit {
  let start = self.pos
  self.pos += 1
  match self.current() {
    Some(ch) if @tok.is_tag_name_start(ch) => {
      let name_start = self.pos
      while !self.is_eof() {
        match self.current() {
          Some(ch) if !@tok.is_tag_name_end(ch) => ignore(self.advance_char())
          _ => break
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
      let mut self_closing = false
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
            if self.current() == Some('>') {
              ignore(self.advance_char())
              self_closing = true
              closed = true
              break
            } else {
              self.error_at(
                "unexpected-character-after-solidus-in-tag",
                self.pos,
              )
            }
          }
          _ => self.parse_attribute(attrs)
        }
      }
      if !closed {
        self.error_at_eof("eof-in-tag")
        self.append_sanitize_escape_source_text(start, self.pos)
        return
      }
      let tag_close_pos = self.pos - 1
      self.flush_deferred_initial_doctype_error()
      self.before_html_phase = false
      if self.handle_foreign_content_start_tag(
          name, attrs, self_closing, start, tag_close_pos,
        ) {
        return
      }
      if self.handle_fragment_shell_start_tag(name, attrs, start) {
        return
      }
      if self.handle_disabled_head_noscript_start_tag(name, start) {
        return
      }
      if self.close_current_document_head_for_start(name, start) {
        return
      }
      if self.handle_late_document_head_start_tag(name, start) {
        return
      }
      if self.in_select_insertion_mode() && name == "frame" {
        self.error_at("unexpected-start-tag-in-select", start)
        return
      }
      if self.handle_select_special_start_tag(
          name, attrs, self_closing, start, tag_close_pos,
        ) {
        return
      }
      if self.handle_document_frameset_start_tag(
          name, attrs, self_closing, start, tag_close_pos,
        ) {
        return
      }
      if self.handle_repeated_document_html_start_tag(name, attrs, start) {
        return
      }
      self.report_body_start_after_repeated_document_html(name, start)
      if !self.is_fragment_parser() && name == "frame" {
        self.error_at("unexpected-start-tag-ignored", start)
        return
      }
      if self.handle_template_table_context_start_tag(name, attrs, start) {
        return
      }
      self.report_template_table_context_fostered_start(name, start)
      self.clear_detached_template_table_context_for_template_start(name)
      let in_template_table_context = self.in_template_content_without_inner_table()
      if name == "col" && in_template_table_context {
        let current = self.current_node()
        if current.kind == Element && current.name == "template" {
          self.enable_template_column_group_mode()
        }
      }
      if self.handle_template_column_group_start_tag(name, attrs, start) {
        return
      }
      if self.handle_fragment_context_colgroup_start_tag(name, attrs, start) {
        return
      }
      if self.in_select_insertion_mode() &&
        select_start_tag_reprocesses_in_body(name) {
        self.error_at("unexpected-start-tag-in-select", start)
        ignore(self.close_open_element("select"))
        self.reset_select_insertion_mode()
        if self.handle_select_reprocessed_foreign_cell_start_tag(
            name, attrs, start, self_closing,
          ) {
          return
        }
      }
      if self.handle_foreign_table_row_recovery_start_tag(
          name, attrs, start, self_closing,
        ) {
        return
      }
      if self.handle_recovered_post_body_cell_start_tag(
          name, attrs, start, self_closing,
        ) {
        return
      }
      if self.handle_fragment_context_caption_start_tag(name, start) {
        return
      }
      if !self.has_open_element("table") &&
        !in_template_table_context &&
        name == "caption" {
        self.error_at("unexpected-start-tag", start)
        return
      }
      if !self.has_open_element("table") &&
        !in_template_table_context &&
        table_start_tag_is_ignored_outside_table(name) {
        self.error_at("unexpected-start-tag-ignored", start)
        return
      }
      if self.col_start_tag_is_ignored_outside_table(name) {
        self.error_at("unexpected-start-tag-ignored", start)
        return
      }
      if self.close_current_caption_for_start(name, tag_close_pos) &&
        self.handle_template_table_context_start_tag(name, attrs, start) {
        return
      }
      self.close_current_column_group_for_start(name, start)
      if self.handle_table_context_hidden_input_or_form_start(
          name, attrs, start, tag_close_pos,
        ) {
        return
      }
      if self.handle_fragment_context_table_cell_start_tag(name, start) {
        return
      }
      if self.handle_fragment_context_table_row_start_tag(name, start) {
        return
      }
      if self.handle_fragment_context_table_section_start_tag(name, start) {
        return
      }
      let closed_table_cell = self.close_current_table_cell_for_start(name)
      self.close_current_table_row_for_start(name)
      self.close_current_table_section_for_start(name)
      self.clear_stack_to_table_context_for_start(name)
      if self.handle_fragment_context_table_start_tag(name, start) {
        return
      }
      ignore(self.handle_nested_table_start_tag(name, tag_close_pos))
      if !closed_table_cell {
        self.report_unexpected_table_body_cell_start(name, tag_close_pos)
      }
      if name == "form" && self.form_element is Some(_) {
        self.error_at("unexpected-start-tag", start)
        return
      }
      if name == "rp" || name == "rt" {
        self.generate_implied_end_tags(Some("rtc"))
      } else if (name == "rb" || name == "rtc") &&
        current_node_is_ruby_annotation(self.current_node()) {
        self.generate_implied_end_tags(None)
      }
      if start_tag_closes_p(name) {
        self.close_open_p_element()
      }
      if name == "button" && self.has_open_element_in_default_scope("button") {
        self.error_at("unexpected-start-tag-implies-end-tag", start)
        ignore(self.close_open_element("button"))
      }
      if name == "select" && self.in_select_insertion_mode() {
        self.error_at("unexpected-select-in-select", start)
        ignore(self.close_open_element("select"))
        self.reset_select_insertion_mode()
        return
      }
      if name == "li" {
        self.close_open_list_item()
      } else if name == "dd" || name == "dt" {
        self.close_open_definition_item(name)
      } else if name == "option" || name == "optgroup" {
        self.close_open_select_item(name)
      } else if name == "td" || name == "th" {
        self.close_open_table_cell()
      }
      if is_heading_element_name(name) {
        self.close_current_heading_element()
      }
      if !self.document_start_tag_preserves_frameset_ok(name, attrs) {
        self.frameset_ok = false
      }
      let node_ns = self.start_tag_namespace(name)
      if node_ns == "html" {
        self.prepare_active_formatting_start(name, start)
      }
      if !start_tag_closes_p(name) &&
        !self.table_context_start_skips_active_reconstruction(name) {
        self.reconstruct_active_formatting_elements()
      }
      let adjusted_name = if node_ns == "html" {
        if name == "image" {
          self.error_at("image-start-tag", start)
          "img"
        } else {
          name
        }
      } else {
        adjusted_start_tag_name_for_namespace(node_ns, name)
      }
      let adjusted_attrs = if node_ns == "html" {
        attrs
      } else {
        prepare_foreign_attrs(node_ns, attrs)
      }
      let node = self.node_with_start_tag_source(
        @dom.element(adjusted_name, attrs=adjusted_attrs, ns=node_ns),
        start,
        tag_close_pos,
      )
      if adjusted_name == "form" {
        self.form_element = Some(node)
      }
      self.append_start_tag_node(node, adjusted_name, start)
      if node_ns == "html" && adjusted_name == "select" {
        self.select_insertion_mode = true
      }
      let self_closes_tree = if node_ns == "html" {
        self_closing && @ser.is_void_element(adjusted_name)
      } else {
        self_closing
      }
      let inserts_empty_nonvoid = self.start_tag_inserts_empty_nonvoid(
        adjusted_name,
      )
      if node_ns == "html" &&
        !self_closes_tree &&
        self.is_special_text_element(adjusted_name) {
        self.consume_special_element_content(node, adjusted_name)
      } else if !self_closes_tree &&
        !@ser.is_void_element(adjusted_name) &&
        !inserts_empty_nonvoid {
        self.stack.push(node)
        if node_ns == "html" && active_formatting_element_name(adjusted_name) {
          let duplicate_index = self.active_formatting_duplicate_index(
            adjusted_name,
            node.attrs,
          )
          if duplicate_index >= 0 {
            self.remove_active_formatting_index(duplicate_index)
          }
          self.append_active_formatting_entry(node)
        }
        if node_ns == "html" &&
          active_formatting_marker_element_name(adjusted_name) {
          self.push_active_formatting_marker()
        }
        if node_ns == "html" && start_tag_ignores_initial_lf(adjusted_name) {
          self.skip_one_initial_lf()
        }
      }
    }
    _ =>
      if self.current() is None {
        self.error_at_eof("eof-before-tag-name")
        self.flush_deferred_initial_doctype_error()
        self.current_node().append_child(self.text_at("<", start))
      } else if self.current() == Some('?') {
        self.error_at("unexpected-question-mark-instead-of-tag-name", self.pos)
        self.parse_bogus_comment(start)
        self.append_sanitize_escape_source_text(start, self.pos)
      } else {
        self.report_current_noncharacter()
        self.parse_invalid_tag_open_as_text(start)
      }
  }
}

///|
fn Parser::parse_invalid_tag_open_as_text(self : Parser, start : Int) -> Unit {
  self.error_at("invalid-first-character-of-tag-name", self.pos)
  while !self.is_eof() && !self.starts_with("<") {
    self.report_current_noncharacter()
    ignore(self.advance_char())
  }
  let view = self.input[start:self.pos]
  self.flush_deferred_initial_doctype_error()
  self.append_text(view, start)
}

///|
fn Parser::parse_attribute(self : Parser, attrs : Map[String, String?]) -> Unit {
  let name_start = self.pos
  if self.current() == Some('=') {
    self.error_at("unexpected-equals-sign-before-attribute-name", self.pos)
    ignore(self.advance_char())
  }
  while !self.is_eof() {
    let ch = self.current().unwrap()
    if ch.is_ascii_whitespace() || ch == '=' || ch == '/' || ch == '>' {
      break
    } else {
      match ch {
        '<' | '"' | '\'' => {
          self.error_at("unexpected-character-in-attribute-name", self.pos)
          ignore(self.advance_char())
        }
        _ => ignore(self.advance_char())
      }
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
  if name == "" {
    ignore(self.advance_char())
    return
  }
  let duplicate = attrs.contains(name)
  if duplicate {
    self.error_at("duplicate-attribute", name_start)
  }
  self.skip_ascii_whitespace()
  if self.current() != Some('=') {
    if !duplicate {
      attrs[name] = None
    }
    return
  }
  ignore(self.advance_char())
  self.skip_ascii_whitespace()
  let missing_value = self.current() == Some('>')
  if missing_value {
    self.error_at("missing-attribute-value", self.pos)
  }
  let value = match self.current() {
    Some('"') => self.parse_quoted_attribute_value('"')
    Some('\'') => self.parse_quoted_attribute_value('\'')
    _ => {
      let start = self.pos
      while !self.is_eof() {
        let ch = self.current().unwrap()
        if ch.is_ascii_whitespace() || ch == '>' {
          break
        }
        match ch {
          '\u{0000}' => {
            self.error_at("unexpected-null-character", self.pos)
            ignore(self.advance_char())
          }
          '"' | '\'' | '<' | '=' | '`' => {
            self.error_at(
              "unexpected-character-in-unquoted-attribute-value",
              self.pos,
            )
            ignore(self.advance_char())
          }
          _ => ignore(self.advance_char())
        }
      }
      let view = self.input[start:self.pos]
      let decoded = @tok.decode_attribute_value_with_errors(view)
      for error in decoded.errors {
        self.error_at(error.code, self.pos)
      }
      decoded.data
    }
  }
  if !duplicate {
    attrs[name] = if missing_value { None } else { Some(value) }
  }
}

///|
fn Parser::parse_quoted_attribute_value(self : Parser, quote : Char) -> String {
  ignore(self.advance_char())
  let start = self.pos
  while !self.is_eof() && self.current() != Some(quote) {
    if self.current() == Some('\u{0000}') {
      self.error_at("unexpected-null-character", self.pos)
    }
    ignore(self.advance_char())
  }
  let raw = self.input[start:self.pos]
  if self.current() == Some(quote) {
    ignore(self.advance_char())
    match self.current() {
      Some(ch) if !ch.is_ascii_whitespace() && ch != '>' && ch != '/' =>
        self.error_at("missing-whitespace-between-attributes", self.pos)
      _ => ()
    }
  }
  let decoded = @tok.decode_attribute_value_with_errors(raw)
  for error in decoded.errors {
    self.error_at(error.code, self.pos)
  }
  decoded.data
}
