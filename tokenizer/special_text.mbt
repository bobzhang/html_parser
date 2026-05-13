///|
pub fn is_tag_name_start(ch : Char) -> Bool {
  ch.is_ascii_alphabetic()
}

///|
pub fn is_tag_name_end(ch : Char) -> Bool {
  ch.is_ascii_whitespace() || ch == '/' || ch == '>'
}

///|
pub fn special_text_decodes_entities(name : StringView) -> Bool {
  match name {
    "title" | "textarea" => true
    _ => false
  }
}

///|
fn is_special_text_element(name : StringView) -> Bool {
  match name {
    "iframe"
    | "noembed"
    | "noframes"
    | "noscript"
    | "plaintext"
    | "script"
    | "style"
    | "title"
    | "textarea"
    | "xmp" => true
    _ => false
  }
}

///|
pub fn find_matching_end_tag(
  input : StringView,
  start : Int,
  name : StringView,
) -> Int? {
  let needle = "</" + name.to_owned()
  let mut pos = start
  while pos < input.length() {
    if @syn.starts_with_case_insensitive(input, pos, needle) {
      let after_name = pos + needle.length()
      match input.get_char(after_name) {
        Some('>') => return Some(pos)
        Some('/') => return Some(pos)
        Some(ch) if ch.is_ascii_whitespace() => return Some(pos)
        _ => ()
      }
    }
    match input.get_char(pos) {
      Some(ch) => pos += ch.utf16_len()
      None => break
    }
  }
  None
}

///|
pub fn matching_end_tag_error_pos(input : StringView, start : Int) -> Int {
  let mut pos = start
  while pos < input.length() {
    match input.get_char(pos) {
      Some('>') => return pos
      Some(ch) => pos += ch.utf16_len()
      None => break
    }
  }
  @syn.eof_error_pos(input)
}
