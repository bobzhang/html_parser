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
  // `mixed_chain` (see walk_continuation_test.mbt) nests list items, strong,
  // blockquote, emphasis and heading continuations inside transparent
  // containers; every level renders on one line, so the exact output is
  // known in closed form at any depth.
  let periods = deep_nesting_depth / mixed_chain_unit.length()
  for passthrough in [false, true] {
    assert_eq(
      @markdown.to_markdown(mixed_chain(periods), html_passthrough=passthrough),
      mixed_chain_markdown(periods),
    )
  }
}

///|
/// `levels` nested `span`s, each holding a text node before the next level,
/// inside a `name` element: code text collection walks the whole chain.
fn deep_code_chain(name : String, levels : Int) -> @dom.Node {
  let mut current = @dom.element("span", children=[@dom.text("a")])
  for _ in 1..<levels {
    current = @dom.element("span", children=[@dom.text("a"), current])
  }
  @dom.element(name, children=[current])
}

///|
test "to_markdown collects deeply nested code text" {
  let levels = 50000
  let text = "a".repeat(levels)
  assert_true(
    @markdown.to_markdown(deep_code_chain("code", levels)) == "`\{text}`",
  )
  assert_true(
    @markdown.to_markdown(deep_code_chain("pre", levels)) == "```\n\{text}\n```",
  )
}
