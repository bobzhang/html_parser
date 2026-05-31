// Blackbox snapshot tests for tree-mutation methods: append_child,
// insert_before, remove_child, replace_child, and clone_node.

///|
fn children_summary(node : @dom.Node) -> Array[(@dom.NodeKind, String)] {
  node.children().map(c => (c.kind(), c.name()))
}

///|
test "append_child adds to the end of children" {
  let parent = @dom.element("div")
  parent.append_child(@dom.element("p"))
  parent.append_child(@dom.element("span"))
  debug_inspect(
    children_summary(parent),
    content=(
      #|[(Element, "p"), (Element, "span")]
    ),
  )
}

///|
test "append_child sets parent on the child" {
  let parent = @dom.element("div")
  let child = @dom.element("p")
  parent.append_child(child)
  // is Some(_) to avoid debug-dumping the entire parent tree.
  debug_inspect(
    child.parent() is Some(_),
    content=(
      #|true
    ),
  )
}

///|
test "insert_before inserts at the given reference position" {
  let parent = @dom.element("div")
  let a = @dom.element("a")
  let b = @dom.element("b")
  let c = @dom.element("c")
  parent.append_child(a)
  parent.append_child(c)
  parent.insert_before(b, Some(c))
  debug_inspect(
    children_summary(parent),
    content=(
      #|[(Element, "a"), (Element, "b"), (Element, "c")]
    ),
  )
}

///|
test "insert_before with None reference appends" {
  let parent = @dom.element("div")
  let a = @dom.element("a")
  parent.append_child(a)
  parent.insert_before(@dom.element("z"), None)
  debug_inspect(
    children_summary(parent),
    content=(
      #|[(Element, "a"), (Element, "z")]
    ),
  )
}

///|
test "remove_child detaches and unlinks parent" {
  let parent = @dom.element("div")
  let a = @dom.element("a")
  let b = @dom.element("b")
  parent.append_child(a)
  parent.append_child(b)
  parent.remove_child(a)
  debug_inspect(
    (children_summary(parent), a.parent() is Some(_)),
    content=(
      #|([(Element, "b")], false)
    ),
  )
}

///|
test "replace_child returns the replaced child" {
  let parent = @dom.element("div")
  let a = @dom.element("a")
  let b = @dom.element("b")
  parent.append_child(a)
  let replaced = parent.replace_child(b, a)
  debug_inspect(
    (children_summary(parent), replaced is Some(_)),
    content=(
      #|([(Element, "b")], true)
    ),
  )
}

///|
test "clone_node defaults to shallow copy" {
  let original = @dom.element("p", attrs={ "class": Some("intro") }, children=[
    @dom.text("hi"),
  ])
  let shallow = original.clone_node()
  let deep = original.clone_node(deep=true)
  // Shallow has no children; deep has the same shape.
  debug_inspect(
    (shallow.children().length(), deep.children().length(), deep.attrs()),
    content=(
      #|(0, 1, { "class": Some("intro") })
    ),
  )
}

///|
test "Node::text concatenates descendant text" {
  let node = @dom.element("p", children=[
    @dom.text("Hello "),
    @dom.element("b", children=[@dom.text("MoonBit")]),
    @dom.text("!"),
  ])
  inspect(
    node.text(),
    content=(
      #|Hello MoonBit!
    ),
  )
}
