///|
fn is_ascii_url_boundary(ch : Char) -> Bool {
  ch == '/' || ch == '?' || ch == '#'
}

///|
fn is_url_scheme_start(ch : Char) -> Bool {
  ch.is_ascii_alphabetic()
}

///|
fn is_url_scheme_char(ch : Char) -> Bool {
  ch.is_ascii_alphabetic() ||
  (ch >= '0' && ch <= '9') ||
  ch == '+' ||
  ch == '-' ||
  ch == '.'
}

///|
fn is_url_ignored_scheme_char(ch : Char) -> Bool {
  let code = ch.to_int()
  code <= 0x20 || code == 0x7F
}

///|
fn string_contains_forbidden_url_char(value : StringView) -> Bool {
  for ch in value {
    let code = ch.to_int()
    if code < 0x20 || code == 0x7F || ch == '\\' {
      return true
    }
  }
  false
}

///|
fn normalize_url_for_checking(value : StringView) -> String {
  let out = StringBuilder::StringBuilder(size_hint=value.length())
  for ch in value {
    if !is_url_ignored_scheme_char(ch) {
      out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn extract_url_scheme(value : StringView) -> String? {
  let out = StringBuilder::StringBuilder()
  let mut pos = 0
  let mut saw_scheme_char = false
  while pos < value.length() {
    let ch = value.get_char(pos).unwrap()
    if is_ascii_url_boundary(ch) {
      return None
    } else if ch == ':' {
      if saw_scheme_char {
        return Some(out.to_string())
      } else {
        return None
      }
    } else if is_url_ignored_scheme_char(ch) {
      pos += ch.utf16_len()
    } else {
      if !saw_scheme_char {
        if !is_url_scheme_start(ch) {
          return None
        }
        saw_scheme_char = true
      } else if !is_url_scheme_char(ch) {
        return None
      }
      if ch.is_ascii_uppercase() {
        out.write_char(ch.to_ascii_lowercase())
      } else {
        out.write_char(ch)
      }
      pos += ch.utf16_len()
    }
  }
  None
}

///|
fn url_scheme_prefix_is_valid(value : StringView, end : Int) -> Bool {
  let mut pos = 0
  let mut saw_scheme_char = false
  while pos < end {
    let ch = value.get_char(pos).unwrap()
    if is_url_ignored_scheme_char(ch) {
      pos += ch.utf16_len()
    } else {
      if !saw_scheme_char {
        if !is_url_scheme_start(ch) {
          return false
        }
        saw_scheme_char = true
      } else if !is_url_scheme_char(ch) {
        return false
      }
      pos += ch.utf16_len()
    }
  }
  saw_scheme_char
}

///|
fn has_invalid_scheme_like_prefix(value : StringView) -> Bool {
  let mut pos = 0
  while pos < value.length() {
    let ch = value.get_char(pos).unwrap()
    match ch {
      ':' =>
        if pos == 0 {
          return false
        } else {
          return !url_scheme_prefix_is_valid(value, pos)
        }
      _ if is_ascii_url_boundary(ch) => return false
      _ => pos += ch.utf16_len()
    }
  }
  false
}
