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
    !start_tag_uses_in_head_rules(name) &&
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
    self.push_open_element(node)
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

///|
/// Append `node`, which the parser has just created, to `parent`.
///
/// Equivalent to `parent.append_child(node)` for a node that has no parent,
/// no children and no template contents, but without its O(depth) walk up
/// `parent`'s ancestors, which made parsing deeply nested markup quadratic.
/// The walk rejects appends that would create a cycle; every node in a tree
/// the parser builds is reachable from its parent's child list or template
/// contents, so a node with neither cannot be an ancestor of `parent`.
/// Anything else, including an HTML `template` parent (whose children go to
/// its contents), takes the `append_child` path.
fn append_new_node(parent : @dom.Node, node : @dom.Node) -> Unit {
  if node.parent is None &&
    node.children.is_empty() &&
    node.template_contents is None &&
    !physical_equal(parent, node) &&
    (
      parent.kind is (Document | Fragment) ||
      table_normalize_target_is_plain(parent)
    ) {
    node.parent = Some(parent)
    parent.children.push(node)
  } else {
    parent.append_child(node)
  }
}
