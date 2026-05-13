///|
fn is_foreign_namespace(ns : StringView) -> Bool {
  ns == "svg" || ns == "math"
}

///|
fn node_attribute_value_ignore_case(
  node : @dom.Node,
  name : StringView,
) -> String? {
  let wanted = @syn.lower_ascii(name)
  for attr_name, attr_value in node.attrs {
    if @syn.lower_ascii(attr_name) == wanted {
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
fn node_is_html_integration_point(node : @dom.Node) -> Bool {
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
fn node_is_mathml_text_integration_point(node : @dom.Node) -> Bool {
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
fn Parser::node_is_foreign_fragment_context(
  self : Parser,
  node : @dom.Node,
) -> Bool {
  match self.fragment_context_foreign {
    Some(context) => physical_equal(node, context)
    None => false
  }
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
  if self.node_is_foreign_fragment_context(current) {
    return "html"
  }
  match current.ns {
    Some(ns) if is_foreign_namespace(ns) => ns
    _ => "html"
  }
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
fn Parser::current_node_is_foreign_namespace(self : Parser) -> Bool {
  match self.current_node().ns {
    Some(ns) => is_foreign_namespace(ns)
    None => false
  }
}

///|
fn node_is_html_namespace(node : @dom.Node) -> Bool {
  !(node.ns is Some(ns) && is_foreign_namespace(ns))
}

///|
fn names_match_end_tag(node : @dom.Node, name : StringView) -> Bool {
  node.name[:] == name ||
  (
    node.kind == Element &&
    !(node.ns is Some("html")) &&
    @syn.lower_ascii(node.name) == name.to_owned()
  )
}
