///|
fn class_contains(value : StringView, needle : StringView) -> Bool {
  if needle.is_empty() {
    return false
  }
  let mut token_start = 0
  let mut pos = 0
  for ch in value {
    if is_html_whitespace_char(ch) {
      if class_token_matches(value, token_start, pos, needle) {
        return true
      }
      pos += ch.utf16_len()
      token_start = pos
    } else {
      pos += ch.utf16_len()
    }
  }
  class_token_matches(value, token_start, value.length(), needle)
}

///|
fn class_token_matches(
  value : StringView,
  start : Int,
  end : Int,
  needle : StringView,
) -> Bool {
  if end <= start {
    false
  } else {
    value[start:end] == needle
  }
}

///|
fn tag_selector_matches(node : @dom.Node, tag : StringView) -> Bool {
  tag == "*" || node.name[:] == tag.to_lower()
}

///|
fn id_selector_matches(node : @dom.Node, id : StringView) -> Bool {
  match node.attrs.get("id") {
    Some(Some(value)) => value[:] == id
    _ => false
  }
}

///|
fn class_selector_matches(node : @dom.Node, class_name : StringView) -> Bool {
  match node.attrs.get("class") {
    Some(Some(value)) => class_contains(value, class_name)
    _ => false
  }
}
