///|
/// Output context used by HTML serialization.
///
/// Non-`Html` contexts escape serialized output for embedding in JavaScript
/// strings, HTML attribute values, or URL text.
#derive(Debug, Eq)
pub(all) enum HtmlContext {
  Html
  JsString
  HtmlAttrValue
  Url
}
