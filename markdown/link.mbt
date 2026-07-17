///|
fn markdown_link_destination(value : StringView) -> String {
  let trimmed = value.trim()
  if trimmed.is_empty() {
    return ""
  }
  if markdown_link_destination_needs_wrap(trimmed) {
    "<\{markdown_percent_encode_link_destination(trimmed)}>"
  } else {
    trimmed.to_owned()
  }
}

///|
fn markdown_link_destination_needs_wrap(value : StringView) -> Bool {
  for ch in value {
    if markdown_link_destination_wrap_trigger(ch) {
      return true
    }
  }
  false
}

///|
fn markdown_link_destination_wrap_trigger(ch : Char) -> Bool {
  match ch {
    ' ' | '\t' | '\n' | '\r' | '(' | ')' | '<' | '>' => true
    _ => false
  }
}

///|
fn markdown_percent_encode_link_destination(value : StringView) -> String {
  let bytes = @utf8.encode(value)
  let out = StringBuilder(size_hint=bytes.length())
  for index in 0..<bytes.length() {
    let byte = bytes[index]
    if markdown_link_destination_byte_is_safe(byte) {
      out.write_char(byte.to_char())
    } else {
      @seri.write_percent_encoded_byte(out, byte)
    }
  }
  out.to_string()
}

///|
fn markdown_link_destination_byte_is_safe(byte : Byte) -> Bool {
  match byte {
    b'A'..=b'Z'
    | b'a'..=b'z'
    | b'0'..=b'9'
    | b':'
    | b'/'
    | b'?'
    | b'#'
    | b'['
    | b']'
    | b'@'
    | b'!'
    | b'$'
    | b'&'
    | b'\''
    | b'*'
    | b'+'
    | b','
    | b';'
    | b'='
    | b'%'
    | b'-'
    | b'.'
    | b'_'
    | b'~'
    | b'('
    | b')' => true
    _ => false
  }
}

///|
fn attribute_value_by_name(node : @dom.Node, attr_name : StringView) -> String? {
  let wanted = @syn.lower_ascii(attr_name)
  for name, value in node.attrs {
    if @syn.lower_ascii(name) == wanted {
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
fn markdown_walk_link(
  node : @dom.Node,
  builder : MarkdownBuilder,
  html_passthrough : Bool,
) -> Unit raise @core.HtmlError {
  let inner = markdown_render_link_children_to_string(node, html_passthrough)
  builder.raw("[")
  builder.raw(inner)
  builder.raw("]")
  match attribute_value_by_name(node, "href") {
    Some(href) => {
      let destination = markdown_link_destination(href)
      if href != "" {
        builder.raw("(")
        builder.raw(destination)
        builder.raw(")")
      }
    }
    None => ()
  }
}

///|
fn markdown_render_link_children_to_string(
  node : @dom.Node,
  html_passthrough : Bool,
) -> String raise @core.HtmlError {
  let builder = MarkdownBuilder()
  for child in markdown_children(node) {
    markdown_walk_link_text(child, builder, html_passthrough)
  }
  builder.finish()
}

///|
fn markdown_link_text_marker(
  node : @dom.Node,
  builder : MarkdownBuilder,
  marker : String,
  html_passthrough : Bool,
) -> Unit raise @core.HtmlError {
  let inner = MarkdownBuilder()
  for child in markdown_children(node) {
    markdown_walk_link_text(child, inner, html_passthrough)
  }
  let content = inner.finish()
  if content != "" {
    builder.raw(marker)
    builder.raw(content)
    builder.raw(marker)
  }
}

///|
fn markdown_walk_link_list(
  node : @dom.Node,
  builder : MarkdownBuilder,
  html_passthrough : Bool,
) -> Unit raise @core.HtmlError {
  for child in markdown_children(node) {
    if child.kind == Element && child.name.to_lower() == "li" {
      builder.raw(" ")
      for grandchild in child.children {
        markdown_walk_link_text(grandchild, builder, html_passthrough)
      }
    }
  }
}

///|
fn markdown_walk_link_text(
  node : @dom.Node,
  builder : MarkdownBuilder,
  html_passthrough : Bool,
) -> Unit raise @core.HtmlError {
  match node.kind {
    Text =>
      if !node.sanitize_escape_only {
        builder.text(markdown_escape_text(node.data))
      }
    Comment | Doctype => ()
    Document | Fragment =>
      for child in markdown_children(node) {
        markdown_walk_link_text(child, builder, html_passthrough)
      }
    Element => {
      let tag = node.name.to_lower()
      if markdown_should_skip_head_or_title(node, tag) || tag == "hr" {
        ()
      } else if markdown_heading_level(tag) > 0 {
        for child in markdown_children(node) {
          markdown_walk_link_text(child, builder, html_passthrough)
        }
      } else {
        match tag {
          "br" => builder.text(" ")
          "html" | "body" | "span" | "blockquote" =>
            for child in markdown_children(node) {
              markdown_walk_link_text(child, builder, html_passthrough)
            }
          "p" => {
            for child in markdown_children(node) {
              markdown_walk_link_text(child, builder, html_passthrough)
            }
            builder.text(" ")
          }
          "b" | "strong" =>
            markdown_link_text_marker(node, builder, "**", html_passthrough)
          "i" | "em" =>
            markdown_link_text_marker(node, builder, "*", html_passthrough)
          "code" | "pre" =>
            builder.raw(markdown_code_span(markdown_collect_text(node)))
          "ul" | "ol" =>
            markdown_walk_link_list(node, builder, html_passthrough)
          "table" => builder.raw(@ser.to_html(node, pretty=false))
          "script" | "style" | "textarea" =>
            if html_passthrough {
              builder.raw(@ser.to_html(node, pretty=false))
            }
          "img" => builder.raw(@ser.to_html(node, pretty=false))
          _ =>
            if markdown_block_container_name(tag) {
              for child in markdown_children(node) {
                markdown_walk_link_text(child, builder, html_passthrough)
              }
              builder.text(" ")
            } else {
              for child in markdown_children(node) {
                markdown_walk_link_text(child, builder, html_passthrough)
              }
            }
        }
      }
    }
  }
}
