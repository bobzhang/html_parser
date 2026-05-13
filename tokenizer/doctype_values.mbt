///|
pub fn parse_quoted_doctype_value_at(
  input : StringView,
  start : Int,
  errors : Array[DoctypeExternalError],
) -> (String?, Int, Bool) {
  match input.get_char(start) {
    Some('"') | Some('\'') as quote_opt => {
      guard quote_opt is Some(quote)
      let mut pos = start + quote.utf16_len()
      let value_start = pos
      while pos < input.length() && input.get_char(pos) != Some(quote) {
        let ch = input.get_char(pos).unwrap()
        pos += ch.utf16_len()
      }
      let mut closed = false
      let value = Some(normalize_doctype_value(input, value_start, pos, errors))
      if input.get_char(pos) == Some(quote) {
        pos += quote.utf16_len()
        closed = true
      }
      (value, pos, closed)
    }
    _ => (None, start, false)
  }
}

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
pub fn normalize_doctype_value(
  input : StringView,
  start : Int,
  end : Int,
  errors : Array[DoctypeExternalError],
) -> String {
  let out = StringBuilder::new(size_hint=end - start)
  let mut pos = start
  while pos < end {
    match input.get_char(pos) {
      Some('\u{0000}') => {
        push_doctype_external_error(errors, "unexpected-null-character", pos)
        out.write_char('\u{FFFD}')
        pos += 1
      }
      Some('\r') => {
        out.write_char('\n')
        pos += 1
        if pos < end && input.get_char(pos) is Some('\n') {
          pos += 1
        }
      }
      Some(ch) => {
        out.write_char(ch)
        pos += ch.utf16_len()
      }
      None => break
    }
  }
  out.to_string()
}

///|
pub fn parse_lower_name_value_replacing_nulls(
  input : StringView,
  start : Int,
  end : Int,
) -> (String, Array[DoctypeExternalError]) {
  let errors : Array[DoctypeExternalError] = []
  if start >= end {
    return ("", errors)
  }
  let out = StringBuilder::new(size_hint=end - start)
  let mut pos = start
  while pos < end {
    match input.get_char(pos) {
      Some('\u{0000}') => {
        push_doctype_external_error(errors, "unexpected-null-character", pos)
        out.write_char('\u{FFFD}')
        pos += 1
      }
      Some(ch) => {
        if ch.is_ascii_uppercase() {
          out.write_char(ch.to_ascii_lowercase())
        } else {
          out.write_char(ch)
        }
        pos += ch.utf16_len()
      }
      None => break
    }
  }
  (out.to_string(), errors)
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
pub fn doctype_eof_error_offset(input : StringView) -> Int {
  if @syn.input_ends_with_newline(input) {
    input.length()
  } else {
    view_last_char_offset(input)
  }
}

///|
fn push_doctype_external_error(
  errors : Array[DoctypeExternalError],
  code : String,
  offset : Int,
) -> Unit {
  errors.push({ code, offset })
}
