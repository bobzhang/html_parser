///|
/// Build `depth` nested elements (cycling through `names`) around a leaf with
/// an unsafe link, each level carrying an event-producing attribute and text.
fn deep_chain(depth : Int, names : Array[String]) -> @dom.Node {
  let mut cur = @dom.element("a", attrs={ "href": Some("javascript:x") }, children=[
    @dom.text("leaf"),
  ])
  for i in 0..<depth {
    cur = @dom.element(
      names[i % names.length()],
      attrs={ "onclick": Some("x()") },
      children=[@dom.text("\u{200B}t"), cur, @dom.comment("c")],
    )
  }
  @dom.document(children=[cur])
}

///|
/// Count nodes and the maximum depth without recursion.
fn deep_measure(root : @dom.Node) -> (Int, Int) {
  let stack : Array[(@dom.Node, Int)] = [(root, 0)]
  let mut count = 0
  let mut max_depth = 0
  while stack.pop() is Some((node, depth)) {
    count += 1
    if depth > max_depth {
      max_depth = depth
    }
    for child in node.children {
      stack.push((child, depth + 1))
    }
  }
  (count, max_depth)
}

///|
test "sanitize_dom handles deeply nested trees without recursion" {
  let depth = 30000
  let events = Ref(0)
  let observer = @sanitize.SanitizeTransformObserver(
    Some(_ => events.val += 1),
    None,
  )
  let allowed = @sanitize.sanitize_dom_with_observer(
    deep_chain(depth, ["b", "div"]),
    None,
    Some(observer),
  )
  // Per level: element + stripped text; plus document, leaf <a>, its text.
  assert_eq(deep_measure(allowed), (2 * depth + 3, depth + 2))
  // Per level: dropped comment, onclick report, stripped text; plus the leaf.
  assert_eq(events.val, 3 * depth + 1)
  let handlings : Array[@sanitize.DisallowedTagHandling] = [Unwrap, Escape]
  for handling in handlings {
    let policy = @sanitize.SanitizationPolicy(
      ["a", "b"],
      disallowed_tag_handling=handling,
    )
    let out = @sanitize.sanitize_dom(
      deep_chain(depth, ["custom", "b"]),
      policy~,
    )
    let (_, max_depth) = deep_measure(out)
    assert_eq(max_depth, depth / 2 + 2)
  }
}
