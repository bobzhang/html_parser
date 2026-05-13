///|
/// Return whether `node` itself matches a CSS selector.
pub fn matches(node : @dom.Node, selector : StringView) -> Bool {
  matches_selector_list(node, selector)
}

///|
/// Return whether a CSS selector parses as a non-empty selector list.
pub fn is_valid(selector : StringView) -> Bool {
  guard selector_list_parts(selector) is Some(parts) && !parts.is_empty() else {
    return false
  }
  for part in parts {
    if !complex_selector_is_valid(part) {
      return false
    }
  }
  true
}
