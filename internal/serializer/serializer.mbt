///|
/// Render a DOM node to HTML using either compact or pretty formatting.
///
/// `pretty=true` emits indentation with `indent_size` spaces per level;
/// `pretty=false` emits the shortest equivalent markup. Attribute values use
/// `quote`, which must already be a valid HTML quote character.
pub fn render_node_html(
  node : @dom.Node,
  pretty : Bool,
  indent_size : Int,
  quote : Char,
) -> String raise @core.HtmlError {
  let writer = HtmlWriter::new(node, pretty, indent_size, quote)
  writer.tasks.push(
    if pretty {
      Pretty(node, index=0, indent=0)
    } else {
      Compact(node)
    },
  )
  writer.finish()
}
