// Whitebox regressions for DOM mutation and selector traversal interaction.

///|
test "dom insert_before moves appends and rejects cycles" {
  let parent = @dom.element("div")
  let first = @dom.element("p", children=[@dom.text("first")])
  let second = @dom.element("span", children=[@dom.text("second")])
  parent.append_child(first)
  parent.append_child(second)
  let inserted = @dom.element("em", children=[@dom.text("mid")])
  parent.insert_before(inserted, Some(second))
  assert_eq(
    @ser.to_html(parent, pretty=false),
    "<div><p>first</p><em>mid</em><span>second</span></div>",
  )
  let fallback = @dom.element("strong", children=[@dom.text("end")])
  parent.insert_before(fallback, Some(@dom.element("missing")))
  assert_eq(
    @ser.to_html(parent, pretty=false),
    "<div><p>first</p><em>mid</em><span>second</span><strong>end</strong></div>",
  )
  let other = @dom.element("section")
  other.append_child(inserted)
  assert_eq(
    @ser.to_html(parent, pretty=false),
    "<div><p>first</p><span>second</span><strong>end</strong></div>",
  )
  assert_eq(
    @ser.to_html(other, pretty=false),
    "<section><em>mid</em></section>",
  )
  inserted.append_child(other)
  assert_eq(@ser.to_html(inserted, pretty=false), "<em>mid</em>")
  let non_container = @dom.comment("x")
  non_container.insert_before(@dom.text("ignored"), Some(first))
  assert_eq(non_container.children().length(), 0)
  non_container.remove_child(first)
  assert_eq(@ser.to_html(first, pretty=false), "<p>first</p>")
}

///|
test "append_child clears stale parent links" {
  let parent = @dom.element("div")
  let child = @dom.element("span")
  child.parent = Some(@dom.comment("stale"))
  parent.append_child(child)
  assert_eq(parent.children.length(), 1)
  assert_true(physical_equal(parent.children[0], child))
  guard child.parent is Some(actual_parent) else {
    fail("expected adopted child parent")
  }
  assert_true(physical_equal(actual_parent, parent))
}

///|
test "query deduplicates shared nodes and ignores traversal cycles" {
  let shared_root = @dom.element("div")
  let shared = @dom.element("span", attrs={ "class": Some("target") })
  shared_root.append_child(shared)
  shared_root.children.push(shared)
  assert_eq(@sel.query(shared_root, "span").length(), 1)
  assert_eq(@sel.query(shared_root, ".target").length(), 1)
  assert_eq(@sel.query(shared_root, "*").length(), 1)
  let cyclic_root = @dom.element("div")
  let child = @dom.element("span", attrs={ "class": Some("cycle") })
  cyclic_root.append_child(child)
  child.children.push(cyclic_root)
  child.children.push(@dom.text("needle"))
  cyclic_root.parent = Some(child)
  assert_eq(@sel.query(cyclic_root, "span").length(), 1)
  assert_eq(@sel.query(cyclic_root, ".cycle").length(), 1)
  assert_eq(@sel.query(cyclic_root, "*").length(), 1)
  assert_true(@sel.matches(child, "div span"))
  assert_eq(@sel.matches(child, "em span"), false)
  assert_eq(@sel.matches(cyclic_root, "div:contains(needle)"), false)
  assert_eq(@sel.matches(child, "span:contains(needle)"), false)
  assert_eq(@sel.query(cyclic_root, "div span").length(), 1)
  assert_eq(@sel.query(cyclic_root, "em span").length(), 0)
  assert_eq(@sel.query(cyclic_root, "span:contains(needle)").length(), 0)
}
