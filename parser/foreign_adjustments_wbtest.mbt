// Whitebox coverage for parser foreign-name adjustment tables.

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
    @dom.fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  parser.stack.push(@dom.element("svg", ns="svg"))
  assert_eq(parser.start_tag_namespace("g"), "svg")
}
