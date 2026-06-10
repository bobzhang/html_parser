// Whitebox regressions for document scaffold and fragment shell helpers.

///|
test "document scaffold text helpers preserve whitespace boundaries" {
  assert_true(
    text_node_without_leading_ascii_whitespace(@dom.text(" \t\n")) is None,
  )
  guard text_node_without_leading_ascii_whitespace(@dom.text(" \tbody"))
    is Some(stripped) else {
    fail("expected stripped body text")
  }
  assert_eq(stripped.data, "body")
  let body = @dom.text("body")
  let (no_leading, unchanged) = split_text_node_leading_ascii_whitespace(body)
  assert_true(no_leading is None)
  guard unchanged is Some(actual) else { fail("expected original body text") }
  assert_true(physical_equal(actual, body))
  let (all_leading, empty_rest) = split_text_node_leading_ascii_whitespace(
    @dom.text(" \n"),
  )
  guard all_leading is Some(leading_only) else {
    fail("expected all-whitespace leading node")
  }
  assert_eq(leading_only.data, " \n")
  assert_true(empty_rest is None)
  let (leading, rest) = split_text_node_leading_ascii_whitespace(
    @dom.text(" \nBody"),
  )
  guard leading is Some(leading_node) else {
    fail("expected leading whitespace node")
  }
  assert_eq(leading_node.data, " \n")
  guard rest is Some(rest_node) else {
    fail("expected non-whitespace rest node")
  }
  assert_eq(rest_node.data, "Body")
}

///|
test "document scaffold merges repeated html helper trees" {
  let primary = @dom.element("html", attrs={ "lang": Some("en") }, children=[
    @dom.element("head", children=[
      @dom.element("title", children=[@dom.text("T")]),
    ]),
    @dom.element("body", children=[@dom.text("A")]),
  ])
  let sibling = @dom.element(
    "html",
    attrs={ "dir": Some("ltr"), "lang": Some("fr") },
    children=[
      @dom.element("html", attrs={ "data-root": Some("sibling") }, children=[
        @dom.element("body", attrs={ "id": Some("merged") }, children=[
          @dom.text("B"),
        ]),
      ]),
    ],
  )
  let root = @dom.document(children=[primary, sibling])
  scaffold_document(root, [], [], [], [])
  assert_eq(root.children.length(), 1)
  let html = root.children[0]
  assert_true(physical_equal(html, primary))
  guard html.attrs["lang"] is Some("en") else {
    fail("expected first html lang to win")
  }
  guard html.attrs["dir"] is Some("ltr") else {
    fail("expected sibling html dir to merge")
  }
  guard html.attrs["data-root"] is Some("sibling") else {
    fail("expected nested html attrs to merge")
  }
  assert_eq(html.children.length(), 2)
  let body = html.children[1]
  guard body.attrs["id"] is Some("merged") else {
    fail("expected nested body attrs to merge")
  }
  assert_eq(@ser.to_html(body, pretty=false), "<body id=\"merged\">AB</body>")
}

///|
test "fragment context unwrap helper preserves sibling nodes" {
  let leading = @dom.comment("before")
  let wrapper_child = @dom.element("tbody", children=[
    @dom.element("tr", children=[@dom.element("td", children=[@dom.text("x")])]),
  ])
  let wrapper = @dom.element("table", children=[wrapper_child])
  let trailing = @dom.text("after")
  let root = @dom.fragment(children=[leading, wrapper, trailing])
  unwrap_fragment_context_element(root, wrapper)
  assert_eq(root.children.length(), 3)
  assert_true(physical_equal(root.children[0], leading))
  assert_true(physical_equal(root.children[1], wrapper_child))
  assert_true(physical_equal(root.children[2], trailing))
  assert_true(wrapper.parent is None)
  assert_eq(wrapper.children.length(), 0)
}

///|
test "document and fragment helpers tolerate missing shells" {
  let parser = Parser(
    "",
    @dom.document(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  parser.pending_document_html_attrs["lang"] = Some("en")
  parser.apply_pending_document_html_attrs()
  assert_eq(parser.root.children.length(), 0)
  let html = @dom.element("html", attrs={ "dir": Some("ltr") })
  parser.root.append_child(html)
  parser.apply_pending_document_html_attrs()
  guard html.attrs["lang"] is Some("en") else {
    fail("expected pending html attrs to survive missing shell")
  }
  guard html.attrs["dir"] is Some("ltr") else {
    fail("expected existing html attrs to survive pending merge")
  }
  let root = @dom.document(children=[@dom.comment("tail")])
  let paragraph = @dom.element("p", children=[@dom.text("x")])
  append_post_body_html_children(root, [paragraph])
  assert_eq(@ser.to_html(root, pretty=false), "<!--tail--><p>x</p>")
  guard paragraph.parent() is Some(parent) else {
    fail("expected appended post-body child parent")
  }
  assert_true(physical_equal(parent, root))
  let nested_before_body = @dom.element("html", children=[
    @dom.comment("c"),
    @dom.element("html", children=[
      @dom.element("meta", attrs={ "name": Some("x") }),
    ]),
  ])
  assert_true(html_fragment_child_is_before_body(nested_before_body))
  let nested_after_body = @dom.element("html", children=[
    @dom.element("html", children=[@dom.element("body")]),
  ])
  assert_eq(html_fragment_child_is_before_body(nested_after_body), false)
  let fragment_parser = Parser(
    "",
    @dom.fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  fragment_parser.insert_html_fragment_body_marker({}, None)
  assert_eq(fragment_parser.root.children.length(), 0)
  assert_eq(
    fragment_parser.handle_html_fragment_shell_start_tag("p", {}, 0),
    false,
  )
}
