///|
fn make_node(
  kind : NodeKind,
  name : String,
  ns : String?,
  attrs : Map[String, String?],
  data : String,
  public_id : String?,
  system_id : String?,
  force_quirks : Bool,
  children : Array[Node],
) -> Node {
  let node = Node::{
    kind,
    name,
    ns,
    attrs,
    data,
    public_id,
    system_id,
    force_quirks,
    parsed_from_source: false,
    source_start_tag: None,
    source_end_tag: None,
    sanitize_escape_only: false,
    origin_offset: None,
    origin_line: None,
    origin_col: None,
    parent: None,
    children: [],
  }
  for child in children {
    node.append_child(child)
  }
  node
}

///|
/// Create a document node with optional children.
pub fn document(children? : Array[Node] = []) -> Node {
  @dom.document(children~)
}

///|
/// Create a document-fragment node with optional children.
pub fn fragment(children? : Array[Node] = []) -> Node {
  @dom.fragment(children~)
}

///|
/// Create an element node.
///
/// Namespace aliases `html`, `svg`, and `mathml` are normalized for serializer
/// and sanitizer behavior. Child nodes are attached in order.
pub fn element(
  name : StringView,
  attrs? : Map[String, String?] = {},
  children? : Array[Node] = [],
  ns? : String = "html",
) -> Node {
  @dom.element(name, attrs~, children~, ns~)
}

///|
/// Create a text node.
pub fn text(data : StringView) -> Node {
  @dom.text(data)
}

///|
/// Create a comment node.
pub fn comment(data : StringView) -> Node {
  @dom.comment(data)
}

///|
/// Create a doctype node.
pub fn doctype(
  name? : String = "html",
  public_id? : String,
  system_id? : String,
  force_quirks? : Bool = false,
) -> Node {
  make_node(
    Doctype,
    "#doctype",
    None,
    {},
    name,
    public_id,
    system_id,
    force_quirks,
    [],
  )
}

///|
fn Node::insert_child_before(self : Node, child : Node, before : Node) -> Unit {
  self.insert_before(child, Some(before))
}

///|
fn Node::set_origin(self : Node, offset : Int, line : Int, col : Int) -> Unit {
  self.origin_offset = Some(offset)
  self.origin_line = Some(line)
  self.origin_col = Some(col)
}

///|
fn Node::mark_parsed_from_source(self : Node) -> Unit {
  self.parsed_from_source = true
}

///|
fn Node::set_source_start_tag(self : Node, value : String) -> Unit {
  self.source_start_tag = Some(value)
}

///|
fn Node::set_source_end_tag(self : Node, value : String) -> Unit {
  self.source_end_tag = Some(value)
}

///|
fn Node::mark_sanitize_escape_only(self : Node) -> Unit {
  self.sanitize_escape_only = true
}

///|
fn Node::copy_origin_from(self : Node, source : Node) -> Unit {
  self.parsed_from_source = source.parsed_from_source
  self.source_start_tag = source.source_start_tag
  self.source_end_tag = source.source_end_tag
  self.sanitize_escape_only = source.sanitize_escape_only
  self.origin_offset = source.origin_offset
  self.origin_line = source.origin_line
  self.origin_col = source.origin_col
}

///|
fn lower_ascii(input : StringView) -> String {
  @syn.lower_ascii(input)
}
