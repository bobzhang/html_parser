///|
pub(all) enum NodeKind {
  Document
  Fragment
  Element
  Text
  Comment
  Doctype
} derive(Debug, Eq)

///|
pub(all) enum HtmlContext {
  Html
  JsString
  HtmlAttrValue
  Url
} derive(Debug, Eq)

///|
pub(all) struct ParseError {
  code : String
  line : Int?
  column : Int?
  category : String
  message : String
} derive(Debug, Eq)

///|
pub fn ParseError::new(
  code : String,
  line? : Int,
  column? : Int,
  category? : String = "parse",
  message? : String,
) -> ParseError {
  ParseError::{ code, line, column, category, message: message.unwrap_or(code) }
}

///|
pub(all) suberror HtmlError {
  StrictMode(ParseError)
  InvalidSerialization(String)
  UnsafeHtml(String)
} derive(Debug, Eq)

///|
pub struct Node {
  priv kind : NodeKind
  priv name : String
  priv ns : String?
  priv attrs : Map[String, String?]
  priv data : String
  priv public_id : String?
  priv system_id : String?
  priv force_quirks : Bool
  priv mut parent : Node?
  priv children : Array[Node]
} derive(Debug)

///|
pub(all) struct FragmentContext {
  tag_name : String
  ns : String?
} derive(Debug, Eq)

///|
pub fn FragmentContext::new(
  tag_name : StringView,
  ns? : String,
) -> FragmentContext {
  FragmentContext::{ tag_name: tag_name.to_lower().to_owned(), ns }
}

///|
pub struct ParsedHtml {
  root : Node
  errors : Array[ParseError]
  encoding : String?
} derive(Debug)
