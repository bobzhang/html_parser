///|
fn is_html_whitespace_char(ch : Char) -> Bool {
  match ch {
    ' ' | '\t' | '\n' | '\r' | '\u{000C}' => true
    _ => false
  }
}

///|
fn collapse_html_whitespace(value : StringView) -> String {
  let out = StringBuilder::StringBuilder(size_hint=value.length())
  let mut pending_space = false
  let mut wrote = false
  for ch in value {
    if is_html_whitespace_char(ch) {
      if wrote {
        pending_space = true
      }
    } else {
      if pending_space {
        out.write_char(' ')
        pending_space = false
      }
      out.write_char(ch)
      wrote = true
    }
  }
  out.to_string()
}

///|
fn formatting_whitespace_char(ch : Char) -> Bool {
  match ch {
    '\n' | '\r' | '\t' | '\u{000C}' => true
    _ => false
  }
}

///|
fn string_view_has_formatting_whitespace(value : StringView) -> Bool {
  for ch in value {
    if formatting_whitespace_char(ch) {
      return true
    }
  }
  false
}

///|
fn compact_pretty_whitespace_separator(value : StringView) -> Bool {
  string_view_has_formatting_whitespace(value) || value.length() > 2
}

///|
fn normalize_formatting_whitespace(value : StringView) -> String {
  let mut has_formatting = false
  for ch in value {
    if formatting_whitespace_char(ch) {
      has_formatting = true
      break
    }
  }
  if !has_formatting {
    return value.to_owned()
  }
  let out : Array[String] = []
  let mut pos = 0
  while pos < value.length() {
    guard value.get_char(pos) is Some(ch) else { break }
    if formatting_whitespace_char(ch) {
      while !out.is_empty() && out.last() == Some(" ") {
        ignore(out.pop())
      }
      let mut run_has_space = false
      while pos < value.length() {
        guard value.get_char(pos) is Some(run_ch) else { break }
        if run_ch == ' ' {
          run_has_space = true
          pos += run_ch.utf16_len()
        } else if formatting_whitespace_char(run_ch) {
          pos += run_ch.utf16_len()
        } else {
          break
        }
      }
      if !out.is_empty() && (pos < value.length() || run_has_space) {
        out.push(" ")
      }
    } else {
      out.push(ch.to_string())
      pos += ch.utf16_len()
    }
  }
  out.join("")
}

///|
fn text_has_visible_char(value : StringView) -> Bool {
  for ch in value {
    if !is_html_whitespace_char(ch) {
      return true
    }
  }
  false
}
