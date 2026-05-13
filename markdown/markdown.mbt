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
