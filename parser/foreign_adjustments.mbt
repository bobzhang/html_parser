///|
let svg_tag_names : ReadOnlyArray[String] = [
  "altGlyph", "altGlyphDef", "altGlyphItem", "animateColor", "animateMotion", "animateTransform",
  "clipPath", "feBlend", "feColorMatrix", "feComponentTransfer", "feComposite", "feConvolveMatrix",
  "feDiffuseLighting", "feDisplacementMap", "feDistantLight", "feFlood", "feFuncA",
  "feFuncB", "feFuncG", "feFuncR", "feGaussianBlur", "feImage", "feMerge", "feMergeNode",
  "feMorphology", "feOffset", "fePointLight", "feSpecularLighting", "feSpotLight",
  "feTile", "feTurbulence", "foreignObject", "glyphRef", "linearGradient", "radialGradient",
  "textPath",
]

///|
fn adjusted_svg_tag_name(name : StringView) -> String {
  adjusted_svg_name(name, svg_tag_names)
}

///|
let svg_attribute_names : ReadOnlyArray[String] = [
  "attributeName", "attributeType", "baseFrequency", "baseProfile", "calcMode", "clipPathUnits",
  "diffuseConstant", "edgeMode", "filterUnits", "glyphRef", "gradientTransform",
  "gradientUnits", "kernelMatrix", "kernelUnitLength", "keyPoints", "keySplines",
  "keyTimes", "lengthAdjust", "limitingConeAngle", "markerHeight", "markerUnits",
  "markerWidth", "maskContentUnits", "maskUnits", "numOctaves", "pathLength", "patternContentUnits",
  "patternTransform", "patternUnits", "pointsAtX", "pointsAtY", "pointsAtZ", "preserveAlpha",
  "preserveAspectRatio", "primitiveUnits", "refX", "refY", "repeatCount", "repeatDur",
  "requiredExtensions", "requiredFeatures", "specularConstant", "specularExponent",
  "spreadMethod", "startOffset", "stdDeviation", "stitchTiles", "surfaceScale", "systemLanguage",
  "tableValues", "targetX", "targetY", "textLength", "viewBox", "viewTarget", "xChannelSelector",
  "yChannelSelector", "zoomAndPan",
]

///|
fn adjusted_svg_attribute_name(name : StringView) -> String {
  adjusted_svg_name(name, svg_attribute_names)
}

///|
// The table contains canonical SVG spellings, sorted by their lowercase keys.
// Only lowercase input keys are adjusted; mixed-case/unknown input is preserved.
fn adjusted_svg_name(
  name : StringView,
  canonical : ReadOnlyArray[String],
) -> String {
  if name.any(ch => ch.is_ascii_uppercase()) {
    return name.to_owned()
  }
  let mut low = 0
  let mut high = canonical.length()
  while low < high {
    let mid = low + (high - low) / 2
    let order = name.compare_ignore_ascii_case(canonical[mid][:])
    if order < 0 {
      high = mid
    } else if order > 0 {
      low = mid + 1
    } else {
      return canonical[mid]
    }
  }
  name.to_owned()
}

///|
fn adjusted_mathml_attribute_name(name : StringView) -> String {
  match name {
    "definitionurl" => "definitionURL"
    _ => name.to_owned()
  }
}

///|
fn adjusted_foreign_attribute_name(name : StringView) -> String {
  name.to_owned()
}

///|
fn adjusted_start_tag_name_for_namespace(
  ns : StringView,
  name : StringView,
) -> String {
  if ns == "svg" {
    adjusted_svg_tag_name(name)
  } else {
    name.to_owned()
  }
}

///|
fn prepare_foreign_attrs(
  ns : StringView,
  attrs : Map[String, String?],
) -> Map[String, String?] {
  let adjusted : Map[String, String?] = Map([])
  for name, value in attrs {
    let namespace_adjusted = if ns == "math" {
      adjusted_mathml_attribute_name(name)
    } else if ns == "svg" {
      adjusted_svg_attribute_name(name)
    } else {
      name
    }
    let foreign_adjusted = adjusted_foreign_attribute_name(namespace_adjusted)
    adjusted[foreign_adjusted] = value
  }
  adjusted
}
