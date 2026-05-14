///|
test "parser adjusts SVG edge names and foreign attributes" {
  let svg = @html_parser.parse_fragment(
    "<svg><altglyph attributetype='xml' xlink:actuate='onLoad'></altglyph><femerge><femergenode></femergenode></femerge><radialgradient gradienttransform='r'></radialgradient></svg>",
    collect_errors=true,
  )
  assert_eq(
    svg.to_html(pretty=false),
    "<svg><altGlyph attributeType=\"xml\" xlink:actuate=\"onLoad\"></altGlyph><feMerge><feMergeNode></feMergeNode></feMerge><radialGradient gradientTransform=\"r\"></radialGradient></svg>",
  )
  assert_eq(svg.errors.length(), 0)
  guard svg.query_one("svg") is Some(svg_node) else { fail("expected svg") }
  let svg_children = svg_node.children()
  assert_eq(svg_children.length(), 3)
  assert_eq(svg_children[0].name(), "altGlyph")
  let alt_attrs = svg_children[0].attrs()
  guard alt_attrs["attributeType"] is Some("xml") else {
    fail("expected adjusted attributeType")
  }
  guard alt_attrs["xlink:actuate"] is Some("onLoad") else {
    fail("expected preserved xlink:actuate")
  }
  assert_eq(svg_children[1].name(), "feMerge")
  let merge_children = svg_children[1].children()
  assert_eq(merge_children.length(), 1)
  assert_eq(merge_children[0].name(), "feMergeNode")
  assert_eq(svg_children[2].name(), "radialGradient")
  let radial_attrs = svg_children[2].attrs()
  guard radial_attrs["gradientTransform"] is Some("r") else {
    fail("expected adjusted gradientTransform")
  }
}
