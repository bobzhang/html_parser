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
