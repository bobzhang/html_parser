///|
fn Parser::handle_column_group_text(
  self : Parser,
  cleaned : StringView,
  start : Int,
) -> Bool {
  let has_non_whitespace = text_has_non_ascii_whitespace(cleaned)
  let current = self.current_node()
  if current.kind == Element && current.name == "colgroup" {
    let in_template_table_context = self.in_template_content_without_inner_table()
    self.error_at("unexpected-characters-in-column-group", start)
    if has_non_whitespace {
      let whitespace = leading_ascii_whitespace(cleaned)
      if !whitespace.is_empty() {
        current.append_child(
          @dom.text(decode_entities_for_tree_text(whitespace)),
        )
      }
      ignore(self.pop_current_element_if_name("colgroup"))
      let non_whitespace = cleaned[whitespace.length():]
      let non_whitespace_start = start + whitespace.length()
      if in_template_table_context {
        self.enable_template_table_context_mode()
        ignore(
          self.report_foster_parenting_character_errors(
            non_whitespace, non_whitespace_start,
          ),
        )
      }
      if self.foster_parent_table_text(non_whitespace, non_whitespace_start) {
        return true
      }
      self
      .current_node()
      .append_child(@dom.text(decode_entities_for_tree_text(non_whitespace)))
    } else {
      current.append_child(@dom.text(decode_entities_for_tree_text(cleaned)))
      ignore(self.pop_current_element_if_name("colgroup"))
      if in_template_table_context {
        self.enable_template_table_context_mode()
      }
    }
    return true
  }
  if self.current_table_last_child_is_col() {
    self.error_at("unexpected-characters-in-column-group", start)
    if has_non_whitespace {
      if self.foster_parent_table_text(cleaned, start) {
        return true
      }
    }
  }
  false
}

///|
fn leading_ascii_whitespace(value : StringView) -> StringView {
  // ASCII whitespace is always a single code unit, so the prefix can be
  // returned as a plain slice of the input.
  let mut length = 0
  for ch in value {
    if ch.is_ascii_whitespace() {
      length += 1
    } else {
      break
    }
  }
  value[:length]
}

///|
fn Parser::handle_fragment_context_colgroup_text(
  self : Parser,
  cleaned : StringView,
  start : Int,
) -> Bool {
  if !self.fragment_context_colgroup {
    return false
  }
  self.error_at("unexpected-characters-in-column-group", start)
  let whitespace = leading_ascii_whitespace(cleaned)
  if !whitespace.is_empty() {
    self
    .current_node()
    .append_child(@dom.text(decode_entities_for_tree_text(whitespace)))
  }
  true
}

///|
fn Parser::handle_fragment_context_colgroup_start_tag(
  self : Parser,
  name : String,
  attrs : Map[String, String?],
  start : Int,
) -> Bool {
  if !self.fragment_context_colgroup {
    return false
  }
  if name == "col" {
    self
    .current_node()
    .append_child(self.node_with_origin(@dom.element("col", attrs~), start))
    return true
  }
  if name == "colgroup" {
    self.error_at("unexpected-start-tag-implies-end-tag", start)
  } else {
    self.error_at("unexpected-start-tag-in-column-group", start)
  }
  true
}

///|
fn Parser::handle_fragment_context_colgroup_end_tag(
  self : Parser,
  name : String,
  start : Int,
) -> Bool {
  if !self.fragment_context_colgroup {
    return false
  }
  if name == "col" || name == "colgroup" {
    self.error_at("unexpected-end-tag", start)
    return true
  }
  if table_context_end_tag_uses_table_voodoo(name) {
    self.error_at("unexpected-end-tag-implies-table-voodoo", start)
  }
  false
}

///|
fn Parser::close_current_column_group_for_start(
  self : Parser,
  name : String,
  start : Int,
) -> Unit {
  if name == "col" || name == "template" {
    // The in-column-group mode handles template with the in-head rules:
    // it nests inside the colgroup instead of closing it.
    return
  }
  match self.stack.last() {
    Some(node) if node.kind == Element && node.name == "colgroup" => {
      if name == "colgroup" {
        self.error_at("unexpected-start-tag-implies-end-tag", start)
      }
      ignore(self.stack.pop())
    }
    _ => ()
  }
}

///|
fn Parser::close_current_column_group_for_end(
  self : Parser,
  name : String,
) -> Unit {
  if name == "col" || name == "colgroup" {
    return
  }
  match self.stack.last() {
    Some(node) if node.kind == Element && node.name == "colgroup" =>
      ignore(self.stack.pop())
    _ => ()
  }
}
