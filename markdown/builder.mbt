///|
priv struct MarkdownBuilder {
  parts : Array[String]
  mut newline_count : Int
  mut pending_space : Bool
}

///|
fn MarkdownBuilder::new() -> MarkdownBuilder {
  { parts: [], newline_count: 0, pending_space: false }
}

///|
fn MarkdownBuilder::raw(self : MarkdownBuilder, value : StringView) -> Unit {
  if value.is_empty() {
    return
  }
  if self.pending_space {
    match value.get_char(0) {
      Some(ch) if !markdown_whitespace_char(ch) &&
        !self.parts.is_empty() &&
        self.newline_count == 0 => self.parts.push(" ")
      _ => ()
    }
    self.pending_space = false
  }
  self.parts.push(value.to_owned())
  let mut saw_newline = false
  let mut trailing_newlines = 0
  for ch in value {
    if ch == '\n' {
      saw_newline = true
      trailing_newlines += 1
    } else {
      trailing_newlines = 0
    }
  }
  if saw_newline {
    self.newline_count = if trailing_newlines > 2 {
      2
    } else {
      trailing_newlines
    }
    if trailing_newlines > 0 {
      self.pending_space = false
    }
  } else {
    self.newline_count = 0
  }
}

///|
fn markdown_trim_trailing_spaces_tabs(value : StringView) -> String {
  let mut end = value.length()
  while end > 0 {
    match value.get_char(end - 1) {
      Some(' ' | '\t') => end -= 1
      _ => break
    }
  }
  value[0:end].to_owned()
}

///|
fn MarkdownBuilder::newline(self : MarkdownBuilder, count : Int) -> Unit {
  for _ in 0..<count {
    self.pending_space = false
    if !self.parts.is_empty() {
      let last_index = self.parts.length() - 1
      self.parts[last_index] = markdown_trim_trailing_spaces_tabs(
        self.parts[last_index],
      )
    }
    self.parts.push("\n")
    if self.newline_count < 2 {
      self.newline_count += 1
    }
  }
}

///|
fn MarkdownBuilder::ensure_newlines(
  self : MarkdownBuilder,
  count : Int,
) -> Unit {
  while self.newline_count < count {
    self.newline(1)
  }
}

///|
fn MarkdownBuilder::text(self : MarkdownBuilder, value : StringView) -> Unit {
  if value.is_empty() {
    return
  }
  let mut pos = 0
  while pos < value.length() {
    guard value.get_char(pos) is Some(ch) else { break }
    if markdown_whitespace_char(ch) {
      self.pending_space = true
      pos += ch.utf16_len()
      continue
    }
    if self.pending_space {
      if !self.parts.is_empty() && self.newline_count == 0 {
        self.parts.push(" ")
      }
      self.pending_space = false
    }
    if self.parts.is_empty() || self.newline_count > 0 {
      let rest = value[pos:value.length()]
      match markdown_escape_line_start(rest) {
        Some((replacement, consumed)) => {
          self.parts.push(replacement)
          self.newline_count = 0
          pos += consumed
          continue
        }
        None => ()
      }
    }
    self.parts.push(ch.to_string())
    self.newline_count = 0
    pos += ch.utf16_len()
  }
}

///|
fn MarkdownBuilder::finish(self : MarkdownBuilder) -> String {
  self.parts.join("")[:].trim().to_owned()
}

///|
fn markdown_whitespace_char(ch : Char) -> Bool {
  match ch {
    ' ' | '\t' | '\n' | '\r' | '\u{000C}' => true
    _ => false
  }
}

///|
fn markdown_escape_text(value : StringView) -> String {
  let out = StringBuilder::new(size_hint=value.length())
  for ch in value {
    match ch {
      '&' => out.write_string("&amp;")
      '<' => out.write_string("&lt;")
      '\\' | '`' | '*' | '_' | '[' | ']' => {
        out.write_char('\\')
        out.write_char(ch)
      }
      _ => out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn markdown_escape_line_start(value : StringView) -> (String, Int)? {
  guard value.get_char(0) is Some(first) else { return None }
  match first {
    '#' =>
      if value.length() == 1 || markdown_next_char_is_space(value, 1) {
        Some(("\\#", 1))
      } else {
        None
      }
    '>' => Some(("\\>", 1))
    '-' =>
      if markdown_next_char_is_space(value, 1) ||
        markdown_thematic_or_setext_line(value, '-', minimum_markers=3) {
        Some(("\\-", 1))
      } else {
        None
      }
    '+' =>
      if markdown_next_char_is_space(value, 1) {
        Some(("\\+", 1))
      } else {
        None
      }
    '=' =>
      if markdown_thematic_or_setext_line(value, '=', minimum_markers=1) {
        Some(("\\=", 1))
      } else {
        None
      }
    '~' => if value.has_prefix("~~~") { Some(("\\~", 1)) } else { None }
    '`' => if value.has_prefix("```") { Some(("\\`", 1)) } else { None }
    ch if markdown_ascii_digit(ch) => markdown_escape_ordered_line_start(value)
    _ => None
  }
}

///|
fn markdown_next_char_is_space(value : StringView, pos : Int) -> Bool {
  match value.get_char(pos) {
    Some(' ' | '\t') => true
    _ => false
  }
}

///|
fn markdown_ascii_digit(ch : Char) -> Bool {
  ch >= '0' && ch <= '9'
}

///|
fn markdown_escape_ordered_line_start(value : StringView) -> (String, Int)? {
  let mut pos = 0
  while pos < value.length() {
    match value.get_char(pos) {
      Some(ch) if markdown_ascii_digit(ch) => pos += ch.utf16_len()
      _ => break
    }
  }
  match value.get_char(pos) {
    Some('.') if markdown_next_char_is_space(value, pos + 1) =>
      Some((value[0:pos].to_owned() + "\\.", pos + 1))
    Some(')') if markdown_next_char_is_space(value, pos + 1) =>
      Some((value[0:pos].to_owned() + "\\)", pos + 1))
    _ => None
  }
}

///|
fn markdown_thematic_or_setext_line(
  value : StringView,
  marker : Char,
  minimum_markers~ : Int,
) -> Bool {
  let mut count = 0
  let mut saw_non_space = false
  for ch in value {
    if ch == ' ' || ch == '\t' {
      continue
    }
    saw_non_space = true
    if ch != marker {
      return false
    }
    count += 1
  }
  saw_non_space && count >= minimum_markers
}
