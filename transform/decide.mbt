///|
fn apply_decide_transform(
  root : @dom.Node,
  transform : TransformSpec,
  limits : @sel.SelectorLimits,
) -> Unit raise @core.HtmlError {
  match root.kind {
    Document | Fragment | Element =>
      decide_transform_children(root, transform, limits)
    _ => ()
  }
}

///|
fn decide_transform_all_nodes(transform : TransformSpec) -> Bool {
  transform.selector[:].trim() == "*"
}

///|
fn decide_action_label(action : DecideAction) -> String {
  match action {
    Keep => "keep"
    Drop => "drop"
    Unwrap => "unwrap"
    Empty => "empty"
    Escape => "escape"
  }
}

///|
fn decide_node_label(node : @dom.Node) -> String {
  if node.name.has_prefix("#") || node.name == "!doctype" {
    node.name
  } else {
    @syn.lower_ascii(node.name)
  }
}

///|
fn decide_transform_matches_node(
  node : @dom.Node,
  transform : TransformSpec,
  all_nodes : Bool,
  limits : @sel.SelectorLimits,
) -> Bool raise @core.HtmlError {
  if all_nodes {
    true
  } else {
    node.kind == Element && transform_matches_element(node, transform, limits)
  }
}

///|
fn decide_transform_action(
  node : @dom.Node,
  transform : TransformSpec,
) -> DecideAction {
  match transform.decide_callback {
    Some(callback) => {
      let action = (callback.callback)(node)
      if action != Keep {
        transform_call_hook(node, transform)
        transform_report(
          transform,
          "Decide -> " +
          decide_action_label(action) +
          " '" +
          decide_node_label(node) +
          "' (matched selector '" +
          transform.selector +
          "')",
          Some(node),
        )
      }
      action
    }
    None => Keep
  }
}

///|
fn decide_escape_child_at(parent : @dom.Node, index : Int) -> Unit {
  match parent.children[index].kind {
    Element => ignore(escape_transform_child_at(parent, index))
    Document | Fragment => ignore(transform_unwrap_child_at(parent, index))
    Text | Comment | Doctype => transform_remove_child_at(parent, index)
  }
}

///|
fn decide_transform_children(
  parent : @dom.Node,
  transform : TransformSpec,
  limits : @sel.SelectorLimits,
) -> Unit raise @core.HtmlError {
  let all_nodes = decide_transform_all_nodes(transform)
  let mut index = 0
  while index < parent.children.length() {
    let child = parent.children[index]
    if decide_transform_matches_node(child, transform, all_nodes, limits) {
      match decide_transform_action(child, transform) {
        Keep => {
          match child.kind {
            Document | Fragment | Element =>
              decide_transform_children(child, transform, limits)
            _ => ()
          }
          index += 1
        }
        Empty => {
          ignore(empty_transform_node(child))
          index += 1
        }
        Drop => transform_remove_child_at(parent, index)
        Unwrap => ignore(transform_unwrap_child_at(parent, index))
        Escape => decide_escape_child_at(parent, index)
      }
    } else {
      match child.kind {
        Document | Fragment | Element =>
          decide_transform_children(child, transform, limits)
        _ => ()
      }
      index += 1
    }
  }
}
