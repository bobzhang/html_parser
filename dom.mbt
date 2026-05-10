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
    parent: None,
    children: [],
  }
  for child in children {
    node.append_child(child)
  }
  node
}

///|
pub fn document(children? : Array[Node] = []) -> Node {
  make_node(Document, "#document", None, {}, "", None, None, false, children)
}

///|
pub fn fragment(children? : Array[Node] = []) -> Node {
  make_node(
    Fragment,
    "#document-fragment",
    None,
    {},
    "",
    None,
    None,
    false,
    children,
  )
}

///|
pub fn element(
  name : StringView,
  attrs? : Map[String, String?] = {},
  children? : Array[Node] = [],
  ns? : String = "html",
) -> Node {
  make_node(
    Element,
    lower_ascii(name),
    Some(ns),
    attrs,
    "",
    None,
    None,
    false,
    children,
  )
}

///|
pub fn text(data : StringView) -> Node {
  make_node(Text, "#text", None, {}, data.to_owned(), None, None, false, [])
}

///|
pub fn comment(data : StringView) -> Node {
  make_node(Comment, "#comment", None, {}, data.to_owned(), None, None, false, [])
}

///|
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
pub fn Node::append_child(self : Node, child : Node) -> Unit {
  if !node_accepts_children(self) || node_is_self_or_ancestor(child, self) {
    return
  }
  detach_from_parent(child)
  child.parent = Some(self)
  self.children.push(child)
}

///|
fn node_accepts_children(node : Node) -> Bool {
  match node.kind {
    Document | Fragment | Element => true
    _ => false
  }
}

///|
fn node_is_self_or_ancestor(node : Node, descendant : Node) -> Bool {
  let mut current = Some(descendant)
  while current is Some(current_node) {
    if physical_equal(node, current_node) {
      return true
    }
    current = current_node.parent
  }
  false
}

///|
fn detach_from_parent(node : Node) -> Unit {
  match node.parent {
    Some(parent) => {
      parent.remove_child(node)
      node.parent = None
    }
    None => ()
  }
}

///|
pub fn Node::remove_child(self : Node, child : Node) -> Unit {
  if !node_accepts_children(self) {
    return
  }
  let mut index = 0
  while index < self.children.length() {
    if physical_equal(self.children[index], child) {
      ignore(self.children.remove(index))
      if child.parent is Some(parent) && physical_equal(parent, self) {
        child.parent = None
      }
      return
    }
    index += 1
  }
}

///|
pub fn Node::has_child_nodes(self : Node) -> Bool {
  !self.children.is_empty()
}

///|
pub fn Node::kind(self : Node) -> NodeKind {
  self.kind
}

///|
pub fn Node::name(self : Node) -> String {
  self.name
}

///|
pub fn Node::namespace_uri(self : Node) -> String? {
  self.ns
}

///|
pub fn Node::attrs(self : Node) -> Map[String, String?] {
  self.attrs.copy()
}

///|
pub fn Node::data(self : Node) -> String {
  self.data
}

///|
pub fn Node::children(self : Node) -> Array[Node] {
  self.children.copy()
}

///|
pub fn Node::clone_node(
  self : Node,
  deep? : Bool = false,
  override_attrs? : Map[String, String?],
) -> Node {
  let attrs = match override_attrs {
    Some(value) => value.copy()
    None => self.attrs.copy()
  }
  let cloned = make_node(
    self.kind,
    self.name,
    self.ns,
    attrs,
    self.data,
    self.public_id,
    self.system_id,
    self.force_quirks,
    [],
  )
  if deep {
    for child in self.children {
      cloned.append_child(child.clone_node(deep=true))
    }
  }
  cloned
}

///|
pub fn Node::text(self : Node) -> String {
  self.to_text(separator="", strip=false)
}

///|
fn lower_ascii(input : StringView) -> String {
  let out = StringBuilder::new(size_hint=input.length())
  for ch in input {
    if ch.is_ascii_uppercase() {
      out.write_char(ch.to_ascii_lowercase())
    } else {
      out.write_char(ch)
    }
  }
  out.to_string()
}
