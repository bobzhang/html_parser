///|
/// A node in a generated well-nested HTML document.
///
/// Unlike `HtmlSource`, which is deliberate token soup, these documents respect
/// HTML's content models: no element appears somewhere the tree builder would
/// relocate or close it. Serializing such a document and reparsing it must
/// therefore reproduce the same tree, which makes them the right input for
/// round-trip properties.
enum HtmlNode {
  /// Character data, rendered with the character references it needs.
  DocText(String)
  /// A comment whose data cannot close the comment early.
  DocComment(String)
  /// A raw-text element (`script`, `style`) whose content is emitted verbatim.
  DocRawText(String, String)
  /// An element with an optional attribute and well-nested children.
  DocElement(String, String?, Array[HtmlNode])
}

///|
/// A generated well-nested HTML document.
struct HtmlDocument {
  nodes : Array[HtmlNode]
}

///|
/// Character runs used for generated text nodes.
///
/// The runs include every character the serializer has to escape so that a
/// round trip exercises escaping, plus non-ASCII text that must survive
/// UTF-16 handling unchanged.
let doc_text_runs : Array[String] = [
  "a", "hello world", "&", "<", ">", "\"", "'", "&amp;", "&lt;", "x&y", "a<b", " ",
  "\u{00A0}", "\u{4F60}\u{597D}", "\u{1F600}",
]

///|
/// Inline elements, safe to nest inside a paragraph.
let doc_inline_elements : Array[String] = [
  "b", "i", "em", "strong", "span", "code", "small", "sub", "sup",
]

///|
/// Attribute values used for generated elements, including values that need
/// quoting or escaping.
let doc_attr_values : Array[String] = [
  "plain", "with space", "with\"quote", "with'apostrophe", "a&b", "a<b", "",
]

///|
/// Raw-text elements whose serialized content must survive verbatim.
///
/// Only `script` and `style` appear here. HTML's other raw-text elements —
/// `xmp`, `iframe`, `noembed`, `noframes` — are currently escaped on output,
/// so a round trip through them adds an escape level; add them here once
/// issue #111 is fixed.
let doc_raw_text_elements : Array[String] = ["script", "style"]

///|
/// Raw-text content that cannot close its own element.
let doc_raw_text_bodies : Array[String] = [
  "var x = 1 < 2;", "a && b", "p { color: red }", "x > y", "&amp; stays raw", "",
]

///|
/// Escape text so it parses back to exactly the same characters.
///
/// This is a deliberately independent implementation: the round-trip property
/// would be vacuous if the generator escaped text by calling the serializer it
/// is meant to check.
fn escape_document_text(value : String) -> String {
  let out = StringBuilder::new()
  for ch in value {
    match ch {
      '&' => out.write_string("&amp;")
      '<' => out.write_string("&lt;")
      '>' => out.write_string("&gt;")
      _ => out.write_char(ch)
    }
  }
  out.to_string()
}

///|
/// Render a generated node as HTML source.
fn HtmlNode::render(self : HtmlNode, out : StringBuilder) -> Unit {
  match self {
    DocText(value) => out.write_string(escape_document_text(value))
    DocComment(value) => out <+ "<!--\{value}-->"
    DocRawText(name, body) => out <+ "<\{name}>\{body}</\{name}>"
    DocElement(name, attr, children) => {
      out <+ "<\{name}"
      if attr is Some(value) {
        out <+ " data-x=\"\{escape_document_attr(value)}\""
      }
      out.write_char('>')
      for child in children {
        child.render(out)
      }
      out <+ "</\{name}>"
    }
  }
}

///|
/// Escape an attribute value for a double-quoted attribute.
fn escape_document_attr(value : String) -> String {
  let out = StringBuilder::new()
  for ch in value {
    match ch {
      '&' => out.write_string("&amp;")
      '"' => out.write_string("&quot;")
      _ => out.write_char(ch)
    }
  }
  out.to_string()
}

///|
/// Render the whole document as HTML source.
fn HtmlDocument::source(self : HtmlDocument) -> String {
  let out = StringBuilder::new()
  out.write_string("<!DOCTYPE html><html><head></head><body>")
  for node in self.nodes {
    node.render(out)
  }
  out.write_string("</body></html>")
  out.to_string()
}

///|
/// Pick an element of `values` using the next number from `state`.
fn[T] pick(values : Array[T], state : @splitmix.RandomState) -> T {
  values[state.next_positive_int() % values.length()]
}

///|
/// Generate inline content: text, comments, or nested inline elements.
fn generate_inline(budget : Int, state : @splitmix.RandomState) -> HtmlNode {
  if budget <= 0 || state.next_positive_int() % 3 == 0 {
    return DocText(pick(doc_text_runs, state))
  }
  if state.next_positive_int() % 7 == 0 {
    return DocComment(pick(["c", "a b", "&amp;", ""], state))
  }
  let name = pick(doc_inline_elements, state)
  let attr = if state.next_positive_int() % 3 == 0 {
    Some(pick(doc_attr_values, state))
  } else {
    None
  }
  let count = state.next_positive_int() % 3
  let children = Array::new(capacity=count)
  for _ in 0..<count {
    children.push(generate_inline(budget - 1, state))
  }
  DocElement(name, attr, children)
}

///|
/// Generate flow content: a block container, a raw-text element, or inline
/// content.
fn generate_flow(budget : Int, state : @splitmix.RandomState) -> HtmlNode {
  if budget <= 0 {
    return generate_inline(0, state)
  }
  match state.next_positive_int() % 8 {
    0 => {
      // A paragraph accepts inline content only; a block child would close it.
      let count = state.next_positive_int() % 3 + 1
      let children = Array::new(capacity=count)
      for _ in 0..<count {
        children.push(generate_inline(budget - 1, state))
      }
      DocElement("p", None, children)
    }
    1 => {
      let count = state.next_positive_int() % 3 + 1
      let children = Array::new(capacity=count)
      for _ in 0..<count {
        children.push(generate_flow(budget - 1, state))
      }
      DocElement("div", None, children)
    }
    2 => {
      let count = state.next_positive_int() % 3 + 1
      let items = Array::new(capacity=count)
      for _ in 0..<count {
        items.push(DocElement("li", None, [generate_flow(budget - 1, state)]))
      }
      DocElement("ul", None, items)
    }
    3 =>
      // Only cells may hold content; stray text inside a table is foster
      // parented back out.
      DocElement("table", None, [
        DocElement("tbody", None, [
          DocElement("tr", None, [
            DocElement("td", None, [generate_flow(budget - 1, state)]),
          ]),
        ]),
      ])
    4 => DocElement("blockquote", None, [generate_flow(budget - 1, state)])
    5 =>
      DocRawText(
        pick(doc_raw_text_elements, state),
        pick(doc_raw_text_bodies, state),
      )
    _ => generate_inline(budget - 1, state)
  }
}

///|
impl @qc.Arbitrary for HtmlDocument with fn arbitrary(size, state) {
  let count = if size <= 0 { 1 } else { size % 6 + 1 }
  let budget = 1 + size % 4
  let nodes = Array::new(capacity=count)
  for _ in 0..<count {
    nodes.push(generate_flow(budget, state))
  }
  { nodes, }
}

///|
impl @shrink.Shrink for HtmlDocument with fn shrink(self) {
  let length = self.nodes.length()
  let candidates = []
  if length > 1 {
    for skip in 0..<length {
      let rest = Array::new(capacity=length - 1)
      for index in 0..<length {
        if index != skip {
          rest.push(self.nodes[index])
        }
      }
      candidates.push({ nodes: rest })
    }
  }
  // Replacing a node by its children peels one nesting level at a time.
  for index in 0..<length {
    if self.nodes[index] is DocElement(_, _, children) && !children.is_empty() {
      let peeled = Array::new(capacity=length)
      for other in 0..<length {
        if other == index {
          for child in children {
            peeled.push(child)
          }
        } else {
          peeled.push(self.nodes[other])
        }
      }
      candidates.push({ nodes: peeled })
    }
  }
  candidates.iter()
}

///|
impl Debug for HtmlDocument with fn to_repr(self) {
  Repr(self.source())
}
