///|
/// Render a DOM node and its descendants as Markdown.
pub fn to_markdown(
  node : Node,
  html_passthrough? : Bool = false,
) -> String raise HtmlError {
  @md.to_markdown(node, html_passthrough~)
}

///|
/// Render the parsed document or fragment root as Markdown.
///
/// This is equivalent to calling `to_markdown` on `self.root`.
pub fn ParsedHtml::to_markdown(
  self : ParsedHtml,
  html_passthrough? : Bool = false,
) -> String raise HtmlError {
  to_markdown(self.root, html_passthrough~)
}
