///|
/// Output context used by HTML serialization.
///
/// Non-`Html` contexts escape serialized output for embedding in JavaScript
/// strings, HTML attribute values, or URL text.
pub(all) enum HtmlContext {
  Html
  JsString
  HtmlAttrValue
  Url
} derive(Debug, Eq)

///|
fn node_to_html_compact(
  node : @dom.Node,
  quote : Char,
) -> String raise @core.HtmlError {
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
fn element_has_only_text_children(node : @dom.Node) -> Bool {
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
fn compact_pretty_text_children(
  node : @dom.Node,
  quote : Char,
) -> String raise @core.HtmlError {
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
fn node_contains_layout_block(node : @dom.Node) -> Bool {
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
fn element_has_compact_inline_children(node : @dom.Node) -> Bool {
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
fn element_has_comment_child(node : @dom.Node) -> Bool {
  for child in node.children {
    if child.kind == Comment {
      return true
    }
  }
  false
}

///|
fn node_is_pretty_formatting_separator(node : @dom.Node) -> Bool {
  node.kind == Text &&
  !text_has_visible_char(node.data) &&
  compact_pretty_whitespace_separator(node.data)
}

///|
fn pretty_inline_run_to_html(
  run : Array[@dom.Node],
  quote : Char,
) -> String raise @core.HtmlError {
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
  node : @dom.Node,
  indent : Int,
  indent_size : Int,
  quote : Char,
) -> String? raise @core.HtmlError {
  if !layout_block_element_name(node.name) ||
    !element_has_compact_inline_children(node) {
    return None
  }
  let runs : Array[Array[@dom.Node]] = []
  let mut current : Array[@dom.Node] = []
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
  node : @dom.Node,
  quote : Char,
  indent_size : Int,
) -> String raise @core.HtmlError {
  match node.kind {
    Document | Fragment => node_to_html_pretty(node, 0, indent_size, quote)
    _ => node_to_html_compact(node, quote)
  }
}

///|
fn node_to_html_pretty_compact_children(
  node : @dom.Node,
  quote : Char,
  indent_size : Int,
) -> String raise @core.HtmlError {
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
  node : @dom.Node,
  indent : Int,
  indent_size : Int,
  quote : Char,
) -> String? raise @core.HtmlError {
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
  node : @dom.Node,
  indent : Int,
  indent_size : Int,
  quote : Char,
) -> String raise @core.HtmlError {
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
  node : @dom.Node,
  pretty : Bool,
  indent_size : Int,
  quote : Char,
) -> String raise @core.HtmlError {
  if pretty {
    node_to_html_pretty(node, 0, indent_size, quote)
  } else {
    node_to_html_compact(node, quote)
  }
}

///|
/// Serialize a node as HTML.
pub fn to_html(
  node : @dom.Node,
  pretty? : Bool = true,
  indent_size? : Int = 2,
  context? : HtmlContext = Html,
  quote? : Char = '"',
) -> String raise @core.HtmlError {
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
fn collect_text(node : @dom.Node, parts : Array[String], strip : Bool) -> Unit {
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
  node : @dom.Node,
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
  node : @dom.Node,
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
/// Render a deterministic tree dump intended for conformance tests.
pub fn to_test_format(node : @dom.Node) -> String {
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
fn test_format_qualified_name(node : @dom.Node) -> String {
  match node.ns {
    Some(ns) if ns != "html" => ns + " " + node.name
    _ => node.name
  }
}

///|
fn is_foreign_attribute_for_test_format(name : StringView) -> Bool {
  match @syn.lower_ascii(name) {
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
fn test_format_attribute_name(node : @dom.Node, name : StringView) -> String {
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
  node : @dom.Node,
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
fn doctype_test_format(node : @dom.Node) -> String {
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
fn write_test_format(
  node : @dom.Node,
  out : Array[String],
  indent : Int,
) -> Unit {
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
