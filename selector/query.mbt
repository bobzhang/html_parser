///|
fn walk_query(
  node : @dom.Node,
  selectors : Array[PreparedComplexSelector],
  out : Array[@dom.Node],
  allow_non_elements : Bool,
  path : Array[@dom.Node],
  irregular_seen : Array[@dom.Node],
) -> Unit {
  if node_identity_seen(path, node) {
    return
  }
  path.push(node)
  irregular_seen.push(node)
  if (allow_non_elements || node.kind == Element) &&
    matches_prepared_selector_list(node, selectors) &&
    !node_identity_seen(out, node) {
    out.push(node)
  }
  match node.template_contents {
    Some(contents) =>
      for child in contents.children {
        walk_query_child(
          contents, child, selectors, out, allow_non_elements, path, irregular_seen,
        )
      }
    None => ()
  }
  for child in node.children {
    walk_query_child(
      node, child, selectors, out, allow_non_elements, path, irregular_seen,
    )
  }
  ignore(path.pop())
}

///|
fn child_parent_matches(parent : @dom.Node, child : @dom.Node) -> Bool {
  child.parent is Some(actual) && physical_equal(actual, parent)
}

///|
fn walk_query_child(
  parent : @dom.Node,
  child : @dom.Node,
  selectors : Array[PreparedComplexSelector],
  out : Array[@dom.Node],
  allow_non_elements : Bool,
  path : Array[@dom.Node],
  irregular_seen : Array[@dom.Node],
) -> Unit {
  if child_parent_matches(parent, child) {
    walk_query(child, selectors, out, allow_non_elements, path, irregular_seen)
  } else if !node_identity_seen(irregular_seen, child) {
    irregular_seen.push(child)
    walk_query(child, selectors, out, allow_non_elements, path, irregular_seen)
  }
}

///|
/// Return all descendants of `root` that match a CSS selector.
pub fn query(root : @dom.Node, selector : StringView) -> Array[@dom.Node] {
  let out : Array[@dom.Node] = []
  guard prepare_selector_list(selector) is Some(selectors) else { return out }
  let allow_non_elements = selector_allows_non_elements(selector)
  let path : Array[@dom.Node] = [root]
  let irregular_seen : Array[@dom.Node] = [root]
  match root.template_contents {
    Some(contents) =>
      for child in contents.children {
        walk_query_child(
          contents, child, selectors, out, allow_non_elements, path, irregular_seen,
        )
      }
    None => ()
  }
  for child in root.children {
    walk_query_child(
      root, child, selectors, out, allow_non_elements, path, irregular_seen,
    )
  }
  out
}

///|
/// Return the first descendant of `root` that matches a CSS selector.
pub fn query_one(root : @dom.Node, selector : StringView) -> @dom.Node? {
  query(root, selector).get(0)
}
