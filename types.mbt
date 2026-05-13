///|
pub using @dom {type NodeKind}

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
pub type ParseError = @core.ParseError

///|
fn parser_error_category(code : StringView) -> String {
  @core.parser_error_category(code)
}

///|
pub type HtmlError = @core.HtmlError

///|
pub using @sel {type SelectorLimits}

///|
fn default_selector_limits() -> SelectorLimits {
  SelectorLimits::new()
}

///|
pub using @dom {type Node}

///|
/// Context element used when parsing an HTML fragment.
///
/// The tag name is normalized to lowercase. `ns` can be used for foreign
/// content contexts such as SVG or MathML.
pub(all) struct FragmentContext {
  tag_name : String
  ns : String?
} derive(Debug, Eq)

///|
/// Construct a fragment parsing context.
pub fn FragmentContext::new(
  tag_name : StringView,
  ns? : String,
) -> FragmentContext {
  { tag_name: tag_name.to_lower().to_owned(), ns }
}

///|
/// Result of parsing HTML.
///
/// `root` is the document or fragment root. `errors` is populated when
/// `collect_errors=true` or strict parsing observes an error. `encoding` is set
/// by byte parsing APIs.
pub struct ParsedHtml {
  root : Node
  errors : Array[ParseError]
  encoding : String?
} derive(Debug)
