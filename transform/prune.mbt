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
fn prune_empty_children(
  parent : @dom.Node,
  transforms : Array[TransformSpec],
  limits : @sel.SelectorLimits,
) -> Unit raise @core.HtmlError {
  match parent.template_contents {
    Some(contents) => prune_empty_children(contents, transforms, limits)
    None => ()
  }
  let mut index = 0
  while index < parent.children.length() {
    let child = parent.children[index]
    match child.kind {
      Document | Fragment => {
        prune_empty_children(child, transforms, limits)
        index += 1
      }
      Element => {
        prune_empty_children(child, transforms, limits)
        let mut removed = false
        for transform in transforms {
          if transform_matches_element(child, transform, limits) &&
            prune_empty_node_is_effectively_empty(
              child,
              transform.strip_whitespace,
            ) {
            transform_call_hook(child, transform)
            let name = @syn.lower_ascii(child.name)
            transform_report(
              transform,
              "Pruned empty <\{name}> (matched selector '\{transform.selector}')",
              Some(child),
            )
            transform_remove_child_at(parent, index)
            removed = true
            break
          }
        }
        if removed {
          ()
        } else {
          index += 1
        }
      }
      _ => index += 1
    }
  }
}
