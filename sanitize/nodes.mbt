///|
/// Remove one child from `parent` and detach its parent pointer.
///
/// `index` must be a valid child index. The removed node's `parent` field is
/// cleared only when it still points at `parent`.
fn remove_child_at(parent : @dom.Node, index : Int) -> Unit {
  let child = parent.children[index]
  ignore(parent.children.remove(index))
  if child.parent is Some(current_parent) &&
    physical_equal(parent, current_parent) {
    child.parent = None
  }
}

///|
/// Replace one child with its own children.
///
/// The child at `index` is removed, detached from `parent`, and its children
/// are inserted into `parent` at the same position with updated parent
/// pointers. Returns the number of inserted children.
fn unwrap_child_at(parent : @dom.Node, index : Int) -> Int {
  let child = parent.children[index]
  ignore(parent.children.remove(index))
  if child.parent is Some(current_parent) &&
    physical_equal(parent, current_parent) {
    child.parent = None
  }
  let mut inserted = 0
  while !child.children.is_empty() {
    let grandchild = child.children[0]
    ignore(child.children.remove(0))
    grandchild.parent = Some(parent)
    parent.children.insert(index + inserted, grandchild)
    inserted += 1
  }
  inserted
}

///|
fn sanitizer_escaped_end_tag_for(node : @dom.Node) -> String? {
  match node.source_end_tag {
    Some(raw) => Some(raw)
    None =>
      if node.parsed_from_source || @ser.is_void_element(node.name) {
        None
      } else {
        Some("</" + node.name + ">")
      }
  }
}

///|
fn sanitizer_escaped_start_tag_for(node : @dom.Node) -> String {
  node.source_start_tag.unwrap_or(
    @seri.serialize_start_tag_unchecked(node, '"'),
  )
}

///|
fn insert_sanitized_escape_text(
  parent : @dom.Node,
  index : Int,
  value : String,
) -> Unit {
  let escaped = @dom.text(value)
  escaped.parent = Some(parent)
  parent.children.insert(index, escaped)
}

///|
fn escape_child_at(
  parent : @dom.Node,
  index : Int,
  policy : SanitizationPolicy,
  observer : SanitizeTransformObserver?,
) -> Int raise @core.HtmlError {
  let child = parent.children[index]
  let start_tag = sanitizer_escaped_start_tag_for(child)
  let end_tag = sanitizer_escaped_end_tag_for(child)
  sanitize_container_children(child, policy, observer)
  ignore(parent.children.remove(index))
  if child.parent is Some(current_parent) &&
    physical_equal(parent, current_parent) {
    child.parent = None
  }
  let mut inserted = 0
  insert_sanitized_escape_text(parent, index + inserted, start_tag)
  inserted += 1
  while !child.children.is_empty() {
    let grandchild = child.children[0]
    ignore(child.children.remove(0))
    grandchild.parent = Some(parent)
    parent.children.insert(index + inserted, grandchild)
    inserted += 1
  }
  match end_tag {
    Some(value) => {
      insert_sanitized_escape_text(parent, index + inserted, value)
      inserted += 1
    }
    None => ()
  }
  inserted
}
