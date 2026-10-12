///|
/// Kind of DOM node represented by `Node`.
pub(all) enum NodeKind {
  Document
  Fragment
  Element
  Text
  Comment
  Doctype
} derive(Debug, Eq)

///|
/// DOM node used for documents, fragments, elements, text, comments, and
/// doctypes.
///
/// Nodes are created with helpers such as `document`, `fragment`, `element`,
/// `text`, `comment`, and `doctype`.
pub(all) struct Node {
  kind : NodeKind
  name : String
  ns : String?
  attrs : Map[String, String?]
  data : String
  public_id : String?
  system_id : String?
  force_quirks : Bool
  mut parsed_from_source : Bool
  mut source_start_tag : String?
  mut source_end_tag : String?
  mut sanitize_escape_only : Bool
  mut origin_offset : Int32?
  mut origin_line : Int32?
  mut origin_col : Int32?
  mut parent : Node?
  children : Array[Node]
  mut template_contents : Node?
} derive(Debug)
