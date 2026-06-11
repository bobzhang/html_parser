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
  let parent = self.current_node()
  if self.merge_into_trailing_text(parent, data) {
    return
  }
  let text_node = self.text_at(data, text_start)
  parent.append_child(text_node)
  self.mark_forced_body_node(text_node)
}

///|
/// Appends character data to an existing trailing text node, mirroring the
/// spec's "insert the characters into that text node" step. Keeps the
/// original node's source origin and never touches sanitizer escape text.
fn Parser::merge_into_trailing_text(
  self : Parser,
  parent : @dom.Node,
  data : String,
) -> Bool {
  match parent.children.last() {
    Some(last) if last.kind == Text &&
      !last.sanitize_escape_only &&
      !self.merge_crosses_body_boundary(parent, last, data) => {
      match self.pending_text_node {
        Some(pending) if physical_equal(pending, last) => ()
        _ => {
          // Start (or restart) a batch on this node. The tree keeps the
          // node with its current data; the builder accumulates the full
          // text and flush_pending_text materializes it once, keeping
          // merges amortized O(n) instead of O(n^2).
          self.flush_pending_text()
          self.pending_text_node = Some(last)
          self.pending_text_builder = StringBuilder()
          self.pending_text_builder.write_string(last.data)
          self.pending_text_is_whitespace = is_whitespace_text_node(last)
        }
      }
      self.pending_text_builder.write_string(data)
      if self.pending_text_is_whitespace && text_has_non_ascii_whitespace(data) {
        self.pending_text_is_whitespace = false
      }
      // Non-whitespace data is the after-body "anything else" case even
      // when it merges into an existing forced text node: the mode
      // switches back to in-body, so later comments insert normally.
      if self.document_after_body &&
        !self.is_fragment_parser() &&
        !self.in_frameset_document() &&
        text_has_non_ascii_whitespace(data) {
        self.document_entered_body = true
        self.document_after_body = false
        self.document_after_html = false
      }
      true
    }
    _ => false
  }
}

///|
/// Materializes a batched trailing text node: replaces the stale node with
/// one carrying the accumulated data, preserving its position, origin, and
/// scaffolder markers. Runs at the end of parsing and whenever a batch
/// moves to a different node.
fn Parser::flush_pending_text(self : Parser) -> Unit {
  let node = match self.pending_text_node {
    Some(node) => node
    None => return
  }
  self.pending_text_node = None
  let full = self.pending_text_builder.to_string()
  if full.length() == node.data.length() {
    return
  }
  let merged = @dom.text(full)
  merged.parsed_from_source = node.parsed_from_source
  merged.origin_offset = node.origin_offset
  merged.origin_line = node.origin_line
  merged.origin_col = node.origin_col
  match node.parent {
    Some(parent) => {
      let mut index = parent.children.length()
      while index > 0 {
        index -= 1
        if physical_equal(parent.children[index], node) {
          parent.children[index] = merged
          merged.parent = Some(parent)
          node.parent = None
          break
        }
      }
    }
    None => ()
  }
  if self.remove_forced_body_node(node) {
    self.forced_body_nodes.push(merged)
  }
  if self.remove_foster_parented_text(node) {
    self.foster_parented_texts.push(merged)
  }
}

///|
/// True when appending would merge body text into a top-level
/// whitespace-only run that the scaffolder must keep between the head and
/// the body (for example `<head></head> </i>X` keeps the space at the
/// html level and files only `X` into the body). Whitespace merges into
/// whitespace, non-whitespace text was already body content (X</body>X
/// yields "XX"), and runs already marked as body content always accept
/// more data.
fn Parser::merge_crosses_body_boundary(
  self : Parser,
  parent : @dom.Node,
  last : @dom.Node,
  data : String,
) -> Bool {
  // The html fragment context scaffolds head/body like a document, so the
  // boundary applies there too; other fragment contexts have no head/body
  // split.
  if self.is_fragment_parser() && !self.fragment_context_html {
    return false
  }
  if !(parent.kind == Document ||
    (parent.kind == Element && parent.name == "html")) {
    return false
  }
  if !self.trailing_text_is_whitespace(last) || self.node_is_forced_body(last) {
    return false
  }
  // After the body has closed, even whitespace belongs to the body (the
  // in-body rules reprocess it), so it must not merge into an unmarked
  // pre-body run either.
  text_has_non_ascii_whitespace(data) || self.document_after_body
}

///|
/// Whitespace check that accounts for batched data not yet materialized
/// into the tree node.
fn Parser::trailing_text_is_whitespace(self : Parser, node : @dom.Node) -> Bool {
  match self.pending_text_node {
    Some(pending) if physical_equal(pending, node) =>
      self.pending_text_is_whitespace
    _ => is_whitespace_text_node(node)
  }
}

///|
fn Parser::node_is_forced_body(self : Parser, node : @dom.Node) -> Bool {
  for candidate in self.forced_body_nodes {
    if physical_equal(candidate, node) {
      return true
    }
  }
  false
}

///|
fn Parser::remove_forced_body_node(self : Parser, node : @dom.Node) -> Bool {
  let mut index = 0
  while index < self.forced_body_nodes.length() {
    if physical_equal(self.forced_body_nodes[index], node) {
      ignore(self.forced_body_nodes.remove(index))
      return true
    }
    index += 1
  }
  false
}

///|
fn Parser::remove_foster_parented_text(self : Parser, node : @dom.Node) -> Bool {
  let mut index = 0
  while index < self.foster_parented_texts.length() {
    if physical_equal(self.foster_parented_texts[index], node) {
      ignore(self.foster_parented_texts.remove(index))
      return true
    }
    index += 1
  }
  false
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
  self.mark_forced_body_node(node)
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
  let out = StringBuilder(size_hint=value.length())
  for ch in value {
    if ch.is_ascii_whitespace() {
      out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn normalize_tree_builder_text(value : StringView) -> String {
  let out = StringBuilder(size_hint=value.length())
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
  let out = StringBuilder(size_hint=raw.length())
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
  let out = StringBuilder(size_hint=raw.length())
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
