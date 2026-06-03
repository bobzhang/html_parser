///|
fn context_to_internal_code(context : HtmlContext) -> Int {
  match context {
    Html => 0
    JsString => 1
    HtmlAttrValue => 2
    Url => 3
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
  @impl.to_html(
    node,
    pretty~,
    indent_size~,
    context=context_to_internal_code(context),
    quote~,
  )
}

///|
pub using @impl {to_text, to_test_format, is_void_element}
