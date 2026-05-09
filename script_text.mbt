///|
priv struct SpecialTextError {
  code : String
  offset : Int
}

///|
priv struct ScriptTextScan {
  data : String
  end_start : Int?
  errors : Array[SpecialTextError]
}

///|
priv enum ScriptTextState {
  ScriptRawText
  ScriptEscaped
  ScriptEscapedDash
  ScriptEscapedDashDash
  ScriptEscapedLessThan
  ScriptDoubleEscapeStart
  ScriptDoubleEscaped
  ScriptDoubleEscapedDash
  ScriptDoubleEscapedDashDash
  ScriptDoubleEscapedLessThan
  ScriptDoubleEscapeEnd
}

///|
fn scan_script_text(input : StringView, start : Int) -> ScriptTextScan {
  let out = StringBuilder::new(size_hint=input.length() - start)
  let errors : Array[SpecialTextError] = []
  let mut state = ScriptRawText
  let mut temp = ""
  let mut pos = start
  while pos < input.length() {
    match state {
      ScriptRawText =>
        if script_end_tag_at(input, pos) {
          return ScriptTextScan::{
            data: out.to_string(),
            end_start: Some(pos),
            errors,
          }
        } else if view_starts_with_at(input, pos, "<!--") {
          out.write_string("<!--")
          pos += 4
          state = ScriptEscaped
        } else {
          pos = write_script_text_char(input, pos, out, errors)
        }
      ScriptEscaped =>
        match input.get_char(pos) {
          Some('-') => {
            out.write_char('-')
            pos += 1
            state = ScriptEscapedDash
          }
          Some('<') => {
            pos += 1
            state = ScriptEscapedLessThan
          }
          Some(_) => pos = write_script_text_char(input, pos, out, errors)
          None => break
        }
      ScriptEscapedDash =>
        match input.get_char(pos) {
          Some('-') => {
            out.write_char('-')
            pos += 1
            state = ScriptEscapedDashDash
          }
          Some('<') => {
            pos += 1
            state = ScriptEscapedLessThan
          }
          Some(_) => {
            pos = write_script_text_char(input, pos, out, errors)
            state = ScriptEscaped
          }
          None => break
        }
      ScriptEscapedDashDash =>
        match input.get_char(pos) {
          Some('-') => {
            out.write_char('-')
            pos += 1
          }
          Some('<') => {
            out.write_char('<')
            pos += 1
            state = ScriptEscapedLessThan
          }
          Some('>') => {
            out.write_char('>')
            pos += 1
            state = ScriptRawText
          }
          Some(_) => {
            pos = write_script_text_char(input, pos, out, errors)
            state = ScriptEscaped
          }
          None => break
        }
      ScriptEscapedLessThan =>
        match input.get_char(pos) {
          Some('/') =>
            if script_end_tag_at(input, pos - 1) {
              return ScriptTextScan::{
                data: out.to_string(),
                end_start: Some(pos - 1),
                errors,
              }
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
            pos = write_normalized_char(input, pos, out)
          }
          Some(ch) if ch.is_ascii_alphabetic() => {
            temp = temp + ch.to_string()
            out.write_char(ch)
            pos += ch.utf16_len()
          }
          _ => state = ScriptEscaped
        }
      ScriptDoubleEscaped =>
        match input.get_char(pos) {
          Some('-') => {
            out.write_char('-')
            pos += 1
            state = ScriptDoubleEscapedDash
          }
          Some('<') => {
            out.write_char('<')
            pos += 1
            state = ScriptDoubleEscapedLessThan
          }
          Some(_) => pos = write_script_text_char(input, pos, out, errors)
          None => break
        }
      ScriptDoubleEscapedDash =>
        match input.get_char(pos) {
          Some('-') => {
            out.write_char('-')
            pos += 1
            state = ScriptDoubleEscapedDashDash
          }
          Some('<') => {
            out.write_char('<')
            pos += 1
            state = ScriptDoubleEscapedLessThan
          }
          Some(_) => {
            pos = write_script_text_char(input, pos, out, errors)
            state = ScriptDoubleEscaped
          }
          None => break
        }
      ScriptDoubleEscapedDashDash =>
        match input.get_char(pos) {
          Some('-') => {
            out.write_char('-')
            pos += 1
          }
          Some('<') => {
            out.write_char('<')
            pos += 1
            state = ScriptDoubleEscapedLessThan
          }
          Some('>') => {
            out.write_char('>')
            pos += 1
            state = ScriptRawText
          }
          Some(_) => {
            pos = write_script_text_char(input, pos, out, errors)
            state = ScriptDoubleEscaped
          }
          None => break
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
            pos = write_normalized_char(input, pos, out)
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
  ScriptTextScan::{ data: out.to_string(), end_start: None, errors }
}

///|
fn write_script_text_char(
  input : StringView,
  pos : Int,
  out : StringBuilder,
  errors : Array[SpecialTextError],
) -> Int {
  match input.get_char(pos) {
    Some('\u{0000}') => {
      errors.push(SpecialTextError::{
        code: "unexpected-null-character",
        offset: pos,
      })
      out.write_char('\u{FFFD}')
      pos + 1
    }
    Some(_) => write_normalized_char(input, pos, out)
    None => pos
  }
}

///|
fn script_end_tag_at(input : StringView, pos : Int) -> Bool {
  let needle = "</script"
  if starts_with_case_insensitive(input, pos, needle) {
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
