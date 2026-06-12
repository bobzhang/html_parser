///|
fn write_script_text_char(
  input : StringView,
  pos : Int,
  out : StringBuilder,
  errors : Array[SpecialTextError],
) -> Int {
  match input.get_char(pos) {
    Some('\u{0000}') => {
      errors.push({ code: "unexpected-null-character", offset: pos })
      out.write_char('\u{FFFD}')
      pos + 1
    }
    Some(_) => @syn.write_normalized_char(input, pos, out)
    None => pos
  }
}

///|
fn script_end_tag_at(input : StringView, pos : Int) -> Bool {
  let needle = "</script"
  if input.get_char(pos) == Some('<') &&
    @syn.starts_with_case_insensitive(input, pos, needle) {
    script_end_tag_boundary(input.get_char(pos + needle.length()))
  } else {
    false
  }
}

///|
fn script_end_tag_boundary(ch : Char?) -> Bool {
  match ch {
    Some('>') | Some('/') => true
    Some(ch) if ch.is_ascii_whitespace() => true
    _ => false
  }
}

///|
fn script_escape_boundary(ch : Char) -> Bool {
  ch.is_ascii_whitespace() || ch == '/' || ch == '>'
}

///|
fn temp_is_script(temp : String) -> Bool {
  temp[:].compare_ignore_ascii_case("script") == 0
}
