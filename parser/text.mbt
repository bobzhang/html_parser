///|
fn Parser::append_text(self : Parser, raw : StringView, start : Int) -> Unit {
  if raw.is_empty() {
    return
  }
  let mut text_start = start
  let mut cleaned = if self.current_node_uses_foreign_content_for_text() {
    self.clean_foreign_content_text(raw, start)
  } else {
    self.remove_null_characters(raw, start)
  }
  cleaned = normalize_tree_builder_text(cleaned)
  if cleaned.is_empty() {
    return
  }
  if text_has_non_ascii_whitespace(cleaned) {
    self.before_html_phase = false
  }
  if self.current_is_disabled_head_noscript() &&
    text_has_non_ascii_whitespace(cleaned) {
    let whitespace = leading_ascii_whitespace(cleaned)
    self.error_at("unexpected-start-tag", start + whitespace.length())
    ignore(self.stack.pop())
    if !whitespace.is_empty() {
      let data = if self.xml_coercion {
        coerce_text_for_xml(whitespace)
      } else {
        whitespace
      }
      self.current_node().append_child(self.text_at(data, start))
    }
    if self.current_is_document_head() {
      ignore(self.stack.pop())
    }
    cleaned = cleaned[whitespace.length():].to_owned()
    text_start += whitespace.length()
  }
  if self.current_is_document_head() && text_has_non_ascii_whitespace(cleaned) {
    let whitespace = leading_ascii_whitespace(cleaned)
    if !whitespace.is_empty() {
      let data = if self.xml_coercion {
        coerce_text_for_xml(whitespace)
      } else {
        whitespace
      }
      self.current_node().append_child(self.text_at(data, text_start))
    }
    ignore(self.stack.pop())
    cleaned = cleaned[whitespace.length():].to_owned()
    text_start += whitespace.length()
  }
  if self.uses_document_frameset_rules() &&
    !self.frameset_reprocesses_in_body_mode &&
    (
      self.after_frameset ||
      self.detached_frameset_mode ||
      self.has_open_element("frameset")
    ) {
    let whitespace = ascii_whitespace_chars_only(cleaned)
    if self.after_frameset && whitespace.length() != cleaned.length() {
      self.error_at("unexpected-token-after-frameset", start + raw.length() - 1)
    }
    if !whitespace.is_empty() {
      self.current_node().append_child(self.text_at(whitespace, text_start))
    }
    return
  }
  if self.uses_document_frameset_rules() &&
    text_has_non_ascii_whitespace(cleaned) {
    self.frameset_ok = false
  }
  if self.handle_template_column_group_text(cleaned, text_start) {
    return
  }
  if self.handle_fragment_context_colgroup_text(cleaned, text_start) {
    return
  }
  if self.handle_column_group_text(cleaned, text_start) {
    return
  }
  self.report_foreign_table_row_recovery_text(cleaned, text_start)
  if self.foster_parent_table_text(cleaned, text_start) {
    return
  }
  if self.foster_parent_template_table_text(cleaned, text_start) {
    return
  }
  if self.template_table_context_mode_active() &&
    text_has_non_ascii_whitespace(cleaned) {
    ignore(self.report_foster_parenting_character_errors(cleaned, text_start))
  }
  self.report_foster_parented_table_context_text(cleaned, text_start)
  let decoded_result = @tok.decode_entities_with_errors(
    cleaned,
    in_attribute=false,
  )
  for error in decoded_result.errors {
    self.error_at(error.code, text_start + error.offset)
  }
  let decoded = normalize_tree_builder_text(decoded_result.data)
  let data = if self.xml_coercion {
    coerce_text_for_xml(decoded)
  } else {
    decoded
  }
  self.reconstruct_active_formatting_elements()
  self.current_node().append_child(self.text_at(data, text_start))
}

///|
fn Parser::insert_body_mode_node(self : Parser, node : @dom.Node) -> Unit {
  let table_index = self.table_context_without_cell_or_caption()
  if table_index >= 0 {
    let current = self.current_node()
    if current.kind == Element && is_table_start_foster_target(current.name) {
      if self.table_index_is_fragment_context_table(table_index) {
        current.append_child(node)
        return
      }
      self.insert_node_before_open_table(node, table_index)
      return
    }
  }
  self.current_node().append_child(node)
}

///|
fn text_has_non_ascii_whitespace(value : StringView) -> Bool {
  for ch in value {
    if !ch.is_ascii_whitespace() {
      return true
    }
  }
  false
}

///|
fn ascii_whitespace_chars_only(value : StringView) -> String {
  let out = StringBuilder::new(size_hint=value.length())
  for ch in value {
    if ch.is_ascii_whitespace() {
      out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn normalize_tree_builder_text(value : StringView) -> String {
  if !text_contains_char(value, '\u{000C}') {
    return value.to_owned()
  }
  let out = StringBuilder::new(size_hint=value.length())
  for ch in value {
    if ch == '\u{000C}' {
      out.write_char(' ')
    } else {
      out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn decode_entities_for_tree_text(value : StringView) -> String {
  let decoded = @tok.decode_entities(value, in_attribute=false)
  normalize_tree_builder_text(decoded)
}

///|
fn Parser::remove_null_characters(
  self : Parser,
  raw : StringView,
  start : Int,
) -> String {
  if !text_contains_char(raw, '\u{0000}') {
    return raw.to_owned()
  }
  let out = StringBuilder::new(size_hint=raw.length())
  let mut pos = 0
  while pos < raw.length() {
    let ch = raw.get_char(pos).unwrap()
    match ch {
      '\u{0000}' => {
        self.error_at("unexpected-null-character", start + pos)
        pos += 1
      }
      _ => {
        out.write_char(ch)
        pos += ch.utf16_len()
      }
    }
  }
  out.to_string()
}

///|
fn Parser::replace_null_characters(
  self : Parser,
  raw : StringView,
  start : Int,
) -> String {
  if !text_contains_char(raw, '\u{0000}') {
    return raw.to_owned()
  }
  let out = StringBuilder::new(size_hint=raw.length())
  let mut pos = 0
  while pos < raw.length() {
    let ch = raw.get_char(pos).unwrap()
    match ch {
      '\u{0000}' => {
        self.error_at("unexpected-null-character", start + pos)
        out.write_char('\u{FFFD}')
        pos += 1
      }
      _ => {
        out.write_char(ch)
        pos += ch.utf16_len()
      }
    }
  }
  out.to_string()
}

///|
fn text_contains_char(value : StringView, target : Char) -> Bool {
  let mut pos = 0
  while pos < value.length() {
    let ch = value.get_char(pos).unwrap()
    if ch == target {
      return true
    }
    pos += ch.utf16_len()
  }
  false
}
