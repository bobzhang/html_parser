///|
fn apply_drop_kind_transform(
  root : @dom.Node,
  kind : @dom.NodeKind,
  transform : TransformSpec,
) -> Unit {
  match root.kind {
    Document | Fragment | Element => {
      let mut index = 0
      while index < root.children.length() {
        let child = root.children[index]
        if child.kind == kind {
          transform_call_hook(child, transform)
          let label = match kind {
            Comment => "comment"
            Doctype => "doctype"
            _ => "node"
          }
          transform_report(transform, "Dropped " + label, Some(child))
          @san.remove_child_at(root, index)
        } else {
          apply_drop_kind_transform(child, kind, transform)
          index += 1
        }
      }
    }
    _ => ()
  }
}

///|
fn node_has_foreign_namespace(node : @dom.Node) -> Bool {
  match node.ns {
    Some(ns) => ns != "html"
    None => false
  }
}

///|
fn apply_drop_foreign_namespaces_transform(
  root : @dom.Node,
  transform : TransformSpec,
) -> Unit {
  match root.kind {
    Document | Fragment | Element => {
      let mut index = 0
      while index < root.children.length() {
        let child = root.children[index]
        if child.kind == Element && node_has_foreign_namespace(child) {
          transform_call_hook(child, transform)
          transform_report(
            transform,
            "Unsafe tag '" +
            @syn.lower_ascii(child.name) +
            "' (foreign namespace)",
            Some(child),
          )
          @san.remove_child_at(root, index)
        } else {
          apply_drop_foreign_namespaces_transform(child, transform)
          index += 1
        }
      }
    }
    _ => ()
  }
}
