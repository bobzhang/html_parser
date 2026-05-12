// Whitebox coverage for linkify DOM replacement helper fallbacks.

///|
test "linkify text replacement helper tolerates degenerate matches" {
  let empty_parent = element("p", children=[text("plain")])
  let empty_inserted = linkify_text_child_at_matches(
    empty_parent,
    0,
    empty_parent.children[0],
    [],
  )
  assert_eq(empty_inserted, 0)
  assert_eq(empty_parent.to_html(pretty=false), "<p>plain</p>")

  let prefix_parent = element("p", children=[text("😀x")])
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
  assert_eq(prefix_parent.to_html(pretty=false), "<p><a href=\"#x\">x</a></p>")

  let tail_parent = element("p", children=[text("😀x")])
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
  assert_eq(tail_parent.to_html(pretty=false), "<p><a href=\"#x\">x</a></p>")
}
