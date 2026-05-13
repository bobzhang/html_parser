///|
fn skip_ascii_whitespace_in_view(input : StringView, start : Int) -> Int {
  let mut pos = start
  while pos < input.length() {
    match input.get_char(pos) {
      Some(ch) if ch.is_ascii_whitespace() => pos += ch.utf16_len()
      _ => break
    }
  }
  pos
}

///|
fn view_has_prefix_case_insensitive_at(
  input : StringView,
  start : Int,
  prefix : StringView,
) -> Bool {
  let end = start + prefix.length()
  if end > input.length() {
    false
  } else {
    input[start:end].compare_ignore_ascii_case(prefix) == 0
  }
}

///|
fn view_last_char_offset(input : StringView) -> Int {
  let mut last = 0
  let mut pos = 0
  while pos < input.length() {
    last = pos
    let ch = input.get_char(pos).unwrap()
    pos += ch.utf16_len()
  }
  last
}

///|
fn push_doctype_external_error(
  errors : Array[DoctypeExternalError],
  code : String,
  offset : Int,
) -> Unit {
  errors.push({ code, offset })
}
