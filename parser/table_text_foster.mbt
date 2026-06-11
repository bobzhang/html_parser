///|
fn is_table_text_foster_target(name : StringView) -> Bool {
  match name {
    "table" | "tbody" | "tfoot" | "thead" | "tr" => true
    _ => false
  }
}

///|
fn Parser::report_foster_parenting_character_errors(
  self : Parser,
  value : StringView,
  start : Int,
) -> Int {
  let mut count = 0
  let mut pos = 0
  while pos < value.length() {
    let ch = value.get_char(pos).unwrap()
    if !ch.is_ascii_whitespace() {
      self.error_at("foster-parenting-character", start + pos)
      count += 1
    }
    pos += ch.utf16_len()
  }
  count
}

///|
fn Parser::foster_parent_table_text_with_formatting(
  self : Parser,
  cleaned : StringView,
  start : Int,
  table_index : Int,
  formatting_index : Int,
) -> Bool {
  let entry = self.active_formatting[formatting_index]
  let node = element_from_formatting_entry(entry)
  node.append_child(
    self.text_at(@tok.decode_entities(cleaned, in_attribute=false), start),
  )
  if self.table_index_is_fragment_context_table(table_index) {
    self.current_node().append_child(node)
  } else {
    self.insert_node_before_open_table(node, table_index)
  }
  self.active_formatting[formatting_index] = formatting_entry_with_node(
    entry, node,
  )
  self.pending_table_view_implied_end_tag = true
  true
}

///|
fn Parser::foster_parent_table_text(
  self : Parser,
  cleaned : StringView,
  start : Int,
) -> Bool {
  if !text_has_non_ascii_whitespace(cleaned) {
    return false
  }
  let table_index = self.last_open_table_index()
  if table_index < 0 || self.table_text_is_inside_cell_or_caption(table_index) {
    return false
  }
  let current = self.current_node()
  if current.kind != Element || !is_table_text_foster_target(current.name) {
    return false
  }
  let formatting_index = self.active_formatting_orphan_anchor_index()
  if formatting_index >= 0 {
    return self.foster_parent_table_text_with_formatting(
      cleaned, start, table_index, formatting_index,
    )
  }
  ignore(self.report_foster_parenting_character_errors(cleaned, start))
  let fostered = self.text_at(
    @tok.decode_entities(cleaned, in_attribute=false),
    start,
  )
  if self.table_index_is_fragment_context_table(table_index) {
    self.current_node().append_child(fostered)
    return true
  }
  let table = self.stack[table_index]
  match table.parent {
    Some(parent) => {
      // The appropriate place for inserting fostered characters is
      // immediately before the table; when a text node already sits
      // there, the characters merge into it ("A" and "C" around a cell
      // become one "AC" node).
      let mut table_pos = -1
      let mut sibling_index = 0
      while sibling_index < parent.children.length() {
        if physical_equal(parent.children[sibling_index], table) {
          table_pos = sibling_index
          break
        }
        sibling_index += 1
      }
      if table_pos > 0 &&
        parent.children[table_pos - 1].kind == Text &&
        !parent.children[table_pos - 1].sanitize_escape_only {
        let previous = parent.children[table_pos - 1]
        let merged = @dom.text(previous.data + fostered.data)
        merged.parsed_from_source = previous.parsed_from_source
        merged.origin_offset = previous.origin_offset
        merged.origin_line = previous.origin_line
        merged.origin_col = previous.origin_col
        merged.parent = Some(parent)
        parent.children[table_pos - 1] = merged
        previous.parent = None
        if self.remove_foster_parented_text(previous) {
          self.foster_parented_texts.push(merged)
        }
        if self.remove_forced_body_node(previous) {
          self.forced_body_nodes.push(merged)
        }
        return true
      }
      parent.insert_before(fostered, Some(table))
    }
    None => self.root.append_child(fostered)
  }
  self.foster_parented_texts.push(fostered)
  true
}

///|
fn Parser::foster_parent_template_table_text(
  self : Parser,
  cleaned : StringView,
  start : Int,
) -> Bool {
  if !self.in_template_content_without_inner_table() ||
    !text_has_non_ascii_whitespace(cleaned) {
    return false
  }
  let current = self.current_node()
  if current.kind != Element || !is_table_text_foster_target(current.name) {
    return false
  }
  let template_index = self.last_open_template_index()
  ignore(self.report_foster_parenting_character_errors(cleaned, start))
  self.stack[template_index].append_child(
    self.text_at(@tok.decode_entities(cleaned, in_attribute=false), start),
  )
  true
}

///|
fn Parser::report_foster_parented_table_context_text(
  self : Parser,
  cleaned : StringView,
  start : Int,
) -> Unit {
  if !text_has_non_ascii_whitespace(cleaned) {
    return
  }
  let table_index = self.table_context_without_cell_or_caption()
  if table_index < 0 {
    return
  }
  let current = self.current_node()
  if current.kind == Element && is_table_text_foster_target(current.name) {
    return
  }
  ignore(self.report_foster_parenting_character_errors(cleaned, start))
}
