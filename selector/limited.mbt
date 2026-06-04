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
        context.tick(1)
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
        context.tick(1)
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
  context.tick(1)
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
    context.tick(1)
    let wanted = parts[needed]
    match combinators[needed] {
      DescendantCombinator => {
        let visited : Array[@dom.Node] = [current]
        let mut cursor = current.parent
        let mut found = false
        while !found {
          context.tick(1)
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
  context.tick(1)
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
/// Test whether `node` matches a selector under explicit resource limits.
///
/// The selector is validated against `limits` before matching. Invalid
/// selectors return `false`; selectors that exceed configured depth, length, or
/// match-budget limits raise `HtmlError`.
pub fn matches_with_limits(
  node : @dom.Node,
  selector : StringView,
  limits : SelectorLimits,
) -> Bool raise @core.HtmlError {
  selector_validate_limits(selector, limits)
  matches_selector_list_with_context(
    node,
    selector,
    SelectorMatchContext(limits),
    0,
  )
}
