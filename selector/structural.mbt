///|
fn is_first_element_child(node : @dom.Node) -> Bool {
  match node.parent {
    Some(parent) => {
      for child in parent.children {
        if child.kind == Element {
          return physical_equal(child, node)
        }
      }
      false
    }
    None => false
  }
}

///|
fn is_last_element_child(node : @dom.Node) -> Bool {
  match node.parent {
    Some(parent) => {
      let mut last : @dom.Node? = None
      for child in parent.children {
        if child.kind == Element {
          last = Some(child)
        }
      }
      match last {
        Some(child) => physical_equal(child, node)
        None => false
      }
    }
    None => false
  }
}

///|
fn is_only_element_child(node : @dom.Node) -> Bool {
  is_first_element_child(node) && is_last_element_child(node)
}

///|
fn is_empty_for_selector(node : @dom.Node) -> Bool {
  for child in node.children {
    match child.kind {
      Element => return false
      Text if !child.data[:].trim().is_empty() => return false
      _ => ()
    }
  }
  true
}

///|
fn is_root_for_selector(node : @dom.Node) -> Bool {
  match node.parent {
    Some(parent) => parent.kind == Document || parent.kind == Fragment
    None => false
  }
}

///|
fn is_first_of_type(node : @dom.Node) -> Bool {
  match node.parent {
    Some(parent) => {
      for child in parent.children {
        if child.kind == Element && child.name == node.name {
          return physical_equal(child, node)
        }
      }
      false
    }
    None => false
  }
}

///|
fn is_last_of_type(node : @dom.Node) -> Bool {
  match node.parent {
    Some(parent) => {
      let mut last : @dom.Node? = None
      for child in parent.children {
        if child.kind == Element && child.name == node.name {
          last = Some(child)
        }
      }
      match last {
        Some(child) => physical_equal(child, node)
        None => false
      }
    }
    None => false
  }
}

///|
fn is_only_of_type(node : @dom.Node) -> Bool {
  is_first_of_type(node) && is_last_of_type(node)
}

///|
fn element_child_index(node : @dom.Node) -> Int? {
  match node.parent {
    Some(parent) => {
      let mut index = 0
      for child in parent.children {
        if child.kind == Element {
          index += 1
          if physical_equal(child, node) {
            return Some(index)
          }
        }
      }
      None
    }
    None => None
  }
}

///|
fn element_type_index(node : @dom.Node) -> Int? {
  match node.parent {
    Some(parent) => {
      let mut index = 0
      for child in parent.children {
        if child.kind == Element && child.name == node.name {
          index += 1
          if physical_equal(child, node) {
            return Some(index)
          }
        }
      }
      None
    }
    None => None
  }
}

///|
fn normalize_nth_expression(expr : StringView) -> String {
  let out = StringBuilder(size_hint=expr.length())
  for ch in expr {
    if !ch.is_ascii_whitespace() {
      if ch.is_ascii_uppercase() {
        out.write_char(ch.to_ascii_lowercase())
      } else {
        out.write_char(ch)
      }
    }
  }
  out.to_string()
}

///|
fn parse_signed_int_view(expr : StringView) -> Int? {
  if expr.is_empty() {
    return None
  }
  let mut sign = 1
  let mut pos = 0
  match expr.get_char(pos) {
    Some('+') => pos += 1
    Some('-') => {
      sign = -1
      pos += 1
    }
    _ => ()
  }
  if pos >= expr.length() {
    return None
  }
  // A number past the range of `Int` is rejected rather than allowed to wrap
  // around to a small one, so it matches nothing, as in browsers. The bound
  // is one larger for negative numbers, which reach -2147483648.
  let limit = if sign < 0 { 2147483648L } else { 2147483647L }
  let mut value = 0L
  while pos < expr.length() {
    match expr.get_char(pos) {
      Some(ch) if ch.is_digit(10) => {
        let digit = (ch.to_int() - ('0' : Int)).to_int64()
        if value > (limit - digit) / 10L {
          return None
        }
        value = value * 10L + digit
        pos += ch.utf16_len()
      }
      _ => return None
    }
  }
  Some((sign.to_int64() * value).to_int())
}

///|
fn parse_nth_expression(expr : StringView) -> (Int, Int)? {
  let normalized = normalize_nth_expression(expr)
  let expr = normalized[:]
  if expr.is_empty() {
    return None
  }
  if expr == "odd" {
    return Some((2, 1))
  }
  if expr == "even" {
    return Some((2, 0))
  }
  match expr.split_once("n") {
    Some((a_part, b_part)) => {
      if string_view_contains(b_part, "n") {
        return None
      }
      let a = if a_part.is_empty() || a_part == "+" {
        Some(1)
      } else if a_part == "-" {
        Some(-1)
      } else {
        parse_signed_int_view(a_part)
      }
      guard a is Some(a) else { return None }
      let b = if b_part.is_empty() {
        Some(0)
      } else {
        parse_signed_int_view(b_part)
      }
      guard b is Some(b) else { return None }
      Some((a, b))
    }
    None => parse_signed_int_view(expr).map(b => (0, b))
  }
}

///|
fn nth_formula_matches(index : Int, a : Int, b : Int) -> Bool {
  if a == 0 {
    index == b
  } else {
    // In `Int64`: `index - b` overflows `Int` when `b` is far below zero.
    let diff = index.to_int64() - b.to_int64()
    let a = a.to_int64()
    if a > 0L {
      diff >= 0L && diff % a == 0L
    } else {
      diff <= 0L && diff % a == 0L
    }
  }
}

///|
fn is_nth_child(node : @dom.Node, expr : StringView) -> Bool {
  guard parse_nth_expression(expr) is Some((a, b)) else { return false }
  match element_child_index(node) {
    Some(index) => nth_formula_matches(index, a, b)
    None => false
  }
}

///|
fn is_nth_of_type(node : @dom.Node, expr : StringView) -> Bool {
  guard parse_nth_expression(expr) is Some((a, b)) else { return false }
  match element_type_index(node) {
    Some(index) => nth_formula_matches(index, a, b)
    None => false
  }
}
