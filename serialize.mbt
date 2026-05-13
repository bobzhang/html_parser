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
/// Serialize a node as HTML.
pub fn to_html(
  node : Node,
  pretty? : Bool = true,
  indent_size? : Int = 2,
  context? : HtmlContext = Html,
  quote? : Char = '"',
) -> String raise HtmlError {
  match context {
    Html => {
      let quote_char = if quote == '\'' { '\'' } else { '"' }
      render_node_html(node, pretty, indent_size, quote_char)
    }
    JsString => {
      let quote_char = validate_serialization_quote(quote)
      escape_js_string(
        render_node_html(node, pretty, indent_size, quote_char),
        quote_char,
      )
    }
    HtmlAttrValue => {
      let quote_char = validate_serialization_quote(quote)
      escape_attr_value(
        render_node_html(node, pretty, indent_size, quote_char),
        quote_char,
      )
    }
    Url => percent_encode_url(to_text(node).trim())
  }
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
/// Extract descendant text from a node.
pub fn to_text(
  node : Node,
  separator? : String = " ",
  strip? : Bool = true,
  separator_blocks_only? : Bool = false,
) -> String {
  if separator_blocks_only {
    let chunks : Array[Array[String]] = [[]]
    collect_text_block_chunks(node, chunks, strip)
    return text_chunks_to_string(chunks, separator, strip)
  }
  let parts : Array[String] = []
  collect_text(node, parts, strip)
  parts.join(separator)
}

///|
fn is_html_whitespace_char(ch : Char) -> Bool {
  match ch {
    ' ' | '\t' | '\n' | '\r' | '\u{000C}' => true
    _ => false
  }
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
/// Return all descendants of `root` that match a CSS selector.
pub fn query(root : Node, selector : StringView) -> Array[Node] {
  @sel.query(root, selector)
}

///|
/// Return the first descendant of `root` that matches a CSS selector.
pub fn query_one(root : Node, selector : StringView) -> Node? {
  @sel.query_one(root, selector)
}

///|
/// Return whether `node` itself matches a CSS selector.
pub fn matches(node : Node, selector : StringView) -> Bool {
  @sel.matches(node, selector)
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
