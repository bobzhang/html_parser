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

///|
test "parser treats foreign integration points as HTML islands" {
  let svg = @html_parser.parse_fragment(
    "<svg><foreignobject><div><span>x</span></div></foreignobject></svg>",
    collect_errors=true,
  )
  assert_eq(
    svg.to_html(pretty=false),
    "<svg><foreignObject><div><span>x</span></div></foreignObject></svg>",
  )
  assert_eq(svg.errors.length(), 0)
  guard svg.query_one("div") is Some(div) else { fail("expected div") }
  assert_true(div.namespace_uri() is Some("html"))
  guard svg.query_one("span") is Some(span) else { fail("expected span") }
  assert_true(span.namespace_uri() is Some("html"))
  let math = @html_parser.parse_fragment(
    "<math><annotation-xml encoding='application/xhtml+xml'><section>x</section></annotation-xml></math>",
    collect_errors=true,
  )
  assert_eq(
    math.to_html(pretty=false),
    "<math><annotation-xml encoding=\"application/xhtml+xml\"><section>x</section></annotation-xml></math>",
  )
  assert_eq(math.errors.length(), 0)
  guard math.query_one("section") is Some(section) else {
    fail("expected integrated section")
  }
  assert_true(section.namespace_uri() is Some("html"))
}

///|
test "parser handles foreign content end tag recovery" {
  let ancestor_end = @html_parser.parse_fragment(
    "<svg><lineargradient></svg>",
    collect_errors=true,
  )
  assert_eq(
    ancestor_end.to_html(pretty=false),
    "<svg><linearGradient></linearGradient></svg>",
  )
  assert_eq(ancestor_end.errors.length(), 1)
  assert_eq(ancestor_end.errors[0].code, "unexpected-end-tag")
  let missing_foreign = @html_parser.parse_fragment(
    "<svg><g></path></svg>",
    collect_errors=true,
  )
  assert_eq(missing_foreign.to_html(pretty=false), "<svg><g></g></svg>")
  assert_eq(missing_foreign.errors.length(), 3)
  assert_eq(missing_foreign.errors[0].code, "unexpected-end-tag")
  assert_eq(missing_foreign.errors[1].code, "unexpected-end-tag")
  assert_eq(missing_foreign.errors[2].code, "unexpected-end-tag")
  let paragraph_breakout = @html_parser.parse_fragment(
    "<svg></p>",
    collect_errors=true,
  )
  assert_eq(paragraph_breakout.to_html(pretty=false), "<svg></svg><p></p>")
  assert_eq(paragraph_breakout.errors.length(), 2)
  assert_eq(
    paragraph_breakout.errors[0].code,
    "unexpected-html-element-in-foreign-content",
  )
  assert_eq(paragraph_breakout.errors[1].code, "unexpected-end-tag")
  let nested_svg_breakout = @html_parser.parse_fragment(
    "<div><svg><g><p>x</p></g></svg>after</div>",
    collect_errors=true,
  )
  assert_eq(
    nested_svg_breakout.to_html(pretty=false),
    "<div><svg><g></g></svg><p>x</p>after</div>",
  )
  assert_eq(nested_svg_breakout.errors.length(), 3)
  assert_eq(
    nested_svg_breakout.errors[0].code,
    "unexpected-html-element-in-foreign-content",
  )
  assert_eq(nested_svg_breakout.errors[1].code, "unexpected-end-tag")
  assert_eq(nested_svg_breakout.errors[2].code, "unexpected-end-tag")
  let math_text_integration = @html_parser.parse_fragment(
    "<math><mi><b>x</b></mi></math>",
    collect_errors=true,
  )
  assert_eq(
    math_text_integration.to_html(pretty=false),
    "<math><mi><b>x</b></mi></math>",
  )
  assert_eq(math_text_integration.errors.length(), 0)
  guard math_text_integration.query_one("b") is Some(bold) else {
    fail("expected html b")
  }
  assert_true(bold.namespace_uri() is Some("html"))
  let math_exception_children = @html_parser.parse_fragment(
    "<math><mi><mglyph></mglyph><malignmark></malignmark><b>x</b></mi></math>",
    collect_errors=true,
  )
  assert_eq(
    math_exception_children.to_html(pretty=false),
    "<math><mi><mglyph></mglyph><malignmark></malignmark><b>x</b></mi></math>",
  )
  assert_eq(math_exception_children.errors.length(), 0)
  guard math_exception_children.query_one("mglyph") is Some(mglyph) else {
    fail("expected mglyph")
  }
  assert_true(mglyph.namespace_uri() is Some("math"))
  guard math_exception_children.query_one("malignmark") is Some(malignmark) else {
    fail("expected malignmark")
  }
  assert_true(malignmark.namespace_uri() is Some("math"))
  guard math_exception_children.query_one("b") is Some(exception_bold) else {
    fail("expected html b after MathML exceptions")
  }
  assert_true(exception_bold.namespace_uri() is Some("html"))
  let integration_breakout = @html_parser.parse_fragment(
    "<svg><foreignObject><svg><p>x</p></svg></foreignObject></svg>",
    collect_errors=true,
  )
  assert_eq(
    integration_breakout.to_html(pretty=false),
    "<svg><foreignObject><svg></svg><p>x</p></foreignObject></svg>",
  )
  assert_eq(integration_breakout.errors.length(), 4)
  assert_eq(
    integration_breakout.errors[0].code,
    "unexpected-html-element-in-foreign-content",
  )
  assert_eq(integration_breakout.errors[1].code, "unexpected-end-tag")
  assert_eq(integration_breakout.errors[2].code, "unexpected-end-tag")
  assert_eq(integration_breakout.errors[3].code, "unexpected-end-tag")
  let ancestor_html_end = @html_parser.parse_fragment(
    "<div><svg></div><p>after</p>",
    collect_errors=true,
  )
  assert_eq(
    ancestor_html_end.to_html(pretty=false),
    "<div><svg></svg></div><p>after</p>",
  )
  assert_eq(ancestor_html_end.errors.length(), 2)
  assert_eq(ancestor_html_end.errors[0].code, "unexpected-end-tag")
  assert_eq(ancestor_html_end.errors[1].code, "end-tag-too-early")
}

///|
test "parser reports invalid codepoints in foreign text" {
  let svg = @html_parser.parse_fragment(
    "<svg>a\u{0000}\u{000C}</svg>",
    collect_errors=true,
  )
  assert_eq(svg.to_html(pretty=false), "<svg>a� </svg>")
  assert_eq(svg.errors.length(), 2)
  assert_eq(svg.errors[0].code, "unexpected-null-character")
  assert_eq(svg.errors[1].code, "invalid-codepoint-in-foreign-content")
  let math_text_integration = @html_parser.parse_fragment(
    "<math><mi>\u{0000}\u{000C}text</mi></math>",
    collect_errors=true,
  )
  assert_eq(
    math_text_integration.to_html(pretty=false),
    "<math><mi> text</mi></math>",
  )
  assert_eq(math_text_integration.errors.length(), 1)
  assert_eq(math_text_integration.errors[0].code, "unexpected-null-character")
}

///|
test "parser treats cdata sections as foreign text" {
  let svg = @html_parser.parse_fragment(
    "<svg><![CDATA[x<y]]><![CDATA[a&lt;b]]></svg>",
    collect_errors=true,
  )
  assert_eq(svg.to_html(pretty=false), "<svg>x&lt;ya&amp;lt;b</svg>")
  assert_eq(svg.errors.length(), 0)
  let nul_svg = @html_parser.parse_fragment(
    "<svg><![CDATA[a\u{0000}b]]></svg>",
    collect_errors=true,
  )
  assert_eq(nul_svg.to_html(pretty=false), "<svg>a�b</svg>")
  assert_eq(nul_svg.errors.length(), 2)
  assert_eq(nul_svg.errors[0].code, "unexpected-null-character")
  assert_eq(nul_svg.errors[1].code, "invalid-codepoint-in-foreign-content")
  let math_text_integration = @html_parser.parse_fragment(
    "<math><mi><![CDATA[a\u{0000}b]]></mi></math>",
    collect_errors=true,
  )
  assert_eq(
    math_text_integration.to_html(pretty=false),
    "<math><mi>ab</mi></math>",
  )
  assert_eq(math_text_integration.errors.length(), 1)
  assert_eq(math_text_integration.errors[0].code, "unexpected-null-character")
  let html = @html_parser.parse_fragment("<![CDATA[x]]>", collect_errors=true)
  assert_eq(html.to_html(pretty=false), "<!--[CDATA[x]]-->")
  assert_eq(html.errors.length(), 1)
  assert_eq(html.errors[0].code, "cdata-in-html-content")
}
