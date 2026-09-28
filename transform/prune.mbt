///|
fn prune_empty_node_is_effectively_empty(
  node : @dom.Node,
  strip_whitespace : Bool,
) -> Bool {
  if node.kind != Element {
    return false
  }
  if node.ns == Some("html") && @ser.is_void_element(node.name) {
    return false
  }
  match node.template_contents {
    Some(contents) =>
      if !prune_children_are_effectively_empty(contents, strip_whitespace) {
        return false
      }
    None => ()
  }
  prune_children_are_effectively_empty(node, strip_whitespace)
}

///|
fn prune_children_are_effectively_empty(
  node : @dom.Node,
  strip_whitespace : Bool,
) -> Bool {
  for child in node.children {
    match child.kind {
      Text =>
        if strip_whitespace {
          if !child.data[:].trim().is_empty() {
            return false
          }
        } else if child.data != "" {
          return false
        }
      Comment | Doctype => ()
      Element | Document | Fragment => return false
    }
  }
  true
}

///|
fn apply_prune_empty_transform(
  root : @dom.Node,
  transform : TransformSpec,
  limits : @sel.SelectorLimits,
) -> Unit raise @core.HtmlError {
  apply_prune_empty_transforms(root, [transform], limits)
}

///|
fn apply_prune_empty_transforms(
  root : @dom.Node,
  transforms : Array[TransformSpec],
  limits : @sel.SelectorLimits,
) -> Unit raise @core.HtmlError {
  match root.kind {
    Document | Fragment | Element =>
      prune_empty_children(root, transforms, limits)
    _ => ()
  }
}

///|
/// Prune empty elements below `root` in post-order: template contents first,
/// then each child's subtree before the child itself is checked. Uses an
/// explicit frame stack instead of recursion; the element whose subtree is
/// being walked is parked in its parent frame's `pending` slot and checked
/// once that subtree walk has finished.
fn prune_empty_children(
  root : @dom.Node,
  transforms : Array[TransformSpec],
  limits : @sel.SelectorLimits,
) -> Unit raise @core.HtmlError {
  let stack : Array[WalkFrame] = [WalkFrame::new(root)]
  while stack.last() is Some(frame) {
    if frame.schedule_template_first(stack) {
      continue
    }
    let parent = frame.node
    let index = frame.index
    if frame.pending is Some(child) {
      frame.pending = None
      if !prune_empty_child_after_walk(parent, index, child, transforms, limits) {
        frame.index = index + 1
      }
      continue
    }
    if index >= parent.children.length() {
      ignore(stack.pop())
      continue
    }
    let child = parent.children[index]
    match child.kind {
      Document | Fragment => {
        frame.index = index + 1
        stack.push(WalkFrame::new(child))
      }
      Element => {
        frame.pending = Some(child)
        stack.push(WalkFrame::new(child))
      }
      _ => frame.index = index + 1
    }
  }
}

///|
/// Post-order step of `prune_empty_children`: remove `child` (at `index` in
/// `parent`) when the first matching transform finds it effectively empty.
/// Returns whether it was removed.
fn prune_empty_child_after_walk(
  parent : @dom.Node,
  index : Int,
  child : @dom.Node,
  transforms : Array[TransformSpec],
  limits : @sel.SelectorLimits,
) -> Bool raise @core.HtmlError {
  for transform in transforms {
    if transform_matches_element(child, transform, limits) &&
      prune_empty_node_is_effectively_empty(child, transform.strip_whitespace) {
      transform_call_hook(child, transform)
      let name = @syn.lower_ascii(child.name)
      transform_report(
        transform,
        "Pruned empty <\{name}> (matched selector '\{transform.selector}')",
        Some(child),
      )
      transform_remove_child_at(parent, index)
      return true
    }
  }
  false
}
