///|
/// One pending child list of the explicit-stack `query` walk.
///
/// `owner` is the node whose list is walked: the visited node itself for its
/// `children`, or its template contents fragment for the contents' children.
/// `trusted` records that no other trusted frame in the same query walks
/// `owner`'s list (see `query_frame_trusted_*`).
priv struct QueryFrame {
  owner : @dom.Node
  list : Array[@dom.Node]
  trusted : Bool
  mut index : Int
}

///|
/// A visited node's own `children` frame is trusted unless the node is also
/// its parent's template contents: in that case the parent's contents frame
/// may walk the same list.
fn query_frame_trusted_children(node : @dom.Node) -> Bool {
  match node.parent {
    Some(parent) =>
      !(parent.template_contents is Some(contents) &&
      physical_equal(contents, node))
    None => true
  }
}

///|
/// A template contents frame is trusted only when the contents fragment's
/// `parent` is the host being walked, so at most one host can own it.
fn query_frame_trusted_contents(host : @dom.Node, contents : @dom.Node) -> Bool {
  contents.parent is Some(parent) && physical_equal(parent, host)
}

///|
/// Push `node`'s child frames so that template contents are walked before
/// the node's own children, matching the former recursive walk.
fn push_query_frames(stack : Array[QueryFrame], node : @dom.Node) -> Unit {
  stack.push({
    owner: node,
    list: node.children,
    trusted: query_frame_trusted_children(node),
    index: 0,
  })
  match node.template_contents {
    Some(contents) =>
      stack.push({
        owner: contents,
        list: contents.children,
        trusted: query_frame_trusted_contents(node, contents),
        index: 0,
      })
    None => ()
  }
}

///|
/// Whether `node`, found at `index` of `frame`, is reached along a regular
/// tree edge: a trusted frame, a matching `parent` link, not the query root,
/// and the first occurrence of `node` in the list.
///
/// A regular node can only have been visited before if it was visited
/// irregularly: a regular earlier visit would need an earlier trusted walk of
/// `node.parent`'s list, and each owner has at most one trusted frame, so it
/// would be this frame at an earlier index, which the last check excludes.
fn query_edge_is_regular(
  frame : QueryFrame,
  index : Int,
  node : @dom.Node,
  root : @dom.Node,
) -> Bool {
  if !frame.trusted || physical_equal(node, root) {
    return false
  }
  guard node.parent is Some(parent) && physical_equal(parent, frame.owner) else {
    return false
  }
  for i in 0..<index {
    if physical_equal(frame.list[i], node) {
      return false
    }
  }
  true
}

///|
/// Return all descendants of `root` that match a CSS selector.
pub fn query(root : @dom.Node, selector : StringView) -> Array[@dom.Node] {
  let out : Array[@dom.Node] = []
  let allow_non_elements = selector_allows_non_elements(selector)
  // Every node visited so far, in visit order; a node reached twice (shared
  // or cyclic structure) is skipped the second time.
  let visited : Array[@dom.Node] = [root]
  // The visited nodes that were reached along an irregular edge. A node
  // reached along a regular edge is already visited exactly when it is in
  // this (normally empty) list, which avoids scanning `visited`.
  let irregular : Array[@dom.Node] = []
  let stack : Array[QueryFrame] = []
  push_query_frames(stack, root)
  while stack.last() is Some(frame) {
    let index = frame.index
    if index >= frame.list.length() {
      ignore(stack.pop())
      continue
    }
    frame.index = index + 1
    let node = frame.list[index]
    if query_edge_is_regular(frame, index, node, root) {
      if node_identity_seen(irregular, node) {
        continue
      }
    } else {
      if node_identity_seen(visited, node) {
        continue
      }
      irregular.push(node)
    }
    visited.push(node)
    if (allow_non_elements || node.kind == Element) &&
      matches_selector_list(node, selector) {
      out.push(node)
    }
    push_query_frames(stack, node)
  }
  out
}

///|
/// Return the first descendant of `root` that matches a CSS selector.
pub fn query_one(root : @dom.Node, selector : StringView) -> @dom.Node? {
  query(root, selector).get(0)
}
