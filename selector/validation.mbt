///|
fn selector_simple_component_count(selector : StringView) -> Int? {
  let selector = selector.trim()
  if !simple_selector_is_valid(selector) {
    return None
  }
  let mut count = 0
  let mut pos = 0
  match selector.get_char(pos).unwrap() {
    '*' => {
      count += 1
      pos += 1
    }
    '.' | '#' | '[' | ':' => ()
    _ => {
      count += 1
      pos = next_simple_selector_marker(selector, pos)
    }
  }
  while pos < selector.length() {
    let marker = selector.get_char(pos).unwrap()
    count += 1
    if marker == '[' {
      let end = find_attribute_selector_end(selector, pos).unwrap()
      pos = end + 1
    } else if marker == ':' {
      let start = pos + marker.utf16_len()
      pos = next_simple_selector_marker(selector, start)
    } else if marker == '.' || marker == '#' {
      let start = pos + marker.utf16_len()
      pos = next_simple_selector_marker(selector, start)
    }
  }
  Some(count)
}

///|
fn selector_validate_simple_parse_depth(
  selector : StringView,
  limits : SelectorLimits,
  depth : Int,
) -> Unit raise @core.HtmlError {
  let selector = selector.trim()
  if selector.is_empty() {
    return
  }
  let mut pos = 0
  match selector.get_char(pos).unwrap() {
    '*' => pos += 1
    '.' | '#' | '[' | ':' => ()
    _ => pos = next_simple_selector_marker(selector, pos)
  }
  while pos < selector.length() {
    let marker = selector.get_char(pos).unwrap()
    if marker == '[' {
      match find_attribute_selector_end(selector, pos) {
        Some(end) => pos = end + 1
        None => return
      }
      continue
    }
    if marker == ':' {
      let start = pos + marker.utf16_len()
      let end = next_simple_selector_marker(selector, start)
      let name = selector[start:end]
      match functional_pseudo_parts(name) {
        Some((pseudo_name, arg)) =>
          if @syn.lower_ascii(pseudo_name) == "not" {
            selector_validate_limits_at_depth(arg, limits, depth + 1)
          }
        None => ()
      }
      pos = end
      continue
    }
    if marker == '.' || marker == '#' {
      let start = pos + marker.utf16_len()
      pos = next_simple_selector_marker(selector, start)
    } else {
      return
    }
  }
}

///|
fn selector_validate_limits_at_depth(
  selector : StringView,
  limits : SelectorLimits,
  depth : Int,
) -> Unit raise @core.HtmlError {
  if depth > limits.max_parse_depth {
    raise SelectorError("Selector nesting is too deep")
  }
  if selector.length() > limits.max_length {
    raise SelectorError("Selector too long")
  }
  guard selector_list_parts(selector) is Some(parts) else { return }
  if parts.length() > limits.max_list_items {
    raise SelectorError("Selector list has too many items")
  }
  for part in parts {
    guard split_complex_selector(part) is Some((simple_parts, _)) else {
      continue
    }
    if simple_parts.length() > limits.max_complex_selector_parts {
      raise SelectorError("Selector has too many complex parts")
    }
    for simple in simple_parts {
      match selector_simple_component_count(simple) {
        Some(count) if count > limits.max_compound_simple_selectors =>
          raise SelectorError("Selector has too many simple selectors")
        _ => ()
      }
      selector_validate_simple_parse_depth(simple, limits, depth)
    }
  }
}

///|
fn selector_validate_limits(
  selector : StringView,
  limits : SelectorLimits,
) -> Unit raise @core.HtmlError {
  selector_validate_limits_at_depth(selector, limits, 0)
}
