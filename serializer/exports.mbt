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
      @impl.render_node_html(node, pretty, indent_size, quote_char)
    }
    JsString => {
      let quote_char = @impl.validate_serialization_quote(quote)
      @impl.escape_js_string(
        @impl.render_node_html(node, pretty, indent_size, quote_char),
        quote_char,
      )
    }
    HtmlAttrValue => {
      let quote_char = @impl.validate_serialization_quote(quote)
      @impl.escape_attr_value(
        @impl.render_node_html(node, pretty, indent_size, quote_char),
        quote_char,
      )
    }
    Url => @impl.percent_encode_url(@impl.to_text(node).trim())
  }
}

///|
pub using @impl {to_text, to_test_format, is_void_element}
