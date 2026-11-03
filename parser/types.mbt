///|
/// Context element used when parsing an HTML fragment.
///
/// The tag name is normalized to lowercase. `ns` can be used for foreign
/// content contexts such as SVG or MathML.
#derive(Debug, Eq)
pub(all) struct FragmentContext {
  tag_name : String
  ns : String?
}

///|
/// Construct a fragment parsing context.
pub fn FragmentContext::FragmentContext(
  tag_name : StringView,
  ns? : String,
) -> FragmentContext {
  { tag_name: tag_name.to_lower().to_owned(), ns, }
}

///|
/// Result of parsing HTML.
///
/// `root` is the document or fragment root. `errors` is populated when
/// `collect_errors=true` or strict parsing observes an error. `encoding` is set
/// by byte parsing APIs.
#derive(Debug)
pub struct ParsedHtml {
  root : @dom.Node
  errors : Array[@core.ParseError]
  encoding : String?
}
