///|
fn sanitize_node_name(node : @dom.Node) -> String {
  @syn.lower_ascii(node.name)
}

///|
fn sanitize_namespace_is_foreign(node : @dom.Node) -> Bool {
  match node.ns {
    Some(ns) => ns != "html"
    None => false
  }
}

///|
/// Return whether a node is treated as foreign-content for sanitization.
///
/// A node is effectively foreign when it or an ancestor has a non-HTML
/// namespace, or when it appears under an `svg` or `math` element name. This is
/// used to harden URL-bearing attributes and active foreign-content elements.
pub fn node_is_effectively_foreign(node : @dom.Node) -> Bool {
  let mut current = Some(node)
  while current is Some(current_node) {
    if sanitize_namespace_is_foreign(current_node) {
      return true
    }
    match current_node.kind {
      Element =>
        match sanitize_node_name(current_node) {
          "math" | "svg" => return true
          _ => ()
        }
      _ => ()
    }
    current = current_node.parent
  }
  false
}

///|
fn is_active_foreign_mutation_tag(name : String) -> Bool {
  match name {
    "animate" | "annotation-xml" | "foreignobject" | "set" => true
    _ => false
  }
}

///|
fn sanitize_node_is_active_foreign_content(node : @dom.Node) -> Bool {
  is_active_foreign_mutation_tag(sanitize_node_name(node)) &&
  node_is_effectively_foreign(node)
}
