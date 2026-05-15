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
