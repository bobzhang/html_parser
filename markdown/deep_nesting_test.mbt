// `to_markdown` walks the DOM with an explicit work stack, so nesting depth
// is bounded by memory rather than by the native call stack. These trees are
// deep enough to overflow a recursive walk on every backend.

///|
let deep_nesting_depth : Int = 30000

///|
fn deep_chain(names : Array[String], leaf : @dom.Node) -> @dom.Node {
  let mut current = leaf
  for index in 0..<deep_nesting_depth {
    let name = names[index % names.length()]
    let attrs : Map[String, String?] = if name == "a" {
      { "href": Some("u") }
    } else {
      Map([])
    }
    current = @dom.element(name, attrs~, children=[current])
  }
  current
}

///|
test "to_markdown handles deeply nested bold" {
  let markers = "*".repeat(2 * deep_nesting_depth)
  assert_eq(
    @markdown.to_markdown(deep_chain(["b"], @dom.text("x"))),
    "\{markers}x\{markers}",
  )
}

///|
test "to_markdown handles deeply nested blockquotes" {
  assert_eq(
    @markdown.to_markdown(deep_chain(["blockquote"], @dom.text("x"))),
    "> ".repeat(deep_nesting_depth) + "x",
  )
}

///|
test "to_markdown handles deeply nested links and headings" {
  let node = deep_chain(["a", "h2", "em", "div"], @dom.text("x"))
  // The outermost div/em/h2/a render as Markdown; everything inside the link
  // is link text, where headings and divs flatten and only the emphasis
  // markers remain.
  let inner_emphasis = "*".repeat((deep_nesting_depth - 4) / 4)
  assert_eq(
    @markdown.to_markdown(node),
    "*## [\{inner_emphasis}x\{inner_emphasis}](u)*",
  )
}

///|
test "to_markdown handles deeply nested mixed containers" {
  let leaf = @dom.element("p", children=[
    @dom.text("leaf "),
    @dom.element("code", children=[@dom.text("c")]),
  ])
  let names = [
    "span", "template", "section", "strong", "x-unknown", "i", "blockquote", "p",
    "pre", "li", "ul",
  ]
  for passthrough in [false, true] {
    let markdown = @markdown.to_markdown(
      deep_chain(names, leaf),
      html_passthrough=passthrough,
    )
    assert_true(markdown.length() > 0)
  }
}
