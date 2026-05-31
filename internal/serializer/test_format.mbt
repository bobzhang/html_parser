///|
/// Render a deterministic tree dump intended for conformance tests.
pub fn to_test_format(node : @dom.Node) -> String {
  let lines : Array[String] = []
  match node.kind {
    Document | Fragment =>
      for child in node.children {
        write_test_format(child, lines, 0)
      }
    _ => write_test_format(node, lines, 0)
  }
  lines.join("\n")
}

///|
fn test_format_line(indent : Int, content : StringView) -> String {
  "| " + " ".repeat(indent) + content.to_owned()
}

///|
fn test_format_qualified_name(node : @dom.Node) -> String {
  match node.ns {
    Some(ns) if ns != "html" => ns + " " + node.name
    _ => node.name
  }
}

///|
fn is_foreign_attribute_for_test_format(name : StringView) -> Bool {
  match @syn.lower_ascii(name) {
    "xlink:actuate"
    | "xlink:arcrole"
    | "xlink:href"
    | "xlink:role"
    | "xlink:show"
    | "xlink:title"
    | "xlink:type"
    | "xml:lang"
    | "xml:space"
    | "xmlns"
    | "xmlns:xlink" => true
    _ => false
  }
}

///|
fn replace_colons_for_test_format(name : StringView) -> String {
  let out = StringBuilder::new(size_hint=name.length())
  for ch in name {
    if ch == ':' {
      out.write_char(' ')
    } else {
      out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn test_format_attribute_name(node : @dom.Node, name : StringView) -> String {
  match node.ns {
    Some(ns) if ns != "html" && is_foreign_attribute_for_test_format(name) =>
      replace_colons_for_test_format(name)
    _ => name.to_owned()
  }
}

///|
fn test_format_string_less(left : StringView, right : StringView) -> Bool {
  let mut left_pos = 0
  let mut right_pos = 0
  while left_pos < left.length() && right_pos < right.length() {
    let left_ch = left.get_char(left_pos).unwrap()
    let right_ch = right.get_char(right_pos).unwrap()
    if left_ch < right_ch {
      return true
    }
    if left_ch > right_ch {
      return false
    }
    left_pos += left_ch.utf16_len()
    right_pos += right_ch.utf16_len()
  }
  left.length() < right.length()
}

///|
fn test_format_attr_less(
  left : (String, String),
  right : (String, String),
) -> Bool {
  let (left_name, left_value) = left
  let (right_name, right_value) = right
  if left_name != right_name {
    return test_format_string_less(left_name, right_name)
  }
  test_format_string_less(left_value, right_value)
}

///|
fn sort_test_format_attrs(attrs : Array[(String, String)]) -> Unit {
  for index in 1..<attrs.length() {
    let current = attrs[index]
    let mut cursor = index
    while cursor > 0 && test_format_attr_less(current, attrs[cursor - 1]) {
      attrs[cursor] = attrs[cursor - 1]
      cursor -= 1
    }
    attrs[cursor] = current
  }
}

///|
fn write_test_format_attributes(
  node : @dom.Node,
  out : Array[String],
  indent : Int,
) -> Unit {
  let attrs : Array[(String, String)] = []
  for name, value in node.attrs {
    let display_name = test_format_attribute_name(node, name)
    let value = match value {
      Some(value) => value
      None => ""
    }
    attrs.push((display_name, value))
  }
  sort_test_format_attrs(attrs)
  for attr in attrs {
    let (name, value) = attr
    out.push(test_format_line(indent + 2, name + "=\"" + value + "\""))
  }
}

///|
fn doctype_test_format(node : @dom.Node) -> String {
  let out = StringBuilder::new()
  out <+ "| <!DOCTYPE \{node.data}"
  if node.public_id is Some(_) || node.system_id is Some(_) {
    let public_id = match node.public_id {
      Some(value) => value
      None => ""
    }
    let system_id = match node.system_id {
      Some(value) => value
      None => ""
    }
    out <+ " \"\{public_id}\" \"\{system_id}\""
  }
  out.write_char('>')
  out.to_string()
}

///|
fn write_test_format(
  node : @dom.Node,
  out : Array[String],
  indent : Int,
) -> Unit {
  match node.kind {
    Document | Fragment =>
      out.push(test_format_line(indent, "<" + node.name + ">"))
    Element => {
      out.push(
        test_format_line(indent, "<" + test_format_qualified_name(node) + ">"),
      )
      write_test_format_attributes(node, out, indent)
    }
    Text =>
      if !node.sanitize_escape_only {
        out.push(test_format_line(indent, "\"" + node.data + "\""))
      }
    Comment => out.push(test_format_line(indent, "<!-- " + node.data + " -->"))
    Doctype => out.push(doctype_test_format(node))
  }
  for child in node.children {
    write_test_format(child, out, indent + 2)
  }
}
