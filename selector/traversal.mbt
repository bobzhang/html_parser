///|
fn previous_element_sibling(node : @dom.Node) -> @dom.Node? {
  match node.parent {
    Some(parent) => {
      let mut previous : @dom.Node? = None
      for child in parent.children {
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
fn previous_matching_sibling(
  node : @dom.Node,
  selector : StringView,
) -> @dom.Node? {
  match node.parent {
    Some(parent) => {
      let mut previous_match : @dom.Node? = None
      for child in parent.children {
        if physical_equal(child, node) {
          return previous_match
        }
        if child.kind == Element && matches_simple_selector(child, selector) {
          previous_match = Some(child)
        }
      }
      None
    }
    None => None
  }
}

///|
fn matches_complex_selector(node : @dom.Node, selector : StringView) -> Bool {
  guard split_complex_selector(selector) is Some((parts, combinators)) else {
    return false
  }
  let last_index = parts.length() - 1
  if !matches_simple_selector(node, parts[last_index]) {
    return false
  }
  let mut needed = last_index - 1
  let mut current = node
  while needed >= 0 {
    let wanted = parts[needed]
    match combinators[needed] {
      DescendantCombinator => {
        let visited : Array[@dom.Node] = [current]
        let mut cursor = current.parent
        let mut found = false
        while !found {
          match cursor {
            Some(ancestor) => {
              if node_identity_seen(visited, ancestor) {
                return false
              }
              visited.push(ancestor)
              if matches_simple_selector(ancestor, wanted) {
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
            if !matches_simple_selector(ancestor, wanted) {
              return false
            }
            current = ancestor
          }
          None => return false
        }
      AdjacentSiblingCombinator =>
        match previous_element_sibling(current) {
          Some(sibling) => {
            if !matches_simple_selector(sibling, wanted) {
              return false
            }
            current = sibling
          }
          None => return false
        }
      GeneralSiblingCombinator =>
        match previous_matching_sibling(current, wanted) {
          Some(sibling) => current = sibling
          None => return false
        }
    }
    needed -= 1
  }
  true
}

///|
fn complex_selector_is_valid(selector : StringView) -> Bool {
  guard split_complex_selector(selector) is Some((parts, _)) else {
    return false
  }
  for part in parts {
    if !simple_selector_is_valid(part) {
      return false
    }
  }
  true
}

///|
fn matches_selector_list(node : @dom.Node, selector : StringView) -> Bool {
  guard selector_list_parts(selector) is Some(parts) else { return false }
  for part in parts {
    if !complex_selector_is_valid(part) {
      return false
    }
  }
  for part in parts {
    if matches_complex_selector(node, part) {
      return true
    }
  }
  false
}
