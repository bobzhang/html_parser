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
  self.track_form_start_element(adjusted_name, node)
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
    if node_ns == "html" && active_formatting_marker_element_name(adjusted_name) {
      self.push_active_formatting_marker()
    }
    if node_ns == "html" && start_tag_ignores_initial_lf(adjusted_name) {
      self.skip_one_initial_lf()
    }
  }
}
