///|
fn render_node_html(
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

///|
/// Serialize a node as HTML.
pub fn to_html(
  node : @dom.Node,
  pretty? : Bool = true,
  indent_size? : Int = 2,
  context? : Int = 0,
  quote? : Char = '"',
) -> String raise @core.HtmlError {
  match context {
    0 => {
      let quote_char = if quote == '\'' { '\'' } else { '"' }
      render_node_html(node, pretty, indent_size, quote_char)
    }
    1 => {
      let quote_char = validate_serialization_quote(quote)
      escape_js_string(
        render_node_html(node, pretty, indent_size, quote_char),
        quote_char,
      )
    }
    2 => {
      let quote_char = validate_serialization_quote(quote)
      escape_attr_value(
        render_node_html(node, pretty, indent_size, quote_char),
        quote_char,
      )
    }
    3 => percent_encode_url(to_text(node).trim())
    _ => {
      let quote_char = if quote == '\'' { '\'' } else { '"' }
      render_node_html(node, pretty, indent_size, quote_char)
    }
  }
}
