///|
fn is_foreign_namespace(ns : StringView) -> Bool {
  ns == "svg" || ns == "math"
}

///|
fn node_attribute_value_ignore_case(node : Node, name : StringView) -> String? {
  let wanted = lower_ascii(name)
  for attr_name, attr_value in node.attrs {
    if lower_ascii(attr_name[:]) == wanted {
      return Some(
        match attr_value {
          Some(value) => value
          None => ""
        },
      )
    }
  }
  None
}

///|
fn node_is_html_integration_point(node : Node) -> Bool {
  match node.ns {
    Some("math") =>
      if node.name == "annotation-xml" {
        match node_attribute_value_ignore_case(node, "encoding") {
          Some(value) => {
            let lowered = value.to_lower()
            lowered == "text/html" || lowered == "application/xhtml+xml"
          }
          None => false
        }
      } else {
        false
      }
    Some("svg") =>
      node.name == "foreignObject" ||
      node.name == "desc" ||
      node.name == "title"
    _ => false
  }
}

///|
fn node_is_mathml_text_integration_point(node : Node) -> Bool {
  node.ns is Some("math") &&
  (
    node.name == "mi" ||
    node.name == "mo" ||
    node.name == "mn" ||
    node.name == "ms" ||
    node.name == "mtext"
  )
}

///|
fn Parser::start_tag_namespace(self : Parser, name : StringView) -> String {
  if name == "svg" {
    return "svg"
  }
  if name == "math" {
    return "math"
  }
  let current = self.current_node()
  if node_is_html_integration_point(current) {
    return "html"
  }
  if node_is_mathml_text_integration_point(current) &&
    name != "mglyph" &&
    name != "malignmark" {
    return "html"
  }
  match current.ns {
    Some(ns) if is_foreign_namespace(ns) => ns
    _ => "html"
  }
}

///|
fn adjusted_svg_tag_name(name : StringView) -> String {
  match name {
    "altglyph" => "altGlyph"
    "altglyphdef" => "altGlyphDef"
    "altglyphitem" => "altGlyphItem"
    "animatecolor" => "animateColor"
    "animatemotion" => "animateMotion"
    "animatetransform" => "animateTransform"
    "clippath" => "clipPath"
    "feblend" => "feBlend"
    "fecolormatrix" => "feColorMatrix"
    "fecomponenttransfer" => "feComponentTransfer"
    "fecomposite" => "feComposite"
    "feconvolvematrix" => "feConvolveMatrix"
    "fediffuselighting" => "feDiffuseLighting"
    "fedisplacementmap" => "feDisplacementMap"
    "fedistantlight" => "feDistantLight"
    "feflood" => "feFlood"
    "fefunca" => "feFuncA"
    "fefuncb" => "feFuncB"
    "fefuncg" => "feFuncG"
    "fefuncr" => "feFuncR"
    "fegaussianblur" => "feGaussianBlur"
    "feimage" => "feImage"
    "femerge" => "feMerge"
    "femergenode" => "feMergeNode"
    "femorphology" => "feMorphology"
    "feoffset" => "feOffset"
    "fepointlight" => "fePointLight"
    "fespecularlighting" => "feSpecularLighting"
    "fespotlight" => "feSpotLight"
    "fetile" => "feTile"
    "feturbulence" => "feTurbulence"
    "foreignobject" => "foreignObject"
    "glyphref" => "glyphRef"
    "lineargradient" => "linearGradient"
    "radialgradient" => "radialGradient"
    "textpath" => "textPath"
    _ => name.to_owned()
  }
}

///|
fn adjusted_svg_attribute_name(name : StringView) -> String {
  match name {
    "attributename" => "attributeName"
    "attributetype" => "attributeType"
    "basefrequency" => "baseFrequency"
    "baseprofile" => "baseProfile"
    "calcmode" => "calcMode"
    "clippathunits" => "clipPathUnits"
    "diffuseconstant" => "diffuseConstant"
    "edgemode" => "edgeMode"
    "filterunits" => "filterUnits"
    "glyphref" => "glyphRef"
    "gradienttransform" => "gradientTransform"
    "gradientunits" => "gradientUnits"
    "kernelmatrix" => "kernelMatrix"
    "kernelunitlength" => "kernelUnitLength"
    "keypoints" => "keyPoints"
    "keysplines" => "keySplines"
    "keytimes" => "keyTimes"
    "lengthadjust" => "lengthAdjust"
    "limitingconeangle" => "limitingConeAngle"
    "markerheight" => "markerHeight"
    "markerunits" => "markerUnits"
    "markerwidth" => "markerWidth"
    "maskcontentunits" => "maskContentUnits"
    "maskunits" => "maskUnits"
    "numoctaves" => "numOctaves"
    "pathlength" => "pathLength"
    "patterncontentunits" => "patternContentUnits"
    "patterntransform" => "patternTransform"
    "patternunits" => "patternUnits"
    "pointsatx" => "pointsAtX"
    "pointsaty" => "pointsAtY"
    "pointsatz" => "pointsAtZ"
    "preservealpha" => "preserveAlpha"
    "preserveaspectratio" => "preserveAspectRatio"
    "primitiveunits" => "primitiveUnits"
    "refx" => "refX"
    "refy" => "refY"
    "repeatcount" => "repeatCount"
    "repeatdur" => "repeatDur"
    "requiredextensions" => "requiredExtensions"
    "requiredfeatures" => "requiredFeatures"
    "specularconstant" => "specularConstant"
    "specularexponent" => "specularExponent"
    "spreadmethod" => "spreadMethod"
    "startoffset" => "startOffset"
    "stddeviation" => "stdDeviation"
    "stitchtiles" => "stitchTiles"
    "surfacescale" => "surfaceScale"
    "systemlanguage" => "systemLanguage"
    "tablevalues" => "tableValues"
    "targetx" => "targetX"
    "targety" => "targetY"
    "textlength" => "textLength"
    "viewbox" => "viewBox"
    "viewtarget" => "viewTarget"
    "xchannelselector" => "xChannelSelector"
    "ychannelselector" => "yChannelSelector"
    "zoomandpan" => "zoomAndPan"
    _ => name.to_owned()
  }
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
  match name {
    "xlink:actuate" => "xlink:actuate"
    "xlink:arcrole" => "xlink:arcrole"
    "xlink:href" => "xlink:href"
    "xlink:role" => "xlink:role"
    "xlink:show" => "xlink:show"
    "xlink:title" => "xlink:title"
    "xlink:type" => "xlink:type"
    "xml:lang" => "xml:lang"
    "xml:space" => "xml:space"
    "xmlns" => "xmlns"
    "xmlns:xlink" => "xmlns:xlink"
    _ => name.to_owned()
  }
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
  let adjusted : Map[String, String?] = {}
  for name, value in attrs {
    let namespace_adjusted = if ns == "math" {
      adjusted_mathml_attribute_name(name[:])
    } else if ns == "svg" {
      adjusted_svg_attribute_name(name[:])
    } else {
      name
    }
    let foreign_adjusted = adjusted_foreign_attribute_name(
      namespace_adjusted[:],
    )
    adjusted[foreign_adjusted] = value
  }
  adjusted
}

///|
fn foreign_breakout_start_name(name : StringView) -> Bool {
  match name {
    "b"
    | "big"
    | "blockquote"
    | "body"
    | "br"
    | "center"
    | "code"
    | "dd"
    | "div"
    | "dl"
    | "dt"
    | "em"
    | "embed"
    | "h1"
    | "h2"
    | "h3"
    | "h4"
    | "h5"
    | "h6"
    | "head"
    | "hr"
    | "i"
    | "img"
    | "li"
    | "listing"
    | "menu"
    | "meta"
    | "nobr"
    | "ol"
    | "p"
    | "pre"
    | "ruby"
    | "s"
    | "small"
    | "span"
    | "strong"
    | "strike"
    | "sub"
    | "sup"
    | "table"
    | "tt"
    | "u"
    | "ul"
    | "var" => true
    _ => false
  }
}

///|
fn foreign_font_has_breakout_attr(attrs : Map[String, String?]) -> Bool {
  attrs.contains("color") || attrs.contains("face") || attrs.contains("size")
}

///|
fn foreign_start_breaks_out(
  name : StringView,
  attrs : Map[String, String?],
) -> Bool {
  foreign_breakout_start_name(name) ||
  (name == "font" && foreign_font_has_breakout_attr(attrs))
}

///|
fn Parser::current_node_uses_foreign_content_for_start(
  self : Parser,
  name : StringView,
) -> Bool {
  let current = self.current_node()
  match current.ns {
    Some(ns) if is_foreign_namespace(ns) => {
      if node_is_html_integration_point(current) {
        return false
      }
      if node_is_mathml_text_integration_point(current) &&
        name != "mglyph" &&
        name != "malignmark" {
        return false
      }
      !(current.ns is Some("math") &&
      current.name == "annotation-xml" &&
      name == "svg")
    }
    _ => false
  }
}

///|
fn Parser::current_node_uses_foreign_content_for_text(self : Parser) -> Bool {
  let current = self.current_node()
  match current.ns {
    Some(ns) if is_foreign_namespace(ns) =>
      !node_is_html_integration_point(current) &&
      !node_is_mathml_text_integration_point(current)
    _ => false
  }
}

///|
fn Parser::clean_foreign_content_text(
  self : Parser,
  raw : StringView,
  start : Int,
) -> String {
  let out = StringBuilder::new(size_hint=raw.length())
  let mut pos = 0
  while pos < raw.length() {
    match raw.get_char(pos) {
      Some('\u{0000}') => {
        self.error_at("unexpected-null-character", start + pos)
        self.error_at("invalid-codepoint-in-foreign-content", start + pos)
        out.write_char('\u{FFFD}')
        pos += 1
      }
      Some(ch) => {
        out.write_char(ch)
        pos += ch.utf16_len()
      }
      None => break
    }
  }
  out.to_string()
}

///|
fn Parser::pop_until_html_or_integration_point(self : Parser) -> Unit {
  while self.stack.length() > 1 {
    let current = self.current_node()
    match current.ns {
      Some(ns) if is_foreign_namespace(ns) => {
        if node_is_html_integration_point(current) {
          return
        }
        ignore(self.stack.pop())
      }
      _ => return
    }
  }
}

///|
fn node_is_html_namespace(node : Node) -> Bool {
  !(node.ns is Some(ns) && is_foreign_namespace(ns))
}

///|
fn Parser::handle_foreign_content_start_tag(
  self : Parser,
  name : String,
  attrs : Map[String, String?],
  self_closing : Bool,
  start : Int,
) -> Bool {
  if !self.current_node_uses_foreign_content_for_start(name) {
    return false
  }
  if foreign_start_breaks_out(name, attrs) {
    self.error_at("unexpected-html-element-in-foreign-content", start)
    self.pop_until_html_or_integration_point()
    return false
  }
  let current = self.current_node()
  let ns = match current.ns {
    Some(ns) => ns
    None => "html"
  }
  let adjusted_name = adjusted_start_tag_name_for_namespace(ns, name)
  let adjusted_attrs = prepare_foreign_attrs(ns, attrs)
  let node = element(adjusted_name, attrs=adjusted_attrs, ns~)
  self.current_node().append_child(node)
  if !self_closing {
    self.stack.push(node)
  }
  true
}

///|
fn Parser::handle_foreign_content_end_tag(
  self : Parser,
  name : String,
  start : Int,
) -> Bool {
  let current = self.current_node()
  match current.ns {
    Some(ns) if is_foreign_namespace(ns) => ()
    _ => return false
  }
  if name == "br" || name == "p" {
    self.error_at("unexpected-html-element-in-foreign-content", start)
    self.pop_until_html_or_integration_point()
    return false
  }
  let mut index = self.stack.length()
  let mut first = true
  while index > 0 {
    index -= 1
    let node = self.stack[index]
    if node.kind == Element && names_match_end_tag(node, name) {
      if node_is_html_namespace(node) {
        return false
      }
      while self.stack.length() > index {
        ignore(self.stack.pop())
      }
      return true
    }
    if first {
      self.error_at("unexpected-end-tag", start)
      first = false
    }
    if node_is_html_namespace(node) {
      return false
    }
  }
  true
}

///|
fn names_match_end_tag(node : Node, name : StringView) -> Bool {
  node.name[:] == name ||
  (
    node.kind == Element &&
    !(node.ns is Some("html")) &&
    lower_ascii(node.name[:]) == name.to_owned()
  )
}
