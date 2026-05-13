// Whitebox coverage for linkify DOM replacement helper fallbacks.

///|
fn assert_linkified_single_anchor(parent : @dom.Node) -> Unit raise {
  assert_eq(parent.children.length(), 1)
  let anchor = parent.children[0]
  assert_true(anchor.kind is Element)
  assert_eq(anchor.name, "a")
  assert_true(anchor.attrs.get("href") is Some(Some("#x")))
  assert_eq(anchor.children.length(), 1)
  let label = anchor.children[0]
  assert_true(label.kind is Text)
  assert_eq(label.data, "x")
}

///|
test "linkify text replacement helper tolerates degenerate matches" {
  let empty_parent = @dom.element("p", children=[@dom.text("plain")])
  let empty_inserted = linkify_text_child_at_matches(
    empty_parent,
    0,
    empty_parent.children[0],
    [],
  )
  assert_eq(empty_inserted, 0)
  assert_eq(empty_parent.children.length(), 1)
  let plain = empty_parent.children[0]
  assert_true(plain.kind is Text)
  assert_eq(plain.data, "plain")

  let prefix_parent = @dom.element("p", children=[@dom.text("😀x")])
  let prefix_matches : Array[LinkMatch] = [
    { start: 1, end: 3, text: "x", href: "#x", kind: "url" },
  ]
  ignore(
    linkify_text_child_at_matches(
      prefix_parent,
      0,
      prefix_parent.children[0],
      prefix_matches,
    ),
  )
  assert_linkified_single_anchor(prefix_parent)

  let tail_parent = @dom.element("p", children=[@dom.text("😀x")])
  let tail_matches : Array[LinkMatch] = [
    { start: 0, end: 1, text: "x", href: "#x", kind: "url" },
  ]
  ignore(
    linkify_text_child_at_matches(
      tail_parent,
      0,
      tail_parent.children[0],
      tail_matches,
    ),
  )
  assert_linkified_single_anchor(tail_parent)
}
