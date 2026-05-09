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
      '"' if quote == '"' => out.write_string("\\\"")
      '\'' if quote == '\'' => out.write_string("\\'")
      '<' => out.write_string("\\u003C")
      '>' => out.write_string("\\u003E")
      '&' => out.write_string("\\u0026")
      _ => out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn percent_encode_url(value : StringView) -> String {
  let out = StringBuilder::new(size_hint=value.length())
  for ch in value {
    match ch {
      ' ' => out.write_string("%20")
      '"' => out.write_string("%22")
      '<' => out.write_string("%3C")
      '>' => out.write_string("%3E")
      '`' => out.write_string("%60")
      _ => out.write_char(ch)
    }
  }
  out.to_string()
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
      match value.get_char(pos) {
        Some(ch) => {
          out.write_char(ch)
          pos += ch.utf16_len()
        }
        None => break
      }
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
    Some(' ') | Some('\t') | Some('\n') | Some('\r') | Some('\u{000C}') => true
    _ => false
  }
}

///|
fn serialize_start_tag(node : Node, quote : Char) -> String {
  let out = StringBuilder::new()
  out.write_char('<')
  out.write_string(node.name)
  for name, value in node.attrs {
    out.write_char(' ')
    out.write_string(name)
    match value {
      Some(v) => {
        out.write_char('=')
        out.write_char(quote)
        out.write_string(escape_attr_value(v, quote))
        out.write_char(quote)
      }
      None => ()
    }
  }
  out.write_char('>')
  out.to_string()
}

///|
fn node_to_html_compact(node : Node, quote : Char) -> String {
  match node.kind {
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
fn node_to_html_pretty(
  node : Node,
  indent : Int,
  indent_size : Int,
  quote : Char,
) -> String {
  match node.kind {
    Document | Fragment => {
      let parts : Array[String] = []
      for child in node.children {
        parts.push(node_to_html_pretty(child, indent, indent_size, quote))
      }
      parts.join("\n")
    }
    Text | Comment | Doctype =>
      " ".repeat(indent) + node_to_html_compact(node, quote)
    Element =>
      if node.children.is_empty() || is_void_element(node.name) {
        " ".repeat(indent) + node_to_html_compact(node, quote)
      } else {
        let out = StringBuilder::new()
        out.write_string(" ".repeat(indent))
        out.write_string(serialize_start_tag(node, quote))
        let child_indent = indent + indent_size
        for child in node.children {
          out.write_char('\n')
          out.write_string(
            node_to_html_pretty(child, child_indent, indent_size, quote),
          )
        }
        out.write_char('\n')
        out.write_string(" ".repeat(indent))
        out.write_string("</")
        out.write_string(node.name)
        out.write_char('>')
        out.to_string()
      }
  }
}

///|
pub fn Node::to_html(
  self : Node,
  pretty? : Bool = true,
  indent_size? : Int = 2,
  context? : HtmlContext = Html,
  quote? : Char = '"',
) -> String {
  let quote_char = if quote == '\'' { '\'' } else { '"' }
  let html = if pretty {
    node_to_html_pretty(self, 0, indent_size, quote_char)
  } else {
    node_to_html_compact(self, quote_char)
  }
  match context {
    Html => html
    JsString => escape_js_string(html, quote_char)
    HtmlAttrValue => escape_attr_value(html, quote_char)
    Url => percent_encode_url(html)
  }
}

///|
pub fn to_html(
  node : Node,
  pretty? : Bool = true,
  indent_size? : Int = 2,
  context? : HtmlContext = Html,
  quote? : Char = '"',
) -> String {
  node.to_html(pretty~, indent_size~, context~, quote~)
}

///|
fn collect_text(node : Node, parts : Array[String], strip : Bool) -> Unit {
  match node.kind {
    Text => {
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
  for part in value.split(" ") {
    if part == needle {
      return true
    }
  }
  false
}

///|
fn matches_simple_selector(node : Node, selector : StringView) -> Bool {
  if node.kind != Element {
    return false
  }
  let selector = selector.trim()
  if selector.is_empty() {
    return false
  }
  if selector.has_prefix("#") {
    match node.attrs.get("id") {
      Some(Some(value)) => value[:] == selector[1:]
      _ => false
    }
  } else if selector.has_prefix(".") {
    match node.attrs.get("class") {
      Some(Some(value)) => class_contains(value, selector[1:])
      _ => false
    }
  } else {
    match selector.split_once(".") {
      Some((tag, class_name)) => {
        let tag_ok = node.name[:] == tag.to_lower()
        let class_ok = match node.attrs.get("class") {
          Some(Some(value)) => class_contains(value, class_name)
          _ => false
        }
        tag_ok && class_ok
      }
      None => node.name[:] == selector.to_lower()
    }
  }
}

///|
fn walk_query(node : Node, selector : StringView, out : Array[Node]) -> Unit {
  if matches_simple_selector(node, selector) {
    out.push(node)
  }
  for child in node.children {
    walk_query(child, selector, out)
  }
}

///|
pub fn Node::query(self : Node, selector : StringView) -> Array[Node] {
  let out : Array[Node] = []
  walk_query(self, selector, out)
  out
}

///|
pub fn Node::query_one(self : Node, selector : StringView) -> Node? {
  let matches = self.query(selector)
  matches.get(0)
}

///|
pub fn matches(node : Node, selector : StringView) -> Bool {
  matches_simple_selector(node, selector)
}

///|
pub fn query(root : Node, selector : StringView) -> Array[Node] {
  root.query(selector)
}

///|
pub fn to_test_format(node : Node) -> String {
  let out = StringBuilder::new()
  write_test_format(node, out, 0)
  out.to_string()
}

///|
fn write_test_format(node : Node, out : StringBuilder, indent : Int) -> Unit {
  let pad = " ".repeat(indent)
  match node.kind {
    Document => out.write_string("#document\n")
    Fragment => out.write_string("#document-fragment\n")
    Element => out.write_string(pad + "| <" + node.name + ">\n")
    Text => out.write_string(pad + "| \"" + node.data + "\"\n")
    Comment => out.write_string(pad + "| <!-- " + node.data + " -->\n")
    Doctype => out.write_string(pad + "| <!DOCTYPE " + node.data + ">\n")
  }
  for child in node.children {
    write_test_format(child, out, indent + 2)
  }
}
