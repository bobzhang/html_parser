///|
/// Parse a quoted doctype identifier beginning at `start`.
///
/// `start` should point at either a single or double quote. The result contains
/// the normalized value if a quote was present, the next UTF-16 offset to scan,
/// and whether a matching closing quote was consumed. Null-character errors
/// are appended to `errors`.
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
/// Normalize a doctype identifier slice.
///
/// Scans `input[start:end]`, replacing null characters with U+FFFD and
/// reporting `unexpected-null-character` at their original offsets. CRLF and
/// bare CR are normalized to LF; all other characters are copied unchanged.
pub fn normalize_doctype_value(
  input : StringView,
  start : Int,
  end : Int,
  errors : Array[DoctypeExternalError],
) -> String {
  let out = StringBuilder::StringBuilder(size_hint=end - start)
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
/// Normalize a doctype name slice for token emission.
///
/// ASCII uppercase letters are folded to lowercase. Null characters are
/// replaced with U+FFFD and reported in the returned error list. Offsets in
/// those errors refer to the original `input`.
pub fn parse_lower_name_value_replacing_nulls(
  input : StringView,
  start : Int,
  end : Int,
) -> (String, Array[DoctypeExternalError]) {
  let errors : Array[DoctypeExternalError] = []
  if start >= end {
    return ("", errors)
  }
  let out = StringBuilder::StringBuilder(size_hint=end - start)
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
/// Return the UTF-16 offset used for doctype EOF diagnostics.
///
/// EOF after a final newline reports `input.length()`. Other non-empty inputs
/// report the offset of the last character, matching tokenizer diagnostic
/// positions.
pub fn doctype_eof_error_offset(input : StringView) -> Int {
  if @syn.input_ends_with_newline(input) {
    input.length()
  } else {
    view_last_char_offset(input)
  }
}
