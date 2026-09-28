///|
/// Drop every node of `kind` below `root`, visiting template contents before
/// regular children. Uses an explicit frame stack instead of recursion; every
/// child that is kept gets its own frame, exactly like the former recursive
/// call, so template contents of any kept node are also visited.
fn apply_drop_kind_transform(
  root : @dom.Node,
  kind : @dom.NodeKind,
  transform : TransformSpec,
) -> Unit {
  let stack : Array[WalkFrame] = [WalkFrame::new(root)]
  while stack.last() is Some(frame) {
    if frame.schedule_template_first(stack) {
      continue
    }
    let node = frame.node
    guard node.kind is (Document | Fragment | Element) &&
      frame.index < node.children.length() else {
      ignore(stack.pop())
      continue
    }
    let index = frame.index
    let child = node.children[index]
    if child.kind == kind {
      transform_call_hook(child, transform)
      let label = match kind {
        Comment => "comment"
        Doctype => "doctype"
        _ => "node"
      }
      transform_report(transform, "Dropped \{label}", Some(child))
      transform_remove_child_at(node, index)
    } else {
      frame.index = index + 1
      stack.push(WalkFrame::new(child))
    }
  }
}

///|
fn node_has_foreign_namespace(node : @dom.Node) -> Bool {
  match node.ns {
    Some(ns) => ns != "html"
    None => false
  }
}

///|
/// Drop every foreign-namespace element below `root`, visiting template
/// contents before regular children. Uses an explicit frame stack instead of
/// recursion, mirroring the former recursive walk frame by frame.
fn apply_drop_foreign_namespaces_transform(
  root : @dom.Node,
  transform : TransformSpec,
) -> Unit {
  let stack : Array[WalkFrame] = [WalkFrame::new(root)]
  while stack.last() is Some(frame) {
    if frame.schedule_template_first(stack) {
      continue
    }
    let node = frame.node
    guard node.kind is (Document | Fragment | Element) &&
      frame.index < node.children.length() else {
      ignore(stack.pop())
      continue
    }
    let index = frame.index
    let child = node.children[index]
    if child.kind == Element && node_has_foreign_namespace(child) {
      transform_call_hook(child, transform)
      let name = @syn.lower_ascii(child.name)
      transform_report(
        transform,
        "Unsafe tag '\{name}' (foreign namespace)",
        Some(child),
      )
      transform_remove_child_at(node, index)
    } else {
      frame.index = index + 1
      stack.push(WalkFrame::new(child))
    }
  }
}
