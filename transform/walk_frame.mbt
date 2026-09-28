///|
/// One activation of a recursive "walk the children of `node`" routine,
/// modelled on an explicit heap-allocated stack so deeply nested DOM trees do
/// not overflow the native call stack.
///
/// `index` is the loop cursor over `node.children`, `skip` carries the
/// inherited skip state (linkify and whitespace walks), and `entered` records
/// whether the node's template contents have already been scheduled, since the
/// recursive walks visit template contents before the regular children.
/// `pending` holds a child whose subtree walk is in progress and which still
/// needs post-order work once that walk finishes (used by `prune_empty`).
priv struct WalkFrame {
  node : @dom.Node
  skip : Bool
  mut entered : Bool
  mut index : Int
  mut pending : @dom.Node?
}

///|
fn WalkFrame::new(node : @dom.Node, skip? : Bool = false) -> WalkFrame {
  { node, skip, entered: false, index: 0, pending: None, }
}

///|
/// On the first visit of `self`, schedule its template contents (inheriting
/// `self.skip`) ahead of its children. Returns `true` when a template frame was
/// pushed, in which case the caller must resume from the top of the stack.
fn WalkFrame::schedule_template_first(
  self : WalkFrame,
  stack : Array[WalkFrame],
) -> Bool {
  if self.entered {
    return false
  }
  self.entered = true
  match self.node.template_contents {
    Some(contents) => {
      stack.push(WalkFrame::new(contents, skip=self.skip))
      true
    }
    None => false
  }
}
