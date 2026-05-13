///|
fn Node::to_html(
  self : Node,
  pretty? : Bool = true,
  indent_size? : Int = 2,
  context? : HtmlContext = Html,
  quote? : Char = '"',
) -> String raise HtmlError {
  to_html(self, pretty~, indent_size~, context~, quote~)
}

///|
fn Node::query(self : Node, selector : StringView) -> Array[Node] {
  query(self, selector)
}
