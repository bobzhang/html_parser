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
/// Move every child of `from` into `parent` at `index`, keeping their order.
///
/// `before` and `after`, when present, are inserted immediately before and
/// after the moved children. Moved children get `parent` as their parent
/// pointer; `before`/`after` are inserted as-is. Runs in linear time, unlike a
/// one-at-a-time `remove(0)`/`insert` loop. Returns the number of inserted
/// nodes.
fn move_children_into(
  parent : @dom.Node,
  index : Int,
  from : @dom.Node,
  before? : @dom.Node,
  after? : @dom.Node,
) -> Int {
  let moved = from.children.copy()
  from.children.clear()
  let tail = parent.children.drain(index, parent.children.length())
  let mut inserted = 0
  if before is Some(node) {
    parent.children.push(node)
    inserted += 1
  }
  for grandchild in moved {
    grandchild.parent = Some(parent)
    parent.children.push(grandchild)
    inserted += 1
  }
  if after is Some(node) {
    parent.children.push(node)
    inserted += 1
  }
  parent.children.append(tail)
  inserted
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
  move_children_into(parent, index, child)
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
/// Build the text node that replaces an escaped start or end tag in `parent`.
fn sanitized_escape_text(
  parent : @dom.Node,
  value : String,
  policy : SanitizationPolicy,
) -> @dom.Node {
  // The escaped tag becomes text the caller skips over, so it is stripped
  // here like every other text node the policy lets through.
  let value = if policy.strip_invisible_unicode {
    strip_invisible_unicode(value)
  } else {
    value
  }
  let escaped = @dom.text(value)
  escaped.parent = Some(parent)
  escaped
}

///|
/// Finish escaping a disallowed element after its children were sanitized.
///
/// The node at `index` is removed from `parent`; escaped start-tag text, the
/// (already sanitized) children of `child`, and the optional escaped end-tag
/// text are inserted in its place. `start_tag` and `end_tag` must have been
/// computed from `child` before its children were sanitized. Returns the
/// number of inserted nodes.
fn finish_escape_child_at(
  parent : @dom.Node,
  index : Int,
  child : @dom.Node,
  start_tag : String,
  end_tag : String?,
  policy : SanitizationPolicy,
) -> Int {
  ignore(parent.children.remove(index))
  if child.parent is Some(current_parent) &&
    physical_equal(parent, current_parent) {
    child.parent = None
  }
  let before = sanitized_escape_text(parent, start_tag, policy)
  let after = end_tag.map(value => sanitized_escape_text(parent, value, policy))
  move_children_into(parent, index, child, before~, after?)
}
