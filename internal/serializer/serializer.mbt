///|
pub fn render_node_html(
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
