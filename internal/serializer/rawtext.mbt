///|
fn serialize_comment_data(value : StringView) -> String {
  let mut out = value.replace_all(old="--", new="- -").to_owned()
  if out.has_prefix(">") || out.has_prefix("->") {
    out = " " + out
  }
  if out.has_suffix("<!-") || out.has_suffix("-") {
    out = out + " "
  }
  out
}

///|
/// Escape raw-text end-tag openings that would prematurely close `tag_name`.
///
/// Case-insensitive `</tag_name` sequences followed by `>`, `/`, whitespace,
/// or EOF are rewritten by escaping only the `<` as `&lt;`. Other text is left
/// unchanged.
pub fn neutralize_rawtext_end_tag_sequences(
  value : StringView,
  tag_name : StringView,
) -> String {
  let needle = "</" + tag_name.to_owned()
  let out = StringBuilder(size_hint=value.length())
  let mut pos = 0
  while pos < value.length() {
    if rawtext_end_tag_sequence_at(value, pos, needle) {
      out.write_string("&lt;")
      pos += 1
    } else {
      let ch = value.get_char(pos).unwrap()
      out.write_char(ch)
      pos += ch.utf16_len()
    }
  }
  out.to_string()
}

///|
fn rawtext_end_tag_sequence_at(
  value : StringView,
  pos : Int,
  needle : StringView,
) -> Bool {
  if @syn.starts_with_case_insensitive(value, pos, needle) {
    rawtext_end_tag_boundary(value.get_char(pos + needle.length()))
  } else {
    false
  }
}

///|
fn rawtext_end_tag_boundary(ch : Char?) -> Bool {
  match ch {
    None | Some('>') | Some('/') => true
    Some(ch) if is_html_whitespace_char(ch) => true
    _ => false
  }
}
