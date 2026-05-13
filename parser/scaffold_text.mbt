///|
fn is_whitespace_text_node(node : @dom.Node) -> Bool {
  if node.kind != Text {
    return false
  }
  for ch in node.data {
    if !ch.is_ascii_whitespace() {
      return false
    }
  }
  true
}

///|
fn text_node_without_leading_ascii_whitespace(node : @dom.Node) -> @dom.Node? {
  let view = node.data[:]
  let mut start = 0
  while start < view.length() {
    match view.get_char(start) {
      Some(ch) if ch.is_ascii_whitespace() => start += ch.utf16_len()
      _ => break
    }
  }
  if start == 0 {
    Some(node)
  } else if start >= view.length() {
    None
  } else {
    Some(@dom.text(view[start:view.length()]))
  }
}

///|
fn split_text_node_leading_ascii_whitespace(
  node : @dom.Node,
) -> (@dom.Node?, @dom.Node?) {
  let view = node.data[:]
  let mut start = 0
  while start < view.length() {
    match view.get_char(start) {
      Some(ch) if ch.is_ascii_whitespace() => start += ch.utf16_len()
      _ => break
    }
  }
  if start == 0 {
    (None, Some(node))
  } else if start >= view.length() {
    (Some(node), None)
  } else {
    (Some(@dom.text(view[0:start])), Some(@dom.text(view[start:view.length()])))
  }
}
