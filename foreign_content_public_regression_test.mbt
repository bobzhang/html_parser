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

///|
test "parser adjusts long tail SVG names attributes and font breakouts" {
  let svg = @html_parser.parse_fragment(
    "<svg><altglyphdef><altglyphitem><femorphology basefrequency='x' gradientunits='u' xlink:arcrole='r'></femorphology><glyphref></glyphref><textpath></textpath></altglyphitem></altglyphdef></svg>",
    collect_errors=true,
  )
  assert_eq(
    svg.to_html(pretty=false),
    "<svg><altGlyphDef><altGlyphItem><feMorphology baseFrequency=\"x\" gradientUnits=\"u\" xlink:arcrole=\"r\"></feMorphology><glyphRef></glyphRef><textPath></textPath></altGlyphItem></altGlyphDef></svg>",
  )
  assert_eq(svg.errors.length(), 0)
  let remaining = @html_parser.parse_fragment(
    "<svg><animatecolor baseprofile='tiny'></animatecolor><feoffset kernelmatrix='k' xlink:href='#f'></feoffset></svg>",
    collect_errors=true,
  )
  assert_eq(
    remaining.to_html(pretty=false),
    "<svg><animateColor baseProfile=\"tiny\"></animateColor><feOffset kernelMatrix=\"k\" xlink:href=\"#f\"></feOffset></svg>",
  )
  assert_eq(remaining.errors.length(), 0)
  let motion = @html_parser.parse_fragment(
    "<svg><animatemotion calcmode='paced'></animatemotion><fepointlight kernelunitlength='1 1' xlink:role='r'></fepointlight></svg>",
    collect_errors=true,
  )
  assert_eq(
    motion.to_html(pretty=false),
    "<svg><animateMotion calcMode=\"paced\"></animateMotion><fePointLight kernelUnitLength=\"1 1\" xlink:role=\"r\"></fePointLight></svg>",
  )
  assert_eq(motion.errors.length(), 0)
  let transform = @html_parser.parse_fragment(
    "<svg><animatetransform clippathunits='userSpaceOnUse' keypoints='0;1' xlink:show='new'></animatetransform><fespecularlighting></fespecularlighting></svg>",
    collect_errors=true,
  )
  assert_eq(
    transform.to_html(pretty=false),
    "<svg><animateTransform clipPathUnits=\"userSpaceOnUse\" keyPoints=\"0;1\" xlink:show=\"new\"></animateTransform><feSpecularLighting></feSpecularLighting></svg>",
  )
  assert_eq(transform.errors.length(), 0)
  let face = @html_parser.parse_fragment(
    "<svg><font face='serif'>text</font></svg>",
    collect_errors=true,
  )
  assert_eq(
    face.to_html(pretty=false),
    "<svg></svg><font face=\"serif\">text</font>",
  )
  assert_eq(face.errors.length(), 2)
  assert_eq(face.errors[0].code, "unexpected-html-element-in-foreign-content")
  assert_eq(face.errors[1].code, "unexpected-end-tag")
  let size = @html_parser.parse_fragment(
    "<svg><font size='3'>text</font></svg>",
    collect_errors=true,
  )
  assert_eq(
    size.to_html(pretty=false),
    "<svg></svg><font size=\"3\">text</font>",
  )
  assert_eq(size.errors.length(), 2)
  assert_eq(size.errors[0].code, "unexpected-html-element-in-foreign-content")
  assert_eq(size.errors[1].code, "unexpected-end-tag")
}

///|
test "parser tracks origins for nested foreign content starts" {
  let svg = @html_parser.parse_fragment(
    "<svg><lineargradient>\n  <stop/></lineargradient><feimage></feimage></svg>",
    track_node_locations=true,
  )
  guard svg.query_one("svg") is Some(svg_node) else { fail("expected svg") }
  assert_node_origin(svg_node, 0, 1, 1)
  let svg_children = svg_node.children()
  assert_eq(svg_children.length(), 2)
  assert_node_origin(svg_children[0], 5, 1, 6)
  let gradient_children = svg_children[0].children()
  assert_eq(gradient_children.length(), 2)
  assert_eq(gradient_children[1].name(), "stop")
  assert_node_origin(gradient_children[1], 24, 2, 3)
  assert_node_origin(svg_children[1], 48, 2, 27)
  let math = @html_parser.parse_fragment(
    "<math><mi definitionurl='x'>y</mi><annotation-xml encoding='text/html'><section>x</section></annotation-xml></math>",
    track_node_locations=true,
  )
  guard math.query_one("mi") is Some(mi) else { fail("expected mi") }
  assert_node_origin(mi, 6, 1, 7)
  guard math.query_one("annotation-xml") is Some(annotation) else {
    fail("expected annotation-xml")
  }
  assert_node_origin(annotation, 34, 1, 35)
}
