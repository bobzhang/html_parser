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
/// Continuation of an unwrap inside `transform_children`: walk the subtrees of
/// the `count` children hoisted into `parent` at `start`, one per step.
priv struct AfterUnwrapFrame {
  parent : @dom.Node
  start : Int
  count : Int
  mut offset : Int
}

///|
/// Explicit-stack frame for `transform_children`.
priv enum SelectorWalkFrame {
  Walk(WalkFrame)
  AfterUnwrap(AfterUnwrapFrame)
}

///|
/// Apply a selector transform to the elements below `root`, visiting template
/// contents before regular children. Uses an explicit frame stack instead of
/// recursion so deeply nested trees (including long chains of unwrapped
/// elements) cannot overflow the call stack; each frame mirrors one activation
/// of the former recursive walk.
fn transform_children(
  root : @dom.Node,
  transform : TransformSpec,
  limits : @sel.SelectorLimits,
) -> Unit raise @core.HtmlError {
  let stack : Array[SelectorWalkFrame] = [Walk(WalkFrame::new(root))]
  while stack.last() is Some(top) {
    match top {
      AfterUnwrap(frame) => {
        let parent = frame.parent
        let offset = frame.offset
        if offset < frame.count &&
          frame.start + offset < parent.children.length() {
          let child = parent.children[frame.start + offset]
          frame.offset = offset + 1
          match child.kind {
            Document | Fragment | Element =>
              stack.push(Walk(WalkFrame::new(child)))
            _ => ()
          }
        } else {
          ignore(stack.pop())
        }
      }
      Walk(frame) => {
        if !frame.entered {
          frame.entered = true
          if frame.node.template_contents is Some(contents) {
            stack.push(Walk(WalkFrame::new(contents)))
            continue
          }
        }
        let parent = frame.node
        let index = frame.index
        if index >= parent.children.length() {
          ignore(stack.pop())
          continue
        }
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
                frame.index = index + inserted
                stack.push(
                  AfterUnwrap({
                    parent,
                    start: index,
                    count: inserted,
                    offset: 0,
                  }),
                )
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
              frame.index = index + 1
            }
            SetAttributes => {
              if apply_set_attrs_transform(child, transform) {
                transform_report_node_action(
                  child, transform, "Set attributes on",
                )
              }
              frame.index = index + 1
              stack.push(Walk(WalkFrame::new(child)))
            }
            DropAttributes => {
              ignore(apply_drop_attrs_transform(child, transform))
              frame.index = index + 1
              stack.push(Walk(WalkFrame::new(child)))
            }
            AllowlistAttributes => {
              ignore(apply_allowlist_attrs_transform(child, transform))
              frame.index = index + 1
              stack.push(Walk(WalkFrame::new(child)))
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
              frame.index = index + 1
              stack.push(Walk(WalkFrame::new(child)))
            }
            EditElement => {
              apply_edit_transform(child, transform)
              if index < parent.children.length() &&
                physical_equal(parent.children[index], child) {
                frame.index = index + 1
                stack.push(Walk(WalkFrame::new(child)))
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
                frame.index = index + 1
                stack.push(Walk(WalkFrame::new(child)))
              }
            }
            DropUrlAttributes => {
              ignore(apply_drop_url_attrs_transform(child, transform))
              frame.index = index + 1
              stack.push(Walk(WalkFrame::new(child)))
            }
            AllowStyleAttributes => {
              ignore(apply_allow_style_attrs_transform(child, transform))
              frame.index = index + 1
              stack.push(Walk(WalkFrame::new(child)))
            }
            _ => frame.index = index + 1
          }
        } else {
          frame.index = index + 1
          match child.kind {
            Document | Fragment | Element =>
              stack.push(Walk(WalkFrame::new(child)))
            _ => ()
          }
        }
      }
    }
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
