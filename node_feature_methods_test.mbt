///|
fn @html_parser.Node::to_html(
  self : @html_parser.Node,
  pretty? : Bool = true,
  indent_size? : Int = 2,
  context? : @html_parser.HtmlContext = Html,
  quote? : Char = '"',
) -> String raise @html_parser.HtmlError {
  @html_parser.to_html(self, pretty~, indent_size~, context~, quote~)
}

///|
fn @html_parser.Node::to_text(
  self : @html_parser.Node,
  separator? : String = " ",
  strip? : Bool = true,
  separator_blocks_only? : Bool = false,
) -> String {
  @html_parser.to_text(self, separator~, strip~, separator_blocks_only~)
}

///|
fn @html_parser.Node::query(
  self : @html_parser.Node,
  selector : StringView,
) -> Array[@html_parser.Node] {
  @html_parser.query(self, selector)
}

///|
fn @html_parser.Node::query_one(
  self : @html_parser.Node,
  selector : StringView,
) -> @html_parser.Node? {
  @html_parser.query_one(self, selector)
}

///|
fn @html_parser.Node::to_markdown(
  self : @html_parser.Node,
  html_passthrough? : Bool = false,
) -> String raise @html_parser.HtmlError {
  @html_parser.to_markdown(self, html_passthrough~)
}
