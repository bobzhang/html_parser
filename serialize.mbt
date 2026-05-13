///|
fn is_void_element(name : StringView) -> Bool {
  @ser.is_void_element(name)
}

///|
/// Serialize a node as HTML.
pub fn to_html(
  node : Node,
  pretty? : Bool = true,
  indent_size? : Int = 2,
  context? : HtmlContext = Html,
  quote? : Char = '"',
) -> String raise HtmlError {
  @ser.to_html(node, pretty~, indent_size~, context~, quote~)
}

///|
/// Extract descendant text from a node.
pub fn to_text(
  node : Node,
  separator? : String = " ",
  strip? : Bool = true,
  separator_blocks_only? : Bool = false,
) -> String {
  @ser.to_text(node, separator~, strip~, separator_blocks_only~)
}

///|
/// Return all descendants of `root` that match a CSS selector.
pub fn query(root : Node, selector : StringView) -> Array[Node] {
  @sel.query(root, selector)
}

///|
/// Return the first descendant of `root` that matches a CSS selector.
pub fn query_one(root : Node, selector : StringView) -> Node? {
  @sel.query_one(root, selector)
}

///|
/// Return whether `node` itself matches a CSS selector.
pub fn matches(node : Node, selector : StringView) -> Bool {
  @sel.matches(node, selector)
}

///|
/// Render a deterministic tree dump intended for conformance tests.
pub fn to_test_format(node : Node) -> String {
  @ser.to_test_format(node)
}
