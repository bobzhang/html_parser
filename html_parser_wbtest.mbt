// Whitebox tests run within the package scope.
// Use them to validate internal helpers or invariants.
// Keep them focused; public behavior belongs in `_test.mbt`.

///|
test "dom insert_child_before moves appends and rejects cycles" {
  let parent = element("div")
  let first = element("p", children=[text("first")])
  let second = element("span", children=[text("second")])
  parent.append_child(first)
  parent.append_child(second)
  let inserted = element("em", children=[text("mid")])
  parent.insert_child_before(inserted, second)
  assert_eq(
    parent.to_html(pretty=false),
    "<div><p>first</p><em>mid</em><span>second</span></div>",
  )
  let fallback = element("strong", children=[text("end")])
  parent.insert_child_before(fallback, element("missing"))
  assert_eq(
    parent.to_html(pretty=false),
    "<div><p>first</p><em>mid</em><span>second</span><strong>end</strong></div>",
  )
  let other = element("section")
  other.append_child(inserted)
  assert_eq(
    parent.to_html(pretty=false),
    "<div><p>first</p><span>second</span><strong>end</strong></div>",
  )
  assert_eq(other.to_html(pretty=false), "<section><em>mid</em></section>")
  inserted.append_child(other)
  assert_eq(inserted.to_html(pretty=false), "<em>mid</em>")
  let non_container = comment("x")
  non_container.insert_child_before(text("ignored"), first)
  assert_eq(non_container.children().length(), 0)
  non_container.remove_child(first)
  assert_eq(first.to_html(pretty=false), "<p>first</p>")
}

///|
test "query deduplicates shared nodes and ignores traversal cycles" {
  let shared_root = element("div")
  let shared = element("span", attrs={ "class": Some("target") })
  shared_root.append_child(shared)
  shared_root.children.push(shared)
  assert_eq(shared_root.query("span").length(), 1)
  assert_eq(shared_root.query(".target").length(), 1)
  assert_eq(shared_root.query("*").length(), 1)
  let cyclic_root = element("div")
  let child = element("span", attrs={ "class": Some("cycle") })
  cyclic_root.append_child(child)
  child.children.push(cyclic_root)
  cyclic_root.parent = Some(child)
  assert_eq(cyclic_root.query("span").length(), 1)
  assert_eq(cyclic_root.query(".cycle").length(), 1)
  assert_eq(cyclic_root.query("*").length(), 1)
  assert_true(matches(child, "div span"))
  assert_eq(matches(child, "em span"), false)
  assert_eq(cyclic_root.query("div span").length(), 1)
  assert_eq(cyclic_root.query("em span").length(), 0)
}

///|
fn assert_script_scan(
  value : StringView,
  expected : String,
  end_start : Int?,
) -> Unit raise {
  let scan = scan_script_text(value, 0)
  assert_eq(scan.data, expected)
  match end_start {
    Some(expected_end) => {
      guard scan.end_start is Some(actual_end) else {
        fail("expected script end tag")
      }
      assert_eq(actual_end, expected_end)
    }
    None => assert_true(scan.end_start is None)
  }
  assert_eq(scan.errors.length(), 0)
}

///|
test "script text scanner covers escaped and double escaped edge states" {
  assert_script_scan("<!---x</script>", "<!---x", Some(6))
  assert_script_scan("<!---<x</script>", "<!---<x", Some(7))
  assert_script_scan("<!----x</script>", "<!----x", Some(7))
  assert_script_scan("<!-----x</script>", "<!-----x", Some(8))
  assert_script_scan("<!----<x</script>", "<!----<<x", Some(8))
  assert_script_scan("<!--</not</script>", "<!--</not", Some(9))
  assert_script_scan("<!--<!</script>", "<!--<!", Some(6))
  assert_script_scan("abc</script x", "abc", Some(3))
  assert_script_scan(
    "<!--<script>-x</script>z</script>",
    "<!--<script>-x</script>z",
    Some(24),
  )
  assert_script_scan(
    "<!--<script>-<!x</script>tail</script>",
    "<!--<script>-<!x</script>tail",
    Some(29),
  )
  assert_script_scan("<!--<script>--></script>", "<!--<script>-->", Some(15))
  assert_script_scan(
    "<!--<script>---x</script>tail</script>",
    "<!--<script>---x</script>tail",
    Some(29),
  )
  assert_script_scan(
    "<!--<script>--<x</script>tail</script>",
    "<!--<script>--<x",
    Some(16),
  )
  assert_script_scan(
    "<!--<script>--x</script>tail</script>",
    "<!--<script>--x</script>tail",
    Some(28),
  )
  assert_script_scan(
    "<!--<script><!x</script>tail</script>",
    "<!--<script><!x</script>tail",
    Some(28),
  )
  assert_script_scan(
    "<!--<script></not</script>z</script>",
    "<!--<script></not</script>z",
    Some(27),
  )
  assert_script_scan(
    "<!--<script></style x</script>tail</script>",
    "<!--<script></style x</script>tail",
    Some(34),
  )
  assert_script_scan(
    "<!--<script><x</script>z</script>",
    "<!--<script><x",
    Some(14),
  )
  assert_script_scan(
    "<!--<script x</script>tail</script>",
    "<!--<script x</script>tail",
    Some(26),
  )
  assert_script_scan(
    "<!--<script\tx</script>tail</script>",
    "<!--<script\tx</script>tail",
    Some(26),
  )
  assert_script_scan(
    "<!--<script\u{000C}>x</script>tail</script>",
    "<!--<script\u{000C}>x</script>tail",
    Some(27),
  )
  assert_script_scan(
    "<!--<script/>x</script>tail</script>",
    "<!--<script/>x</script>tail",
    Some(27),
  )
  assert_script_scan(
    "<!--<scriptx>x</script>tail</script>",
    "<!--<scriptx>x",
    Some(14),
  )
  assert_script_scan("<!--<script><", "<!--<script><", None)
}

///|
fn assert_svg_tag_adjustment(
  input : StringView,
  expected : String,
) -> Unit raise {
  assert_eq(adjusted_svg_tag_name(input), expected)
}

///|
fn assert_svg_attr_adjustment(
  input : StringView,
  expected : String,
) -> Unit raise {
  assert_eq(adjusted_svg_attribute_name(input), expected)
}

///|
fn assert_foreign_attr_adjustment(
  input : StringView,
  expected : String,
) -> Unit raise {
  assert_eq(adjusted_foreign_attribute_name(input), expected)
}

///|
test "foreign adjustment helper tables match spec names" {
  assert_svg_tag_adjustment("clippath", "clipPath")
  assert_svg_tag_adjustment("feblend", "feBlend")
  assert_svg_tag_adjustment("fecolormatrix", "feColorMatrix")
  assert_svg_tag_adjustment("fecomponenttransfer", "feComponentTransfer")
  assert_svg_tag_adjustment("fecomposite", "feComposite")
  assert_svg_tag_adjustment("feconvolvematrix", "feConvolveMatrix")
  assert_svg_tag_adjustment("fediffuselighting", "feDiffuseLighting")
  assert_svg_tag_adjustment("fedisplacementmap", "feDisplacementMap")
  assert_svg_tag_adjustment("fedistantlight", "feDistantLight")
  assert_svg_tag_adjustment("feflood", "feFlood")
  assert_svg_tag_adjustment("fefunca", "feFuncA")
  assert_svg_tag_adjustment("fefuncb", "feFuncB")
  assert_svg_tag_adjustment("fefuncg", "feFuncG")
  assert_svg_tag_adjustment("fefuncr", "feFuncR")
  assert_svg_tag_adjustment("fegaussianblur", "feGaussianBlur")
  assert_svg_tag_adjustment("fespotlight", "feSpotLight")
  assert_svg_tag_adjustment("fetile", "feTile")
  assert_svg_tag_adjustment("feturbulence", "feTurbulence")
  assert_svg_tag_adjustment("unknown", "unknown")
  assert_svg_attr_adjustment("diffuseconstant", "diffuseConstant")
  assert_svg_attr_adjustment("edgemode", "edgeMode")
  assert_svg_attr_adjustment("filterunits", "filterUnits")
  assert_svg_attr_adjustment("glyphref", "glyphRef")
  assert_svg_attr_adjustment("keysplines", "keySplines")
  assert_svg_attr_adjustment("keytimes", "keyTimes")
  assert_svg_attr_adjustment("lengthadjust", "lengthAdjust")
  assert_svg_attr_adjustment("limitingconeangle", "limitingConeAngle")
  assert_svg_attr_adjustment("markerheight", "markerHeight")
  assert_svg_attr_adjustment("markerunits", "markerUnits")
  assert_svg_attr_adjustment("markerwidth", "markerWidth")
  assert_svg_attr_adjustment("maskcontentunits", "maskContentUnits")
  assert_svg_attr_adjustment("maskunits", "maskUnits")
  assert_svg_attr_adjustment("numoctaves", "numOctaves")
  assert_svg_attr_adjustment("pathlength", "pathLength")
  assert_svg_attr_adjustment("patterncontentunits", "patternContentUnits")
  assert_svg_attr_adjustment("patterntransform", "patternTransform")
  assert_svg_attr_adjustment("patternunits", "patternUnits")
  assert_svg_attr_adjustment("pointsatx", "pointsAtX")
  assert_svg_attr_adjustment("pointsaty", "pointsAtY")
  assert_svg_attr_adjustment("pointsatz", "pointsAtZ")
  assert_svg_attr_adjustment("preservealpha", "preserveAlpha")
  assert_svg_attr_adjustment("preserveaspectratio", "preserveAspectRatio")
  assert_svg_attr_adjustment("primitiveunits", "primitiveUnits")
  assert_svg_attr_adjustment("refx", "refX")
  assert_svg_attr_adjustment("refy", "refY")
  assert_svg_attr_adjustment("repeatcount", "repeatCount")
  assert_svg_attr_adjustment("repeatdur", "repeatDur")
  assert_svg_attr_adjustment("requiredextensions", "requiredExtensions")
  assert_svg_attr_adjustment("requiredfeatures", "requiredFeatures")
  assert_svg_attr_adjustment("specularconstant", "specularConstant")
  assert_svg_attr_adjustment("specularexponent", "specularExponent")
  assert_svg_attr_adjustment("spreadmethod", "spreadMethod")
  assert_svg_attr_adjustment("startoffset", "startOffset")
  assert_svg_attr_adjustment("stddeviation", "stdDeviation")
  assert_svg_attr_adjustment("stitchtiles", "stitchTiles")
  assert_svg_attr_adjustment("surfacescale", "surfaceScale")
  assert_svg_attr_adjustment("systemlanguage", "systemLanguage")
  assert_svg_attr_adjustment("tablevalues", "tableValues")
  assert_svg_attr_adjustment("targetx", "targetX")
  assert_svg_attr_adjustment("targety", "targetY")
  assert_svg_attr_adjustment("textlength", "textLength")
  assert_svg_attr_adjustment("viewbox", "viewBox")
  assert_svg_attr_adjustment("viewtarget", "viewTarget")
  assert_svg_attr_adjustment("xchannelselector", "xChannelSelector")
  assert_svg_attr_adjustment("ychannelselector", "yChannelSelector")
  assert_svg_attr_adjustment("zoomandpan", "zoomAndPan")
  assert_svg_attr_adjustment("plain", "plain")
  assert_foreign_attr_adjustment("xlink:title", "xlink:title")
  assert_foreign_attr_adjustment("xlink:type", "xlink:type")
  assert_foreign_attr_adjustment("xml:lang", "xml:lang")
  assert_foreign_attr_adjustment("xml:space", "xml:space")
  assert_foreign_attr_adjustment("xmlns", "xmlns")
  assert_foreign_attr_adjustment("xmlns:xlink", "xmlns:xlink")
  assert_foreign_attr_adjustment("plain", "plain")
  let custom = prepare_foreign_attrs("custom", {
    "plain": Some("p"),
    "xlink:title": Some("t"),
  })
  guard custom["plain"] is Some("p") else {
    fail("expected custom namespace attr to stay unchanged")
  }
  guard custom["xlink:title"] is Some("t") else {
    fail("expected foreign attr to be preserved")
  }
  let parser = Parser::new(
    "",
    fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  parser.stack.push(element("svg", ns="svg"))
  assert_eq(parser.start_tag_namespace("g"), "svg")
}

///|
fn assert_markdown_line_start_escape(
  value : StringView,
  replacement : String,
  consumed : Int,
) -> Unit raise {
  guard markdown_escape_line_start(value) is Some((actual, actual_consumed)) else {
    fail("expected markdown line-start escape")
  }
  assert_eq(actual, replacement)
  assert_eq(actual_consumed, consumed)
}

///|
test "markdown helper edge cases match reference" {
  assert_true(markdown_escape_line_start("") is None)
  assert_markdown_line_start_escape("# heading", "\\#", 1)
  assert_true(markdown_escape_line_start("#heading") is None)
  assert_markdown_line_start_escape("> quote", "\\>", 1)
  assert_markdown_line_start_escape("- item", "\\-", 1)
  assert_true(markdown_escape_line_start("-x") is None)
  assert_markdown_line_start_escape("+ item", "\\+", 1)
  assert_true(markdown_escape_line_start("+item") is None)
  assert_markdown_line_start_escape("1. item", "1\\.", 2)
  assert_markdown_line_start_escape("2) item", "2\\)", 2)
  assert_markdown_line_start_escape("12. item", "12\\.", 3)
  assert_markdown_line_start_escape("~~~", "\\~", 1)
  assert_true(markdown_escape_line_start("~~") is None)
  assert_markdown_line_start_escape("```", "\\`", 1)
  assert_true(markdown_escape_line_start("``") is None)
  assert_markdown_line_start_escape("---", "\\-", 1)
  assert_markdown_line_start_escape("===", "\\=", 1)
  assert_true(markdown_escape_line_start("=x") is None)
  assert_true(markdown_escape_line_start("plain text") is None)
  assert_eq(
    markdown_thematic_or_setext_line("   ", '-', minimum_markers=3),
    false,
  )
  assert_true(markdown_thematic_or_setext_line("- - -", '-', minimum_markers=3))
  assert_eq(
    markdown_thematic_or_setext_line("- - x", '-', minimum_markers=3),
    false,
  )
  assert_eq(markdown_link_destination(""), "")
  assert_eq(markdown_link_destination("   "), "")
  assert_eq(markdown_link_destination("https://e.com/x"), "https://e.com/x")
  assert_eq(
    markdown_link_destination("https://e.com/a b"),
    "<https://e.com/a%20b>",
  )
  assert_eq(
    markdown_collect_text(
      element("code", children=[comment("skip"), text("x"), doctype()]),
    ),
    "x",
  )
  let builder = MarkdownBuilder::new()
  builder.raw("a\n\n\n")
  assert_eq(builder.newline_count, 2)
  assert_eq(builder.pending_space, false)
  assert_eq(builder.finish(), "a")
}
