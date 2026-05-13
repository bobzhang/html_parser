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
/// Resource limits used while parsing and matching CSS selectors.
///
/// Limits are defensive bounds for selector length, nesting, list size, and
/// match cost. Negative match budgets are treated as exhausted.
pub(all) struct SelectorLimits {
  max_match_depth : Int
  max_length : Int
  max_list_items : Int
  max_compound_simple_selectors : Int
  max_complex_selector_parts : Int
  max_parse_depth : Int
  max_match_steps : Int
  max_match_bytes : Int
} derive(Debug, Eq)

///|
/// Construct selector limits, using conservative defaults for omitted values.
pub fn SelectorLimits::new(
  max_match_depth? : Int = 100,
  max_length? : Int = 8192,
  max_list_items? : Int = 256,
  max_compound_simple_selectors? : Int = 512,
  max_complex_selector_parts? : Int = 512,
  max_parse_depth? : Int = 100,
  max_match_steps? : Int = 100000000,
  max_match_bytes? : Int = 100000000,
) -> SelectorLimits {
  {
    max_match_depth,
    max_length,
    max_list_items,
    max_compound_simple_selectors,
    max_complex_selector_parts,
    max_parse_depth,
    max_match_steps,
    max_match_bytes,
  }
}

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
