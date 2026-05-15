///|
test "nodes expose empty origin metadata by default" {
  let text = @html_parser.text("hello")
  assert_true(text.origin_offset() is None)
  assert_true(text.origin_line() is None)
  assert_true(text.origin_col() is None)
  assert_true(text.origin_location() is None)
  let parent = @html_parser.element("p", children=[text])
  assert_true(parent.origin_offset() is None)
  assert_true(parent.origin_location() is None)
  let clone = parent.clone_node(deep=true)
  assert_true(clone.origin_offset() is None)
  assert_true(clone.origin_location() is None)
  let doc = @html_parser.parse_fragment("<p>hi</p>")
  guard doc.query_one("p") is Some(parsed_p) else {
    fail("expected parsed paragraph")
  }
  assert_true(parsed_p.origin_offset() is None)
  assert_true(parsed_p.origin_location() is None)
  let parsed_children = parsed_p.children()
  assert_eq(parsed_children.length(), 1)
  assert_true(parsed_children[0].origin_location() is None)
}

///|
test "parser tracks simple element and text origins when requested" {
  let doc = @html_parser.parse_fragment("<p>hi</p>", track_node_locations=true)
  guard doc.query_one("p") is Some(paragraph) else {
    fail("expected parsed paragraph")
  }
  assert_node_origin(paragraph, 0, 1, 1)
  let children = paragraph.children()
  assert_eq(children.length(), 1)
  assert_eq(children[0].data(), "hi")
  assert_node_origin(children[0], 3, 1, 4)
  let multiline = @html_parser.parse_fragment(
    "lead\n<p>x</p>",
    track_node_locations=true,
  )
  guard multiline.query_one("p") is Some(multiline_p) else {
    fail("expected multiline paragraph")
  }
  assert_node_origin(multiline_p, 5, 2, 1)
  let multiline_children = multiline_p.children()
  assert_eq(multiline_children.length(), 1)
  assert_node_origin(multiline_children[0], 8, 2, 4)
}

///|
test "parser tracks comment and doctype origins when requested" {
  let fragment = @html_parser.parse_fragment(
    "<!--x--><p><!--y--></p>",
    track_node_locations=true,
  )
  let root_children = fragment.root.children()
  assert_eq(root_children.length(), 2)
  assert_true(root_children[0].kind() is Comment)
  assert_node_origin(root_children[0], 0, 1, 1)
  guard fragment.query_one("p") is Some(paragraph) else {
    fail("expected parsed paragraph")
  }
  assert_node_origin(paragraph, 8, 1, 9)
  let paragraph_children = paragraph.children()
  assert_eq(paragraph_children.length(), 1)
  assert_true(paragraph_children[0].kind() is Comment)
  assert_node_origin(paragraph_children[0], 11, 1, 12)
  let doc = @html_parser.parse(
    "<!doctype html><p>x</p>",
    track_node_locations=true,
  )
  let doc_children = doc.root.children()
  assert_true(doc_children[0].kind() is Doctype)
  assert_node_origin(doc_children[0], 0, 1, 1)
}

///|
test "parse_bytes forwards node origin tracking" {
  let doc = @html_parser.parse_bytes(b"<p>x</p>", track_node_locations=true)
  guard doc.query_one("p") is Some(paragraph) else {
    fail("expected parsed paragraph")
  }
  assert_node_origin(paragraph, 0, 1, 1)
  let children = paragraph.children()
  assert_eq(children.length(), 1)
  assert_node_origin(children[0], 3, 1, 4)
}

///|
test "parser tracks origins for end-tag recovery elements" {
  let before_html = @html_parser.parse("</br>", track_node_locations=true)
  guard before_html.query_one("br") is Some(before_br) else {
    fail("expected before-html br")
  }
  assert_node_origin(before_br, 0, 1, 1)
  let paragraph = @html_parser.parse_fragment(
    "<p>one</br>two",
    track_node_locations=true,
  )
  guard paragraph.query_one("br") is Some(br) else { fail("expected br") }
  assert_node_origin(br, 6, 1, 7)
  let stray_p = @html_parser.parse_fragment(
    "<div></p>after</div>",
    track_node_locations=true,
  )
  guard stray_p.query_one("p") is Some(p) else { fail("expected recovered p") }
  assert_node_origin(p, 5, 1, 6)
}
