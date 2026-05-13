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

///|
fn selector_uses_byte_scanned_match(selector : StringView) -> Bool {
  string_view_contains(selector, "*=") ||
  string_view_contains(@syn.lower_ascii(selector), ":contains")
}

///|
fn selector_match_byte_cost(node : @dom.Node, include_text : Bool) -> Int {
  let mut cost = 0
  for _, value in node.attrs {
    match value {
      Some(raw) => cost += raw.length()
      None => ()
    }
  }
  if include_text {
    cost += selector_text_content(node).length()
  }
  cost
}

///|
fn selector_check_match_budget(
  node : @dom.Node,
  selector : StringView,
  limits : SelectorLimits,
) -> Unit raise @core.HtmlError {
  if limits.max_match_bytes < 0 {
    raise SelectorError("Selector match byte budget exceeded")
  }
  if selector_uses_byte_scanned_match(selector) {
    let include_text = string_view_contains(
      @syn.lower_ascii(selector),
      ":contains",
    )
    if selector_match_byte_cost(node, include_text) > limits.max_match_bytes {
      raise SelectorError("Selector match byte budget exceeded")
    }
  }
}

///|
priv struct SelectorMatchContext {
  limits : SelectorLimits
  mut remaining_steps : Int
}

///|
fn SelectorMatchContext::new(limits : SelectorLimits) -> SelectorMatchContext {
  { limits, remaining_steps: limits.max_match_steps }
}

///|
fn SelectorMatchContext::tick(
  self : SelectorMatchContext,
  steps? : Int = 1,
) -> Unit raise @core.HtmlError {
  if steps <= 0 {
    return
  }
  self.remaining_steps -= steps
  if self.remaining_steps < 0 {
    raise SelectorError("Selector match budget exceeded")
  }
}

///|
fn previous_matching_sibling_with_context(
  node : @dom.Node,
  selector : StringView,
  context : SelectorMatchContext,
  depth : Int,
) -> @dom.Node? raise @core.HtmlError {
  match node.parent {
    Some(parent) => {
      let mut previous_match : @dom.Node? = None
      for child in parent.children {
        context.tick()
        if physical_equal(child, node) {
          return previous_match
        }
        if child.kind == Element &&
          matches_simple_selector_with_context(child, selector, context, depth) {
          previous_match = Some(child)
        }
      }
      None
    }
    None => None
  }
}

///|
fn previous_element_sibling_with_context(
  node : @dom.Node,
  context : SelectorMatchContext,
) -> @dom.Node? raise @core.HtmlError {
  match node.parent {
    Some(parent) => {
      let mut previous : @dom.Node? = None
      for child in parent.children {
        context.tick()
        if physical_equal(child, node) {
          return previous
        }
        if child.kind == Element {
          previous = Some(child)
        }
      }
      None
    }
    None => None
  }
}

///|
fn matches_complex_selector_with_context(
  node : @dom.Node,
  selector : StringView,
  context : SelectorMatchContext,
  depth : Int,
) -> Bool raise @core.HtmlError {
  context.tick()
  if depth > context.limits.max_match_depth {
    raise SelectorError("Selector nesting is too deep")
  }
  guard split_complex_selector(selector) is Some((parts, combinators)) else {
    return false
  }
  let last_index = parts.length() - 1
  if !matches_simple_selector_with_context(
      node,
      parts[last_index],
      context,
      depth,
    ) {
    return false
  }
  let mut needed = last_index - 1
  let mut current = node
  while needed >= 0 {
    context.tick()
    let wanted = parts[needed]
    match combinators[needed] {
      DescendantCombinator => {
        let visited : Array[@dom.Node] = [current]
        let mut cursor = current.parent
        let mut found = false
        while !found {
          context.tick()
          match cursor {
            Some(ancestor) => {
              if node_identity_seen(visited, ancestor) {
                return false
              }
              visited.push(ancestor)
              if matches_simple_selector_with_context(
                  ancestor, wanted, context, depth,
                ) {
                current = ancestor
                found = true
              } else {
                cursor = ancestor.parent
              }
            }
            None => return false
          }
        }
      }
      ChildCombinator =>
        match current.parent {
          Some(ancestor) => {
            if !matches_simple_selector_with_context(
                ancestor, wanted, context, depth,
              ) {
              return false
            }
            current = ancestor
          }
          None => return false
        }
      AdjacentSiblingCombinator =>
        match previous_element_sibling_with_context(current, context) {
          Some(sibling) => {
            if !matches_simple_selector_with_context(
                sibling, wanted, context, depth,
              ) {
              return false
            }
            current = sibling
          }
          None => return false
        }
      GeneralSiblingCombinator =>
        match
          previous_matching_sibling_with_context(
            current, wanted, context, depth,
          ) {
          Some(sibling) => current = sibling
          None => return false
        }
    }
    needed -= 1
  }
  true
}

///|
fn matches_selector_list_with_context(
  node : @dom.Node,
  selector : StringView,
  context : SelectorMatchContext,
  depth : Int,
) -> Bool raise @core.HtmlError {
  context.tick()
  if depth > context.limits.max_match_depth {
    raise SelectorError("Selector nesting is too deep")
  }
  guard selector_list_parts(selector) is Some(parts) else { return false }
  for part in parts {
    if !complex_selector_is_valid(part) {
      return false
    }
  }
  for part in parts {
    selector_check_match_budget(node, part, context.limits)
    if matches_complex_selector_with_context(node, part, context, depth) {
      return true
    }
  }
  false
}

///|
pub fn matches_with_limits(
  node : @dom.Node,
  selector : StringView,
  limits : SelectorLimits,
) -> Bool raise @core.HtmlError {
  selector_validate_limits(selector, limits)
  matches_selector_list_with_context(
    node,
    selector,
    SelectorMatchContext::new(limits),
    0,
  )
}

///|
fn node_identity_seen(nodes : Array[@dom.Node], node : @dom.Node) -> Bool {
  for seen in nodes {
    if physical_equal(seen, node) {
      return true
    }
  }
  false
}

///|
fn walk_query(
  node : @dom.Node,
  selector : StringView,
  out : Array[@dom.Node],
  allow_non_elements : Bool,
  visited : Array[@dom.Node],
) -> Unit {
  if node_identity_seen(visited, node) {
    return
  }
  visited.push(node)
  if (allow_non_elements || node.kind == Element) &&
    matches_selector_list(node, selector) {
    out.push(node)
  }
  for child in node.children {
    walk_query(child, selector, out, allow_non_elements, visited)
  }
}

///|
/// Return all descendants of `root` that match a CSS selector.
pub fn query(root : @dom.Node, selector : StringView) -> Array[@dom.Node] {
  let out : Array[@dom.Node] = []
  let allow_non_elements = selector_allows_non_elements(selector)
  let visited : Array[@dom.Node] = [root]
  for child in root.children {
    walk_query(child, selector, out, allow_non_elements, visited)
  }
  out
}

///|
/// Return the first descendant of `root` that matches a CSS selector.
pub fn query_one(root : @dom.Node, selector : StringView) -> @dom.Node? {
  query(root, selector).get(0)
}

///|
/// Return whether `node` itself matches a CSS selector.
pub fn matches(node : @dom.Node, selector : StringView) -> Bool {
  matches_selector_list(node, selector)
}

///|

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
