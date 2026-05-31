///|
/// Render a DOM node and its descendants as Markdown.
pub fn to_markdown(
  node : @dom.Node,
  html_passthrough? : Bool = false,
) -> String raise @core.HtmlError {
  let builder = MarkdownBuilder()
  markdown_walk(node, builder, html_passthrough, 0)
  builder.finish()
}
