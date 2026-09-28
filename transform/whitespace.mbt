///|
fn collapse_transform_html_space(value : StringView) -> String {
  let out = StringBuilder(size_hint=value.length())
  let mut in_ws = false
  for ch in value {
    if is_html_whitespace_char(ch) {
      if !in_ws {
        out.write_char(' ')
        in_ws = true
      }
    } else {
      out.write_char(ch)
      in_ws = false
    }
  }
  out.to_string()
}

///|
fn apply_collapse_whitespace_transform(
  root : @dom.Node,
  skip_tags : Set[String],
  transform : TransformSpec,
) -> Unit {
  match root.kind {
    Document | Fragment =>
      collapse_whitespace_children(root, skip_tags, false, transform)
    Element =>
      collapse_whitespace_children(
        root,
        skip_tags,
        skip_tags.contains(@syn.lower_ascii(root.name)),
        transform,
      )
    _ => ()
  }
}

///|
/// Collapse whitespace in text below `root` (template contents first, then the
/// regular children), skipping text inside skipped elements. Uses an explicit
/// frame stack instead of recursion; each frame carries the inherited skip
/// state of one activation of the former recursive walk.
fn collapse_whitespace_children(
  root : @dom.Node,
  skip_tags : Set[String],
  skip : Bool,
  transform : TransformSpec,
) -> Unit {
  let stack : Array[WalkFrame] = [WalkFrame::new(root, skip~)]
  while stack.last() is Some(frame) {
    if frame.schedule_template_first(stack) {
      continue
    }
    let parent = frame.node
    let index = frame.index
    if index >= parent.children.length() {
      ignore(stack.pop())
      continue
    }
    let child = parent.children[index]
    frame.index = index + 1
    match child.kind {
      Text if !frame.skip && child.data != "" => {
        let collapsed = collapse_transform_html_space(child.data)
        if collapsed != child.data {
          transform_call_hook(child, transform)
          transform_report(
            transform,
            "Collapsed whitespace in text node",
            Some(child),
          )
          let replacement = @dom.text(collapsed)
          replacement.parent = Some(parent)
          parent.children[index] = replacement
          if child.parent is Some(current_parent) &&
            physical_equal(current_parent, parent) {
            child.parent = None
          }
        }
      }
      Document | Fragment => stack.push(WalkFrame::new(child, skip=frame.skip))
      Element => {
        let child_skip = frame.skip ||
          skip_tags.contains(@syn.lower_ascii(child.name))
        stack.push(WalkFrame::new(child, skip=child_skip))
      }
      _ => ()
    }
  }
}
