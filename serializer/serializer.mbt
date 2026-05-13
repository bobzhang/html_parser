///|
/// Output context used by HTML serialization.
///
/// Non-`Html` contexts escape serialized output for embedding in JavaScript
/// strings, HTML attribute values, or URL text.
pub(all) enum HtmlContext {
  Html
  JsString
  HtmlAttrValue
  Url
} derive(Debug, Eq)

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
  context? : HtmlContext = Html,
  quote? : Char = '"',
) -> String raise @core.HtmlError {
  match context {
    Html => {
      let quote_char = if quote == '\'' { '\'' } else { '"' }
      render_node_html(node, pretty, indent_size, quote_char)
    }
    JsString => {
      let quote_char = validate_serialization_quote(quote)
      escape_js_string(
        render_node_html(node, pretty, indent_size, quote_char),
        quote_char,
      )
    }
    HtmlAttrValue => {
      let quote_char = validate_serialization_quote(quote)
      escape_attr_value(
        render_node_html(node, pretty, indent_size, quote_char),
        quote_char,
      )
    }
    Url => percent_encode_url(to_text(node).trim())
  }
}
