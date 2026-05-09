///|
priv struct SpecialTextError {
  code : String
  offset : Int
}

///|
priv enum ScriptTextState {
  ScriptRawText
  ScriptEscaped
  ScriptEscapedDash
  ScriptEscapedDashDash
} derive(Eq)

///|
fn decode_script_text(
  raw : StringView,
  start : Int,
  closed : Bool,
) -> (String, Array[SpecialTextError]) {
  let out = StringBuilder::new(size_hint=raw.length())
  let errors : Array[SpecialTextError] = []
  let mut state = ScriptRawText
  let mut pos = 0
  while pos < raw.length() {
    match state {
      ScriptRawText =>
        if view_starts_with_at(raw, pos, "<!--") {
          out.write_string("<!--")
          pos += 4
          state = ScriptEscaped
        } else {
          match raw.get_char(pos) {
            Some('\u{0000}') => {
              errors.push(SpecialTextError::{
                code: "unexpected-null-character",
                offset: start + pos,
              })
              out.write_char('\u{FFFD}')
              pos += 1
            }
            Some(_) => pos = write_normalized_char(raw, pos, out)
            None => break
          }
        }
      ScriptEscaped =>
        match raw.get_char(pos) {
          Some('-') => {
            out.write_char('-')
            pos += 1
            state = ScriptEscapedDash
          }
          Some('<') => {
            out.write_char('<')
            pos += 1
          }
          Some('\u{0000}') => {
            errors.push(SpecialTextError::{
              code: "unexpected-null-character",
              offset: start + pos,
            })
            out.write_char('\u{FFFD}')
            pos += 1
          }
          Some(_) => pos = write_normalized_char(raw, pos, out)
          None => break
        }
      ScriptEscapedDash =>
        match raw.get_char(pos) {
          Some('-') => {
            out.write_char('-')
            pos += 1
            state = ScriptEscapedDashDash
          }
          Some('<') => {
            out.write_char('<')
            pos += 1
            state = ScriptEscaped
          }
          Some('\u{0000}') => {
            errors.push(SpecialTextError::{
              code: "unexpected-null-character",
              offset: start + pos,
            })
            out.write_char('\u{FFFD}')
            pos += 1
            state = ScriptEscaped
          }
          Some(_) => {
            pos = write_normalized_char(raw, pos, out)
            state = ScriptEscaped
          }
          None => break
        }
      ScriptEscapedDashDash =>
        match raw.get_char(pos) {
          Some('-') => {
            out.write_char('-')
            pos += 1
          }
          Some('<') => {
            out.write_string("<<")
            pos += 1
            state = ScriptEscaped
          }
          Some('>') => {
            out.write_char('>')
            pos += 1
            state = ScriptRawText
          }
          Some('\u{0000}') => {
            errors.push(SpecialTextError::{
              code: "unexpected-null-character",
              offset: start + pos,
            })
            out.write_char('\u{FFFD}')
            pos += 1
            state = ScriptEscaped
          }
          Some(_) => {
            pos = write_normalized_char(raw, pos, out)
            state = ScriptEscaped
          }
          None => break
        }
    }
  }
  if closed && state == ScriptEscapedDashDash {
    out.write_char('<')
  }
  (out.to_string(), errors)
}
