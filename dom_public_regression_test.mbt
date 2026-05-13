///|
fn dom_public_attr_id(node : @html_parser.Node) -> String {
  match node.attrs().get("id") {
    Some(Some(value)) => value
    _ => ""
  }
}

///|
fn assert_dom_public_origin(
  node : @html_parser.Node,
  offset : Int,
  line : Int,
  col : Int,
) -> Unit raise {
  guard node.origin_offset() is Some(actual_offset) && actual_offset == offset else {
    fail("unexpected origin offset")
  }
  guard node.origin_line() is Some(actual_line) && actual_line == line else {
    fail("unexpected origin line")
  }
  guard node.origin_col() is Some(actual_col) && actual_col == col else {
    fail("unexpected origin column")
  }
  guard node.origin_location() is Some((actual_line, actual_col)) &&
    actual_line == line &&
    actual_col == col else {
    fail("unexpected origin location")
  }
}

///|
test "public DOM mutation graph invariants stay stable" {
  let root = @html_parser.element("div", attrs={ "id": Some("root") })
  let first = @html_parser.element("span", attrs={ "id": Some("first") }, children=[
    @html_parser.text("1"),
  ])
  let second = @html_parser.element("span", attrs={ "id": Some("second") }, children=[
    @html_parser.text("2"),
  ])
  let third = @html_parser.element("em", attrs={ "id": Some("third") }, children=[
    @html_parser.text("3"),
  ])
  root.append_child(first)
  root.insert_before(second, Some(first))
  root.insert_before(third, None)
  assert_eq(
    root.to_html(pretty=false),
    "<div id=\"root\"><span id=\"second\">2</span><span id=\"first\">1</span><em id=\"third\">3</em></div>",
  )
  guard first.parent() is Some(first_parent) else {
    fail("expected first parent")
  }
  assert_eq(dom_public_attr_id(first_parent), "root")

  let replacement = @html_parser.element(
    "strong",
    attrs={ "id": Some("replacement") },
    children=[@html_parser.text("R")],
  )
  guard root.replace_child(replacement, first) is Some(replaced) else {
    fail("expected replacement")
  }
  assert_eq(dom_public_attr_id(replaced), "first")
  assert_true(first.parent() is None)
  guard replacement.parent() is Some(replacement_parent) else {
    fail("expected replacement parent")
  }
  assert_eq(dom_public_attr_id(replacement_parent), "root")
  root.remove_child(second)
  assert_true(second.parent() is None)
  assert_eq(
    root.to_html(pretty=false),
    "<div id=\"root\"><strong id=\"replacement\">R</strong><em id=\"third\">3</em></div>",
  )

  let children_copy = root.children()
  children_copy.push(@html_parser.element("i", attrs={ "id": Some("copy") }))
  assert_eq(root.children().length(), 2)
  let attrs_copy = replacement.attrs()
  attrs_copy["id"] = Some("mutated")
  assert_eq(dom_public_attr_id(replacement), "replacement")
}

///|
test "public DOM clone workflow keeps copies detached" {
  let root = @html_parser.element(
    "article",
    attrs={ "id": Some("original"), "data-stable": Some("yes") },
    children=[
      @html_parser.element("h2", children=[@html_parser.text("Title")]),
      @html_parser.element("p", children=[
        @html_parser.text("A "),
        @html_parser.element("span", children=[@html_parser.text("B")]),
      ]),
    ],
  )
  let shallow = root.clone_node()
  assert_eq(
    shallow.to_html(pretty=false),
    "<article id=\"original\" data-stable=\"yes\"></article>",
  )
  let override_attrs = { "id": Some("clone"), "data-extra": None }
  let deep = root.clone_node(deep=true, override_attrs~)
  override_attrs["id"] = Some("mutated")
  assert_eq(
    deep.to_html(pretty=false),
    "<article id=\"clone\" data-extra><h2>Title</h2><p>A <span>B</span></p></article>",
  )
  assert_eq(
    root.to_html(pretty=false),
    "<article id=\"original\" data-stable=\"yes\"><h2>Title</h2><p>A <span>B</span></p></article>",
  )
  guard deep.query_one("h2") is Some(cloned_heading) else {
    fail("expected cloned heading")
  }
  guard cloned_heading.parent() is Some(cloned_parent) else {
    fail("expected cloned parent")
  }
  assert_eq(dom_public_attr_id(cloned_parent), "clone")
  cloned_heading.append_child(@html_parser.text("!"))
  assert_eq(deep.query("h2").length(), 1)
  assert_eq(
    deep.to_html(pretty=false),
    "<article id=\"clone\" data-extra><h2>Title!</h2><p>A <span>B</span></p></article>",
  )
  assert_eq(
    root.query_one("h2").unwrap().to_html(pretty=false),
    "<h2>Title</h2>",
  )
}

///|
test "public parsed DOM origin metadata uses UTF-16 offsets" {
  let doc = @html_parser.parse_fragment(
    "😀\n<p>hi</p>",
    track_node_locations=true,
  )
  guard doc.query_one("p") is Some(paragraph) else {
    fail("expected paragraph")
  }
  assert_dom_public_origin(paragraph, 3, 2, 1)
  let children = paragraph.children()
  assert_eq(children.length(), 1)
  assert_eq(children[0].data(), "hi")
  assert_dom_public_origin(children[0], 6, 2, 4)

  let clone = paragraph.clone_node(deep=true)
  assert_dom_public_origin(clone, 3, 2, 1)
  assert_dom_public_origin(clone.children()[0], 6, 2, 4)
}
