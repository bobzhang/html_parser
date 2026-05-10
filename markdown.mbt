///|
priv struct MarkdownBuilder {
  parts : Array[String]
  mut newline_count : Int
  mut pending_space : Bool
}

///|
fn MarkdownBuilder::new() -> MarkdownBuilder {
  MarkdownBuilder::{ parts: [], newline_count: 0, pending_space: false }
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
fn MarkdownBuilder::newline(self : MarkdownBuilder, count : Int) -> Unit {
  for _ in 0..<count {
    self.pending_space = false
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
      guard value.get_view(start=pos, end=value.length()) is Some(rest) else {
        break
      }
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
      match value.get_view(start=0, end=pos) {
        Some(prefix) => Some((prefix.to_owned() + "\\.", pos + 1))
        None => None
      }
    Some(')') if markdown_next_char_is_space(value, pos + 1) =>
      match value.get_view(start=0, end=pos) {
        Some(prefix) => Some((prefix.to_owned() + "\\)", pos + 1))
        None => None
      }
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

///|
fn markdown_backtick_fence(value : StringView, minimum : Int) -> String {
  let mut longest = 0
  let mut run = 0
  for ch in value {
    if ch == '`' {
      run += 1
      if run > longest {
        longest = run
      }
    } else {
      run = 0
    }
  }
  let size = if minimum > longest + 1 { minimum } else { longest + 1 }
  "`".repeat(size)
}

///|
fn markdown_code_span(value : StringView) -> String {
  let fence = markdown_backtick_fence(value, 1)
  if value.has_prefix("`") || value.has_suffix("`") {
    fence + " " + value.to_owned() + " " + fence
  } else {
    fence + value.to_owned() + fence
  }
}

///|
fn markdown_collect_text(node : Node) -> String {
  let parts : Array[String] = []
  markdown_collect_text_into(node, parts)
  parts.join("")
}

///|
fn markdown_collect_text_into(node : Node, parts : Array[String]) -> Unit {
  match node.kind {
    Text => parts.push(node.data)
    Comment | Doctype => ()
    _ =>
      for child in node.children {
        markdown_collect_text_into(child, parts)
      }
  }
}

///|
fn markdown_code_block_body(value : StringView) -> String {
  let mut end = value.length()
  while end > 0 {
    match value.get_char(end - 1) {
      Some('\n') => end -= 1
      _ => break
    }
  }
  while end > 0 {
    match value.get_char(end - 1) {
      Some(' ' | '\t') => end -= 1
      _ => break
    }
  }
  match value.get_view(start=0, end~) {
    Some(body) => body.to_owned()
    None => value.to_owned()
  }
}

///|
fn markdown_render_children(
  node : Node,
  builder : MarkdownBuilder,
  html_passthrough : Bool,
) -> Unit {
  for child in node.children {
    markdown_walk(child, builder, html_passthrough)
  }
}

///|
fn markdown_render_children_to_string(
  node : Node,
  html_passthrough : Bool,
) -> String {
  let builder = MarkdownBuilder::new()
  markdown_render_children(node, builder, html_passthrough)
  builder.finish()
}

///|
fn markdown_heading_level(name : StringView) -> Int {
  match name {
    "h1" => 1
    "h2" => 2
    "h3" => 3
    "h4" => 4
    "h5" => 5
    "h6" => 6
    _ => 0
  }
}

///|
fn markdown_block_container_name(name : StringView) -> Bool {
  match name {
    "div"
    | "section"
    | "article"
    | "header"
    | "footer"
    | "main"
    | "nav"
    | "aside" => true
    _ => false
  }
}

///|
fn markdown_wrapped_inline(
  node : Node,
  builder : MarkdownBuilder,
  marker : String,
  html_passthrough : Bool,
) -> Unit {
  let inner = markdown_render_children_to_string(node, html_passthrough)
  if inner != "" {
    builder.raw(marker)
    builder.raw(inner)
    builder.raw(marker)
  }
}

///|
fn markdown_link_destination(value : StringView) -> String {
  let trimmed = value.trim()
  if trimmed.is_empty() {
    return ""
  }
  if markdown_link_destination_needs_wrap(trimmed) {
    "<" + markdown_percent_encode_link_destination(trimmed) + ">"
  } else {
    trimmed.to_owned()
  }
}

///|
fn markdown_link_destination_needs_wrap(value : StringView) -> Bool {
  for ch in value {
    if markdown_whitespace_char(ch) ||
      ch == '(' ||
      ch == ')' ||
      ch == '<' ||
      ch == '>' {
      return true
    }
  }
  false
}

///|
fn markdown_percent_encode_link_destination(value : StringView) -> String {
  let bytes = @utf8.encode(value)
  let out = StringBuilder::new(size_hint=bytes.length())
  for index in 0..<bytes.length() {
    let byte = bytes[index]
    if markdown_link_destination_byte_is_safe(byte) {
      out.write_char(byte.to_char())
    } else {
      write_percent_encoded_byte(out, byte)
    }
  }
  out.to_string()
}

///|
fn markdown_link_destination_byte_is_safe(byte : Byte) -> Bool {
  let value = byte.to_int()
  value >= 0x21 && value <= 0x7E && value != 0x3C && value != 0x3E
}

///|
fn markdown_walk_link(
  node : Node,
  builder : MarkdownBuilder,
  html_passthrough : Bool,
) -> Unit {
  let inner = markdown_render_children_to_string(node, html_passthrough)
  builder.raw("[")
  builder.raw(inner)
  builder.raw("]")
  match attribute_value_by_name(node, "href") {
    Some(href) => {
      let destination = markdown_link_destination(href)
      if destination != "" {
        builder.raw("(")
        builder.raw(destination)
        builder.raw(")")
      }
    }
    None => ()
  }
}

///|
fn markdown_walk_pre(node : Node, builder : MarkdownBuilder) -> Unit {
  let code = markdown_collect_text(node)
  let body = markdown_code_block_body(code)
  let fence = markdown_backtick_fence(code, 3)
  builder.ensure_newlines(2)
  builder.raw(fence)
  builder.newline(1)
  if body != "" {
    builder.raw(body)
    builder.newline(1)
  }
  builder.raw(fence)
  builder.ensure_newlines(2)
}

///|
fn markdown_walk_list(
  node : Node,
  builder : MarkdownBuilder,
  ordered : Bool,
  html_passthrough : Bool,
) -> Unit {
  builder.ensure_newlines(2)
  let mut index = 1
  for child in node.children {
    if child.kind == Element && child.name == "li" {
      let inner = markdown_render_children_to_string(child, html_passthrough)
      if inner != "" {
        if ordered {
          builder.raw(index.to_string())
          builder.raw(". ")
        } else {
          builder.raw("- ")
        }
        builder.raw(inner)
        builder.newline(1)
      }
      index += 1
    }
  }
  builder.ensure_newlines(2)
}

///|
fn markdown_walk_blockquote(
  node : Node,
  builder : MarkdownBuilder,
  html_passthrough : Bool,
) -> Unit {
  let inner = markdown_render_children_to_string(node, html_passthrough)
  if inner == "" {
    return
  }
  let quoted = StringBuilder::new(size_hint=inner.length() + 2)
  let mut line_start = true
  for ch in inner {
    if line_start {
      quoted.write_string("> ")
      line_start = false
    }
    quoted.write_char(ch)
    if ch == '\n' {
      line_start = true
    }
  }
  builder.ensure_newlines(2)
  builder.raw(quoted.to_string())
  builder.ensure_newlines(2)
}

///|
fn markdown_walk(
  node : Node,
  builder : MarkdownBuilder,
  html_passthrough : Bool,
) -> Unit {
  match node.kind {
    Text => builder.text(markdown_escape_text(node.data))
    Comment | Doctype => ()
    Document | Fragment =>
      markdown_render_children(node, builder, html_passthrough)
    Element => {
      let level = markdown_heading_level(node.name)
      if level > 0 {
        let inner = markdown_render_children_to_string(node, html_passthrough)
        builder.ensure_newlines(2)
        builder.raw("#".repeat(level))
        builder.raw(" ")
        builder.raw(inner)
        builder.ensure_newlines(2)
      } else {
        match node.name {
          "html" | "body" | "span" =>
            markdown_render_children(node, builder, html_passthrough)
          "head" => ()
          "p" => {
            builder.ensure_newlines(2)
            markdown_render_children(node, builder, html_passthrough)
            builder.ensure_newlines(2)
          }
          "br" => builder.newline(1)
          "b" | "strong" =>
            markdown_wrapped_inline(node, builder, "**", html_passthrough)
          "i" | "em" =>
            markdown_wrapped_inline(node, builder, "*", html_passthrough)
          "code" => builder.raw(markdown_code_span(markdown_collect_text(node)))
          "pre" => markdown_walk_pre(node, builder)
          "a" => markdown_walk_link(node, builder, html_passthrough)
          "ul" => markdown_walk_list(node, builder, false, html_passthrough)
          "ol" => markdown_walk_list(node, builder, true, html_passthrough)
          "blockquote" =>
            markdown_walk_blockquote(node, builder, html_passthrough)
          "hr" => {
            builder.ensure_newlines(2)
            builder.raw("---")
            builder.ensure_newlines(2)
          }
          "script" | "style" | "textarea" =>
            if html_passthrough {
              builder.raw(node.to_html(pretty=false))
            }
          "img" => builder.raw(node.to_html(pretty=false))
          "table" => {
            builder.ensure_newlines(2)
            builder.raw(node.to_html(pretty=false))
            builder.ensure_newlines(2)
          }
          _ =>
            if markdown_block_container_name(node.name) {
              builder.ensure_newlines(2)
              markdown_render_children(node, builder, html_passthrough)
              builder.ensure_newlines(2)
            } else {
              markdown_render_children(node, builder, html_passthrough)
            }
        }
      }
    }
  }
}

///|
pub fn Node::to_markdown(
  self : Node,
  html_passthrough? : Bool = false,
) -> String {
  let builder = MarkdownBuilder::new()
  markdown_walk(self, builder, html_passthrough)
  builder.finish()
}

///|
pub fn ParsedHtml::to_markdown(
  self : ParsedHtml,
  html_passthrough? : Bool = false,
) -> String {
  self.root.to_markdown(html_passthrough~)
}
