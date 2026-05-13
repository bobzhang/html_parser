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

///|
fn linkify_count_char(
  text : StringView,
  start : Int,
  end : Int,
  needle : Char,
) -> Int {
  let mut count = 0
  for ch in text[start:end] {
    if ch == needle {
      count += 1
    }
  }
  count
}

///|
fn linkify_find_substring(haystack : StringView, needle : StringView) -> Int? {
  if needle.is_empty() || needle.length() > haystack.length() {
    return None
  }
  let mut pos = 0
  for ch in haystack {
    if pos + needle.length() > haystack.length() {
      break
    }
    match haystack.get_view(start=pos, end=pos + needle.length()) {
      Some(part) if part == needle => return Some(pos)
      _ => ()
    }
    pos += ch.utf16_len()
  }
  None
}

///|
fn linkify_parse_uint(value : StringView) -> Int? {
  if value.is_empty() {
    return None
  }
  let mut out = 0
  for ch in value {
    if !ch.is_digit(10) {
      return None
    }
    out = out * 10 + ch.to_int() - ('0' : Int)
  }
  Some(out)
}

///|
fn linkify_last_char_index(value : StringView, needle : Char) -> Int? {
  let mut pos = 0
  let mut last : Int? = None
  for ch in value {
    if ch == needle {
      last = Some(pos)
    }
    pos += ch.utf16_len()
  }
  last
}

///|
fn linkify_starts_with_digit(value : StringView) -> Bool {
  match value.get_char(0) {
    Some(ch) => ch >= '0' && ch <= '9'
    None => false
  }
}

///|
fn linkify_all_digits_or_dots(value : StringView) -> Bool {
  if value.is_empty() {
    return false
  }
  for ch in value {
    if !(ch == '.' || (ch >= '0' && ch <= '9')) {
      return false
    }
  }
  true
}

///|
fn linkify_ascii_alnum(ch : Char) -> Bool {
  (ch >= '0' && ch <= '9') ||
  (ch >= 'A' && ch <= 'Z') ||
  (ch >= 'a' && ch <= 'z')
}

///|
fn linkify_fuzzy_start_char(ch : Char) -> Bool {
  linkify_ascii_alnum(ch) || ch.to_int() > 127
}
