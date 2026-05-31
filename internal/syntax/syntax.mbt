///|
/// Return `input` with ASCII uppercase letters folded to lowercase.
///
/// Non-ASCII characters are left unchanged. This is intended for HTML syntax
/// names, sanitizer policy keys, and protocol-like values where the grammar
/// defines ASCII case-insensitivity, not for locale-sensitive text.
pub fn lower_ascii(input : StringView) -> String {
  let out = StringBuilder::StringBuilder(size_hint=input.length())
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
/// Test whether `input` starts with `prefix` at a UTF-16 code-unit offset,
/// comparing ASCII letters case-insensitively.
///
/// Returns `false` when `pos..pos + prefix.length()` is outside `input` or
/// cannot form a valid `StringView`.
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
/// Test whether `input` contains `prefix` at a UTF-16 code-unit offset.
///
/// The comparison is case-sensitive. Returns `false` when the requested view is
/// outside `input` or starts or ends inside an invalid UTF-16 boundary.
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
/// Convert a UTF-16 code-unit offset into a 1-based `(line, column)` pair.
///
/// CRLF is counted as one newline, and bare CR or LF also starts a new line.
/// Offsets point at source positions: offset `0` is line 1, column 1. When the
/// offset is exactly EOF after a final newline, this returns the EOF diagnostic
/// position from `eof_line_col`.
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
/// Return whether the last character in `input` is a line break.
///
/// Both LF and CR count as line breaks. For CRLF input this checks the final LF,
/// so the pair also returns `true`.
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
/// Return the `(line, column)` used for diagnostics that point at EOF.
///
/// Lines are 1-based. The returned column is the number of characters after the
/// most recent newline, so EOF immediately after a newline is column `0` on the
/// following line. CRLF is treated as a single newline.
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
/// Return the UTF-16 code-unit offset used for EOF-related parse errors.
///
/// Empty input reports offset `0`. Input ending with CR or LF reports
/// `input.length()`, placing the diagnostic after the final line break. Other
/// input reports the offset of the final character, preserving MoonBit string
/// offsets for non-BMP characters.
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
/// Drop a leading Unicode byte-order mark from `input`, if present.
///
/// The returned value is a `StringView` into the original input and does not
/// allocate.
pub fn strip_leading_bom(input : StringView) -> StringView {
  if input.has_prefix("\u{FEFF}") {
    input[1:]
  } else {
    input
  }
}

///|
/// Normalize source newlines to LF.
///
/// CRLF and bare CR are emitted as a single `\n`. All other characters are
/// copied unchanged.
pub fn normalize_newlines(input : StringView) -> String {
  let out = StringBuilder::StringBuilder(size_hint=input.length())
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
/// Normalize text captured by the tokenizer's bogus-comment path.
///
/// Null characters are replaced with U+FFFD, and CRLF or bare CR newlines are
/// normalized to LF. Other characters are copied unchanged.
pub fn normalize_bogus_comment_data(input : StringView) -> String {
  let out = StringBuilder::StringBuilder(size_hint=input.length())
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
/// Append one normalized character from `input` to `out`.
///
/// `pos` is a UTF-16 code-unit offset. A CR or CRLF sequence writes one LF and
/// returns the offset after the consumed newline. Other valid characters are
/// copied as-is and return the next character offset. If `pos` is EOF or not a
/// character boundary, nothing is written and `pos` is returned.
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

///|
/// Return whether `code` is a Unicode noncharacter.
///
/// This covers U+FDD0..U+FDEF and every code point whose low 16 bits are
/// U+FFFE or U+FFFF, matching the range this parser replaces when XML coercion
/// is enabled.
pub fn is_xml_noncharacter_code(code : Int) -> Bool {
  if code >= 0xFDD0 && code <= 0xFDEF {
    return true
  }
  let low = code % 0x10000
  low == 0xFFFE || low == 0xFFFF
}

///|
/// Return whether `ch` is a Unicode noncharacter.
pub fn is_xml_noncharacter(ch : Char) -> Bool {
  is_xml_noncharacter_code(ch.to_int())
}

///|
/// Return text data adjusted for XML-compatible output.
///
/// XML coercion replaces form feed with a space and Unicode noncharacters with
/// U+FFFD. It does not escape markup; callers still serialize text through the
/// normal escaping path.
pub fn coerce_text_for_xml(input : StringView) -> String {
  let out = StringBuilder::StringBuilder(size_hint=input.length())
  for ch in input {
    if ch == '\u{000C}' {
      out.write_char(' ')
    } else if is_xml_noncharacter(ch) {
      out.write_char('\u{FFFD}')
    } else {
      out.write_char(ch)
    }
  }
  out.to_string()
}

///|
/// Return comment data adjusted to avoid consecutive hyphens in XML comments.
///
/// Every `--` sequence is rewritten as `- -`. The function only rewrites the
/// comment data and does not add comment delimiters.
pub fn coerce_comment_for_xml(input : StringView) -> String {
  input.to_owned().replace_all(old="--", new="- -")
}
