///|
fn is_xml_noncharacter(ch : Char) -> Bool {
  let code = ch.to_int()
  if code >= 0xFDD0 && code <= 0xFDEF {
    return true
  }
  let low = code % 0x10000
  low == 0xFFFE || low == 0xFFFF
}

///|
fn coerce_text_for_xml(input : StringView) -> String {
  let out = StringBuilder::new(size_hint=input.length())
  for ch in input {
    if ch == '\u{000C}' {
      out.write_char(' ')
    } else if is_xml_noncharacter(ch) {
      out.write_char('\u{FFFD}')
    } else {
      out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn coerce_comment_for_xml(input : StringView) -> String {
  input.to_owned().replace_all(old="--", new="- -")
}
