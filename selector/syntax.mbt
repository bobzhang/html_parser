///|
fn is_html_whitespace_char(ch : Char) -> Bool {
  match ch {
    ' ' | '\t' | '\n' | '\r' | '\u{000C}' => true
    _ => false
  }
}

///|
fn next_simple_selector_marker(selector : StringView, start : Int) -> Int {
  let mut pos = start
  let mut paren_depth = 0
  while pos < selector.length() {
    let ch = selector.get_char(pos).unwrap()
    if ch == '(' {
      paren_depth += 1
    } else if ch == ')' && paren_depth > 0 {
      paren_depth -= 1
    } else if paren_depth == 0 &&
      (ch == '.' || ch == '#' || ch == '[' || ch == ':') {
      return pos
    }
    pos += ch.utf16_len()
  }
  selector.length()
}

///|
fn find_attribute_selector_end(selector : StringView, start : Int) -> Int? {
  let mut pos = start + 1
  let mut quote : Char? = None
  let mut escaped = false
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
        if ch == '"' || ch == '\'' {
          quote = Some(ch)
          escaped = false
        } else if ch == ']' {
          return Some(pos)
        }
    }
    pos += ch.utf16_len()
  }
  None
}

///|
fn selector_identifier_start(ch : Char) -> Bool {
  ch == '_' || ch == '-' || ch.is_ascii_alphabetic() || ch.to_int() > 127
}

///|
fn selector_identifier_char(ch : Char) -> Bool {
  selector_identifier_start(ch) || ch.is_digit(10)
}

///|
fn selector_identifier_is_valid(name : StringView) -> Bool {
  if name.is_empty() {
    return false
  }
  guard name.get_char(0) is Some(first) else { return false }
  if !selector_identifier_start(first) {
    return false
  }
  let mut pos = first.utf16_len()
  while pos < name.length() {
    match name.get_char(pos) {
      Some(ch) if selector_identifier_char(ch) => pos += ch.utf16_len()
      _ => return false
    }
  }
  true
}

///|
fn string_view_has_html_whitespace(value : StringView) -> Bool {
  for ch in value {
    if is_html_whitespace_char(ch) {
      return true
    }
  }
  false
}

///|
fn string_view_contains(haystack : StringView, needle : StringView) -> Bool {
  if needle.is_empty() || needle.length() > haystack.length() {
    return false
  }
  let mut pos = 0
  while pos + needle.length() <= haystack.length() {
    match haystack.get_view(start=pos, end=pos + needle.length()) {
      Some(part) if part == needle => return true
      _ => ()
    }
    pos += haystack.get_char(pos).unwrap().utf16_len()
  }
  false
}
