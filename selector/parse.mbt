///|
fn selector_list_part(
  selector : StringView,
  start : Int,
  end : Int,
) -> StringView? {
  let part = selector[start:end].trim()
  if part.is_empty() {
    None
  } else {
    Some(part)
  }
}

///|
fn selector_list_parts(selector : StringView) -> Array[StringView]? {
  let selector = selector.trim()
  if selector.is_empty() {
    return None
  }
  let parts : Array[StringView] = []
  let mut start = 0
  let mut pos = 0
  let mut bracket_depth = 0
  let mut paren_depth = 0
  let mut quote : Char? = None
  let mut escaped = false
  let mut seen_part = false
  while pos < selector.length() {
    let ch = selector.get_char(pos).unwrap()
    match quote {
      Some(q) =>
        if escaped {
          escaped = false
        } else if ch == '\\' {
          escaped = true
        } else if ch == q {
          quote = None
        }
      None =>
        if bracket_depth > 0 && (ch == '"' || ch == '\'') {
          quote = Some(ch)
          escaped = false
        } else if ch == '[' {
          bracket_depth += 1
        } else if ch == ']' && bracket_depth > 0 {
          bracket_depth -= 1
        } else if bracket_depth == 0 && ch == '(' {
          paren_depth += 1
        } else if bracket_depth == 0 && ch == ')' && paren_depth > 0 {
          paren_depth -= 1
        } else if ch == ',' && bracket_depth == 0 && paren_depth == 0 {
          match selector_list_part(selector, start, pos) {
            Some(part) => {
              seen_part = true
              parts.push(part)
            }
            None => if !seen_part { return None }
          }
          start = pos + ch.utf16_len()
        }
    }
    pos += ch.utf16_len()
  }
  match selector_list_part(selector, start, selector.length()) {
    Some(part) => {
      parts.push(part)
      Some(parts)
    }
    None => if seen_part { Some(parts) } else { None }
  }
}

///|
priv enum SelectorCombinator {
  DescendantCombinator
  ChildCombinator
  AdjacentSiblingCombinator
  GeneralSiblingCombinator
} derive(Eq)

///|
priv struct PreparedComplexSelector {
  parts : Array[StringView]
  combinators : Array[SelectorCombinator]
}

///|
fn push_complex_selector_part(
  parts : Array[StringView],
  combinators : Array[SelectorCombinator],
  part : StringView,
  pending : SelectorCombinator,
) -> Unit {
  if !parts.is_empty() {
    combinators.push(pending)
  }
  parts.push(part)
}

///|
fn split_complex_selector(
  selector : StringView,
) -> (Array[StringView], Array[SelectorCombinator])? {
  let selector = selector.trim()
  if selector.is_empty() {
    return None
  }
  let parts : Array[StringView] = []
  let combinators : Array[SelectorCombinator] = []
  let mut start = 0
  let mut pos = 0
  let mut bracket_depth = 0
  let mut paren_depth = 0
  let mut quote : Char? = None
  let mut escaped = false
  let mut pending = DescendantCombinator
  while pos < selector.length() {
    let ch = selector.get_char(pos).unwrap()
    match quote {
      Some(q) =>
        if escaped {
          escaped = false
        } else if ch == '\\' {
          escaped = true
        } else if ch == q {
          quote = None
        }
      None =>
        if bracket_depth > 0 && (ch == '"' || ch == '\'') {
          quote = Some(ch)
          escaped = false
        } else if ch == '[' {
          bracket_depth += 1
        } else if ch == ']' && bracket_depth > 0 {
          bracket_depth -= 1
        } else if bracket_depth == 0 && ch == '(' {
          paren_depth += 1
        } else if bracket_depth == 0 && ch == ')' && paren_depth > 0 {
          paren_depth -= 1
        } else if bracket_depth == 0 &&
          paren_depth == 0 &&
          is_html_whitespace_char(ch) {
          match selector_list_part(selector, start, pos) {
            Some(part) => {
              push_complex_selector_part(parts, combinators, part, pending)
              pending = DescendantCombinator
            }
            None => ()
          }
          start = pos + ch.utf16_len()
        } else if bracket_depth == 0 &&
          paren_depth == 0 &&
          (ch == '>' || ch == '+' || ch == '~') {
          match selector_list_part(selector, start, pos) {
            Some(part) =>
              push_complex_selector_part(parts, combinators, part, pending)
            None =>
              if parts.is_empty() || pending != DescendantCombinator {
                return None
              }
          }
          pending = if ch == '>' {
            ChildCombinator
          } else if ch == '+' {
            AdjacentSiblingCombinator
          } else {
            GeneralSiblingCombinator
          }
          start = pos + ch.utf16_len()
        }
    }
    pos += ch.utf16_len()
  }
  match selector_list_part(selector, start, selector.length()) {
    Some(part) => push_complex_selector_part(parts, combinators, part, pending)
    None => return None
  }
  Some((parts, combinators))
}

///|
fn selector_identifier_end(selector : StringView, start : Int) -> Int {
  guard selector.get_char(start) is Some(first) else { return start }
  if !selector_identifier_start(first) {
    return start
  }
  let mut pos = start + first.utf16_len()
  while pos < selector.length() {
    match selector.get_char(pos) {
      Some(ch) if selector_identifier_char(ch) => pos += ch.utf16_len()
      _ => return pos
    }
  }
  pos
}

///|
fn selector_allows_non_elements(selector : StringView) -> Bool {
  let mut pos = 0
  let mut bracket_depth = 0
  let mut paren_depth = 0
  let mut quote : Char? = None
  let mut escaped = false
  for ch in selector {
    match quote {
      Some(q) =>
        if escaped {
          escaped = false
        } else if ch == '\\' {
          escaped = true
        } else if ch == q {
          quote = None
        }
      None =>
        if bracket_depth > 0 && (ch == '"' || ch == '\'') {
          quote = Some(ch)
          escaped = false
        } else if ch == '[' {
          bracket_depth += 1
        } else if ch == ']' && bracket_depth > 0 {
          bracket_depth -= 1
        } else if bracket_depth == 0 && ch == '(' {
          paren_depth += 1
        } else if bracket_depth == 0 && ch == ')' && paren_depth > 0 {
          paren_depth -= 1
        } else if bracket_depth == 0 && paren_depth == 0 && ch == ':' {
          let start = pos + ch.utf16_len()
          let end = selector_identifier_end(selector, start)
          if end > start {
            let name = selector[start:end]
            if @syn.lower_ascii(name) == "comment" {
              return true
            }
          }
        }
    }
    pos += ch.utf16_len()
  }
  false
}
