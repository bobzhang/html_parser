///|
/// Nesting depth for these regressions. Serialization and text extraction
/// used to recurse once per level and overflowed the stack at around 2,000
/// levels on js and wasm-gc (about 20,000 on native).
let deep_levels : Int = 50000

///|
/// `levels` nested `name` elements around `leaf`, built directly so the test
/// does not depend on the parser.
fn deep_chain(
  name : String,
  levels : Int,
  leaf : Array[@dom.Node],
) -> @dom.Node {
  let mut node = @dom.element(name, children=leaf)
  for _ in 1..<levels {
    node = @dom.element(name, children=[node])
  }
  node
}

///|
test "deep nesting: compact to_html" {
  let tree = deep_chain("div", deep_levels, [@dom.text("a<b")])
  assert_true(
    @serializer.to_html(tree, pretty=false) ==
    "<div>".repeat(deep_levels) + "a&lt;b" + "</div>".repeat(deep_levels),
  )
  // Raw-text elements capture their whole subtree as one guarded payload.
  let script = @dom.element("script", children=[
    deep_chain("i", deep_levels, [@dom.text("</script>")]),
  ])
  assert_true(
    @serializer.to_html(script, pretty=false) ==
    "<script>" +
    "<i>".repeat(deep_levels) +
    "&lt;/script&gt;" +
    "</i>".repeat(deep_levels) +
    "</script>",
  )
  // Template children live in the contents fragment at every level.
  let template = deep_chain("template", deep_levels, [])
  assert_true(
    @serializer.to_html(template, pretty=false) ==
    "<template>".repeat(deep_levels) + "</template>".repeat(deep_levels),
  )
}

///|
test "deep nesting: pretty to_html" {
  let tree = deep_chain("div", deep_levels, [])
  // Without indentation the output stays linear in depth.
  assert_true(
    @serializer.to_html(tree, indent_size=0) ==
    "<div>\n".repeat(deep_levels - 1) +
    "<div></div>" +
    "\n</div>".repeat(deep_levels - 1),
  )
  // Nested inline elements collapse onto one line.
  let inline = deep_chain("b", deep_levels, [@dom.text("x")])
  assert_true(
    @serializer.to_html(inline) ==
    "<b>".repeat(deep_levels) + "x" + "</b>".repeat(deep_levels),
  )
}

///|
test "deep nesting: indented pretty to_html is linear in its output" {
  // Indentation makes the output quadratic in depth, so this runs shallower.
  // Each level used to copy its subtree's output as well, which made the
  // work cubic in depth.
  let levels = 1500
  let tree = deep_chain("div", levels, [])
  let expected = StringBuilder()
  for level in 0..<(levels - 1) {
    expected.write_string(" ".repeat(2 * level) + "<div>\n")
  }
  expected.write_string(" ".repeat(2 * (levels - 1)) + "<div></div>")
  for level = levels - 2; level >= 0; level = level - 1 {
    expected.write_string("\n" + " ".repeat(2 * level) + "</div>")
  }
  assert_eq(@serializer.to_html(tree), expected.to_string())
  // The html5lib test format also indents every level.
  let dump = @serializer.to_test_format(@dom.fragment(children=[tree]))
  assert_eq(dump.split("\n").count(), levels)
}

///|
test "deep nesting: text extraction" {
  let tree = deep_chain("p", deep_levels, [
    @dom.text(" hello "),
    @dom.element("br"),
    @dom.text(" world "),
  ])
  assert_true(@serializer.to_text(tree) == "hello world")
  assert_true(
    @serializer.to_text(tree, separator="|", separator_blocks_only=true) ==
    "hello|world",
  )
  assert_true(tree.text() == " hello  world ")
}
