///|
/// Whether a tag token opens an element or closes one.
///
/// `StartTag` represents tags such as `<p>` and `EndTag` represents tags such
/// as `</p>`.
pub(all) enum TagKind {
  StartTag
  EndTag
} derive(Debug, Eq)

///|
/// A start or end tag emitted by `tokenize`.
///
/// `name` is lower-cased for HTML tag tokens. `attrs` maps attribute names to
/// optional values; a value of `None` represents a minimized or missing-value
/// attribute. `self_closing` records the solidus marker on start tags.
pub(all) struct TagToken {
  kind : TagKind
  name : String
  attrs : Map[String, String?]
  self_closing : Bool
} derive(Debug, Eq)

///|
/// Doctype data emitted by the tokenizer.
///
/// `force_quirks` is set when the tokenizer sees a malformed or legacy doctype
/// form that should place a parsed document into quirks mode.
pub(all) struct DoctypeInfo {
  name : String
  public_id : String?
  system_id : String?
  force_quirks : Bool
} derive(Debug, Eq)

///|
/// Token variants produced by the HTML tokenizer.
///
/// `Eof` is appended as the final token. Character data and comments are stored
/// as already-normalized MoonBit strings; parse diagnostics are returned through
/// `TokenizedHtml.errors` when error collection is enabled.
pub(all) enum HtmlToken {
  Tag(TagToken)
  Characters(String)
  CommentToken(String)
  DoctypeToken(DoctypeInfo)
  Eof
} derive(Debug, Eq)

///|
/// Result returned by `tokenize`.
///
/// `tokens` always ends with `HtmlToken::Eof`. `errors` is empty unless
/// `collect_errors=true` was passed.
pub(all) struct TokenizedHtml {
  tokens : Array[HtmlToken]
  errors : Array[@core.ParseError]
} derive(Debug)
