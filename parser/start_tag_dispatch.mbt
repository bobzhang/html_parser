///|
fn Parser::handle_parsed_start_tag(
  self : Parser,
  name : String,
  attrs : Map[String, String?],
  self_closing : Bool,
  start : Int,
  tag_close_pos : Int,
) -> Unit {
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
  if self.document_after_body && !self.is_fragment_parser() && name == "head" {
    self.error_at("unexpected-start-tag", start)
    return
  }
  if self.close_current_document_head_for_start(name, start) {
    return
  }
  if self.handle_late_document_head_start_tag(name, start) {
    return
  }
  if name == "html" &&
    !self.is_fragment_parser() &&
    !self.in_frameset_document() &&
    !self.has_open_element("template") &&
    self.open_html_element() is None &&
    document_has_any_content(self.root) {
    // A non-first <html> start tag merges its attributes into the
    // (implied) html element and is otherwise ignored.
    self.error_at("unexpected-start-tag", start)
    self.merge_document_html_attrs(attrs)
    return
  }
  if name == "body" &&
    (self.has_open_element("template") || self.in_select_insertion_mode()) {
    // The in-template and in-select rules ignore body start tags
    // entirely; their attributes never reach the document body.
    self.error_at("unexpected-start-tag", start)
    return
  }
  if name == "html" && self.has_open_element("template") {
    // The in-template rules ignore html start tags; in select mode they
    // use the in-body attribute merge below.
    self.error_at("unexpected-start-tag", start)
    return
  }
  if name == "html" && self.in_select_insertion_mode() {
    // Select-mode html start tags process via the in-body rules: merge
    // missing attributes into the document shell, ignore the element.
    self.error_at("unexpected-start-tag", start)
    self.merge_document_html_attrs(attrs)
    return
  }
  if !self.is_fragment_parser() &&
    name == "body" &&
    document_children_contain_body_content(self.root) {
    // A late <body> start tag is a parse error: it is ignored, its
    // attributes merge into the existing body without overwriting,
    // frameset-ok becomes not ok, and (when reprocessed from the
    // after-body modes) parsing returns to in-body.
    self.error_at("unexpected-start-tag", start)
    self.frameset_ok = false
    if self.document_after_body {
      self.document_entered_body = true
      self.document_after_body = false
      self.document_after_html = false
    }
    for attr_name, attr_value in attrs {
      if !self.pending_document_body_attrs.contains(attr_name) {
        self.pending_document_body_attrs[attr_name] = attr_value
      }
    }
    return
  }
  if !self.is_fragment_parser() &&
    !self.in_frameset_document() &&
    name != "html" &&
    name != "head" &&
    name != "frameset" &&
    !is_document_head_element_name(name) {
    // Any other start tag transitions the document into body parsing,
    // even when the token itself is then ignored (a lone <frame>); later
    // stray end tags use the in-body recoveries.
    self.document_entered_body = true
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
  self.close_bare_template_row_for_flow(name)
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
  if self.close_select_for_reprocessed_start_tag(name, start) &&
    self.handle_select_reprocessed_foreign_cell_start_tag(
      name, attrs, start, self_closing,
    ) {
    return
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
  if self.handle_duplicate_form_start_tag(name, start) {
    return
  }
  if name == "rp" || name == "rt" {
    self.generate_implied_end_tags(Some("rtc"))
  } else if (name == "rb" || name == "rtc") &&
    current_node_is_ruby_annotation(self.current_node()) {
    self.generate_implied_end_tags(None)
  }
  if start_tag_closes_p(name) && !(name == "table" && self.in_quirks_mode()) {
    // In quirks mode a table start tag does not close an open p; the
    // table nests inside the paragraph.
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
  self.insert_normal_start_tag(name, attrs, self_closing, start, tag_close_pos)
}
