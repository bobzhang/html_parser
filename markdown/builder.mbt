///|
/// One piece of buffered Markdown output.
priv enum MarkdownPart {
  /// Literal output.
  Chunk(String)
  /// Start of a blockquote body: every line of the output up to the matching
  /// `QuoteClose` is prefixed with `> ` when the output is joined.
  QuoteOpen
  /// End of a blockquote body.
  QuoteClose
}

///|
/// Accumulates Markdown output as a list of parts.
///
/// Nested builders (used for headings, emphasis, links and blockquotes, whose
/// rendered children are post-processed by the parent) share the parent's
/// `parts` array and own the suffix starting at `start`. While a nested
/// builder is active its parent is never written to, so the nested output can
/// be trimmed in place and adopted by the parent without copying it, and
/// blockquote line prefixes are applied once, when the root output is joined.
/// This keeps deeply nested markup linear in the size of the output instead of
/// re-copying the inner output at every nesting level.
priv struct MarkdownBuilder {
  parts : Array[MarkdownPart]
  start : Int
  mut newline_count : Int
  mut pending_space : Bool
}

///|
fn MarkdownBuilder::MarkdownBuilder() -> MarkdownBuilder {
  { parts: [], start: 0, newline_count: 0, pending_space: false, }
}

///|
/// A fresh, empty builder that appends to the end of this builder's parts.
/// This builder must not be written to until the nested one is closed.
fn MarkdownBuilder::nested(self : MarkdownBuilder) -> MarkdownBuilder {
  {
    parts: self.parts,
    start: self.parts.length(),
    newline_count: 0,
    pending_space: false,
  }
}

///|
fn MarkdownBuilder::is_empty(self : MarkdownBuilder) -> Bool {
  self.parts.length() == self.start
}

///|
/// The builder state a speculative write can be rolled back to.
priv struct MarkdownSnapshot {
  length : Int
  last_part : MarkdownPart?
  newline_count : Int
  pending_space : Bool
}

///|
/// Capture the state needed to undo `raw` and `ensure_newlines` calls: those
/// only append parts, except that `newline` may rewrite the last part.
fn MarkdownBuilder::snapshot(self : MarkdownBuilder) -> MarkdownSnapshot {
  {
    length: self.parts.length(),
    last_part: if self.is_empty() {
      None
    } else {
      Some(self.parts[self.parts.length() - 1])
    },
    newline_count: self.newline_count,
    pending_space: self.pending_space,
  }
}

///|
/// Undo every write since `snapshot` was taken.
fn MarkdownBuilder::restore(
  self : MarkdownBuilder,
  snapshot : MarkdownSnapshot,
) -> Unit {
  while self.parts.length() > snapshot.length {
    ignore(self.parts.pop())
  }
  if snapshot.last_part is Some(part) {
    self.parts[snapshot.length - 1] = part
  }
  self.newline_count = snapshot.newline_count
  self.pending_space = snapshot.pending_space
}

///|
/// Trim this nested builder's output in place, exactly as `finish` trims the
/// joined string: leading and trailing tab/LF/CR/space characters are removed
/// across part boundaries, and all-whitespace output is removed entirely.
/// Returns whether any output remains. Trailing parts that become empty are
/// popped, so the output then ends with a non-whitespace character.
///
/// A blockquote body always starts with `> ` and ends with non-whitespace,
/// so `QuoteOpen` and `QuoteClose` stop the scan.
fn MarkdownBuilder::trim_in_place(self : MarkdownBuilder) -> Bool {
  let parts = self.parts
  while parts.length() > self.start {
    let last = parts.length() - 1
    guard parts[last] is Chunk(part) else { break }
    let trimmed = part.trim_end()
    if trimmed.is_empty() {
      ignore(parts.pop())
    } else {
      if trimmed.length() != part.length() {
        parts[last] = Chunk(trimmed.to_owned())
      }
      break
    }
  }
  if parts.length() == self.start {
    return false
  }
  for index in self.start..<parts.length() {
    guard parts[index] is Chunk(part) else { break }
    let trimmed = part.trim_start()
    if trimmed.is_empty() {
      parts[index] = Chunk("")
    } else {
      if trimmed.length() != part.length() {
        parts[index] = Chunk(trimmed.to_owned())
      }
      break
    }
  }
  true
}

///|
fn MarkdownBuilder::raw(self : MarkdownBuilder, value : StringView) -> Unit {
  if value.is_empty() {
    return
  }
  if self.pending_space {
    match value.get_char(0) {
      Some(ch) if !markdown_whitespace_char(ch) &&
        !self.is_empty() &&
        self.newline_count == 0 => self.parts.push(Chunk(" "))
      _ => ()
    }
    self.pending_space = false
  }
  self.parts.push(Chunk(value.to_owned()))
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
    // A `QuoteClose` last part stands for a blockquote body, which ends with
    // non-whitespace, so there is nothing to trim.
    if !self.is_empty() && self.parts[self.parts.length() - 1] is Chunk(last) {
      self.parts[self.parts.length() - 1] = Chunk(
        markdown_trim_trailing_spaces_tabs(last),
      )
    }
    self.parts.push(Chunk("\n"))
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
      if !self.is_empty() && self.newline_count == 0 {
        self.parts.push(Chunk(" "))
      }
      self.pending_space = false
    }
    if self.is_empty() || self.newline_count > 0 {
      let rest = value[pos:value.length()]
      match markdown_escape_line_start(rest) {
        Some((replacement, consumed)) => {
          self.parts.push(Chunk(replacement))
          self.newline_count = 0
          pos += consumed
          continue
        }
        None => ()
      }
    }
    self.parts.push(Chunk(ch.to_string()))
    self.newline_count = 0
    pos += ch.utf16_len()
  }
}

///|
/// Join the output and trim surrounding whitespace.
///
/// Blockquote bodies are expanded here, as the recursive formulation's
/// per-level quoting did: before each character, every enclosing body whose
/// own (already quoted) text is at a line start contributes a `> ` prefix,
/// outermost first. A body's text starts at a line start, and each character
/// updates the line-start state of all enclosing bodies alike (a newline sets
/// it, anything else clears it), so the bodies at a line start are always
/// the innermost ones from `line_start_depth` up. Prefixes therefore cost
/// only the output they produce.
fn MarkdownBuilder::finish(self : MarkdownBuilder) -> String {
  let out = StringBuilder()
  let mut depth = 0
  let mut line_start_depth = 0
  for part in self.parts {
    match part {
      Chunk(value) =>
        if depth == 0 {
          out.write_string(value)
        } else {
          for ch in value {
            for _ in line_start_depth..<depth {
              out.write_string("> ")
            }
            out.write_char(ch)
            line_start_depth = if ch == '\n' { 0 } else { depth }
          }
        }
      QuoteOpen => depth += 1
      QuoteClose => {
        depth -= 1
        if line_start_depth > depth {
          line_start_depth = depth
        }
      }
    }
  }
  out.to_string()[:].trim().to_owned()
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
  let out = StringBuilder(size_hint=value.length())
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
  value.get_char(pos) is Some(' ' | '\t')
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
