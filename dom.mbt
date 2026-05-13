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
  match (public_id, system_id) {
    (Some(public_id), Some(system_id)) =>
      @dom.doctype(name~, public_id~, system_id~, force_quirks~)
    (Some(public_id), None) => @dom.doctype(name~, public_id~, force_quirks~)
    (None, Some(system_id)) => @dom.doctype(name~, system_id~, force_quirks~)
    (None, None) => @dom.doctype(name~, force_quirks~)
  }
}
