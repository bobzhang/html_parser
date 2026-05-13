///|
fn is_void_element(name : StringView) -> Bool {
  @ser.is_void_element(name)
}

///|
fn write_percent_encoded_byte(out : StringBuilder, byte : Byte) -> Unit {
  @ser.write_percent_encoded_byte(out, byte)
}

///|
fn neutralize_rawtext_end_tag_sequences(
  value : StringView,
  tag_name : StringView,
) -> String {
  @ser.neutralize_rawtext_end_tag_sequences(value, tag_name)
}

///|
fn string_contains_char(value : StringView, needle : Char) -> Bool {
  @ser.string_contains_char(value, needle)
}

///|
fn serialize_start_tag_unchecked(node : Node, quote : Char) -> String {
  @ser.serialize_start_tag_unchecked(node, quote)
}

///|
/// Serialize a node as HTML.
pub fn to_html(
  node : Node,
  pretty? : Bool = true,
  indent_size? : Int = 2,
  context? : HtmlContext = Html,
  quote? : Char = '"',
) -> String raise HtmlError {
  @ser.to_html(node, pretty~, indent_size~, context~, quote~)
}

///|
/// Extract descendant text from a node.
pub fn to_text(
  node : Node,
  separator? : String = " ",
  strip? : Bool = true,
  separator_blocks_only? : Bool = false,
) -> String {
  @ser.to_text(node, separator~, strip~, separator_blocks_only~)
}

///|
fn is_html_whitespace_char(ch : Char) -> Bool {
  match ch {
    ' ' | '\t' | '\n' | '\r' | '\u{000C}' => true
    _ => false
  }
}

///|
fn string_view_contains(haystack : StringView, needle : StringView) -> Bool {
  if needle.is_empty() || needle.length() > haystack.length() {
    return false
  }
  let mut pos = 0
  while pos + needle.length() <= haystack.length() {
    match haystack.get_view(start=pos, end=pos + needle.length()) {
      Some(part) if part == needle => return true
      _ => ()
    }
    pos += haystack.get_char(pos).unwrap().utf16_len()
  }
  false
}

///|
fn attribute_value_by_name(node : Node, attr_name : StringView) -> String? {
  let wanted = lower_ascii(attr_name)
  for name, value in node.attrs {
    if lower_ascii(name) == wanted {
      return Some(
        match value {
          Some(text) => text
          None => ""
        },
      )
    }
  }
  None
}

///|
/// Return all descendants of `root` that match a CSS selector.
pub fn query(root : Node, selector : StringView) -> Array[Node] {
  @sel.query(root, selector)
}

///|
/// Return the first descendant of `root` that matches a CSS selector.
pub fn query_one(root : Node, selector : StringView) -> Node? {
  @sel.query_one(root, selector)
}

///|
/// Return whether `node` itself matches a CSS selector.
pub fn matches(node : Node, selector : StringView) -> Bool {
  @sel.matches(node, selector)
}

///|
/// Render a deterministic tree dump intended for conformance tests.
pub fn to_test_format(node : Node) -> String {
  @ser.to_test_format(node)
}
