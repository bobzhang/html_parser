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
  make_node(Document, "#document", None, {}, "", None, None, false, children)
}

///|
/// Create a document-fragment node with optional children.
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
fn normalize_element_namespace(ns : StringView) -> String {
  match ns.to_lower() {
    "mathml" => "math"
    "html" => "html"
    "svg" => "svg"
    "math" => "math"
    _ => ns.to_owned()
  }
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
  let ns = normalize_element_namespace(ns)
  make_node(
    Element,
    name.to_owned(),
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
/// Create a text node.
pub fn text(data : StringView) -> Node {
  make_node(Text, "#text", None, {}, data.to_owned(), None, None, false, [])
}

///|
/// Create a comment node.
pub fn comment(data : StringView) -> Node {
  make_node(Comment, "#comment", None, {}, data.to_owned(), None, None, false, [])
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
/// Append `child` to this node.
///
/// The child is detached from any existing parent first. Non-container nodes
/// and cycle-producing appends are ignored.
pub fn Node::append_child(self : Node, child : Node) -> Unit {
  if !node_accepts_children(self) || node_is_self_or_ancestor(child, self) {
    return
  }
  detach_from_parent(child)
  child.parent = Some(self)
  self.children.push(child)
}

///|
fn Node::insert_child_before(self : Node, child : Node, before : Node) -> Unit {
  if !node_accepts_children(self) || node_is_self_or_ancestor(child, self) {
    return
  }
  if physical_equal(child, before) {
    return
  }
  detach_from_parent(child)
  child.parent = Some(self)
  let mut index = 0
  while index < self.children.length() {
    if physical_equal(self.children[index], before) {
      self.children.insert(index, child)
      return
    }
    index += 1
  }
  self.children.push(child)
}

///|
/// Insert `child` before `before`, or append when `before` is absent.
///
/// If `before` is not a current child, the child is appended. Invalid insertions
/// are ignored in the same way as `append_child`.
pub fn Node::insert_before(self : Node, child : Node, before : Node?) -> Unit {
  match before {
    Some(reference) => self.insert_child_before(child, reference)
    None => self.append_child(child)
  }
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
/// Replace `old_child` with `new_child`.
///
/// Returns the removed child when replacement succeeds, or `None` when
/// `old_child` is not a current child or the replacement would create a cycle.
pub fn Node::replace_child(
  self : Node,
  new_child : Node,
  old_child : Node,
) -> Node? {
  if !node_accepts_children(self) || node_is_self_or_ancestor(new_child, self) {
    return None
  }
  let mut index = 0
  while index < self.children.length() {
    if physical_equal(self.children[index], old_child) {
      if physical_equal(new_child, old_child) {
        return Some(old_child)
      }
      detach_from_parent(new_child)
      let mut target_index = 0
      while target_index < self.children.length() {
        if physical_equal(self.children[target_index], old_child) {
          self.children[target_index] = new_child
          new_child.parent = Some(self)
          if old_child.parent is Some(parent) && physical_equal(parent, self) {
            old_child.parent = None
          }
          return Some(old_child)
        }
        target_index += 1
      }
      return None
    }
    index += 1
  }
  None
}

///|
/// Remove `child` from this node if it is a current child.
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
/// Test whether this node has any child nodes.
pub fn Node::has_child_nodes(self : Node) -> Bool {
  !self.children.is_empty()
}

///|
/// Return this node's kind.
pub fn Node::kind(self : Node) -> NodeKind {
  self.kind
}

///|
/// Return this node's parent, if any.
pub fn Node::parent(self : Node) -> Node? {
  self.parent
}

///|
/// Return this node's name.
pub fn Node::name(self : Node) -> String {
  self.name
}

///|
/// Return this element's namespace URI, if any.
pub fn Node::namespace_uri(self : Node) -> String? {
  self.ns
}

///|
/// Return a copy of this node's attributes.
pub fn Node::attrs(self : Node) -> Map[String, String?] {
  self.attrs.copy()
}

///|
/// Return this text, comment, or doctype node's data payload.
pub fn Node::data(self : Node) -> String {
  self.data
}

///|
/// Return a copy of this node's child list.
///
/// The returned array is detached from the node, but the child nodes themselves
/// are the same node objects.
pub fn Node::children(self : Node) -> Array[Node] {
  self.children.copy()
}

///|
/// Return this node's original source offset, if known.
pub fn Node::origin_offset(self : Node) -> Int? {
  self.origin_offset
}

///|
/// Return this node's original 1-based source line, if known.
pub fn Node::origin_line(self : Node) -> Int? {
  self.origin_line
}

///|
/// Return this node's original 1-based source column, if known.
pub fn Node::origin_col(self : Node) -> Int? {
  self.origin_col
}

///|
/// Return this node's original `(line, column)` source location, if known.
pub fn Node::origin_location(self : Node) -> (Int, Int)? {
  match (self.origin_line, self.origin_col) {
    (Some(line), Some(col)) => Some((line, col))
    _ => None
  }
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
fn Node::clear_sanitize_escape_only(self : Node) -> Unit {
  self.sanitize_escape_only = false
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
/// Clone this node.
///
/// `deep=true` recursively clones descendants. `override_attrs` replaces the
/// cloned node's attributes, which is useful for transform operations.
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
  cloned.copy_origin_from(self)
  if deep {
    let stack : Array[(Node, Node)] = [(self, cloned)]
    while !stack.is_empty() {
      match stack.pop() {
        Some((source, target)) =>
          for child in source.children {
            let child_clone = child.clone_node(deep=false)
            target.append_child(child_clone)
            stack.push((child, child_clone))
          }
        None => ()
      }
    }
  }
  cloned
}

///|
/// Return this node's descendant text with no separator and no trimming.
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
