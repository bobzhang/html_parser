///|
test "public node builders expose stable accessors" {
  let text_node = @html_parser.text("Hello <world>")
  assert_true(text_node.kind() is Text)
  assert_eq(text_node.name(), "#text")
  assert_eq(text_node.data(), "Hello <world>")
  assert_eq(text_node.text(), "Hello <world>")
  assert_eq(text_node.has_child_nodes(), false)
  assert_eq(text_node.children().length(), 0)
  assert_true(text_node.parent() is None)
  assert_true(text_node.namespace_uri() is None)
  assert_true(text_node.origin_location() is None)

  let comment = @html_parser.comment("note")
  assert_true(comment.kind() is Comment)
  assert_eq(comment.name(), "#comment")
  assert_eq(comment.data(), "note")
  assert_eq(comment.text(), "")
  assert_eq(comment.to_html(pretty=false), "<!--note-->")

  let element = @html_parser.element(
    "mi",
    ns="mathml",
    attrs={ "data-x": Some("1"), "hidden": None },
    children=[@html_parser.text("x")],
  )
  assert_true(element.kind() is Element)
  assert_eq(element.name(), "mi")
  guard element.namespace_uri() is Some("math") else {
    fail("expected mathml namespace alias to normalize")
  }
  assert_eq(element.text(), "x")
  assert_true(element.has_child_nodes())
  guard element.attrs().get("hidden") is Some(None) else {
    fail("expected boolean attribute")
  }
  let children = element.children()
  assert_eq(children.length(), 1)
  guard children[0].parent() is Some(parent) else {
    fail("expected element child parent")
  }
  assert_eq(parent.name(), "mi")

  let fragment = @html_parser.fragment(children=[element])
  assert_true(fragment.kind() is Fragment)
  assert_eq(fragment.name(), "#document-fragment")
  assert_true(fragment.parent() is None)
  assert_eq(fragment.to_html(pretty=false), "<mi data-x=\"1\" hidden>x</mi>")

  let doc = @html_parser.document(children=[
    @html_parser.doctype(public_id="pub", system_id="sys", force_quirks=true),
    @html_parser.element("html", children=[
      @html_parser.element("body", children=[@html_parser.element("p")]),
    ]),
  ])
  assert_true(doc.kind() is Document)
  assert_eq(doc.name(), "#document")
  assert_eq(
    doc.to_html(pretty=false),
    "<!DOCTYPE html PUBLIC \"pub\" \"sys\"><html><body><p></p></body></html>",
  )
}

///|
test "public builder test-format output stays stable" {
  let node = @html_parser.element(
    "div",
    attrs={ "b": Some("2"), "a": Some("1"), "data-none": None },
    children=[
      @html_parser.text("x"),
      @html_parser.comment("c"),
      @html_parser.element("svg", ns="svg", attrs={
        "xlink:href": Some("u"),
        "viewBox": Some("0 0"),
      }),
    ],
  )
  assert_eq(
    @html_parser.to_test_format(node),
    "| <div>\n|   a=\"1\"\n|   b=\"2\"\n|   data-none=\"\"\n|   \"x\"\n|   <!-- c -->\n|   <svg svg>\n|     viewBox=\"0 0\"\n|     xlink href=\"u\"",
  )
  assert_eq(
    @html_parser.to_test_format(
      @html_parser.doctype(name="", system_id="about:legacy-compat"),
    ),
    "| <!DOCTYPE  \"\" \"about:legacy-compat\">",
  )
}

///|
test "public builder mutation no-ops stay stable" {
  let first_parent = @html_parser.element("section")
  let second_parent = @html_parser.element("article")
  let child = @html_parser.element("span", children=[@html_parser.text("x")])
  first_parent.append_child(child)
  second_parent.append_child(child)
  assert_eq(first_parent.to_html(pretty=false), "<section></section>")
  assert_eq(
    second_parent.to_html(pretty=false),
    "<article><span>x</span></article>",
  )
  guard child.parent() is Some(parent) else { fail("expected moved parent") }
  assert_eq(parent.name(), "article")

  child.append_child(second_parent)
  assert_eq(
    second_parent.to_html(pretty=false),
    "<article><span>x</span></article>",
  )

  let leaf = @html_parser.text("leaf")
  leaf.append_child(@html_parser.text("ignored"))
  leaf.insert_before(@html_parser.text("also ignored"), None)
  assert_eq(leaf.children().length(), 0)
  assert_eq(leaf.text(), "leaf")

  let missing = @html_parser.element("missing")
  assert_true(second_parent.replace_child(missing, first_parent) is None)
  second_parent.remove_child(first_parent)
  assert_eq(
    second_parent.to_html(pretty=false),
    "<article><span>x</span></article>",
  )
}
