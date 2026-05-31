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
/// Extract descendant text from a node.
pub fn to_text(
  node : @dom.Node,
  separator? : String = " ",
  strip? : Bool = true,
  separator_blocks_only? : Bool = false,
) -> String {
  @impl.to_text(node, separator~, strip~, separator_blocks_only~)
}

///|
/// Render a deterministic tree dump intended for conformance tests.
pub fn to_test_format(node : @dom.Node) -> String {
  @impl.to_test_format(node)
}

///|
/// Return whether `name` is an HTML void element.
pub fn is_void_element(name : StringView) -> Bool {
  @impl.is_void_element(name)
}
