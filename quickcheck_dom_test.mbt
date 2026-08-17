///|
/// The markup a generated tree carries in its text nodes.
///
/// Every property over `HandBuiltDom` asks the same question: can this text
/// stop being text? Using one payload keeps the answer a simple element count.
const DOM_PAYLOAD_TAG : String = "img"

///|
/// A node in a generated hand-built DOM.
///
/// `HtmlSource` and `HtmlDocument` both reach the DOM through `parse`, so they
/// only ever produce trees the tree builder can build. This one goes through
/// the public `@dom` constructors instead, which accept any name in any
/// namespace and will happily nest an element inside a `textarea`. Those trees
/// are exactly where serialization has gone wrong: a foreign ancestor, a name
/// that contradicts its namespace, or an ancestor whose content is tokenized as
/// text all change whether emitting a descendant's text literally is safe.
enum DomNode {
  /// Text, sometimes carrying markup that would go live if left unescaped.
  DomText(String)
  /// An element with a name, a namespace, and children.
  DomElement(String, String, Array[DomNode])
}

///|
/// A generated hand-built DOM tree.
struct HandBuiltDom {
  root : DomNode
}

///|
/// Element names that change how a descendant's text must be serialized.
///
/// Raw-text and RCDATA elements tokenize their content as text; `svg` and
/// `math` open foreign content; the integration points hand parsing back to
/// HTML. Mixed case is included because the tokenizer folds tag names while
/// `@dom.element` keeps whatever the caller wrote.
let dom_element_names : Array[String] = [
  // Raw text and RCDATA.
  "xmp", "XMP", "iframe", "noembed", "noframes", "noscript", "script", "style", "textarea",
  "title", "plaintext",
  // Foreign-content roots, and the same names in the wrong case.
   "svg", "SVG", "math", "MATH",
  // Integration points, and MathML text integration points.
   "foreignObject", "desc", "annotation-xml", "mi", "mtext", "mglyph",
  // Ordinary containers, including tags that break out of foreign content.
   "div", "p", "span", "b", "font", "table", "td", "custom-element", "foo",
]

///|
/// Namespaces `@dom.element` accepts, including ones that contradict the name.
let dom_namespaces : Array[String] = ["html", "svg", "math"]

///|
/// Text payloads, half of them trying to close an enclosing element.
///
/// The closing sequences are split across the corpus rather than spelled out
/// once, so a tree can also assemble one from adjacent text nodes.
let dom_text_payloads : Array[String] = [
  "plain text", "a<b &amp; c", "&", "<", "", "<img src=x onerror=1>", "</xmp><img src=x onerror=1>",
  "</textarea><img src=x onerror=1>", "</title><img src=x onerror=1>", "</noscript><img src=x onerror=1>",
  "</script><img src=x onerror=1>", "</iframe><img src=x onerror=1>", "</style><img src=x onerror=1>",
  "</x", "mp><img src=x onerror=1>", "]]><img src=x onerror=1>",
]

///|
/// Build the generated tree through the public DOM constructors.
fn DomNode::build(self : DomNode) -> @dom.Node {
  match self {
    DomText(value) => @html_parser.text(value)
    DomElement(name, ns, children) => {
      let built = Array::new(capacity=children.length())
      for child in children {
        built.push(child.build())
      }
      @html_parser.element(name, ns~, children=built)
    }
  }
}

///|
/// Build the whole tree.
fn HandBuiltDom::build(self : HandBuiltDom) -> @dom.Node {
  self.root.build()
}

///|
/// Render the tree as a readable shape, for counterexample reporting.
fn DomNode::describe(self : DomNode, out : StringBuilder) -> Unit {
  match self {
    DomText(value) => out <+ "\"\{value}\""
    DomElement(name, ns, children) => {
      out <+ "\{name}(\{ns})["
      for index, child in children {
        if index > 0 {
          out.write_string(", ")
        }
        child.describe(out)
      }
      out.write_char(']')
    }
  }
}

///|
impl Debug for HandBuiltDom with fn to_repr(self) {
  let out = StringBuilder::new()
  self.root.describe(out)
  Repr(out.to_string())
}

///|
/// Generate a node, spending `budget` on nesting depth.
fn generate_dom_node(budget : Int, state : @splitmix.RandomState) -> DomNode {
  if budget <= 0 || state.next_positive_int() % 3 == 0 {
    return DomText(pick(dom_text_payloads, state))
  }
  let count = state.next_positive_int() % 3 + 1
  let children = Array::new(capacity=count)
  for _ in 0..<count {
    children.push(generate_dom_node(budget - 1, state))
  }
  DomElement(
    pick(dom_element_names, state),
    pick(dom_namespaces, state),
    children,
  )
}

///|
impl @qc.Arbitrary for HandBuiltDom with fn arbitrary(size, state) {
  { root: generate_dom_node(1 + size % 5, state) }
}

///|
impl @shrink.Shrink for HandBuiltDom with fn shrink(self) {
  match self.root {
    DomText(_) => Iter::empty()
    DomElement(_, _, children) => {
      let candidates = []
      // Promoting a child drops one level of nesting at a time, which is what
      // matters here: these counterexamples are about ancestor chains.
      for child in children {
        candidates.push({ root: child })
      }
      if children.length() > 1 {
        for skip in 0..<children.length() {
          let rest = Array::new(capacity=children.length() - 1)
          for index in 0..<children.length() {
            if index != skip {
              rest.push(children[index])
            }
          }
          match self.root {
            DomElement(name, ns, _) =>
              candidates.push({ root: DomElement(name, ns, rest) })
            DomText(_) => ()
          }
        }
      }
      candidates.iter()
    }
  }
}

///|
/// Collect every node in a tree, text and comments included.
///
/// `collect_elements` is not enough for the properties below: `to_html` accepts
/// any node, and serializing a *text* node on its own was itself a way to lose
/// the ancestor that kept the text inert.
fn collect_all_nodes(root : @dom.Node) -> Array[@dom.Node] {
  let out = []
  fn walk(node : @dom.Node) -> Unit {
    out.push(node)
    for child in node.children() {
      walk(child)
    }
    if node.template_content() is Some(content) {
      walk(content)
    }
  }

  walk(root)
  out
}

///|
/// Count elements of `name` in a tree.
fn count_elements(root : @dom.Node, name : String) -> Int {
  let mut total = 0
  for element in collect_elements(root) {
    if element.name() == name {
      total += 1
    }
  }
  total
}

///|
/// Serialize `node`, treating the serializer's name guard as out of scope.
///
/// `to_html` refuses some names the parser itself produces (issue #113); that
/// is tracked separately and is a raise rather than a silent escape, so it
/// cannot hide the breakout these properties look for.
fn serialize_or_skip(
  node : @dom.Node,
  pretty~ : Bool,
) -> String? raise @core.HtmlError {
  Some(@html_parser.to_html(node, pretty~)) catch {
    InvalidSerialization(_) => None
    error => raise error
  }
}

///|
/// Check that serializing `node` cannot turn text into a live element.
///
/// The tree carries `<img …>` inside text nodes. If serializing and reparsing
/// yields more `img` elements than the tree already had, some text escaped its
/// container — which is the shape every raw-text serialization bug has taken.
fn text_stays_inert(
  node : @dom.Node,
  pretty~ : Bool,
) -> Bool raise @core.HtmlError {
  let before = count_elements(node, DOM_PAYLOAD_TAG)
  guard serialize_or_skip(node, pretty~) is Some(html) else { return true }
  // Both scripting modes: a document parsed one way is routinely reparsed the
  // other, and `noscript` is only text when scripting is enabled.
  for scripting in [true, false] {
    let reparsed = @html_parser.parse_fragment(
      html,
      scripting_enabled=scripting,
    )
    if count_elements(reparsed.root, DOM_PAYLOAD_TAG) > before {
      return false
    }
  }
  true
}

///|
test "property: serializing a hand-built DOM keeps its text inert" {
  @qc.check(
    (input : HandBuiltDom) => {
      let tree = input.build()
      text_stays_inert(tree, pretty=false) &&
      text_stays_inert(tree, pretty=true)
    },
    count=4000,
    seed=20260817,
  )
}

///|
test "property: serializing any node of a hand-built DOM keeps its text inert" {
  // `to_html` accepts any node, so an ancestor that made the text safe may not
  // be part of the output. Every node has to hold on its own.
  @qc.check(
    (input : HandBuiltDom) => {
      let tree = input.build()
      for node in collect_all_nodes(tree) {
        if !text_stays_inert(node, pretty=false) {
          return false
        }
      }
      true
    },
    count=3000,
    seed=20260818,
  )
}

///|
test "property: serializing any node of a parsed document keeps its text inert" {
  @qc.check(
    (input : HtmlSource) => {
      let parsed = @html_parser.parse(input.source())
      for node in collect_all_nodes(parsed.root) {
        if !text_stays_inert(node, pretty=false) {
          return false
        }
      }
      true
    },
    count=1000,
    seed=20260819,
  )
}

///|
test "property: a scripting-disabled parse survives a scripting-enabled reparse" {
  // Output crosses parse modes routinely: this parser defaults to scripting
  // enabled and browsers always have it on, so a tree parsed with it disabled
  // must not go live when it is read back.
  @qc.check(
    (input : HtmlSource) => {
      let src = input.source()
      for scripting in [true, false] {
        let parsed = @html_parser.parse(src, scripting_enabled=scripting)
        if !text_stays_inert(parsed.root, pretty=false) {
          return false
        }
      }
      true
    },
    count=1000,
    seed=20260820,
  )
}
