///|
fn is_html_whitespace_char(ch : Char) -> Bool {
  match ch {
    ' ' | '\t' | '\n' | '\r' | '\u{000C}' => true
    _ => false
  }
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
