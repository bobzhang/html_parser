///|
fn Parser::insert_normal_start_tag(
  self : Parser,
  name : String,
  attrs : Map[String, String?],
  self_closing : Bool,
  start : Int,
  tag_close_pos : Int,
) -> Unit {
  let node_ns = self.start_tag_namespace(name)
  let is_html_ns = node_ns == "html"
  if is_html_ns {
    self.prepare_active_formatting_start(name, start)
  }
  if !start_tag_closes_p(name) &&
    !start_tag_uses_in_head_rules(name) &&
    !self.table_context_start_skips_active_reconstruction(name) {
    self.reconstruct_active_formatting_elements()
  }
  let adjusted_name = if is_html_ns {
    if name == "image" {
      self.error_at("image-start-tag", start)
      "img"
    } else {
      name
    }
  } else {
    adjusted_start_tag_name_for_namespace(node_ns, name)
  }
  let adjusted_attrs = if is_html_ns {
    attrs
  } else {
    prepare_foreign_attrs(node_ns, attrs)
  }
  let node = self.node_with_start_tag_source(
    @dom.element(adjusted_name, attrs=adjusted_attrs, ns=node_ns),
    start,
    tag_close_pos,
  )
  self.track_form_start_element(adjusted_name, node)
  self.append_start_tag_node(node, adjusted_name, start)
  if is_html_ns && adjusted_name == "select" {
    self.select_insertion_mode = true
  }
  let is_void_element = @ser.is_void_element(adjusted_name)
  let self_closes_tree = if is_html_ns {
    self_closing && is_void_element
  } else {
    self_closing
  }
  let inserts_empty_nonvoid = self.start_tag_inserts_empty_nonvoid(
    adjusted_name,
  )
  if is_html_ns &&
    !self_closes_tree &&
    self.is_special_text_element(adjusted_name) {
    self.consume_special_element_content(node, adjusted_name)
  } else if !self_closes_tree && !is_void_element && !inserts_empty_nonvoid {
    self.push_open_element(node)
    if is_html_ns && active_formatting_element_name(adjusted_name) {
      let duplicate_index = self.active_formatting_duplicate_index(
        adjusted_name,
        node.attrs,
      )
      if duplicate_index >= 0 {
        self.remove_active_formatting_index(duplicate_index)
      }
      self.append_active_formatting_entry(node)
    }
    if is_html_ns && active_formatting_marker_element_name(adjusted_name) {
      self.push_active_formatting_marker()
    }
    if is_html_ns && start_tag_ignores_initial_lf(adjusted_name) {
      // A literal newline is skipped here; an entity-encoded one decodes
      // later, so the text path drops it via the pending flag.
      self.pending_initial_lf_skip = self.current() is Some('&')
      self.skip_one_initial_lf()
    }
  }
}

///|
/// In-body start tags handled by the in-head rules insert without
/// reconstructing active formatting.
fn start_tag_uses_in_head_rules(name : StringView) -> Bool {
  match name {
    "base"
    | "basefont"
    | "bgsound"
    | "link"
    | "meta"
    | "noframes"
    | "script"
    | "style"
    | "template"
    | "title" => true
    _ => false
  }
}
