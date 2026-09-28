// Whitebox regressions: post-parse tree passes must not recurse once per
// nesting level. The trees are built by pushing children directly (instead of
// append_child, whose cycle check walks every ancestor) to keep setup linear.

///|
let deep_nesting_levels : Int = 50000

///|
fn deep_nesting_attach(parent : @dom.Node, child : @dom.Node) -> Unit {
  child.parent = Some(parent)
  parent.children.push(child)
}

///|
/// Walk the single-child spine below `root`, returning the element names in
/// order and the first non-element node found (if any).
fn deep_nesting_spine(root : @dom.Node) -> (Array[String], @dom.Node?) {
  let names : Array[String] = []
  let mut current = root
  while current.children.length() == 1 {
    let child = current.children[0]
    if child.kind != Element {
      return (names, Some(child))
    }
    names.push(child.name)
    current = child
  }
  (names, None)
}

///|
test "normalize_tables handles deeply nested bare table cells" {
  let root = @dom.fragment()
  let mut current = root
  for _ in 0..<deep_nesting_levels {
    let table = @dom.element("table")
    let cell = @dom.element("td")
    deep_nesting_attach(current, table)
    deep_nesting_attach(table, cell)
    current = cell
  }
  deep_nesting_attach(current, @dom.text("leaf"))
  normalize_tables(root)
  let (names, leaf) = deep_nesting_spine(root)
  assert_eq(names.length(), deep_nesting_levels * 4)
  let expected = ["table", "tbody", "tr", "td"]
  for index, name in names {
    assert_eq(name, expected[index % 4])
  }
  guard leaf is Some(text) && text.data == "leaf" else {
    fail("expected the leaf text at the bottom of the normalized spine")
  }
}

///|
test "normalize_tables handles deeply nested template contents" {
  let root = @dom.fragment()
  let mut current = root
  for _ in 0..<deep_nesting_levels {
    let template = @dom.element("template")
    let contents = @dom.fragment()
    contents.parent = Some(template)
    template.template_contents = Some(contents)
    let table = @dom.element("table")
    let row = @dom.element("tr")
    deep_nesting_attach(current, template)
    deep_nesting_attach(contents, table)
    deep_nesting_attach(table, row)
    current = row
  }
  normalize_tables(root)
  let mut node = root
  let mut levels = 0
  while node.children.get(0) is Some(template) {
    guard template.template_contents is Some(contents) else {
      fail("expected template contents")
    }
    let table = contents.children[0]
    assert_eq(table.children.length(), 1)
    let body = table.children[0]
    assert_eq(body.name, "tbody")
    let row = body.children[0]
    assert_eq(row.name, "tr")
    node = row
    levels += 1
  }
  assert_eq(levels, deep_nesting_levels)
}

///|
test "nested html and body flattening handles deep chains" {
  for name in ["html", "body"] {
    let top = @dom.element(name, attrs={ "k": Some("v0") })
    let mut current = top
    for depth in 1..<deep_nesting_levels {
      deep_nesting_attach(current, @dom.comment("c\{depth - 1}"))
      let attrs : Map[String, String?] = { "k": Some("v\{depth}") }
      attrs["d\{depth % 5}"] = Some("\{depth}")
      let nested = @dom.element(name, attrs~)
      deep_nesting_attach(current, nested)
      current = nested
    }
    deep_nesting_attach(current, @dom.text("leaf"))
    let target = @dom.element(name)
    let out : Array[@dom.Node] = []
    if name == "html" {
      append_html_node_contents(target, top, out)
    } else {
      append_body_node_contents(target, top, out)
    }
    assert_eq(out.length(), deep_nesting_levels)
    for index in 0..<(deep_nesting_levels - 1) {
      assert_eq(out[index].data, "c\{index}")
    }
    assert_eq(out[deep_nesting_levels - 1].data, "leaf")
    assert_eq(top.children.length(), 0)
    assert_true(target.attrs.get("k") is Some(Some("v0")))
    for depth in 1..<=5 {
      // The first nested element carrying each attribute wins.
      let expected = "\{depth}"
      assert_true(
        target.attrs.get("d\{depth % 5}") is Some(Some(value)) &&
        value == expected,
      )
    }
  }
}

///|
test "nested html content checks handle deep chains" {
  for with_body_content in [false, true] {
    let root = @dom.document()
    let top = @dom.element("html")
    deep_nesting_attach(root, top)
    let mut current = top
    for _ in 0..<deep_nesting_levels {
      deep_nesting_attach(current, @dom.element("head"))
      deep_nesting_attach(current, @dom.comment("c"))
      let nested = @dom.element("html")
      deep_nesting_attach(current, nested)
      current = nested
    }
    deep_nesting_attach(current, @dom.text(" "))
    if with_body_content {
      deep_nesting_attach(current, @dom.element("p"))
    }
    assert_eq(document_children_contain_body_content(root), with_body_content)
    assert_eq(html_fragment_child_is_before_body(top), !with_body_content)
  }
}
