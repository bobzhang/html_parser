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
