///|
fn apply_selector_transform(
  root : @dom.Node,
  transform : TransformSpec,
  limits : @sel.SelectorLimits,
) -> Unit raise @core.HtmlError {
  match root.kind {
    Document | Fragment | Element => transform_children(root, transform, limits)
    _ => ()
  }
}

///|
fn transform_children(
  parent : @dom.Node,
  transform : TransformSpec,
  limits : @sel.SelectorLimits,
) -> Unit raise @core.HtmlError {
  match parent.template_contents {
    Some(contents) => transform_children(contents, transform, limits)
    None => ()
  }
  let mut index = 0
  while index < parent.children.length() {
    let child = parent.children[index]
    if child.kind == Element &&
      transform_matches_element(child, transform, limits) {
      match transform.kind {
        DropElements => {
          transform_report_node_action(child, transform, "Dropped")
          transform_remove_child_at(parent, index)
        }
        UnwrapElements => {
          transform_report_node_action(child, transform, "Unwrapped")
          let inserted = transform_unwrap_child_at(parent, index)
          if inserted > 0 {
            transform_inserted_children_after_unwrap(
              parent, index, inserted, transform, limits,
            )
            index += inserted
          }
        }
        EscapeElements => {
          transform_report_node_action(child, transform, "Escaped")
          ignore(escape_transform_child_at(parent, index))
        }
        EmptyElements => {
          if empty_transform_node(child) {
            transform_report_node_action(child, transform, "Emptied")
          }
          index += 1
        }
        SetAttributes => {
          if apply_set_attrs_transform(child, transform) {
            transform_report_node_action(child, transform, "Set attributes on")
          }
          transform_children(child, transform, limits)
          index += 1
        }
        DropAttributes => {
          ignore(apply_drop_attrs_transform(child, transform))
          transform_children(child, transform, limits)
          index += 1
        }
        AllowlistAttributes => {
          ignore(apply_allowlist_attrs_transform(child, transform))
          transform_children(child, transform, limits)
          index += 1
        }
        MergeAttributeTokens => {
          if apply_merge_attrs_transform(child, transform) {
            transform_call_hook(child, transform)
            transform_report(
              transform,
              "Merged tokens into attribute '\{transform.merge_attr}' on <\{transform.merge_tag}>",
              Some(child),
            )
          }
          transform_children(child, transform, limits)
          index += 1
        }
        EditElement => {
          apply_edit_transform(child, transform)
          if index < parent.children.length() &&
            physical_equal(parent.children[index], child) {
            transform_children(child, transform, limits)
            index += 1
          }
        }
        EditAttributes => {
          if apply_edit_attrs_transform(child, transform) {
            transform_report_node_action(
              child, transform, "Edited attributes on",
            )
          }
          if index < parent.children.length() &&
            physical_equal(parent.children[index], child) {
            transform_children(child, transform, limits)
            index += 1
          }
        }
        DropUrlAttributes => {
          ignore(apply_drop_url_attrs_transform(child, transform))
          transform_children(child, transform, limits)
          index += 1
        }
        AllowStyleAttributes => {
          ignore(apply_allow_style_attrs_transform(child, transform))
          transform_children(child, transform, limits)
          index += 1
        }
        _ => index += 1
      }
    } else {
      match child.kind {
        Document | Fragment | Element =>
          transform_children(child, transform, limits)
        _ => ()
      }
      index += 1
    }
  }
}

///|
fn transform_inserted_children_after_unwrap(
  parent : @dom.Node,
  start : Int,
  count : Int,
  transform : TransformSpec,
  limits : @sel.SelectorLimits,
) -> Unit raise @core.HtmlError {
  let mut offset = 0
  while offset < count && start + offset < parent.children.length() {
    let child = parent.children[start + offset]
    match child.kind {
      Document | Fragment | Element =>
        transform_children(child, transform, limits)
      _ => ()
    }
    offset += 1
  }
}

///|
fn transform_matches_element(
  node : @dom.Node,
  transform : TransformSpec,
  limits : @sel.SelectorLimits,
) -> Bool raise @core.HtmlError {
  match transform.kind {
    MergeAttributeTokens => @syn.lower_ascii(node.name) == transform.merge_tag
    _ => @sel.matches_with_limits(node, transform.selector, limits)
  }
}
