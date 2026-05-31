///|
fn context_to_internal(context : HtmlContext) -> @impl.HtmlContext {
  match context {
    Html => Html
    JsString => JsString
    HtmlAttrValue => HtmlAttrValue
    Url => Url
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
    context=context_to_internal(context),
    quote~,
  )
}

///|
pub using @impl {to_text, to_test_format, is_void_element}
