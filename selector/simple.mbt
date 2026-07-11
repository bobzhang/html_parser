///|
fn matches_simple_selector(node : @dom.Node, selector : StringView) -> Bool {
  let selector = selector.trim()
  if selector.is_empty() {
    return false
  }
  if node.kind != Element {
    return non_element_simple_selector_matches(node, selector)
  }
  let mut pos = 0
  match selector.get_char(pos).unwrap() {
    '*' => {
      pos += 1
      if pos < selector.length() {
        match selector.get_char(pos) {
          Some('.') | Some('#') | Some('[') | Some(':') => ()
          _ => return false
        }
      }
    }
    '.' | '#' | '[' | ':' => ()
    _ => {
      let end = next_simple_selector_marker(selector, pos)
      let tag = selector[pos:end]
      if tag.is_empty() ||
        !selector_identifier_is_valid(tag) ||
        !tag_selector_matches(node, tag) {
        return false
      }
      pos = end
    }
  }
  while pos < selector.length() {
    let marker = selector.get_char(pos).unwrap()
    if marker == '[' {
      guard find_attribute_selector_end(selector, pos) is Some(end) else {
        return false
      }
      let attribute = selector[pos + 1:end]
      if !attribute_selector_matches(node, attribute) {
        return false
      }
      pos = end + 1
      continue
    }
    if marker == ':' {
      let start = pos + marker.utf16_len()
      let end = next_simple_selector_marker(selector, start)
      let name = selector[start:end]
      if name.is_empty() || !pseudo_selector_matches(node, name) {
        return false
      }
      pos = end
      continue
    }
    if marker != '.' && marker != '#' {
      return false
    }
    let start = pos + marker.utf16_len()
    let end = next_simple_selector_marker(selector, start)
    let name = selector[start:end]
    if name.is_empty() || !selector_identifier_is_valid(name) {
      return false
    }
    if marker == '.' {
      if !class_selector_matches(node, name) {
        return false
      }
    } else if !id_selector_matches(node, name) {
      return false
    }
    pos = end
  }
  true
}

///|
fn simple_selector_is_valid(selector : StringView) -> Bool {
  let selector = selector.trim()
  if selector.is_empty() {
    return false
  }
  let mut pos = 0
  match selector.get_char(pos).unwrap() {
    '*' => {
      pos += 1
      if pos < selector.length() {
        match selector.get_char(pos) {
          Some('.') | Some('#') | Some('[') | Some(':') => ()
          _ => return false
        }
      }
    }
    '.' | '#' | '[' | ':' => ()
    _ => {
      let end = next_simple_selector_marker(selector, pos)
      let tag = selector[pos:end]
      if tag.is_empty() || !selector_identifier_is_valid(tag) {
        return false
      }
      pos = end
    }
  }
  while pos < selector.length() {
    let marker = selector.get_char(pos).unwrap()
    if marker == '[' {
      guard find_attribute_selector_end(selector, pos) is Some(end) else {
        return false
      }
      let attribute = selector[pos + 1:end]
      if !attribute_selector_is_valid(attribute) {
        return false
      }
      pos = end + 1
      continue
    }
    if marker == ':' {
      let start = pos + marker.utf16_len()
      let end = next_simple_selector_marker(selector, start)
      let name = selector[start:end]
      if name.is_empty() || !pseudo_selector_is_valid(name) {
        return false
      }
      pos = end
      continue
    }
    if marker != '.' && marker != '#' {
      return false
    }
    let start = pos + marker.utf16_len()
    let end = next_simple_selector_marker(selector, start)
    let name = selector[start:end]
    if name.is_empty() || !selector_identifier_is_valid(name) {
      return false
    }
    pos = end
  }
  true
}

///|
fn non_element_simple_selector_matches(
  node : @dom.Node,
  selector : StringView,
) -> Bool {
  let mut pos = 0
  while pos < selector.length() {
    guard selector.get_char(pos) is Some(':') else { return false }
    let start = pos + ':'.utf16_len()
    let end = next_simple_selector_marker(selector, start)
    guard selector.get_view(start~, end~) is Some(name) else { return false }
    if name.is_empty() || !pseudo_selector_matches(node, name) {
      return false
    }
    pos = end
  }
  true
}

///|
fn non_element_simple_selector_matches_with_context(
  node : @dom.Node,
  selector : StringView,
  context : SelectorMatchContext,
  depth : Int,
) -> Bool raise @core.HtmlError {
  let mut pos = 0
  while pos < selector.length() {
    context.tick(1)
    guard selector.get_char(pos) is Some(':') else { return false }
    let start = pos + ':'.utf16_len()
    let end = next_simple_selector_marker(selector, start)
    guard selector.get_view(start~, end~) is Some(name) else { return false }
    if name.is_empty() ||
      !pseudo_selector_matches_with_context(node, name, context, depth) {
      return false
    }
    pos = end
  }
  true
}

///|
fn matches_simple_selector_with_context(
  node : @dom.Node,
  selector : StringView,
  context : SelectorMatchContext,
  depth : Int,
) -> Bool raise @core.HtmlError {
  context.tick(1)
  let selector = selector.trim()
  if selector.is_empty() {
    return false
  }
  if node.kind != Element {
    return non_element_simple_selector_matches_with_context(
      node, selector, context, depth,
    )
  }
  let mut pos = 0
  match selector.get_char(pos).unwrap() {
    '*' => {
      pos += 1
      if pos < selector.length() {
        match selector.get_char(pos) {
          Some('.') | Some('#') | Some('[') | Some(':') => ()
          _ => return false
        }
      }
    }
    '.' | '#' | '[' | ':' => ()
    _ => {
      let end = next_simple_selector_marker(selector, pos)
      let tag = selector[pos:end]
      if tag.is_empty() ||
        !selector_identifier_is_valid(tag) ||
        !tag_selector_matches(node, tag) {
        return false
      }
      pos = end
    }
  }
  while pos < selector.length() {
    context.tick(1)
    let marker = selector.get_char(pos).unwrap()
    if marker == '[' {
      guard find_attribute_selector_end(selector, pos) is Some(end) else {
        return false
      }
      let attribute = selector[pos + 1:end]
      if !attribute_selector_matches(node, attribute) {
        return false
      }
      pos = end + 1
      continue
    }
    if marker == ':' {
      let start = pos + marker.utf16_len()
      let end = next_simple_selector_marker(selector, start)
      let name = selector[start:end]
      if name.is_empty() ||
        !pseudo_selector_matches_with_context(node, name, context, depth) {
        return false
      }
      pos = end
      continue
    }
    if marker != '.' && marker != '#' {
      return false
    }
    let start = pos + marker.utf16_len()
    let end = next_simple_selector_marker(selector, start)
    let name = selector[start:end]
    if name.is_empty() || !selector_identifier_is_valid(name) {
      return false
    }
    if marker == '.' {
      if !class_selector_matches(node, name) {
        return false
      }
    } else if !id_selector_matches(node, name) {
      return false
    }
    pos = end
  }
  true
}
