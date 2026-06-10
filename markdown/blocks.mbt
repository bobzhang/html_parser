///|
/// Children to render: an HTML template's children live in its contents
/// fragment.
fn markdown_children(node : @dom.Node) -> Array[@dom.Node] {
  match node.template_contents {
    Some(contents) => contents.children
    None => node.children
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
  for child in markdown_children(node) {
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
  let quoted = StringBuilder(size_hint=inner.length() + 2)
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
