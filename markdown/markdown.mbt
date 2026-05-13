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
fn markdown_collect_text(node : @dom.Node) -> String {
  let parts : Array[String] = []
  markdown_collect_text_into(node, parts)
  parts.join("")
}

///|
fn markdown_collect_text_into(node : @dom.Node, parts : Array[String]) -> Unit {
  match node.kind {
    Text => if !node.sanitize_escape_only { parts.push(node.data) }
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
  value[0:end].to_owned()
}

///|
fn markdown_render_children(
  node : @dom.Node,
  builder : MarkdownBuilder,
  html_passthrough : Bool,
  list_depth : Int,
) -> Unit raise @core.HtmlError {
  for child in node.children {
    markdown_walk(child, builder, html_passthrough, list_depth)
  }
}

///|
fn markdown_render_children_to_string(
  node : @dom.Node,
  html_passthrough : Bool,
  list_depth : Int,
) -> String raise @core.HtmlError {
  let builder = MarkdownBuilder::new()
  markdown_render_children(node, builder, html_passthrough, list_depth)
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
    | "aside"
    | "li" => true
    _ => false
  }
}

///|
fn markdown_wrapped_inline(
  node : @dom.Node,
  builder : MarkdownBuilder,
  marker : String,
  html_passthrough : Bool,
  list_depth : Int,
) -> Unit raise @core.HtmlError {
  let inner = markdown_render_children_to_string(
    node, html_passthrough, list_depth,
  )
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
  let out = StringBuilder::new(size_hint=bytes.length())
  for index in 0..<bytes.length() {
    let byte = bytes[index]
    if markdown_link_destination_byte_is_safe(byte) {
      out.write_char(byte.to_char())
    } else {
      @ser.write_percent_encoded_byte(out, byte)
    }
  }
  out.to_string()
}

///|
fn markdown_link_destination_byte_is_safe(byte : Byte) -> Bool {
  let value = byte.to_int()
  (value >= 0x41 && value <= 0x5A) ||
  (value >= 0x61 && value <= 0x7A) ||
  (value >= 0x30 && value <= 0x39) ||
  value == 0x3A ||
  value == 0x2F ||
  value == 0x3F ||
  value == 0x23 ||
  value == 0x5B ||
  value == 0x5D ||
  value == 0x40 ||
  value == 0x21 ||
  value == 0x24 ||
  value == 0x26 ||
  value == 0x27 ||
  value == 0x2A ||
  value == 0x2B ||
  value == 0x2C ||
  value == 0x3B ||
  value == 0x3D ||
  value == 0x25 ||
  value == 0x2D ||
  value == 0x2E ||
  value == 0x5F ||
  value == 0x7E ||
  value == 0x28 ||
  value == 0x29
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
  let builder = MarkdownBuilder::new()
  for child in node.children {
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
  let inner = MarkdownBuilder::new()
  for child in node.children {
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
  for child in node.children {
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
      for child in node.children {
        markdown_walk_link_text(child, builder, html_passthrough)
      }
    Element => {
      let tag = node.name.to_lower()
      if markdown_should_skip_head_or_title(node, tag) || tag == "hr" {
        ()
      } else if markdown_heading_level(tag) > 0 {
        for child in node.children {
          markdown_walk_link_text(child, builder, html_passthrough)
        }
      } else {
        match tag {
          "br" => builder.text(" ")
          "html" | "body" | "span" | "blockquote" =>
            for child in node.children {
              markdown_walk_link_text(child, builder, html_passthrough)
            }
          "p" => {
            for child in node.children {
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
              for child in node.children {
                markdown_walk_link_text(child, builder, html_passthrough)
              }
              builder.text(" ")
            } else {
              for child in node.children {
                markdown_walk_link_text(child, builder, html_passthrough)
              }
            }
        }
      }
    }
  }
}

///|
fn markdown_walk_pre(node : @dom.Node, builder : MarkdownBuilder) -> Unit {
  let code = markdown_collect_text(node)
  let body = markdown_code_block_body(code)
  let fence = markdown_backtick_fence(code, 3)
  builder.ensure_newlines(2)
  builder.raw(fence)
  builder.newline(1)
  if code != "" {
    builder.raw(body)
    builder.newline(1)
  }
  builder.raw(fence)
  builder.ensure_newlines(2)
}

///|
fn markdown_walk_list(
  node : @dom.Node,
  builder : MarkdownBuilder,
  ordered : Bool,
  html_passthrough : Bool,
  list_depth : Int,
) -> Unit raise @core.HtmlError {
  if !builder.parts.is_empty() {
    builder.ensure_newlines(2)
  }
  let mut index = 1
  let mut rendered = 0
  for child in node.children {
    if child.kind == Element && child.name.to_lower() == "li" {
      if rendered > 0 {
        builder.newline(1)
      }
      builder.raw("  ".repeat(list_depth))
      if ordered {
        builder.raw(index.to_string())
        builder.raw(". ")
      } else {
        builder.raw("- ")
      }
      markdown_render_children(child, builder, html_passthrough, list_depth + 1)
      index += 1
      rendered += 1
    }
  }
  builder.ensure_newlines(2)
}

///|
fn markdown_walk_blockquote(
  node : @dom.Node,
  builder : MarkdownBuilder,
  html_passthrough : Bool,
  list_depth : Int,
) -> Unit raise @core.HtmlError {
  let inner = markdown_render_children_to_string(
    node, html_passthrough, list_depth,
  )
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
  node : @dom.Node,
  builder : MarkdownBuilder,
  html_passthrough : Bool,
  list_depth : Int,
) -> Unit raise @core.HtmlError {
  match node.kind {
    Text =>
      if !node.sanitize_escape_only {
        builder.text(markdown_escape_text(node.data))
      }
    Comment | Doctype => ()
    Document | Fragment =>
      markdown_render_children(node, builder, html_passthrough, list_depth)
    Element => {
      let tag = node.name.to_lower()
      let level = markdown_heading_level(tag)
      if markdown_should_skip_head_or_title(node, tag) {
        ()
      } else if level > 0 {
        let inner = markdown_render_children_to_string(
          node, html_passthrough, list_depth,
        )
        builder.ensure_newlines(2)
        builder.raw("#".repeat(level))
        builder.raw(" ")
        builder.raw(inner)
        builder.ensure_newlines(2)
      } else {
        match tag {
          "html" | "body" | "span" =>
            markdown_render_children(
              node, builder, html_passthrough, list_depth,
            )
          "p" => {
            builder.ensure_newlines(2)
            markdown_render_children(
              node, builder, html_passthrough, list_depth,
            )
            builder.ensure_newlines(2)
          }
          "br" => builder.newline(1)
          "b" | "strong" =>
            markdown_wrapped_inline(
              node, builder, "**", html_passthrough, list_depth,
            )
          "i" | "em" =>
            markdown_wrapped_inline(
              node, builder, "*", html_passthrough, list_depth,
            )
          "code" => builder.raw(markdown_code_span(markdown_collect_text(node)))
          "pre" => markdown_walk_pre(node, builder)
          "a" => markdown_walk_link(node, builder, html_passthrough)
          "ul" =>
            markdown_walk_list(
              node, builder, false, html_passthrough, list_depth,
            )
          "ol" =>
            markdown_walk_list(
              node, builder, true, html_passthrough, list_depth,
            )
          "blockquote" =>
            markdown_walk_blockquote(
              node, builder, html_passthrough, list_depth,
            )
          "hr" => {
            builder.ensure_newlines(2)
            builder.raw("---")
            builder.ensure_newlines(2)
          }
          "script" | "style" | "textarea" => {
            builder.ensure_newlines(2)
            if html_passthrough {
              builder.raw(@ser.to_html(node, pretty=false))
            }
            builder.ensure_newlines(2)
          }
          "img" => builder.raw(@ser.to_html(node, pretty=false))
          "table" => {
            builder.ensure_newlines(2)
            builder.raw(@ser.to_html(node, pretty=false))
            builder.ensure_newlines(2)
          }
          _ =>
            if markdown_block_container_name(tag) {
              markdown_render_children(
                node, builder, html_passthrough, list_depth,
              )
              builder.ensure_newlines(2)
            } else {
              markdown_render_children(
                node, builder, html_passthrough, list_depth,
              )
            }
        }
      }
    }
  }
}

///|
fn markdown_should_skip_head_or_title(
  node : @dom.Node,
  tag : StringView,
) -> Bool {
  match tag {
    "head" | "title" =>
      !(node.parsed_from_source && markdown_node_inside_fragment(node))
    _ => false
  }
}

///|
fn markdown_node_inside_fragment(node : @dom.Node) -> Bool {
  let mut current = node
  while true {
    match current.parent {
      Some(parent) => current = parent
      None => return current.kind == Fragment
    }
  }
  false
}

///|
/// Render a DOM node and its descendants as Markdown.
pub fn to_markdown(
  node : @dom.Node,
  html_passthrough? : Bool = false,
) -> String raise @core.HtmlError {
  let builder = MarkdownBuilder::new()
  markdown_walk(node, builder, html_passthrough, 0)
  builder.finish()
}
