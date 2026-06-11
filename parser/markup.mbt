///|
fn Parser::parse_comment(self : Parser) -> Unit {
  let comment_start = self.pos
  self.pos += 4
  let scan = @tok.scan_comment_data(self.input, self.pos)
  for error in scan.errors {
    self.error_at(error.code, error.offset)
  }
  self.pos = scan.end
  if scan.eof {
    self.append_sanitize_escape_source_text(comment_start, self.pos)
  }
  let data = if self.xml_coercion {
    coerce_comment_for_xml(scan.data)
  } else {
    scan.data
  }
  let node = self.comment_at(data, comment_start)
  if self.append_after_body_comment(node) {
    return
  }
  self.current_node().append_child(node)
  self.mark_entered_body_comment(node)
}

///|
fn Parser::parse_bogus_comment(self : Parser, origin_start : Int) -> Unit {
  let data_start = self.pos
  while !self.is_eof() && self.current() != Some('>') {
    ignore(self.advance_char())
  }
  let view = self.input[data_start:self.pos]
  let data = normalize_bogus_comment_data(view)
  let data = if self.xml_coercion { coerce_comment_for_xml(data) } else { data }
  let node = self.comment_at(data, origin_start)
  if !self.append_after_body_comment(node) {
    self.current_node().append_child(node)
    self.mark_entered_body_comment(node)
  }
  if self.current() == Some('>') {
    ignore(self.advance_char())
  }
}

///|
fn Parser::parse_markup_declaration(self : Parser) -> Unit {
  let origin_start = self.pos
  self.pos += 2
  if self.starts_with("[CDATA[") {
    if self.current_node_is_foreign_namespace() {
      self.parse_foreign_cdata_section()
      return
    }
    self.error_at("cdata-in-html-content", self.pos + "[CDATA[".length() - 1)
  } else {
    self.error_at("incorrectly-opened-comment", self.pos - 1)
  }
  self.parse_bogus_comment(origin_start)
  self.append_sanitize_escape_source_text(origin_start, self.pos)
}

///|
fn Parser::parse_foreign_cdata_section(self : Parser) -> Unit {
  self.pos += "[CDATA[".length()
  let start = self.pos
  while !self.is_eof() && !self.starts_with("]]>") {
    ignore(self.advance_char())
  }
  let view = self.input[start:self.pos]
  // Input-stream newline preprocessing happens before any null handling
  // so a NUL between CR and LF does not fabricate a CRLF pair.
  let normalized = normalize_raw_newlines(view)
  let cleaned = if self.current_node_uses_foreign_content_for_text() {
    self.clean_foreign_content_text(normalized, start)
  } else {
    self.remove_null_characters(normalized, start)
  }
  if !cleaned.is_empty() {
    let cleaned = normalize_tree_builder_text(cleaned)
    let data = if self.xml_coercion {
      coerce_text_for_xml(cleaned)
    } else {
      cleaned
    }
    self.current_node().append_child(self.text_at(data, start))
  }
  if self.starts_with("]]>") {
    self.pos += 3
  }
}

///|
fn Parser::parse_doctype(self : Parser) -> Unit {
  let doctype_start = self.pos
  self.pos += "<!doctype".length()
  let missing_before_name = match self.current() {
    Some('>') | None => None
    Some(ch) if ch.is_ascii_whitespace() => {
      self.skip_ascii_whitespace()
      None
    }
    _ => Some(self.pos)
  }
  let name_start = self.pos
  while !self.is_eof() {
    let ch = self.current().unwrap()
    if ch == '>' || ch.is_ascii_whitespace() {
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
  let ids_start = self.pos
  while !self.is_eof() && !self.starts_with(">") {
    ignore(self.advance_char())
  }
  let external = @tok.parse_doctype_external(
    self.input[ids_start:self.pos],
    self.starts_with(">"),
  )
  let public_id = external.public_id
  let system_id = external.system_id
  let has_external_error = !external.errors.is_empty()
  let eof_doctype = name != "" && !has_external_error && !self.starts_with(">")
  let error_pos = if self.starts_with(">") {
    self.pos
  } else {
    self.eof_error_pos()
  }
  let force_quirks = name == "" || external.force_quirks || eof_doctype
  if !self.is_fragment_parser() && document_doctype_is_initial_target(self) {
    self.doctype_quirks_mode = doctype_triggers_quirks(
      name, public_id, system_id, force_quirks,
    )
  }
  match missing_before_name {
    Some(pos) => self.error_at("missing-whitespace-before-doctype-name", pos)
    None => ()
  }
  for error in name_errors {
    self.error_at(error.code, error.offset)
  }
  if name == "" {
    if self.starts_with(">") {
      self.error_at("expected-doctype-name-but-got-right-bracket", error_pos)
    } else {
      self.error_at_eof("eof-in-doctype")
    }
  } else {
    for error in external.errors {
      self.error_at(error.code, ids_start + error.offset)
    }
  }
  if eof_doctype {
    self.error_at_eof("eof-in-doctype")
  }
  if self.starts_with(">") {
    self.pos += 1
  }
  if self.root.kind == Fragment {
    self.error_at("unexpected-doctype", error_pos)
    self.append_sanitize_escape_source_text(doctype_start, self.pos)
    return
  }
  if !self.document_doctype_is_initial() {
    self.error_at("unexpected-doctype", error_pos)
    return
  }
  if !is_known_doctype(name, public_id, system_id) {
    self.error_at("unknown-doctype", error_pos)
  }
  let doctype_node = match (public_id, system_id) {
    (Some(public_id), Some(system_id)) =>
      @dom.doctype(name~, public_id~, system_id~, force_quirks~)
    (Some(public_id), None) => @dom.doctype(name~, public_id~, force_quirks~)
    (None, Some(system_id)) => @dom.doctype(name~, system_id~, force_quirks~)
    (None, None) => @dom.doctype(name~, force_quirks~)
  }
  self.root.append_child(self.node_with_origin(doctype_node, doctype_start))
}

///|
fn is_known_doctype(
  name : StringView,
  public_id : String?,
  system_id : String?,
) -> Bool {
  if name != "html" {
    return false
  }
  match (public_id, system_id) {
    (None, None) => true
    (None, Some("about:legacy-compat")) => true
    (Some("-//W3C//DTD HTML 4.0//EN"), None) => true
    (
      Some("-//W3C//DTD HTML 4.0//EN"),
      Some("http://www.w3.org/TR/REC-html40/strict.dtd"),
    ) => true
    (Some("-//W3C//DTD HTML 4.01//EN"), None) => true
    (
      Some("-//W3C//DTD HTML 4.01//EN"),
      Some("http://www.w3.org/TR/html4/strict.dtd"),
    ) => true
    (
      Some("-//W3C//DTD XHTML 1.0 Strict//EN"),
      Some("http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"),
    ) => true
    (
      Some("-//W3C//DTD XHTML 1.1//EN"),
      Some("http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd"),
    ) => true
    _ => false
  }
}
