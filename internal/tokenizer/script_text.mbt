///|
/// Scan `<script>` raw text using HTML script-data state transitions.
///
/// `start` is the UTF-16 offset where script data begins. The scanner preserves
/// script text up to a matching `</script` end tag, handles escaped and
/// double-escaped script states, normalizes CRLF and bare CR to LF, and replaces
/// null characters with U+FFFD while collecting diagnostics. `end_start` points
/// at the `<` of the matching end tag when one is found.
pub fn scan_script_text(input : StringView, start : Int) -> ScriptTextScan {
  let errors : Array[SpecialTextError] = []
  // Fast path: script text without a `<!--` escape opener is the input
  // verbatim, so this loop only locates the end tag and the data
  // materializes as one slice copy. The escaped states are not verbatim
  // (a `<` after `--` is kept twice), so they keep the writing machine.
  let mut pos = start
  while pos < input.length() {
    if script_end_tag_at(input, pos) {
      return {
        data: scanned_data_slice(input, start, pos),
        end_start: Some(pos),
        errors,
      }
    }
    if @syn.view_starts_with_at(input, pos, "<!--") {
      return scan_escaped_script_text(input, start, pos, errors)
    }
    pos = skip_script_text_char(input, pos, errors)
  }
  { data: scanned_data_slice(input, start, pos), end_start: None, errors }
}

///|
/// Continue a script-text scan that hit a `<!--` opener at `escape_start`,
/// building the data explicitly through the escaped-state machine. The
/// builder is seeded with the (already diagnosed) verbatim prefix and grows
/// as needed instead of preallocating the rest of the document.
fn scan_escaped_script_text(
  input : StringView,
  start : Int,
  escape_start : Int,
  errors : Array[SpecialTextError],
) -> ScriptTextScan {
  let out = StringBuilder()
  out.write_string(scanned_data_slice(input, start, escape_start))
  out.write_string("<!--")
  let mut state = ScriptEscaped
  let mut temp = ""
  let mut pos = escape_start + 4
  while pos < input.length() {
    match state {
      ScriptRawText =>
        if script_end_tag_at(input, pos) {
          return { data: out.to_string(), end_start: Some(pos), errors }
        } else if @syn.view_starts_with_at(input, pos, "<!--") {
          out.write_string("<!--")
          pos += 4
          state = ScriptEscaped
        } else {
          pos = write_script_text_char(input, pos, out, errors)
        }
      ScriptEscaped =>
        match input.get_char(pos).unwrap() {
          '-' => {
            out.write_char('-')
            pos += 1
            state = ScriptEscapedDash
          }
          '<' => {
            pos += 1
            state = ScriptEscapedLessThan
          }
          _ => pos = write_script_text_char(input, pos, out, errors)
        }
      ScriptEscapedDash =>
        match input.get_char(pos).unwrap() {
          '-' => {
            out.write_char('-')
            pos += 1
            state = ScriptEscapedDashDash
          }
          '<' => {
            pos += 1
            state = ScriptEscapedLessThan
          }
          _ => {
            pos = write_script_text_char(input, pos, out, errors)
            state = ScriptEscaped
          }
        }
      ScriptEscapedDashDash =>
        match input.get_char(pos).unwrap() {
          '-' => {
            out.write_char('-')
            pos += 1
          }
          '<' => {
            out.write_char('<')
            pos += 1
            state = ScriptEscapedLessThan
          }
          '>' => {
            out.write_char('>')
            pos += 1
            state = ScriptRawText
          }
          _ => {
            pos = write_script_text_char(input, pos, out, errors)
            state = ScriptEscaped
          }
        }
      ScriptEscapedLessThan =>
        match input.get_char(pos) {
          Some('/') =>
            if script_end_tag_at(input, pos - 1) {
              return { data: out.to_string(), end_start: Some(pos - 1), errors }
            } else {
              out.write_string("</")
              pos += 1
              state = ScriptEscaped
            }
          Some(ch) if ch.is_ascii_alphabetic() => {
            out.write_char('<')
            temp = ""
            state = ScriptDoubleEscapeStart
          }
          _ => {
            out.write_char('<')
            state = ScriptEscaped
          }
        }
      ScriptDoubleEscapeStart =>
        match input.get_char(pos) {
          Some(ch) if script_escape_boundary(ch) => {
            if temp_is_script(temp) {
              state = ScriptDoubleEscaped
            } else {
              state = ScriptEscaped
            }
            pos = @syn.write_normalized_char(input, pos, out)
          }
          Some(ch) if ch.is_ascii_alphabetic() => {
            temp = temp + ch.to_string()
            out.write_char(ch)
            pos += ch.utf16_len()
          }
          _ => state = ScriptEscaped
        }
      ScriptDoubleEscaped =>
        match input.get_char(pos).unwrap() {
          '-' => {
            out.write_char('-')
            pos += 1
            state = ScriptDoubleEscapedDash
          }
          '<' => {
            out.write_char('<')
            pos += 1
            state = ScriptDoubleEscapedLessThan
          }
          _ => pos = write_script_text_char(input, pos, out, errors)
        }
      ScriptDoubleEscapedDash =>
        match input.get_char(pos).unwrap() {
          '-' => {
            out.write_char('-')
            pos += 1
            state = ScriptDoubleEscapedDashDash
          }
          '<' => {
            out.write_char('<')
            pos += 1
            state = ScriptDoubleEscapedLessThan
          }
          _ => {
            pos = write_script_text_char(input, pos, out, errors)
            state = ScriptDoubleEscaped
          }
        }
      ScriptDoubleEscapedDashDash =>
        match input.get_char(pos).unwrap() {
          '-' => {
            out.write_char('-')
            pos += 1
          }
          '<' => {
            out.write_char('<')
            pos += 1
            state = ScriptDoubleEscapedLessThan
          }
          '>' => {
            out.write_char('>')
            pos += 1
            state = ScriptRawText
          }
          _ => {
            pos = write_script_text_char(input, pos, out, errors)
            state = ScriptDoubleEscaped
          }
        }
      ScriptDoubleEscapedLessThan =>
        match input.get_char(pos) {
          Some('/') => {
            out.write_char('/')
            pos += 1
            temp = ""
            state = ScriptDoubleEscapeEnd
          }
          Some(ch) if ch.is_ascii_alphabetic() => {
            temp = ""
            state = ScriptDoubleEscapeStart
          }
          _ => state = ScriptDoubleEscaped
        }
      ScriptDoubleEscapeEnd =>
        match input.get_char(pos) {
          Some(ch) if script_escape_boundary(ch) => {
            if temp_is_script(temp) {
              state = ScriptEscaped
            } else {
              state = ScriptDoubleEscaped
            }
            pos = @syn.write_normalized_char(input, pos, out)
          }
          Some(ch) if ch.is_ascii_alphabetic() => {
            temp = temp + ch.to_string()
            out.write_char(ch)
            pos += ch.utf16_len()
          }
          _ => state = ScriptDoubleEscaped
        }
    }
  }
  if state is ScriptEscapedLessThan {
    out.write_char('<')
  }
  { data: out.to_string(), end_start: None, errors }
}
