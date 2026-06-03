///|
/// Return whether `ch` can begin an HTML tag name in this tokenizer.
///
/// The tokenizer accepts ASCII letters as tag-name starts. Other characters
/// after `<` are treated as invalid tag opens or text, depending on context.
pub fn is_tag_name_start(ch : Char) -> Bool {
  ch.is_ascii_alphabetic()
}

///|
/// Return whether `ch` terminates a tag name.
///
/// Tag names end before ASCII whitespace, `/`, or `>`.
pub fn is_tag_name_end(ch : Char) -> Bool {
  ch.is_ascii_whitespace() || ch == '/' || ch == '>'
}

///|
/// Return whether special-text content for `name` decodes entities.
///
/// HTML RCDATA elements `title` and `textarea` decode character references;
/// raw-text elements such as `style`, `script`, and `xmp` do not.
pub fn special_text_decodes_entities(name : StringView) -> Bool {
  match name {
    "title" | "textarea" => true
    _ => false
  }
}

///|
/// Return whether `name` uses HTML's special-text tokenization path.
///
/// Special-text elements do not tokenize child markup normally: RCDATA elements
/// decode entities until their matching end tag, raw-text elements scan text
/// literally, and `plaintext` consumes the rest of the input as text.
pub fn is_special_text_element(name : StringView) -> Bool {
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
/// Find a matching special-text end tag.
///
/// Searches from UTF-16 offset `start` for `</` followed by `name`, comparing
/// the tag name ASCII-case-insensitively. A match must be followed by `>`, `/`,
/// or ASCII whitespace. The returned offset points at the `<` of the end tag.
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
/// Return the diagnostic offset for a matching special-text end tag.
///
/// Starting at the end tag's `<`, this returns the offset of the closing `>` if
/// present; otherwise it returns the EOF diagnostic offset for `input`.
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
