///|
pub fn lower_ascii(input : StringView) -> String {
  let out = StringBuilder::new(size_hint=input.length())
  for ch in input {
    if ch.is_ascii_uppercase() {
      out.write_char(ch.to_ascii_lowercase())
    } else {
      out.write_char(ch)
    }
  }
  out.to_string()
}

///|
pub fn starts_with_case_insensitive(
  input : StringView,
  pos : Int,
  prefix : StringView,
) -> Bool {
  let end = pos + prefix.length()
  match input.get_view(start=pos, end~) {
    Some(view) => view.compare_ignore_ascii_case(prefix) == 0
    None => false
  }
}

///|
pub fn view_starts_with_at(
  input : StringView,
  pos : Int,
  prefix : StringView,
) -> Bool {
  let end = pos + prefix.length()
  match input.get_view(start=pos, end~) {
    Some(view) => view == prefix
    None => false
  }
}

///|
pub fn line_col_at(input : StringView, target : Int) -> (Int, Int) {
  if target == input.length() && input_ends_with_newline(input) {
    return eof_line_col(input)
  }
  let mut offset = 0
  let mut line = 1
  let mut col = 1
  while offset < target && offset < input.length() {
    let ch = input.get_char(offset).unwrap()
    match ch {
      '\r' => {
        line += 1
        col = 1
        offset += 1
        if offset < target && input.get_char(offset) is Some('\n') {
          offset += 1
        }
      }
      '\n' => {
        line += 1
        col = 1
        offset += 1
      }
      _ => {
        col += 1
        offset += ch.utf16_len()
      }
    }
  }
  (line, col)
}

///|
pub fn input_ends_with_newline(input : StringView) -> Bool {
  let mut pos = 0
  let mut last : Char? = None
  while pos < input.length() {
    let ch = input.get_char(pos).unwrap()
    last = Some(ch)
    pos += ch.utf16_len()
  }
  match last {
    Some('\r') | Some('\n') => true
    _ => false
  }
}

///|
pub fn eof_line_col(input : StringView) -> (Int, Int) {
  let mut offset = 0
  let mut line = 1
  let mut col = 0
  while offset < input.length() {
    let ch = input.get_char(offset).unwrap()
    match ch {
      '\r' => {
        line += 1
        col = 0
        offset += 1
        if input.get_char(offset) is Some('\n') {
          offset += 1
        }
      }
      '\n' => {
        line += 1
        col = 0
        offset += 1
      }
      _ => {
        col += 1
        offset += ch.utf16_len()
      }
    }
  }
  (line, col)
}

///|
pub fn eof_error_pos(input : StringView) -> Int {
  let mut pos = 0
  let mut last = 0
  let mut last_char : Char? = None
  while pos < input.length() {
    last = pos
    let ch = input.get_char(pos).unwrap()
    last_char = Some(ch)
    pos += ch.utf16_len()
  }
  match last_char {
    Some('\r') | Some('\n') => input.length()
    Some(_) => last
    None => 0
  }
}

///|
pub fn strip_leading_bom(input : StringView) -> StringView {
  if input.has_prefix("\u{FEFF}") {
    input[1:]
  } else {
    input
  }
}

///|
pub fn normalize_newlines(input : StringView) -> String {
  let out = StringBuilder::new(size_hint=input.length())
  let mut pos = 0
  while pos < input.length() {
    let ch = input.get_char(pos).unwrap()
    match ch {
      '\r' => {
        out.write_char('\n')
        pos += 1
        if input.get_char(pos) is Some('\n') {
          pos += 1
        }
      }
      _ => {
        out.write_char(ch)
        pos += ch.utf16_len()
      }
    }
  }
  out.to_string()
}

///|
pub fn normalize_bogus_comment_data(input : StringView) -> String {
  let out = StringBuilder::new(size_hint=input.length())
  let mut pos = 0
  while pos < input.length() {
    let ch = input.get_char(pos).unwrap()
    match ch {
      '\u{0000}' => {
        out.write_char('\u{FFFD}')
        pos += 1
      }
      '\r' => {
        out.write_char('\n')
        pos += 1
        if input.get_char(pos) is Some('\n') {
          pos += 1
        }
      }
      _ => {
        out.write_char(ch)
        pos += ch.utf16_len()
      }
    }
  }
  out.to_string()
}

///|
pub fn write_normalized_char(
  input : StringView,
  pos : Int,
  out : StringBuilder,
) -> Int {
  match input.get_char(pos) {
    Some('\r') => {
      out.write_char('\n')
      let next = pos + 1
      if input.get_char(next) is Some('\n') {
        next + 1
      } else {
        next
      }
    }
    Some(ch) => {
      out.write_char(ch)
      pos + ch.utf16_len()
    }
    None => pos
  }
}
