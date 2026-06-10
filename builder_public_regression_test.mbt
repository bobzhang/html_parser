///|
fn test_attr_id(node : @html_parser.Node) -> String {
  match node.attrs().get("id") {
    Some(Some(value)) => value
    _ => ""
  }
}

///|
test "builder serializes compact HTML" {
  let node = @html_parser.element("p", attrs={ "class": Some("intro") }, children=[
    @html_parser.text("Hello "),
    @html_parser.element("b", children=[@html_parser.text("MoonBit")]),
  ])
  assert_eq(
    node.to_html(pretty=false),
    "<p class=\"intro\">Hello <b>MoonBit</b></p>",
  )
}

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
test "builder preserves adjusted foreign element names" {
  let gradient = @html_parser.element("linearGradient", ns="svg")
  assert_eq(gradient.name(), "linearGradient")
  assert_true(gradient.namespace_uri() is Some("svg"))
  assert_eq(gradient.to_html(pretty=false), "<linearGradient></linearGradient>")
  let math = @html_parser.element("math", ns="mathml", children=[
    @html_parser.element("mi", ns="mathml", children=[@html_parser.text("x")]),
  ])
  assert_true(math.namespace_uri() is Some("math"))
  assert_eq(math.to_html(pretty=false), "<math><mi>x</mi></math>")
  let rect = @html_parser.element("rect", ns="SVG")
  assert_true(rect.namespace_uri() is Some("svg"))
  let div = @html_parser.element("DIV")
  assert_eq(div.name(), "DIV")
  assert_true(div.namespace_uri() is Some("html"))
}

///|
test "builder exposes DOM helper invariants" {
  let custom = @html_parser.element("Thing", ns="CustomNS")
  assert_eq(custom.name(), "Thing")
  assert_true(custom.namespace_uri() is Some("CustomNS"))
  assert_true(custom.kind() is Element)
  assert_eq(custom.data(), "")
  assert_eq(custom.text(), "")
  assert_eq(custom.has_child_nodes(), false)
  let parent = @html_parser.element("div", attrs={ "id": Some("root") }, children=[
    @html_parser.text("a"),
    @html_parser.element("span", children=[@html_parser.text("b")]),
  ])
  assert_true(parent.has_child_nodes())
  assert_eq(parent.text(), "ab")
  let shallow = parent.clone_node()
  assert_eq(shallow.to_html(pretty=false), "<div id=\"root\"></div>")
  let deep = parent.clone_node(deep=true, override_attrs={ "id": Some("clone") })
  assert_eq(
    deep.to_html(pretty=false),
    "<div id=\"clone\">a<span>b</span></div>",
  )
  assert_eq(
    parent.to_html(pretty=false),
    "<div id=\"root\">a<span>b</span></div>",
  )
  let original_children = parent.children()
  assert_true(original_children[0].kind() is Text)
  assert_eq(original_children[0].data(), "a")
  let attrs_copy = parent.attrs()
  attrs_copy["id"] = Some("mutated")
  assert_eq(
    parent.to_html(pretty=false),
    "<div id=\"root\">a<span>b</span></div>",
  )
  let override_attrs = { "id": Some("override") }
  let override_clone = parent.clone_node(override_attrs~)
  override_attrs["id"] = Some("mutated")
  assert_eq(override_clone.to_html(pretty=false), "<div id=\"override\"></div>")
  let note = @html_parser.comment("note")
  assert_true(note.kind() is Comment)
  assert_eq(note.data(), "note")
  assert_eq(note.text(), "")
  note.append_child(@html_parser.text("ignored"))
  assert_eq(note.has_child_nodes(), false)
}

///|
test "text nodes expose no children" {
  let value = @html_parser.text("hello")
  assert_eq(value.children().length(), 0)
  assert_eq(value.has_child_nodes(), false)
  value.append_child(@html_parser.text("ignored"))
  assert_eq(value.children().length(), 0)
  assert_eq(value.text(), "hello")
}

///|
test "to_test_format matches reference line format" {
  let node = @html_parser.element(
    "div",
    attrs={ "b": Some("2"), "a": Some("1"), "data-none": None },
    children=[@html_parser.text("x"), @html_parser.comment("c")],
  )
  assert_eq(
    @html_parser.to_test_format(node),
    "| <div>\n|   a=\"1\"\n|   b=\"2\"\n|   data-none=\"\"\n|   \"x\"\n|   <!-- c -->",
  )
  let nested_fragment = @html_parser.element("div", children=[
    @html_parser.fragment(children=[@html_parser.text("x")]),
  ])
  assert_eq(
    @html_parser.to_test_format(nested_fragment),
    "| <div>\n|   <#document-fragment>\n|     \"x\"",
  )
  let doc = @html_parser.document(children=[
    @html_parser.doctype(),
    @html_parser.element("html", children=[
      @html_parser.element("body", children=[@html_parser.element("p")]),
    ]),
  ])
  assert_eq(
    @html_parser.to_test_format(doc),
    "| <!DOCTYPE html>\n| <html>\n|   <body>\n|     <p>",
  )
  let fragment = @html_parser.fragment(children=[
    @html_parser.element("span", children=[@html_parser.text("x")]),
  ])
  assert_eq(@html_parser.to_test_format(fragment), "| <span>\n|   \"x\"")
  let doctype = @html_parser.doctype(public_id="pub", system_id="sys")
  assert_eq(
    @html_parser.to_test_format(doctype),
    "| <!DOCTYPE html \"pub\" \"sys\">",
  )
  assert_eq(
    @html_parser.to_test_format(@html_parser.doctype(name="")),
    "| <!DOCTYPE >",
  )
  assert_eq(
    @html_parser.to_test_format(@html_parser.doctype(system_id="sys")),
    "| <!DOCTYPE html \"\" \"sys\">",
  )
  assert_eq(
    @html_parser.to_test_format(@html_parser.doctype(public_id="pub")),
    "| <!DOCTYPE html \"pub\" \"\">",
  )
  let svg = @html_parser.element(
    "svg",
    attrs={ "xlink:href": Some("u"), "viewBox": Some("0 0") },
    ns="svg",
  )
  assert_eq(
    @html_parser.to_test_format(svg),
    "| <svg svg>\n|   viewBox=\"0 0\"\n|   xlink href=\"u\"",
  )
  let collision = @html_parser.element(
    "svg",
    attrs={ "xlink href": Some("va"), "xlink:href": Some("v") },
    ns="svg",
  )
  assert_eq(
    @html_parser.to_test_format(collision),
    "| <svg svg>\n|   xlink href=\"v\"\n|   xlink href=\"va\"",
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

///|
test "builder insert and replace helpers preserve graph invariants" {
  let parent = @html_parser.element("div", attrs={ "id": Some("parent") })
  let first = @html_parser.element("span", attrs={ "id": Some("1") })
  let second = @html_parser.element("span", attrs={ "id": Some("2") })
  let third = @html_parser.element("span", attrs={ "id": Some("3") })
  parent.append_child(first)
  parent.insert_before(second, Some(first))
  parent.insert_before(third, None)
  let children = parent.children()
  assert_eq(children.length(), 3)
  assert_eq(test_attr_id(children[0]), "2")
  assert_eq(test_attr_id(children[1]), "1")
  assert_eq(test_attr_id(children[2]), "3")
  guard second.parent() is Some(second_parent) else {
    fail("expected inserted child parent")
  }
  assert_eq(test_attr_id(second_parent), "parent")
  parent.insert_before(second, Some(second))
  assert_eq(test_attr_id(parent.children()[0]), "2")
  let fallback = @html_parser.element("span", attrs={ "id": Some("4") })
  parent.insert_before(fallback, Some(@html_parser.element("missing")))
  assert_eq(test_attr_id(parent.children()[3]), "4")
  let replacement = @html_parser.element("p", attrs={ "id": Some("new") })
  guard parent.replace_child(replacement, first) is Some(replaced) else {
    fail("expected replaced child")
  }
  assert_eq(test_attr_id(replaced), "1")
  assert_true(first.parent() is None)
  guard replacement.parent() is Some(replacement_parent) else {
    fail("expected replacement parent")
  }
  assert_eq(test_attr_id(replacement_parent), "parent")
  let after_replace = parent.children()
  assert_eq(test_attr_id(after_replace[0]), "2")
  assert_eq(test_attr_id(after_replace[1]), "new")
  assert_eq(test_attr_id(after_replace[2]), "3")
  assert_eq(test_attr_id(after_replace[3]), "4")
  guard parent.replace_child(replacement, replacement) is Some(same_child) else {
    fail("expected same-child replacement")
  }
  assert_eq(test_attr_id(same_child), "new")
  assert_eq(test_attr_id(parent.children()[1]), "new")
  guard parent.replace_child(second, third) is Some(moved_out) else {
    fail("expected moved old child")
  }
  assert_eq(test_attr_id(moved_out), "3")
  assert_true(third.parent() is None)
  let after_move = parent.children()
  assert_eq(after_move.length(), 3)
  assert_eq(test_attr_id(after_move[0]), "new")
  assert_eq(test_attr_id(after_move[1]), "2")
  assert_eq(test_attr_id(after_move[2]), "4")
  assert_true(parent.replace_child(@html_parser.element("x"), first) is None)
  let nested = @html_parser.element("i", attrs={ "id": Some("nested") })
  replacement.append_child(nested)
  assert_true(replacement.replace_child(parent, nested) is None)
  assert_eq(test_attr_id(replacement.children()[0]), "nested")
}

///|
test "clone_node copies template descendants through child traversal" {
  let template = @html_parser.element("template", children=[
    @html_parser.element("div", attrs={ "id": Some("content") }),
    @html_parser.element("span"),
  ])
  assert_eq(
    template.clone_node().to_html(pretty=false),
    "<template></template>",
  )
  let cloned = template.clone_node(deep=true)
  assert_eq(
    cloned.to_html(pretty=false),
    "<template><div id=\"content\"></div><span></span></template>",
  )
  guard cloned.query_one("div") is Some(cloned_div) else {
    fail("expected cloned template content")
  }
  cloned_div.append_child(@html_parser.text("clone"))
  guard cloned_div.parent() is Some(cloned_parent) else {
    fail("expected cloned template child parent")
  }
  assert_eq(cloned_parent.name(), "#document-fragment")
  assert_eq(
    template.to_html(pretty=false),
    "<template><div id=\"content\"></div><span></span></template>",
  )
  assert_eq(
    cloned.to_html(pretty=false),
    "<template><div id=\"content\">clone</div><span></span></template>",
  )
}

///|
test "clone_node deep handles deep trees iteratively" {
  let root = @html_parser.document()
  let mut parent = root
  for _ in 0..<1200 {
    let child = @html_parser.element("div")
    parent.append_child(child)
    parent = child
  }
  parent.append_child(@html_parser.text("x"))
  let cloned = root.clone_node(deep=true)
  assert_eq(cloned.to_text(separator="", strip=false), "x")
  let mut current = cloned
  let mut depth = 0
  while current.children().length() > 0 {
    let children = current.children()
    current = children[0]
    depth += 1
    if current.kind() is Text {
      break
    }
  }
  assert_eq(depth, 1201)
}
