///|
fn is_void_element(name : StringView) -> Bool {
  match name {
    "area"
    | "base"
    | "br"
    | "col"
    | "embed"
    | "hr"
    | "img"
    | "input"
    | "link"
    | "meta"
    | "param"
    | "source"
    | "track"
    | "wbr" => true
    _ => false
  }
}

///|
fn escape_text(value : StringView) -> String {
  let out = StringBuilder::new(size_hint=value.length())
  for ch in value {
    match ch {
      '&' => out.write_string("&amp;")
      '<' => out.write_string("&lt;")
      '>' => out.write_string("&gt;")
      _ => out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn escape_attr_value(value : StringView, quote : Char) -> String {
  let out = StringBuilder::new(size_hint=value.length())
  for ch in value {
    match ch {
      '&' => out.write_string("&amp;")
      '<' => out.write_string("&lt;")
      '>' => out.write_string("&gt;")
      '"' if quote == '"' => out.write_string("&quot;")
      '\'' if quote == '\'' => out.write_string("&#39;")
      _ => out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn escape_js_string(value : StringView, quote : Char) -> String {
  let out = StringBuilder::new(size_hint=value.length())
  for ch in value {
    match ch {
      '\\' => out.write_string("\\\\")
      '\n' => out.write_string("\\n")
      '\r' => out.write_string("\\r")
      '\t' => out.write_string("\\t")
      '\u{0008}' => out.write_string("\\b")
      '\u{000C}' => out.write_string("\\f")
      '"' if quote == '"' => out.write_string("\\\"")
      '\'' if quote == '\'' => out.write_string("\\'")
      '<' => out.write_string("\\u003c")
      '>' => out.write_string("\\u003e")
      '\u{2028}' => out.write_string("\\u2028")
      '\u{2029}' => out.write_string("\\u2029")
      _ => out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn percent_encode_url(value : StringView) -> String {
  let bytes = @utf8.encode(value)
  let out = StringBuilder::new(size_hint=bytes.length())
  for index in 0..<bytes.length() {
    let byte = bytes[index]
    if is_url_safe_byte(byte) {
      out.write_char(byte.to_char())
    } else {
      write_percent_encoded_byte(out, byte)
    }
  }
  out.to_string()
}

///|
fn is_url_safe_byte(byte : Byte) -> Bool {
  let value = byte.to_int()
  (value >= 0x41 && value <= 0x5A) ||
  (value >= 0x61 && value <= 0x7A) ||
  (value >= 0x30 && value <= 0x39) ||
  value == 0x2F ||
  value == 0x3A ||
  value == 0x40 ||
  value == 0x3F ||
  value == 0x26 ||
  value == 0x3D ||
  value == 0x23 ||
  value == 0x2B ||
  value == 0x2D ||
  value == 0x2E ||
  value == 0x5F ||
  value == 0x7E
}

///|
fn write_percent_encoded_byte(out : StringBuilder, byte : Byte) -> Unit {
  let value = byte.to_int()
  out.write_char('%')
  out.write_char(hex_digit_upper(value / 16))
  out.write_char(hex_digit_upper(value % 16))
}

///|
fn hex_digit_upper(value : Int) -> Char {
  match value {
    0 => '0'
    1 => '1'
    2 => '2'
    3 => '3'
    4 => '4'
    5 => '5'
    6 => '6'
    7 => '7'
    8 => '8'
    9 => '9'
    10 => 'A'
    11 => 'B'
    12 => 'C'
    13 => 'D'
    14 => 'E'
    15 => 'F'
    _ => '0'
  }
}

///|
fn serializable_ascii_alpha(ch : Char) -> Bool {
  (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z')
}

///|
fn serializable_ascii_digit(ch : Char) -> Bool {
  ch >= '0' && ch <= '9'
}

///|
fn serializable_tag_name_char(ch : Char) -> Bool {
  serializable_ascii_alpha(ch) ||
  serializable_ascii_digit(ch) ||
  ch == ':' ||
  ch == '_' ||
  ch == '-'
}

///|
fn serializable_attr_name_start(ch : Char) -> Bool {
  serializable_ascii_alpha(ch) || ch == '_' || ch == ':'
}

///|
fn serializable_attr_name_char(ch : Char) -> Bool {
  serializable_attr_name_start(ch) ||
  serializable_ascii_digit(ch) ||
  ch == '-' ||
  ch == '.'
}

///|
fn validate_serializable_tag_name(name : StringView) -> Unit raise HtmlError {
  match name.get_char(0) {
    Some(ch) if serializable_ascii_alpha(ch) => {
      let mut pos = ch.utf16_len()
      while pos < name.length() {
        match name.get_char(pos) {
          Some(ch) if serializable_tag_name_char(ch) => pos += ch.utf16_len()
          _ =>
            raise InvalidSerialization(
              "Unsafe element name for serialization: " + name.to_owned(),
            )
        }
      }
    }
    _ =>
      raise InvalidSerialization(
        "Unsafe element name for serialization: " + name.to_owned(),
      )
  }
}

///|
fn validate_serializable_attr_name(name : StringView) -> Unit raise HtmlError {
  match name.get_char(0) {
    Some(ch) if serializable_attr_name_start(ch) => {
      let mut pos = ch.utf16_len()
      while pos < name.length() {
        match name.get_char(pos) {
          Some(ch) if serializable_attr_name_char(ch) => pos += ch.utf16_len()
          _ =>
            raise InvalidSerialization(
              "Unsafe attribute name for serialization: " + name.to_owned(),
            )
        }
      }
    }
    _ =>
      raise InvalidSerialization(
        "Unsafe attribute name for serialization: " + name.to_owned(),
      )
  }
}

///|
fn serialize_comment_data(value : StringView) -> String {
  let mut out = value.replace_all(old="--", new="- -").to_owned()
  if out.has_prefix(">") || out.has_prefix("->") {
    out = " " + out
  }
  if out.has_suffix("<!-") || out.has_suffix("-") {
    out = out + " "
  }
  out
}

///|
fn neutralize_rawtext_end_tag_sequences(
  value : StringView,
  tag_name : StringView,
) -> String {
  let needle = "</" + tag_name.to_owned()
  let out = StringBuilder::new(size_hint=value.length())
  let mut pos = 0
  while pos < value.length() {
    if rawtext_end_tag_sequence_at(value, pos, needle) {
      out.write_string("&lt;")
      pos += 1
    } else {
      let ch = value.get_char(pos).unwrap()
      out.write_char(ch)
      pos += ch.utf16_len()
    }
  }
  out.to_string()
}

///|
fn rawtext_end_tag_sequence_at(
  value : StringView,
  pos : Int,
  needle : StringView,
) -> Bool {
  if starts_with_case_insensitive(value, pos, needle) {
    rawtext_end_tag_boundary(value.get_char(pos + needle.length()))
  } else {
    false
  }
}

///|
fn rawtext_end_tag_boundary(ch : Char?) -> Bool {
  match ch {
    None | Some('>') | Some('/') => true
    Some(ch) if is_html_whitespace_char(ch) => true
    _ => false
  }
}

///|
fn attr_value_should_minimize(name : StringView, value : StringView) -> Bool {
  value.is_empty() || value.compare_ignore_ascii_case(name) == 0
}

///|
fn choose_attr_quote(value : StringView, preferred : Char) -> Char {
  if preferred == '\'' {
    '\''
  } else if string_contains_char(value, '"') &&
    !string_contains_char(value, '\'') {
    '\''
  } else {
    '"'
  }
}

///|
fn validate_serialization_quote(quote : Char) -> Char raise HtmlError {
  match quote {
    '"' | '\'' => quote
    _ => raise InvalidSerialization("quote must be ' or \"")
  }
}

///|
fn string_contains_char(value : StringView, needle : Char) -> Bool {
  for ch in value {
    if ch == needle {
      return true
    }
  }
  false
}

///|
fn serialize_start_tag_unchecked(node : Node, quote : Char) -> String {
  let out = StringBuilder::new()
  out.write_char('<')
  out.write_string(node.name)
  for name, value in node.attrs {
    out.write_char(' ')
    out.write_string(name)
    match value {
      Some(v) if attr_value_should_minimize(name, v) => ()
      Some(v) => {
        let attr_quote = choose_attr_quote(v, quote)
        out.write_char('=')
        out.write_char(attr_quote)
        out.write_string(escape_attr_value(v, attr_quote))
        out.write_char(attr_quote)
      }
      None => ()
    }
  }
  out.write_char('>')
  out.to_string()
}

///|
fn serialize_start_tag(node : Node, quote : Char) -> String raise HtmlError {
  validate_serializable_tag_name(node.name)
  for name, _ in node.attrs {
    validate_serializable_attr_name(name)
  }
  serialize_start_tag_unchecked(node, quote)
}

///|
fn node_to_html_compact(node : Node, quote : Char) -> String raise HtmlError {
  match node.kind {
    Text if node.sanitize_escape_only => ""
    Document | Fragment => {
      let out = StringBuilder::new()
      for child in node.children {
        out.write_string(node_to_html_compact(child, quote))
      }
      out.to_string()
    }
    Text =>
      match node.parent {
        Some(parent) if parent.name == "script" || parent.name == "style" =>
          neutralize_rawtext_end_tag_sequences(node.data, parent.name)
        _ => escape_text(node.data)
      }
    Comment => "<!--" + serialize_comment_data(node.data) + "-->"
    Doctype => {
      let out = StringBuilder::new()
      out.write_string("<!DOCTYPE")
      if node.data != "" {
        validate_serializable_tag_name(node.data)
        out.write_char(' ')
        out.write_string(node.data)
      }
      match node.public_id {
        Some(value) => {
          out.write_string(" PUBLIC \"")
          out.write_string(escape_attr_value(value, '"'))
          out.write_char('"')
        }
        None => ()
      }
      match node.system_id {
        Some(value) => {
          if node.public_id is None {
            out.write_string(" SYSTEM")
          }
          out.write_string(" \"")
          out.write_string(escape_attr_value(value, '"'))
          out.write_char('"')
        }
        None => ()
      }
      out.write_char('>')
      out.to_string()
    }
    Element => {
      let out = StringBuilder::new()
      out.write_string(serialize_start_tag(node, quote))
      if !is_void_element(node.name) {
        for child in node.children {
          out.write_string(node_to_html_compact(child, quote))
        }
        out.write_string("</")
        out.write_string(node.name)
        out.write_char('>')
      }
      out.to_string()
    }
  }
}

///|
fn collapse_html_whitespace(value : StringView) -> String {
  let out = StringBuilder::new(size_hint=value.length())
  let mut pending_space = false
  let mut wrote = false
  for ch in value {
    if is_html_whitespace_char(ch) {
      if wrote {
        pending_space = true
      }
    } else {
      if pending_space {
        out.write_char(' ')
        pending_space = false
      }
      out.write_char(ch)
      wrote = true
    }
  }
  out.to_string()
}

///|
fn element_has_only_text_children(node : Node) -> Bool {
  if node.children.is_empty() {
    return false
  }
  for child in node.children {
    if child.kind != Text {
      return false
    }
  }
  true
}

///|
fn pretty_text_preserves_whitespace(name : StringView) -> Bool {
  match name {
    "script" | "style" | "pre" | "textarea" | "listing" | "xmp" | "plaintext" =>
      true
    _ => false
  }
}

///|
fn compact_pretty_text_children(
  node : Node,
  quote : Char,
) -> String raise HtmlError {
  let out = StringBuilder::new()
  if pretty_text_preserves_whitespace(node.name) {
    for child in node.children {
      out.write_string(node_to_html_compact(child, quote))
    }
  } else {
    let raw = StringBuilder::new()
    for child in node.children {
      if !child.sanitize_escape_only {
        raw.write_string(child.data)
      }
    }
    out.write_string(escape_text(collapse_html_whitespace(raw.to_string())))
  }
  out.to_string()
}

///|
fn formatting_whitespace_char(ch : Char) -> Bool {
  match ch {
    '\n' | '\r' | '\t' | '\u{000C}' => true
    _ => false
  }
}

///|
fn string_view_has_formatting_whitespace(value : StringView) -> Bool {
  for ch in value {
    if formatting_whitespace_char(ch) {
      return true
    }
  }
  false
}

///|
fn compact_pretty_whitespace_separator(value : StringView) -> Bool {
  string_view_has_formatting_whitespace(value) || value.length() > 2
}

///|
fn normalize_formatting_whitespace(value : StringView) -> String {
  let mut has_formatting = false
  for ch in value {
    if formatting_whitespace_char(ch) {
      has_formatting = true
      break
    }
  }
  if !has_formatting {
    return value.to_owned()
  }
  let out : Array[String] = []
  let mut pos = 0
  while pos < value.length() {
    guard value.get_char(pos) is Some(ch) else { break }
    if formatting_whitespace_char(ch) {
      while !out.is_empty() && out.last() == Some(" ") {
        ignore(out.pop())
      }
      let mut run_has_space = false
      while pos < value.length() {
        guard value.get_char(pos) is Some(run_ch) else { break }
        if run_ch == ' ' {
          run_has_space = true
          pos += run_ch.utf16_len()
        } else if formatting_whitespace_char(run_ch) {
          pos += run_ch.utf16_len()
        } else {
          break
        }
      }
      if !out.is_empty() && (pos < value.length() || run_has_space) {
        out.push(" ")
      }
    } else {
      out.push(ch.to_string())
      pos += ch.utf16_len()
    }
  }
  out.join("")
}

///|
fn text_has_visible_char(value : StringView) -> Bool {
  for ch in value {
    if !is_html_whitespace_char(ch) {
      return true
    }
  }
  false
}

///|
fn layout_block_element_name(name : StringView) -> Bool {
  match name {
    "address"
    | "article"
    | "aside"
    | "blockquote"
    | "body"
    | "caption"
    | "center"
    | "dd"
    | "details"
    | "dialog"
    | "dir"
    | "div"
    | "dl"
    | "dt"
    | "fieldset"
    | "figcaption"
    | "figure"
    | "footer"
    | "form"
    | "h1"
    | "h2"
    | "h3"
    | "h4"
    | "h5"
    | "h6"
    | "header"
    | "hgroup"
    | "hr"
    | "html"
    | "iframe"
    | "li"
    | "listing"
    | "main"
    | "marquee"
    | "menu"
    | "nav"
    | "noframes"
    | "noscript"
    | "ol"
    | "p"
    | "plaintext"
    | "pre"
    | "search"
    | "section"
    | "summary"
    | "table"
    | "tbody"
    | "td"
    | "tfoot"
    | "th"
    | "thead"
    | "tr"
    | "ul" => true
    _ => false
  }
}

///|
fn inline_pretty_element_name(name : StringView) -> Bool {
  match name {
    "a"
    | "abbr"
    | "b"
    | "bdi"
    | "bdo"
    | "cite"
    | "code"
    | "data"
    | "del"
    | "dfn"
    | "em"
    | "i"
    | "ins"
    | "kbd"
    | "label"
    | "mark"
    | "q"
    | "rp"
    | "rt"
    | "ruby"
    | "s"
    | "samp"
    | "small"
    | "span"
    | "strong"
    | "sub"
    | "sup"
    | "time"
    | "u"
    | "var" => true
    _ => false
  }
}

///|
fn node_contains_layout_block(node : Node) -> Bool {
  if node.kind == Element && layout_block_element_name(node.name) {
    return true
  }
  for child in node.children {
    if node_contains_layout_block(child) {
      return true
    }
  }
  false
}

///|
fn element_has_compact_inline_children(node : Node) -> Bool {
  let mut has_visible_text = false
  let mut has_inline_element = false
  for child in node.children {
    match child.kind {
      Text => if text_has_visible_char(child.data) { has_visible_text = true }
      Element => {
        if !inline_pretty_element_name(child.name) ||
          node_contains_layout_block(child) {
          return false
        }
        has_inline_element = true
      }
      _ => return false
    }
  }
  has_visible_text ||
  (has_inline_element && !layout_block_element_name(node.name))
}

///|
fn element_has_comment_child(node : Node) -> Bool {
  for child in node.children {
    if child.kind == Comment {
      return true
    }
  }
  false
}

///|
fn node_is_pretty_formatting_separator(node : Node) -> Bool {
  node.kind == Text &&
  !text_has_visible_char(node.data) &&
  compact_pretty_whitespace_separator(node.data)
}

///|
fn pretty_inline_run_to_html(
  run : Array[Node],
  quote : Char,
) -> String raise HtmlError {
  let out = StringBuilder::new()
  for child in run {
    match child.kind {
      Text => {
        if child.sanitize_escape_only {
          continue
        }
        let data = child.data[:]
        if text_has_visible_char(data) {
          out.write_string(escape_text(normalize_formatting_whitespace(data)))
        } else {
          out.write_string(escape_text(data))
        }
      }
      _ => out.write_string(node_to_html_compact(child, quote))
    }
  }
  out.to_string()
}

///|
fn node_to_html_pretty_inline_runs(
  node : Node,
  indent : Int,
  indent_size : Int,
  quote : Char,
) -> String? raise HtmlError {
  if !layout_block_element_name(node.name) ||
    !element_has_compact_inline_children(node) {
    return None
  }
  let runs : Array[Array[Node]] = []
  let mut current : Array[Node] = []
  let mut saw_separator = false
  for child in node.children {
    if node_is_pretty_formatting_separator(child) {
      saw_separator = true
      if !current.is_empty() {
        runs.push(current)
        current = []
      }
    } else {
      current.push(child)
    }
  }
  if !current.is_empty() {
    runs.push(current)
  }
  if !saw_separator || runs.is_empty() {
    return None
  }
  let out = StringBuilder::new()
  out.write_string(" ".repeat(indent))
  out.write_string(serialize_start_tag(node, quote))
  let child_prefix = " ".repeat(indent + indent_size)
  let mut wrote_run = false
  for run in runs {
    let line = pretty_inline_run_to_html(run, quote)
    if line.is_empty() {
      continue
    }
    wrote_run = true
    out.write_char('\n')
    out.write_string(child_prefix)
    out.write_string(line)
  }
  if !wrote_run {
    return None
  }
  out.write_char('\n')
  out.write_string(" ".repeat(indent))
  out.write_string("</")
  out.write_string(node.name)
  out.write_char('>')
  Some(out.to_string())
}

///|
fn node_to_html_pretty_compact_part(
  node : Node,
  quote : Char,
  indent_size : Int,
) -> String raise HtmlError {
  match node.kind {
    Document | Fragment => node_to_html_pretty(node, 0, indent_size, quote)
    _ => node_to_html_compact(node, quote)
  }
}

///|
fn node_to_html_pretty_compact_children(
  node : Node,
  quote : Char,
  indent_size : Int,
) -> String raise HtmlError {
  let out = StringBuilder::new()
  out.write_string(serialize_start_tag(node, quote))
  let child_count = node.children.length()
  for index in 0..<child_count {
    let child = node.children[index]
    match child.kind {
      Text => {
        if child.sanitize_escape_only {
          continue
        }
        let data = child.data[:]
        let has_visible = text_has_visible_char(data)
        if !has_visible && (index == 0 || index + 1 == child_count) {
          ()
        } else if !has_visible && compact_pretty_whitespace_separator(data) {
          out.write_char(' ')
        } else {
          let normalized = normalize_formatting_whitespace(data)
          out.write_string(escape_text(normalized))
        }
      }
      _ =>
        out.write_string(
          node_to_html_pretty_compact_part(child, quote, indent_size),
        )
    }
  }
  out.write_string("</")
  out.write_string(node.name)
  out.write_char('>')
  out.to_string()
}

///|
fn node_to_html_pretty_child_line(
  node : Node,
  indent : Int,
  indent_size : Int,
  quote : Char,
) -> String? raise HtmlError {
  match node.kind {
    Text => {
      if node.sanitize_escape_only {
        return None
      }
      let normalized = normalize_formatting_whitespace(node.data)
      let trimmed = normalized[:].trim()
      if trimmed.is_empty() {
        None
      } else {
        Some(" ".repeat(indent) + escape_text(trimmed))
      }
    }
    Document | Fragment => {
      let rendered = node_to_html_pretty(node, indent, indent_size, quote)
      if rendered.is_empty() {
        None
      } else {
        Some(rendered)
      }
    }
    _ => Some(node_to_html_pretty(node, indent, indent_size, quote))
  }
}

///|
fn node_to_html_pretty(
  node : Node,
  indent : Int,
  indent_size : Int,
  quote : Char,
) -> String raise HtmlError {
  match node.kind {
    Document | Fragment => {
      let parts : Array[String] = []
      for child in node.children {
        match
          node_to_html_pretty_child_line(child, indent, indent_size, quote) {
          Some(line) => parts.push(line)
          None => ()
        }
      }
      parts.join("\n")
    }
    Text =>
      if node.sanitize_escape_only {
        ""
      } else {
        let normalized = normalize_formatting_whitespace(node.data)
        let trimmed = normalized[:].trim()
        if trimmed.is_empty() {
          ""
        } else {
          " ".repeat(indent) + escape_text(trimmed)
        }
      }
    Comment | Doctype => " ".repeat(indent) + node_to_html_compact(node, quote)
    Element =>
      if node.children.is_empty() || is_void_element(node.name) {
        " ".repeat(indent) + node_to_html_compact(node, quote)
      } else if pretty_text_preserves_whitespace(node.name) {
        " ".repeat(indent) + node_to_html_compact(node, quote)
      } else if element_has_only_text_children(node) {
        let out = StringBuilder::new()
        out.write_string(" ".repeat(indent))
        out.write_string(serialize_start_tag(node, quote))
        out.write_string(compact_pretty_text_children(node, quote))
        out.write_string("</")
        out.write_string(node.name)
        out.write_char('>')
        out.to_string()
      } else if node_to_html_pretty_inline_runs(
          node, indent, indent_size, quote,
        )
        is Some(html) {
        html
      } else if element_has_compact_inline_children(node) {
        " ".repeat(indent) +
        node_to_html_pretty_compact_children(node, quote, indent_size)
      } else if element_has_comment_child(node) {
        " ".repeat(indent) +
        node_to_html_pretty_compact_children(node, quote, indent_size)
      } else {
        let out = StringBuilder::new()
        out.write_string(" ".repeat(indent))
        out.write_string(serialize_start_tag(node, quote))
        let child_indent = indent + indent_size
        let mut wrote_child = false
        for child in node.children {
          match
            node_to_html_pretty_child_line(
              child, child_indent, indent_size, quote,
            ) {
            Some(line) => {
              wrote_child = true
              out.write_char('\n')
              out.write_string(line)
            }
            None => ()
          }
        }
        if wrote_child {
          out.write_char('\n')
          out.write_string(" ".repeat(indent))
          out.write_string("</")
          out.write_string(node.name)
          out.write_char('>')
          out.to_string()
        } else {
          " ".repeat(indent) +
          node_to_html_pretty_compact_children(node, quote, indent_size)
        }
      }
  }
}

///|
fn render_node_html(
  node : Node,
  pretty : Bool,
  indent_size : Int,
  quote : Char,
) -> String raise HtmlError {
  if pretty {
    node_to_html_pretty(node, 0, indent_size, quote)
  } else {
    node_to_html_compact(node, quote)
  }
}

///|
/// Serialize this node and its descendants as HTML or an escaped context value.
///
/// `pretty=false` emits compact HTML. `context` controls escaping for raw HTML,
/// JavaScript strings, HTML attribute values, or URL text extraction.
pub fn Node::to_html(
  self : Node,
  pretty? : Bool = true,
  indent_size? : Int = 2,
  context? : HtmlContext = Html,
  quote? : Char = '"',
) -> String raise HtmlError {
  match context {
    Html => {
      let quote_char = if quote == '\'' { '\'' } else { '"' }
      render_node_html(self, pretty, indent_size, quote_char)
    }
    JsString => {
      let quote_char = validate_serialization_quote(quote)
      escape_js_string(
        render_node_html(self, pretty, indent_size, quote_char),
        quote_char,
      )
    }
    HtmlAttrValue => {
      let quote_char = validate_serialization_quote(quote)
      escape_attr_value(
        render_node_html(self, pretty, indent_size, quote_char),
        quote_char,
      )
    }
    Url => percent_encode_url(self.to_text().trim())
  }
}

///|
/// Serialize a node as HTML.
///
/// This is the function form of `Node::to_html`.
pub fn to_html(
  node : Node,
  pretty? : Bool = true,
  indent_size? : Int = 2,
  context? : HtmlContext = Html,
  quote? : Char = '"',
) -> String raise HtmlError {
  node.to_html(pretty~, indent_size~, context~, quote~)
}

///|
fn collect_text(node : Node, parts : Array[String], strip : Bool) -> Unit {
  match node.kind {
    Text => {
      if node.sanitize_escape_only {
        return
      }
      let value = if strip { node.data[:].trim().to_owned() } else { node.data }
      if value != "" {
        parts.push(value)
      }
    }
    _ =>
      for child in node.children {
        collect_text(child, parts, strip)
      }
  }
}

///|
fn is_text_block_element(name : StringView) -> Bool {
  match name {
    "address"
    | "article"
    | "aside"
    | "blockquote"
    | "body"
    | "dd"
    | "div"
    | "dl"
    | "dt"
    | "fieldset"
    | "figcaption"
    | "figure"
    | "footer"
    | "form"
    | "h1"
    | "h2"
    | "h3"
    | "h4"
    | "h5"
    | "h6"
    | "header"
    | "hr"
    | "html"
    | "li"
    | "main"
    | "nav"
    | "ol"
    | "p"
    | "pre"
    | "section"
    | "table"
    | "tbody"
    | "td"
    | "tfoot"
    | "th"
    | "thead"
    | "tr"
    | "ul" => true
    _ => false
  }
}

///|
fn text_chunk_break(chunks : Array[Array[String]]) -> Unit {
  match chunks.last() {
    Some(chunk) if !chunk.is_empty() => chunks.push([])
    None => chunks.push([])
    _ => ()
  }
}

///|
fn current_text_chunk(chunks : Array[Array[String]]) -> Array[String] {
  match chunks.last() {
    Some(chunk) => chunk
    None => {
      let chunk : Array[String] = []
      chunks.push(chunk)
      chunk
    }
  }
}

///|
fn collect_text_block_chunks(
  node : Node,
  chunks : Array[Array[String]],
  strip : Bool,
) -> Unit {
  match node.kind {
    Text => {
      if node.sanitize_escape_only {
        return
      }
      let value = if strip { node.data[:].trim().to_owned() } else { node.data }
      if value != "" {
        current_text_chunk(chunks).push(value)
      }
    }
    Element if node.name == "br" => text_chunk_break(chunks)
    Element if is_text_block_element(node.name) => {
      text_chunk_break(chunks)
      for child in node.children {
        collect_text_block_chunks(child, chunks, strip)
      }
      text_chunk_break(chunks)
    }
    _ =>
      for child in node.children {
        collect_text_block_chunks(child, chunks, strip)
      }
  }
}

///|
fn text_chunks_to_string(
  chunks : Array[Array[String]],
  separator : String,
  strip : Bool,
) -> String {
  let texts : Array[String] = []
  let intra_sep = if strip { " " } else { "" }
  for chunk in chunks {
    if !chunk.is_empty() {
      texts.push(chunk.join(intra_sep))
    }
  }
  texts.join(separator)
}

///|
/// Extract descendant text from this node.
///
/// `separator` is inserted between text chunks. Set
/// `separator_blocks_only=true` to join only block-level text groups.
pub fn Node::to_text(
  self : Node,
  separator? : String = " ",
  strip? : Bool = true,
  separator_blocks_only? : Bool = false,
) -> String {
  if separator_blocks_only {
    let chunks : Array[Array[String]] = [[]]
    collect_text_block_chunks(self, chunks, strip)
    return text_chunks_to_string(chunks, separator, strip)
  }
  let parts : Array[String] = []
  collect_text(self, parts, strip)
  parts.join(separator)
}

///|
fn class_contains(value : StringView, needle : StringView) -> Bool {
  if needle.is_empty() {
    return false
  }
  let mut token_start = 0
  let mut pos = 0
  for ch in value {
    if is_html_whitespace_char(ch) {
      if class_token_matches(value, token_start, pos, needle) {
        return true
      }
      pos += ch.utf16_len()
      token_start = pos
    } else {
      pos += ch.utf16_len()
    }
  }
  class_token_matches(value, token_start, value.length(), needle)
}

///|
fn class_token_matches(
  value : StringView,
  start : Int,
  end : Int,
  needle : StringView,
) -> Bool {
  if end <= start {
    false
  } else {
    value[start:end] == needle
  }
}

///|
fn is_html_whitespace_char(ch : Char) -> Bool {
  match ch {
    ' ' | '\t' | '\n' | '\r' | '\u{000C}' => true
    _ => false
  }
}

///|
fn next_simple_selector_marker(selector : StringView, start : Int) -> Int {
  let mut pos = start
  let mut paren_depth = 0
  while pos < selector.length() {
    let ch = selector.get_char(pos).unwrap()
    if ch == '(' {
      paren_depth += 1
    } else if ch == ')' && paren_depth > 0 {
      paren_depth -= 1
    } else if paren_depth == 0 &&
      (ch == '.' || ch == '#' || ch == '[' || ch == ':') {
      return pos
    }
    pos += ch.utf16_len()
  }
  selector.length()
}

///|
fn find_attribute_selector_end(selector : StringView, start : Int) -> Int? {
  let mut pos = start + 1
  let mut quote : Char? = None
  let mut escaped = false
  while pos < selector.length() {
    let ch = selector.get_char(pos).unwrap()
    match quote {
      Some(q) =>
        if escaped {
          escaped = false
        } else if ch == '\\' {
          escaped = true
        } else if ch == q {
          quote = None
        }
      None =>
        if ch == '"' || ch == '\'' {
          quote = Some(ch)
          escaped = false
        } else if ch == ']' {
          return Some(pos)
        }
    }
    pos += ch.utf16_len()
  }
  None
}

///|
fn tag_selector_matches(node : Node, tag : StringView) -> Bool {
  tag == "*" || node.name[:] == tag.to_lower()
}

///|
fn id_selector_matches(node : Node, id : StringView) -> Bool {
  match node.attrs.get("id") {
    Some(Some(value)) => value[:] == id
    _ => false
  }
}

///|
fn class_selector_matches(node : Node, class_name : StringView) -> Bool {
  match node.attrs.get("class") {
    Some(Some(value)) => class_contains(value, class_name)
    _ => false
  }
}

///|
fn attribute_value_by_name(node : Node, attr_name : StringView) -> String? {
  let wanted = lower_ascii(attr_name)
  for name, value in node.attrs {
    if lower_ascii(name) == wanted {
      return Some(
        match value {
          Some(text) => text
          None => ""
        },
      )
    }
  }
  None
}

///|
priv enum AttributeSelectorOperator {
  AttrExact
  AttrWord
  AttrHyphen
  AttrPrefix
  AttrSuffix
  AttrContains
}

///|
fn attribute_name_with_operator(
  name : StringView,
  operator : AttributeSelectorOperator,
) -> (StringView, AttributeSelectorOperator)? {
  let end = name.length() - 1
  guard name.get_view(start=0, end~) is Some(name) else { return None }
  let name = name.trim()
  if !selector_identifier_is_valid(name) {
    None
  } else {
    Some((name, operator))
  }
}

///|
fn selector_identifier_start(ch : Char) -> Bool {
  ch == '_' || ch == '-' || ch.is_ascii_alphabetic() || ch.to_int() > 127
}

///|
fn selector_identifier_char(ch : Char) -> Bool {
  selector_identifier_start(ch) || ch.is_digit(10)
}

///|
fn selector_identifier_is_valid(name : StringView) -> Bool {
  if name.is_empty() {
    return false
  }
  guard name.get_char(0) is Some(first) else { return false }
  if !selector_identifier_start(first) {
    return false
  }
  let mut pos = first.utf16_len()
  while pos < name.length() {
    match name.get_char(pos) {
      Some(ch) if selector_identifier_char(ch) => pos += ch.utf16_len()
      _ => return false
    }
  }
  true
}

///|
fn attribute_name_and_operator(
  name : StringView,
) -> (StringView, AttributeSelectorOperator)? {
  let name = name.trim()
  if name.has_suffix("~") {
    attribute_name_with_operator(name, AttrWord)
  } else if name.has_suffix("|") {
    attribute_name_with_operator(name, AttrHyphen)
  } else if name.has_suffix("^") {
    attribute_name_with_operator(name, AttrPrefix)
  } else if name.has_suffix("$") {
    attribute_name_with_operator(name, AttrSuffix)
  } else if name.has_suffix("*") {
    attribute_name_with_operator(name, AttrContains)
  } else if selector_identifier_is_valid(name) {
    Some((name, AttrExact))
  } else {
    None
  }
}

///|
fn quoted_attribute_selector_value(value : StringView) -> String? {
  let value = value.trim()
  if value.length() < 2 {
    return Some(value.to_owned())
  }
  let end = value.length() - 1
  match (value.get_char(0), value.get_char(end)) {
    (Some('"'), Some('"')) | (Some('\''), Some('\'')) =>
      Some(unescape_quoted_attribute_selector_value(value[1:end]))
    _ =>
      if string_view_has_html_whitespace(value) {
        None
      } else {
        Some(value.to_owned())
      }
  }
}

///|
fn string_view_has_html_whitespace(value : StringView) -> Bool {
  for ch in value {
    if is_html_whitespace_char(ch) {
      return true
    }
  }
  false
}

///|
fn unescape_quoted_attribute_selector_value(value : StringView) -> String {
  let out = StringBuilder::new(size_hint=value.length())
  let mut escaped = false
  for ch in value {
    if escaped {
      out.write_char(ch)
      escaped = false
    } else if ch == '\\' {
      escaped = true
    } else {
      out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn string_view_contains(haystack : StringView, needle : StringView) -> Bool {
  if needle.is_empty() || needle.length() > haystack.length() {
    return false
  }
  let mut pos = 0
  while pos + needle.length() <= haystack.length() {
    match haystack.get_view(start=pos, end=pos + needle.length()) {
      Some(part) if part == needle => return true
      _ => ()
    }
    pos += haystack.get_char(pos).unwrap().utf16_len()
  }
  false
}

///|
fn attribute_hyphen_matches(actual : StringView, expected : StringView) -> Bool {
  if actual == expected {
    return true
  }
  if actual.length() <= expected.length() || !actual.has_prefix(expected) {
    return false
  }
  match actual.get_char(expected.length()) {
    Some('-') => true
    _ => false
  }
}

///|
fn attribute_value_matches(
  actual : StringView,
  operator : AttributeSelectorOperator,
  expected : StringView,
) -> Bool {
  match operator {
    AttrExact => actual == expected
    AttrWord => class_contains(actual, expected)
    AttrHyphen => attribute_hyphen_matches(actual, expected)
    AttrPrefix => !expected.is_empty() && actual.has_prefix(expected)
    AttrSuffix => !expected.is_empty() && actual.has_suffix(expected)
    AttrContains => string_view_contains(actual, expected)
  }
}

///|
fn attribute_selector_matches(node : Node, selector : StringView) -> Bool {
  let selector = selector.trim()
  if selector.is_empty() {
    return false
  }
  match selector.split_once("=") {
    Some((name, expected)) => {
      guard attribute_name_and_operator(name) is Some((name, operator)) else {
        return false
      }
      guard quoted_attribute_selector_value(expected) is Some(expected) else {
        return false
      }
      match attribute_value_by_name(node, name) {
        Some(actual) => attribute_value_matches(actual, operator, expected)
        None => false
      }
    }
    None =>
      selector_identifier_is_valid(selector) &&
      attribute_value_by_name(node, selector) is Some(_)
  }
}

///|
fn attribute_selector_is_valid(selector : StringView) -> Bool {
  let selector = selector.trim()
  if selector.is_empty() {
    return false
  }
  match selector.split_once("=") {
    Some((name, expected)) =>
      attribute_name_and_operator(name) is Some(_) &&
      quoted_attribute_selector_value(expected) is Some(_)
    None => selector_identifier_is_valid(selector)
  }
}

///|
fn is_first_element_child(node : Node) -> Bool {
  match node.parent {
    Some(parent) => {
      for child in parent.children {
        if child.kind == Element {
          return physical_equal(child, node)
        }
      }
      false
    }
    None => false
  }
}

///|
fn is_last_element_child(node : Node) -> Bool {
  match node.parent {
    Some(parent) => {
      let mut last : Node? = None
      for child in parent.children {
        if child.kind == Element {
          last = Some(child)
        }
      }
      match last {
        Some(child) => physical_equal(child, node)
        None => false
      }
    }
    None => false
  }
}

///|
fn is_only_element_child(node : Node) -> Bool {
  is_first_element_child(node) && is_last_element_child(node)
}

///|
fn is_empty_for_selector(node : Node) -> Bool {
  for child in node.children {
    match child.kind {
      Element => return false
      Text if !child.data[:].trim().is_empty() => return false
      _ => ()
    }
  }
  true
}

///|
fn is_root_for_selector(node : Node) -> Bool {
  match node.parent {
    Some(parent) => parent.kind == Document || parent.kind == Fragment
    None => false
  }
}

///|
fn is_first_of_type(node : Node) -> Bool {
  match node.parent {
    Some(parent) => {
      for child in parent.children {
        if child.kind == Element && child.name == node.name {
          return physical_equal(child, node)
        }
      }
      false
    }
    None => false
  }
}

///|
fn is_last_of_type(node : Node) -> Bool {
  match node.parent {
    Some(parent) => {
      let mut last : Node? = None
      for child in parent.children {
        if child.kind == Element && child.name == node.name {
          last = Some(child)
        }
      }
      match last {
        Some(child) => physical_equal(child, node)
        None => false
      }
    }
    None => false
  }
}

///|
fn is_only_of_type(node : Node) -> Bool {
  is_first_of_type(node) && is_last_of_type(node)
}

///|
fn element_child_index(node : Node) -> Int? {
  match node.parent {
    Some(parent) => {
      let mut index = 0
      for child in parent.children {
        if child.kind == Element {
          index += 1
          if physical_equal(child, node) {
            return Some(index)
          }
        }
      }
      None
    }
    None => None
  }
}

///|
fn element_type_index(node : Node) -> Int? {
  match node.parent {
    Some(parent) => {
      let mut index = 0
      for child in parent.children {
        if child.kind == Element && child.name == node.name {
          index += 1
          if physical_equal(child, node) {
            return Some(index)
          }
        }
      }
      None
    }
    None => None
  }
}

///|
fn normalize_nth_expression(expr : StringView) -> String {
  let out = StringBuilder::new(size_hint=expr.length())
  for ch in expr {
    if !ch.is_ascii_whitespace() {
      if ch.is_ascii_uppercase() {
        out.write_char(ch.to_ascii_lowercase())
      } else {
        out.write_char(ch)
      }
    }
  }
  out.to_string()
}

///|
fn parse_signed_int_view(expr : StringView) -> Int? {
  if expr.is_empty() {
    return None
  }
  let mut sign = 1
  let mut pos = 0
  match expr.get_char(pos) {
    Some('+') => pos += 1
    Some('-') => {
      sign = -1
      pos += 1
    }
    _ => ()
  }
  if pos >= expr.length() {
    return None
  }
  let mut value = 0
  while pos < expr.length() {
    match expr.get_char(pos) {
      Some(ch) if ch.is_digit(10) => {
        value = value * 10 + ch.to_int() - ('0' : Int)
        pos += ch.utf16_len()
      }
      _ => return None
    }
  }
  Some(sign * value)
}

///|
fn parse_nth_expression(expr : StringView) -> (Int, Int)? {
  let normalized = normalize_nth_expression(expr)
  let expr = normalized[:]
  if expr.is_empty() {
    return None
  }
  if expr == "odd" {
    return Some((2, 1))
  }
  if expr == "even" {
    return Some((2, 0))
  }
  match expr.split_once("n") {
    Some((a_part, b_part)) => {
      if string_view_contains(b_part, "n") {
        return None
      }
      let a = if a_part.is_empty() || a_part == "+" {
        Some(1)
      } else if a_part == "-" {
        Some(-1)
      } else {
        parse_signed_int_view(a_part)
      }
      guard a is Some(a) else { return None }
      let b = if b_part.is_empty() {
        Some(0)
      } else {
        parse_signed_int_view(b_part)
      }
      guard b is Some(b) else { return None }
      Some((a, b))
    }
    None =>
      match parse_signed_int_view(expr) {
        Some(b) => Some((0, b))
        None => None
      }
  }
}

///|
fn nth_formula_matches(index : Int, a : Int, b : Int) -> Bool {
  if a == 0 {
    index == b
  } else {
    let diff = index - b
    if a > 0 {
      diff >= 0 && diff % a == 0
    } else {
      diff <= 0 && diff % a == 0
    }
  }
}

///|
fn is_nth_child(node : Node, expr : StringView) -> Bool {
  guard parse_nth_expression(expr) is Some((a, b)) else { return false }
  match element_child_index(node) {
    Some(index) => nth_formula_matches(index, a, b)
    None => false
  }
}

///|
fn is_nth_of_type(node : Node, expr : StringView) -> Bool {
  guard parse_nth_expression(expr) is Some((a, b)) else { return false }
  match element_type_index(node) {
    Some(index) => nth_formula_matches(index, a, b)
    None => false
  }
}

///|
fn unescape_quoted_pseudo_arg(value : StringView, quote : Char) -> String {
  let out = StringBuilder::new(size_hint=value.length())
  let mut escaped = false
  for ch in value {
    if escaped {
      if ch == quote || ch == '\\' {
        out.write_char(ch)
      } else {
        out.write_char('\\')
        out.write_char(ch)
      }
      escaped = false
    } else if ch == '\\' {
      escaped = true
    } else {
      out.write_char(ch)
    }
  }
  if escaped {
    out.write_char('\\')
  }
  out.to_string()
}

///|
fn unquote_pseudo_arg(arg : StringView) -> String? {
  let arg = arg.trim()
  if arg.is_empty() {
    return None
  }
  if arg.length() >= 2 {
    let end = arg.length() - 1
    match (arg.get_char(0), arg.get_char(end)) {
      (Some('"'), Some('"')) => {
        guard arg.get_view(start=1, end~) is Some(inner) else { return None }
        return Some(unescape_quoted_pseudo_arg(inner, '"'))
      }
      (Some('\''), Some('\'')) => {
        guard arg.get_view(start=1, end~) is Some(inner) else { return None }
        return Some(unescape_quoted_pseudo_arg(inner, '\''))
      }
      _ => ()
    }
  }
  Some(arg.to_owned())
}

///|
fn remove_node_identity(nodes : Array[Node], node : Node) -> Unit {
  let mut index = 0
  while index < nodes.length() {
    if physical_equal(nodes[index], node) {
      ignore(nodes.remove(index))
      return
    }
    index += 1
  }
}

///|
fn node_text_cache_get(
  nodes : Array[Node],
  texts : Array[String],
  node : Node,
) -> String? {
  for index in 0..<nodes.length() {
    if physical_equal(nodes[index], node) {
      return Some(texts[index])
    }
  }
  None
}

///|
fn node_text_cache_set(
  nodes : Array[Node],
  texts : Array[String],
  node : Node,
  text : String,
) -> Unit {
  nodes.push(node)
  texts.push(text)
}

///|
fn selector_text_content(node : Node) -> String {
  let cache_nodes : Array[Node] = []
  let cache_texts : Array[String] = []
  let visiting : Array[Node] = []
  let stack : Array[(Node, Bool)] = [(node, false)]
  while !stack.is_empty() {
    let (current, visited) = stack[stack.length() - 1]
    ignore(stack.pop())
    if node_text_cache_get(cache_nodes, cache_texts, current) is Some(_) {
      continue
    }
    if visited {
      remove_node_identity(visiting, current)
      if current.kind == Text {
        node_text_cache_set(
          cache_nodes,
          cache_texts,
          current,
          current.data[:].trim().to_owned(),
        )
      } else {
        let parts : Array[String] = []
        for child in current.children {
          match node_text_cache_get(cache_nodes, cache_texts, child) {
            Some(text) if text != "" => parts.push(text)
            _ => ()
          }
        }
        node_text_cache_set(cache_nodes, cache_texts, current, parts.join(" "))
      }
    } else if node_identity_seen(visiting, current) {
      node_text_cache_set(cache_nodes, cache_texts, current, "")
    } else {
      visiting.push(current)
      stack.push((current, true))
      let mut index = current.children.length()
      while index > 0 {
        index -= 1
        stack.push((current.children[index], false))
      }
    }
  }
  node_text_cache_get(cache_nodes, cache_texts, node).unwrap_or("")
}

///|
fn contains_text(node : Node, arg : StringView) -> Bool {
  guard unquote_pseudo_arg(arg) is Some(needle) else { return false }
  if needle == "" {
    return true
  }
  let text = selector_text_content(node)
  string_view_contains(text, needle)
}

///|
fn functional_pseudo_parts(name : StringView) -> (StringView, StringView)? {
  match name.split_once("(") {
    Some((pseudo_name, rest)) => {
      let mut depth = 1
      let mut pos = 0
      while pos < rest.length() {
        guard rest.get_char(pos) is Some(ch) else { return None }
        if ch == '(' {
          depth += 1
        } else if ch == ')' {
          depth -= 1
          if depth == 0 {
            if pos + ch.utf16_len() != rest.length() {
              return None
            }
            return Some((pseudo_name, rest[0:pos]))
          }
        }
        pos += ch.utf16_len()
      }
      None
    }
    None => None
  }
}

///|
fn pseudo_selector_matches(node : Node, name : StringView) -> Bool {
  let lower_name = lower_ascii(name)
  match lower_name[:] {
    "comment" => node.kind == Comment
    "first-child" => is_first_element_child(node)
    "last-child" => is_last_element_child(node)
    "only-child" => is_only_element_child(node)
    "empty" => is_empty_for_selector(node)
    "root" => is_root_for_selector(node)
    "first-of-type" => is_first_of_type(node)
    "last-of-type" => is_last_of_type(node)
    "only-of-type" => is_only_of_type(node)
    _ =>
      match functional_pseudo_parts(name) {
        Some((pseudo_name, arg)) =>
          match lower_ascii(pseudo_name)[:] {
            "nth-child" => is_nth_child(node, arg)
            "nth-of-type" => is_nth_of_type(node, arg)
            "not" => !matches_selector_list(node, arg)
            "contains" => contains_text(node, arg)
            "comment" => node.kind == Comment
            _ => false
          }
        _ => false
      }
  }
}

///|
fn pseudo_selector_is_valid(name : StringView) -> Bool {
  let lower_name = lower_ascii(name)
  match lower_name[:] {
    "comment"
    | "first-child"
    | "last-child"
    | "only-child"
    | "empty"
    | "root"
    | "first-of-type"
    | "last-of-type"
    | "only-of-type" => true
    _ =>
      match functional_pseudo_parts(name) {
        Some((pseudo_name, arg)) =>
          match lower_ascii(pseudo_name)[:] {
            "nth-child" | "nth-of-type" | "not" | "comment" => true
            "contains" => !arg.trim().is_empty()
            _ => false
          }
        None => false
      }
  }
}

///|
fn matches_simple_selector(node : Node, selector : StringView) -> Bool {
  let selector = selector.trim()
  if selector.is_empty() {
    return false
  }
  if node.kind != Element {
    return non_element_simple_selector_matches(node, selector)
  }
  let mut pos = 0
  match selector.get_char(pos).unwrap() {
    '*' => {
      pos += 1
      if pos < selector.length() {
        match selector.get_char(pos) {
          Some('.') | Some('#') | Some('[') | Some(':') => ()
          _ => return false
        }
      }
    }
    '.' | '#' | '[' | ':' => ()
    _ => {
      let end = next_simple_selector_marker(selector, pos)
      let tag = selector[pos:end]
      if tag.is_empty() ||
        !selector_identifier_is_valid(tag) ||
        !tag_selector_matches(node, tag) {
        return false
      }
      pos = end
    }
  }
  while pos < selector.length() {
    let marker = selector.get_char(pos).unwrap()
    if marker == '[' {
      guard find_attribute_selector_end(selector, pos) is Some(end) else {
        return false
      }
      let attribute = selector[pos + 1:end]
      if !attribute_selector_matches(node, attribute) {
        return false
      }
      pos = end + 1
      continue
    }
    if marker == ':' {
      let start = pos + marker.utf16_len()
      let end = next_simple_selector_marker(selector, start)
      let name = selector[start:end]
      if name.is_empty() || !pseudo_selector_matches(node, name) {
        return false
      }
      pos = end
      continue
    }
    if marker != '.' && marker != '#' {
      return false
    }
    let start = pos + marker.utf16_len()
    let end = next_simple_selector_marker(selector, start)
    let name = selector[start:end]
    if name.is_empty() || !selector_identifier_is_valid(name) {
      return false
    }
    if marker == '.' {
      if !class_selector_matches(node, name) {
        return false
      }
    } else if !id_selector_matches(node, name) {
      return false
    }
    pos = end
  }
  true
}

///|
fn simple_selector_is_valid(selector : StringView) -> Bool {
  let selector = selector.trim()
  if selector.is_empty() {
    return false
  }
  let mut pos = 0
  match selector.get_char(pos).unwrap() {
    '*' => {
      pos += 1
      if pos < selector.length() {
        match selector.get_char(pos) {
          Some('.') | Some('#') | Some('[') | Some(':') => ()
          _ => return false
        }
      }
    }
    '.' | '#' | '[' | ':' => ()
    _ => {
      let end = next_simple_selector_marker(selector, pos)
      let tag = selector[pos:end]
      if tag.is_empty() || !selector_identifier_is_valid(tag) {
        return false
      }
      pos = end
    }
  }
  while pos < selector.length() {
    let marker = selector.get_char(pos).unwrap()
    if marker == '[' {
      guard find_attribute_selector_end(selector, pos) is Some(end) else {
        return false
      }
      let attribute = selector[pos + 1:end]
      if !attribute_selector_is_valid(attribute) {
        return false
      }
      pos = end + 1
      continue
    }
    if marker == ':' {
      let start = pos + marker.utf16_len()
      let end = next_simple_selector_marker(selector, start)
      let name = selector[start:end]
      if name.is_empty() || !pseudo_selector_is_valid(name) {
        return false
      }
      pos = end
      continue
    }
    if marker != '.' && marker != '#' {
      return false
    }
    let start = pos + marker.utf16_len()
    let end = next_simple_selector_marker(selector, start)
    let name = selector[start:end]
    if name.is_empty() || !selector_identifier_is_valid(name) {
      return false
    }
    pos = end
  }
  true
}

///|
fn non_element_simple_selector_matches(
  node : Node,
  selector : StringView,
) -> Bool {
  let mut pos = 0
  while pos < selector.length() {
    guard selector.get_char(pos) is Some(':') else { return false }
    let start = pos + ':'.utf16_len()
    let end = next_simple_selector_marker(selector, start)
    guard selector.get_view(start~, end~) is Some(name) else { return false }
    if name.is_empty() || !pseudo_selector_matches(node, name) {
      return false
    }
    pos = end
  }
  true
}

///|
fn selector_list_part(
  selector : StringView,
  start : Int,
  end : Int,
) -> StringView? {
  let part = selector[start:end].trim()
  if part.is_empty() {
    None
  } else {
    Some(part)
  }
}

///|
fn selector_list_parts(selector : StringView) -> Array[StringView]? {
  let selector = selector.trim()
  if selector.is_empty() {
    return None
  }
  let parts : Array[StringView] = []
  let mut start = 0
  let mut pos = 0
  let mut bracket_depth = 0
  let mut paren_depth = 0
  let mut quote : Char? = None
  let mut escaped = false
  let mut seen_part = false
  while pos < selector.length() {
    let ch = selector.get_char(pos).unwrap()
    match quote {
      Some(q) =>
        if escaped {
          escaped = false
        } else if ch == '\\' {
          escaped = true
        } else if ch == q {
          quote = None
        }
      None =>
        if bracket_depth > 0 && (ch == '"' || ch == '\'') {
          quote = Some(ch)
          escaped = false
        } else if ch == '[' {
          bracket_depth += 1
        } else if ch == ']' && bracket_depth > 0 {
          bracket_depth -= 1
        } else if bracket_depth == 0 && ch == '(' {
          paren_depth += 1
        } else if bracket_depth == 0 && ch == ')' && paren_depth > 0 {
          paren_depth -= 1
        } else if ch == ',' && bracket_depth == 0 && paren_depth == 0 {
          match selector_list_part(selector, start, pos) {
            Some(part) => {
              seen_part = true
              parts.push(part)
            }
            None => if !seen_part { return None }
          }
          start = pos + ch.utf16_len()
        }
    }
    pos += ch.utf16_len()
  }
  match selector_list_part(selector, start, selector.length()) {
    Some(part) => {
      parts.push(part)
      Some(parts)
    }
    None => if seen_part { Some(parts) } else { None }
  }
}

///|
priv enum SelectorCombinator {
  DescendantCombinator
  ChildCombinator
  AdjacentSiblingCombinator
  GeneralSiblingCombinator
} derive(Eq)

///|
fn push_complex_selector_part(
  parts : Array[StringView],
  combinators : Array[SelectorCombinator],
  part : StringView,
  pending : SelectorCombinator,
) -> Unit {
  if !parts.is_empty() {
    combinators.push(pending)
  }
  parts.push(part)
}

///|
fn split_complex_selector(
  selector : StringView,
) -> (Array[StringView], Array[SelectorCombinator])? {
  let selector = selector.trim()
  if selector.is_empty() {
    return None
  }
  let parts : Array[StringView] = []
  let combinators : Array[SelectorCombinator] = []
  let mut start = 0
  let mut pos = 0
  let mut bracket_depth = 0
  let mut paren_depth = 0
  let mut quote : Char? = None
  let mut escaped = false
  let mut pending = DescendantCombinator
  while pos < selector.length() {
    let ch = selector.get_char(pos).unwrap()
    match quote {
      Some(q) =>
        if escaped {
          escaped = false
        } else if ch == '\\' {
          escaped = true
        } else if ch == q {
          quote = None
        }
      None =>
        if bracket_depth > 0 && (ch == '"' || ch == '\'') {
          quote = Some(ch)
          escaped = false
        } else if ch == '[' {
          bracket_depth += 1
        } else if ch == ']' && bracket_depth > 0 {
          bracket_depth -= 1
        } else if bracket_depth == 0 && ch == '(' {
          paren_depth += 1
        } else if bracket_depth == 0 && ch == ')' && paren_depth > 0 {
          paren_depth -= 1
        } else if bracket_depth == 0 &&
          paren_depth == 0 &&
          is_html_whitespace_char(ch) {
          match selector_list_part(selector, start, pos) {
            Some(part) => {
              push_complex_selector_part(parts, combinators, part, pending)
              pending = DescendantCombinator
            }
            None => ()
          }
          start = pos + ch.utf16_len()
        } else if bracket_depth == 0 &&
          paren_depth == 0 &&
          (ch == '>' || ch == '+' || ch == '~') {
          match selector_list_part(selector, start, pos) {
            Some(part) =>
              push_complex_selector_part(parts, combinators, part, pending)
            None =>
              if parts.is_empty() || pending != DescendantCombinator {
                return None
              }
          }
          pending = if ch == '>' {
            ChildCombinator
          } else if ch == '+' {
            AdjacentSiblingCombinator
          } else {
            GeneralSiblingCombinator
          }
          start = pos + ch.utf16_len()
        }
    }
    pos += ch.utf16_len()
  }
  match selector_list_part(selector, start, selector.length()) {
    Some(part) => push_complex_selector_part(parts, combinators, part, pending)
    None => return None
  }
  Some((parts, combinators))
}

///|
fn selector_identifier_end(selector : StringView, start : Int) -> Int {
  guard selector.get_char(start) is Some(first) else { return start }
  if !selector_identifier_start(first) {
    return start
  }
  let mut pos = start + first.utf16_len()
  while pos < selector.length() {
    match selector.get_char(pos) {
      Some(ch) if selector_identifier_char(ch) => pos += ch.utf16_len()
      _ => return pos
    }
  }
  pos
}

///|
fn selector_allows_non_elements(selector : StringView) -> Bool {
  let mut pos = 0
  let mut bracket_depth = 0
  let mut paren_depth = 0
  let mut quote : Char? = None
  let mut escaped = false
  for ch in selector {
    match quote {
      Some(q) =>
        if escaped {
          escaped = false
        } else if ch == '\\' {
          escaped = true
        } else if ch == q {
          quote = None
        }
      None =>
        if bracket_depth > 0 && (ch == '"' || ch == '\'') {
          quote = Some(ch)
          escaped = false
        } else if ch == '[' {
          bracket_depth += 1
        } else if ch == ']' && bracket_depth > 0 {
          bracket_depth -= 1
        } else if bracket_depth == 0 && ch == '(' {
          paren_depth += 1
        } else if bracket_depth == 0 && ch == ')' && paren_depth > 0 {
          paren_depth -= 1
        } else if bracket_depth == 0 && paren_depth == 0 && ch == ':' {
          let start = pos + ch.utf16_len()
          let end = selector_identifier_end(selector, start)
          if end > start {
            let name = selector[start:end]
            if lower_ascii(name) == "comment" {
              return true
            }
          }
        }
    }
    pos += ch.utf16_len()
  }
  false
}

///|
fn previous_element_sibling(node : Node) -> Node? {
  match node.parent {
    Some(parent) => {
      let mut previous : Node? = None
      for child in parent.children {
        if physical_equal(child, node) {
          return previous
        }
        if child.kind == Element {
          previous = Some(child)
        }
      }
      None
    }
    None => None
  }
}

///|
fn previous_matching_sibling(node : Node, selector : StringView) -> Node? {
  match node.parent {
    Some(parent) => {
      let mut previous_match : Node? = None
      for child in parent.children {
        if physical_equal(child, node) {
          return previous_match
        }
        if child.kind == Element && matches_simple_selector(child, selector) {
          previous_match = Some(child)
        }
      }
      None
    }
    None => None
  }
}

///|
fn matches_complex_selector(node : Node, selector : StringView) -> Bool {
  guard split_complex_selector(selector) is Some((parts, combinators)) else {
    return false
  }
  let last_index = parts.length() - 1
  if !matches_simple_selector(node, parts[last_index]) {
    return false
  }
  let mut needed = last_index - 1
  let mut current = node
  while needed >= 0 {
    let wanted = parts[needed]
    match combinators[needed] {
      DescendantCombinator => {
        let visited : Array[Node] = [current]
        let mut cursor = current.parent
        let mut found = false
        while !found {
          match cursor {
            Some(ancestor) => {
              if node_identity_seen(visited, ancestor) {
                return false
              }
              visited.push(ancestor)
              if matches_simple_selector(ancestor, wanted) {
                current = ancestor
                found = true
              } else {
                cursor = ancestor.parent
              }
            }
            None => return false
          }
        }
      }
      ChildCombinator =>
        match current.parent {
          Some(ancestor) => {
            if !matches_simple_selector(ancestor, wanted) {
              return false
            }
            current = ancestor
          }
          None => return false
        }
      AdjacentSiblingCombinator =>
        match previous_element_sibling(current) {
          Some(sibling) => {
            if !matches_simple_selector(sibling, wanted) {
              return false
            }
            current = sibling
          }
          None => return false
        }
      GeneralSiblingCombinator =>
        match previous_matching_sibling(current, wanted) {
          Some(sibling) => current = sibling
          None => return false
        }
    }
    needed -= 1
  }
  true
}

///|
fn complex_selector_is_valid(selector : StringView) -> Bool {
  guard split_complex_selector(selector) is Some((parts, _)) else {
    return false
  }
  for part in parts {
    if !simple_selector_is_valid(part) {
      return false
    }
  }
  true
}

///|
fn matches_selector_list(node : Node, selector : StringView) -> Bool {
  guard selector_list_parts(selector) is Some(parts) else { return false }
  for part in parts {
    if !complex_selector_is_valid(part) {
      return false
    }
  }
  for part in parts {
    if matches_complex_selector(node, part) {
      return true
    }
  }
  false
}

///|
fn selector_simple_component_count(selector : StringView) -> Int? {
  let selector = selector.trim()
  if !simple_selector_is_valid(selector) {
    return None
  }
  let mut count = 0
  let mut pos = 0
  match selector.get_char(pos).unwrap() {
    '*' => {
      count += 1
      pos += 1
    }
    '.' | '#' | '[' | ':' => ()
    _ => {
      count += 1
      pos = next_simple_selector_marker(selector, pos)
    }
  }
  while pos < selector.length() {
    let marker = selector.get_char(pos).unwrap()
    count += 1
    if marker == '[' {
      let end = find_attribute_selector_end(selector, pos).unwrap()
      pos = end + 1
    } else if marker == ':' {
      let start = pos + marker.utf16_len()
      pos = next_simple_selector_marker(selector, start)
    } else if marker == '.' || marker == '#' {
      let start = pos + marker.utf16_len()
      pos = next_simple_selector_marker(selector, start)
    }
  }
  Some(count)
}

///|
fn selector_validate_simple_parse_depth(
  selector : StringView,
  limits : SelectorLimits,
  depth : Int,
) -> Unit raise HtmlError {
  let selector = selector.trim()
  if selector.is_empty() {
    return
  }
  let mut pos = 0
  match selector.get_char(pos) {
    Some('*') => pos += 1
    Some('.') | Some('#') | Some('[') | Some(':') => ()
    Some(_) => pos = next_simple_selector_marker(selector, pos)
    None => return
  }
  while pos < selector.length() {
    guard selector.get_char(pos) is Some(marker) else { return }
    if marker == '[' {
      match find_attribute_selector_end(selector, pos) {
        Some(end) => pos = end + 1
        None => return
      }
      continue
    }
    if marker == ':' {
      let start = pos + marker.utf16_len()
      let end = next_simple_selector_marker(selector, start)
      guard selector.get_view(start~, end~) is Some(name) else { return }
      match functional_pseudo_parts(name) {
        Some((pseudo_name, arg)) =>
          if lower_ascii(pseudo_name) == "not" {
            selector_validate_limits_at_depth(arg, limits, depth + 1)
          }
        None => ()
      }
      pos = end
      continue
    }
    if marker == '.' || marker == '#' {
      let start = pos + marker.utf16_len()
      pos = next_simple_selector_marker(selector, start)
    } else {
      return
    }
  }
}

///|
fn selector_validate_limits_at_depth(
  selector : StringView,
  limits : SelectorLimits,
  depth : Int,
) -> Unit raise HtmlError {
  if depth > limits.max_parse_depth {
    raise SelectorError("Selector nesting is too deep")
  }
  if selector.length() > limits.max_length {
    raise SelectorError("Selector too long")
  }
  guard selector_list_parts(selector) is Some(parts) else { return }
  if parts.length() > limits.max_list_items {
    raise SelectorError("Selector list has too many items")
  }
  for part in parts {
    guard split_complex_selector(part) is Some((simple_parts, _)) else {
      continue
    }
    if simple_parts.length() > limits.max_complex_selector_parts {
      raise SelectorError("Selector has too many complex parts")
    }
    for simple in simple_parts {
      match selector_simple_component_count(simple) {
        Some(count) if count > limits.max_compound_simple_selectors =>
          raise SelectorError("Selector has too many simple selectors")
        _ => ()
      }
      selector_validate_simple_parse_depth(simple, limits, depth)
    }
  }
}

///|
fn selector_validate_limits(
  selector : StringView,
  limits : SelectorLimits,
) -> Unit raise HtmlError {
  selector_validate_limits_at_depth(selector, limits, 0)
}

///|
fn selector_uses_byte_scanned_match(selector : StringView) -> Bool {
  string_view_contains(selector, "*=") ||
  string_view_contains(lower_ascii(selector), ":contains")
}

///|
fn selector_match_byte_cost(node : Node, include_text : Bool) -> Int {
  let mut cost = 0
  for _, value in node.attrs {
    match value {
      Some(raw) => cost += raw.length()
      None => ()
    }
  }
  if include_text {
    cost += selector_text_content(node).length()
  }
  cost
}

///|
fn selector_check_match_budget(
  node : Node,
  selector : StringView,
  limits : SelectorLimits,
) -> Unit raise HtmlError {
  if limits.max_match_bytes < 0 {
    raise SelectorError("Selector match byte budget exceeded")
  }
  if selector_uses_byte_scanned_match(selector) {
    let include_text = string_view_contains(lower_ascii(selector), ":contains")
    if selector_match_byte_cost(node, include_text) > limits.max_match_bytes {
      raise SelectorError("Selector match byte budget exceeded")
    }
  }
}

///|
priv struct SelectorMatchContext {
  limits : SelectorLimits
  mut remaining_steps : Int
}

///|
fn SelectorMatchContext::new(limits : SelectorLimits) -> SelectorMatchContext {
  { limits, remaining_steps: limits.max_match_steps }
}

///|
fn SelectorMatchContext::tick(
  self : SelectorMatchContext,
  steps? : Int = 1,
) -> Unit raise HtmlError {
  if steps <= 0 {
    return
  }
  self.remaining_steps -= steps
  if self.remaining_steps < 0 {
    raise SelectorError("Selector match budget exceeded")
  }
}

///|
fn pseudo_selector_matches_with_context(
  node : Node,
  name : StringView,
  context : SelectorMatchContext,
  depth : Int,
) -> Bool raise HtmlError {
  let lower_name = lower_ascii(name)
  match lower_name[:] {
    "comment" => node.kind == Comment
    "first-child" => is_first_element_child(node)
    "last-child" => is_last_element_child(node)
    "only-child" => is_only_element_child(node)
    "empty" => is_empty_for_selector(node)
    "root" => is_root_for_selector(node)
    "first-of-type" => is_first_of_type(node)
    "last-of-type" => is_last_of_type(node)
    "only-of-type" => is_only_of_type(node)
    _ =>
      match functional_pseudo_parts(name) {
        Some((pseudo_name, arg)) =>
          match lower_ascii(pseudo_name)[:] {
            "nth-child" => is_nth_child(node, arg)
            "nth-of-type" => is_nth_of_type(node, arg)
            "not" =>
              !matches_selector_list_with_context(node, arg, context, depth + 1)
            "contains" => contains_text(node, arg)
            "comment" => node.kind == Comment
            _ => false
          }
        _ => false
      }
  }
}

///|
fn non_element_simple_selector_matches_with_context(
  node : Node,
  selector : StringView,
  context : SelectorMatchContext,
  depth : Int,
) -> Bool raise HtmlError {
  let mut pos = 0
  while pos < selector.length() {
    context.tick()
    guard selector.get_char(pos) is Some(':') else { return false }
    let start = pos + ':'.utf16_len()
    let end = next_simple_selector_marker(selector, start)
    guard selector.get_view(start~, end~) is Some(name) else { return false }
    if name.is_empty() ||
      !pseudo_selector_matches_with_context(node, name, context, depth) {
      return false
    }
    pos = end
  }
  true
}

///|
fn matches_simple_selector_with_context(
  node : Node,
  selector : StringView,
  context : SelectorMatchContext,
  depth : Int,
) -> Bool raise HtmlError {
  context.tick()
  let selector = selector.trim()
  if selector.is_empty() {
    return false
  }
  if node.kind != Element {
    return non_element_simple_selector_matches_with_context(
      node, selector, context, depth,
    )
  }
  let mut pos = 0
  match selector.get_char(pos).unwrap() {
    '*' => {
      pos += 1
      if pos < selector.length() {
        match selector.get_char(pos) {
          Some('.') | Some('#') | Some('[') | Some(':') => ()
          _ => return false
        }
      }
    }
    '.' | '#' | '[' | ':' => ()
    _ => {
      let end = next_simple_selector_marker(selector, pos)
      let tag = selector[pos:end]
      if tag.is_empty() ||
        !selector_identifier_is_valid(tag) ||
        !tag_selector_matches(node, tag) {
        return false
      }
      pos = end
    }
  }
  while pos < selector.length() {
    context.tick()
    let marker = selector.get_char(pos).unwrap()
    if marker == '[' {
      guard find_attribute_selector_end(selector, pos) is Some(end) else {
        return false
      }
      let attribute = selector[pos + 1:end]
      if !attribute_selector_matches(node, attribute) {
        return false
      }
      pos = end + 1
      continue
    }
    if marker == ':' {
      let start = pos + marker.utf16_len()
      let end = next_simple_selector_marker(selector, start)
      let name = selector[start:end]
      if name.is_empty() ||
        !pseudo_selector_matches_with_context(node, name, context, depth) {
        return false
      }
      pos = end
      continue
    }
    if marker != '.' && marker != '#' {
      return false
    }
    let start = pos + marker.utf16_len()
    let end = next_simple_selector_marker(selector, start)
    let name = selector[start:end]
    if name.is_empty() || !selector_identifier_is_valid(name) {
      return false
    }
    if marker == '.' {
      if !class_selector_matches(node, name) {
        return false
      }
    } else if !id_selector_matches(node, name) {
      return false
    }
    pos = end
  }
  true
}

///|
fn previous_matching_sibling_with_context(
  node : Node,
  selector : StringView,
  context : SelectorMatchContext,
  depth : Int,
) -> Node? raise HtmlError {
  match node.parent {
    Some(parent) => {
      let mut previous_match : Node? = None
      for child in parent.children {
        context.tick()
        if physical_equal(child, node) {
          return previous_match
        }
        if child.kind == Element &&
          matches_simple_selector_with_context(child, selector, context, depth) {
          previous_match = Some(child)
        }
      }
      None
    }
    None => None
  }
}

///|
fn previous_element_sibling_with_context(
  node : Node,
  context : SelectorMatchContext,
) -> Node? raise HtmlError {
  match node.parent {
    Some(parent) => {
      let mut previous : Node? = None
      for child in parent.children {
        context.tick()
        if physical_equal(child, node) {
          return previous
        }
        if child.kind == Element {
          previous = Some(child)
        }
      }
      None
    }
    None => None
  }
}

///|
fn matches_complex_selector_with_context(
  node : Node,
  selector : StringView,
  context : SelectorMatchContext,
  depth : Int,
) -> Bool raise HtmlError {
  context.tick()
  if depth > context.limits.max_match_depth {
    raise SelectorError("Selector nesting is too deep")
  }
  guard split_complex_selector(selector) is Some((parts, combinators)) else {
    return false
  }
  let last_index = parts.length() - 1
  if !matches_simple_selector_with_context(
      node,
      parts[last_index],
      context,
      depth,
    ) {
    return false
  }
  let mut needed = last_index - 1
  let mut current = node
  while needed >= 0 {
    context.tick()
    let wanted = parts[needed]
    match combinators[needed] {
      DescendantCombinator => {
        let visited : Array[Node] = [current]
        let mut cursor = current.parent
        let mut found = false
        while !found {
          context.tick()
          match cursor {
            Some(ancestor) => {
              if node_identity_seen(visited, ancestor) {
                return false
              }
              visited.push(ancestor)
              if matches_simple_selector_with_context(
                  ancestor, wanted, context, depth,
                ) {
                current = ancestor
                found = true
              } else {
                cursor = ancestor.parent
              }
            }
            None => return false
          }
        }
      }
      ChildCombinator =>
        match current.parent {
          Some(ancestor) => {
            if !matches_simple_selector_with_context(
                ancestor, wanted, context, depth,
              ) {
              return false
            }
            current = ancestor
          }
          None => return false
        }
      AdjacentSiblingCombinator =>
        match previous_element_sibling_with_context(current, context) {
          Some(sibling) => {
            if !matches_simple_selector_with_context(
                sibling, wanted, context, depth,
              ) {
              return false
            }
            current = sibling
          }
          None => return false
        }
      GeneralSiblingCombinator =>
        match
          previous_matching_sibling_with_context(
            current, wanted, context, depth,
          ) {
          Some(sibling) => current = sibling
          None => return false
        }
    }
    needed -= 1
  }
  true
}

///|
fn matches_selector_list_with_context(
  node : Node,
  selector : StringView,
  context : SelectorMatchContext,
  depth : Int,
) -> Bool raise HtmlError {
  context.tick()
  if depth > context.limits.max_match_depth {
    raise SelectorError("Selector nesting is too deep")
  }
  guard selector_list_parts(selector) is Some(parts) else { return false }
  for part in parts {
    if !complex_selector_is_valid(part) {
      return false
    }
  }
  for part in parts {
    selector_check_match_budget(node, part, context.limits)
    if matches_complex_selector_with_context(node, part, context, depth) {
      return true
    }
  }
  false
}

///|
fn matches_selector_list_with_limits(
  node : Node,
  selector : StringView,
  limits : SelectorLimits,
) -> Bool raise HtmlError {
  selector_validate_limits(selector, limits)
  matches_selector_list_with_context(
    node,
    selector,
    SelectorMatchContext::new(limits),
    0,
  )
}

///|
fn node_identity_seen(nodes : Array[Node], node : Node) -> Bool {
  for seen in nodes {
    if physical_equal(seen, node) {
      return true
    }
  }
  false
}

///|
fn walk_query(
  node : Node,
  selector : StringView,
  out : Array[Node],
  allow_non_elements : Bool,
  visited : Array[Node],
) -> Unit {
  if node_identity_seen(visited, node) {
    return
  }
  visited.push(node)
  if (allow_non_elements || node.kind == Element) &&
    matches_selector_list(node, selector) {
    out.push(node)
  }
  for child in node.children {
    walk_query(child, selector, out, allow_non_elements, visited)
  }
}

///|
/// Return all descendants that match a CSS selector.
pub fn Node::query(self : Node, selector : StringView) -> Array[Node] {
  let out : Array[Node] = []
  let allow_non_elements = selector_allows_non_elements(selector)
  let visited : Array[Node] = [self]
  for child in self.children {
    walk_query(child, selector, out, allow_non_elements, visited)
  }
  out
}

///|
/// Return the first descendant that matches a CSS selector.
pub fn Node::query_one(self : Node, selector : StringView) -> Node? {
  let matches = self.query(selector)
  matches.get(0)
}

///|
/// Return whether `node` itself matches a CSS selector.
pub fn matches(node : Node, selector : StringView) -> Bool {
  matches_selector_list(node, selector)
}

///|
/// Return all descendants of `root` that match a CSS selector.
pub fn query(root : Node, selector : StringView) -> Array[Node] {
  root.query(selector)
}

///|
/// Render a deterministic tree dump intended for conformance tests.
pub fn to_test_format(node : Node) -> String {
  let lines : Array[String] = []
  match node.kind {
    Document | Fragment =>
      for child in node.children {
        write_test_format(child, lines, 0)
      }
    _ => write_test_format(node, lines, 0)
  }
  lines.join("\n")
}

///|
fn test_format_line(indent : Int, content : StringView) -> String {
  "| " + " ".repeat(indent) + content.to_owned()
}

///|
fn test_format_qualified_name(node : Node) -> String {
  match node.ns {
    Some(ns) if ns != "html" => ns + " " + node.name
    _ => node.name
  }
}

///|
fn is_foreign_attribute_for_test_format(name : StringView) -> Bool {
  match lower_ascii(name) {
    "xlink:actuate"
    | "xlink:arcrole"
    | "xlink:href"
    | "xlink:role"
    | "xlink:show"
    | "xlink:title"
    | "xlink:type"
    | "xml:lang"
    | "xml:space"
    | "xmlns"
    | "xmlns:xlink" => true
    _ => false
  }
}

///|
fn replace_colons_for_test_format(name : StringView) -> String {
  let out = StringBuilder::new(size_hint=name.length())
  for ch in name {
    if ch == ':' {
      out.write_char(' ')
    } else {
      out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn test_format_attribute_name(node : Node, name : StringView) -> String {
  match node.ns {
    Some(ns) if ns != "html" && is_foreign_attribute_for_test_format(name) =>
      replace_colons_for_test_format(name)
    _ => name.to_owned()
  }
}

///|
fn test_format_string_less(left : StringView, right : StringView) -> Bool {
  let mut left_pos = 0
  let mut right_pos = 0
  while left_pos < left.length() && right_pos < right.length() {
    let left_ch = left.get_char(left_pos).unwrap()
    let right_ch = right.get_char(right_pos).unwrap()
    if left_ch < right_ch {
      return true
    }
    if left_ch > right_ch {
      return false
    }
    left_pos += left_ch.utf16_len()
    right_pos += right_ch.utf16_len()
  }
  left.length() < right.length()
}

///|
fn test_format_attr_less(
  left : (String, String),
  right : (String, String),
) -> Bool {
  let (left_name, left_value) = left
  let (right_name, right_value) = right
  if left_name != right_name {
    return test_format_string_less(left_name, right_name)
  }
  test_format_string_less(left_value, right_value)
}

///|
fn sort_test_format_attrs(attrs : Array[(String, String)]) -> Unit {
  for index in 1..<attrs.length() {
    let current = attrs[index]
    let mut cursor = index
    while cursor > 0 && test_format_attr_less(current, attrs[cursor - 1]) {
      attrs[cursor] = attrs[cursor - 1]
      cursor -= 1
    }
    attrs[cursor] = current
  }
}

///|
fn write_test_format_attributes(
  node : Node,
  out : Array[String],
  indent : Int,
) -> Unit {
  let attrs : Array[(String, String)] = []
  for name, value in node.attrs {
    let display_name = test_format_attribute_name(node, name)
    let value = match value {
      Some(value) => value
      None => ""
    }
    attrs.push((display_name, value))
  }
  sort_test_format_attrs(attrs)
  for attr in attrs {
    let (name, value) = attr
    out.push(test_format_line(indent + 2, name + "=\"" + value + "\""))
  }
}

///|
fn doctype_test_format(node : Node) -> String {
  let out = StringBuilder::new()
  out.write_string("| <!DOCTYPE")
  if node.data == "" {
    out.write_char(' ')
  } else {
    out.write_char(' ')
    out.write_string(node.data)
  }
  if node.public_id is Some(_) || node.system_id is Some(_) {
    let public_id = match node.public_id {
      Some(value) => value
      None => ""
    }
    let system_id = match node.system_id {
      Some(value) => value
      None => ""
    }
    out.write_string(" \"")
    out.write_string(public_id)
    out.write_string("\" \"")
    out.write_string(system_id)
    out.write_char('"')
  }
  out.write_char('>')
  out.to_string()
}

///|
fn write_test_format(node : Node, out : Array[String], indent : Int) -> Unit {
  match node.kind {
    Document | Fragment =>
      out.push(test_format_line(indent, "<" + node.name + ">"))
    Element => {
      out.push(
        test_format_line(indent, "<" + test_format_qualified_name(node) + ">"),
      )
      write_test_format_attributes(node, out, indent)
    }
    Text =>
      if !node.sanitize_escape_only {
        out.push(test_format_line(indent, "\"" + node.data + "\""))
      }
    Comment => out.push(test_format_line(indent, "<!-- " + node.data + " -->"))
    Doctype => out.push(doctype_test_format(node))
  }
  for child in node.children {
    write_test_format(child, out, indent + 2)
  }
}
