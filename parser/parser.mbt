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
