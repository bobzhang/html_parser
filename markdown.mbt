///|
/// Render a DOM node and its descendants as Markdown.
pub fn to_markdown(
  node : Node,
  html_passthrough? : Bool = false,
) -> String raise HtmlError {
  @md.to_markdown(node, html_passthrough~)
}
