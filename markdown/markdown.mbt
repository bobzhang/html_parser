///|
/// Render a DOM node and its descendants as Markdown.
pub fn to_markdown(
  node : @dom.Node,
  html_passthrough? : Bool = false,
) -> String raise @core.HtmlError {
  markdown_render(node, html_passthrough)
}
