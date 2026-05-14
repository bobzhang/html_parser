// Whitebox regressions for active-formatting and adoption-agency helpers.

///|
test "active formatting helpers respect marker boundaries" {
  let parser = Parser::new(
    "",
    @dom.fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  parser.append_active_formatting_entry(@dom.comment("ignored"))
  assert_eq(parser.active_formatting.length(), 0)
  let before_marker = @dom.element("a", attrs={ "href": Some("x") })
  parser.append_active_formatting_entry(before_marker)
  parser.push_active_formatting_marker()
  let after_marker = @dom.element("b", attrs={ "class": Some("fresh") })
  parser.append_active_formatting_entry(after_marker)
  assert_eq(parser.active_formatting.length(), 3)
  assert_eq(parser.active_formatting_index("a"), -1)
  assert_eq(parser.active_formatting_index("b"), 2)
  parser.remove_last_active_formatting_by_name("a")
  assert_eq(parser.active_formatting.length(), 3)
  parser.remove_last_active_formatting_by_name("b")
  assert_eq(parser.active_formatting.length(), 2)
  assert_eq(parser.active_formatting_orphan_anchor_index(), -1)
  let orphan_anchor = @dom.element("a", attrs={ "href": Some("later") })
  parser.active_formatting.push({
    marker: false,
    name: "a",
    ns: "html",
    attrs: orphan_anchor.attrs.copy(),
    node: orphan_anchor,
  })
  assert_eq(parser.active_formatting_orphan_anchor_index(), 2)
  parser.clear_active_formatting_to_marker()
  assert_eq(parser.active_formatting.length(), 1)
  assert_eq(parser.active_formatting_index("a"), 0)
  let transient = @dom.element("span")
  parser.stack.push(transient)
  parser.remove_last_open_element_by_name("span")
  assert_eq(parser.stack.length(), 1)
  let parent = @dom.element("div")
  parser.root.append_child(parent)
  parser.stack.push(parent)
  let orphan_strong = @dom.element("strong", attrs={ "id": Some("orphan") })
  parser.active_formatting.clear()
  parser.active_formatting.push({
    marker: false,
    name: "em",
    ns: "html",
    attrs: {},
    node: parent,
  })
  parser.active_formatting.push({
    marker: false,
    name: "strong",
    ns: "html",
    attrs: orphan_strong.attrs.copy(),
    node: orphan_strong,
  })
  parser.reconstruct_active_formatting_elements()
  assert_eq(
    @ser.to_html(parent, pretty=false),
    "<div><strong id=\"orphan\"></strong></div>",
  )
  assert_eq(parser.stack.length(), 3)
  guard parser.stack.last() is Some(last) else {
    fail("expected reconstructed formatting node on stack")
  }
  assert_eq(last.name, "strong")

  let current_only = Parser::new(
    "",
    @dom.fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  let current_b = @dom.element("b")
  current_only.stack.push(current_b)
  current_only.adoption_agency("b", 4)
  assert_eq(current_only.stack.length(), 1)
  assert_eq(current_only.errors.length(), 0)

  let scoped = Parser::new(
    "",
    @dom.fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  let scoped_b = @dom.element("b")
  scoped.stack.push(scoped_b)
  scoped.stack.push(@dom.element("table"))
  scoped.active_formatting.push({
    marker: false,
    name: "b",
    ns: "html",
    attrs: {},
    node: scoped_b,
  })
  scoped.adoption_agency("b", 7)
  assert_eq(scoped.errors.length(), 1)
  assert_eq(scoped.errors[0].code, "adoption-agency-1.3")
  assert_eq(scoped.stack.length(), 3)
  assert_eq(scoped.active_formatting.length(), 1)
}

///|
test "adoption agency removes non-formatting inner stack nodes" {
  let parser = Parser::new(
    "",
    @dom.fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  let original_b = @dom.element("b", attrs={ "data-origin": Some("start") })
  let loose_span = @dom.element("span")
  let furthest_block = @dom.element("p")
  parser.stack.push(original_b)
  parser.stack.push(loose_span)
  parser.stack.push(furthest_block)
  parser.active_formatting.push({
    marker: false,
    name: "b",
    ns: "html",
    attrs: original_b.attrs.copy(),
    node: original_b,
  })
  parser.adoption_agency("b", 0)
  assert_eq(parser.errors.length(), 1)
  assert_eq(parser.errors[0].code, "adoption-agency-1.3")
  assert_eq(parser.stack_index_by_node(loose_span), -1)
  assert_eq(parser.stack_index_by_node(original_b), -1)
  assert_eq(parser.stack.length(), 2)
  assert_eq(parser.stack_index_by_node(furthest_block), 1)
  assert_eq(
    @ser.to_html(parser.root, pretty=false),
    "<p><b data-origin=\"start\"></b></p>",
  )
  assert_eq(parser.active_formatting.length(), 0)
  guard furthest_block.children.length() == 1 else {
    fail("expected replacement formatting child")
  }
  let replacement_b = furthest_block.children[0]
  assert_eq(replacement_b.name, "b")
  assert_true(!physical_equal(replacement_b, original_b))
  guard replacement_b.parent is Some(parent) else {
    fail("expected replacement formatting node to be under furthest block")
  }
  assert_true(physical_equal(parent, furthest_block))
}

///|
test "adoption agency prunes late active inner nodes" {
  let parser = Parser::new(
    "",
    @dom.fragment(),
    scripting_enabled=true,
    xml_coercion=false,
  )
  let original_b = @dom.element("b", attrs={ "data-origin": Some("start") })
  let late_i = @dom.element("i", attrs={ "data-late": Some("drop") })
  let loose_one = @dom.element("span")
  let loose_two = @dom.element("span")
  let top_em = @dom.element("em", attrs={ "data-top": Some("keep") })
  let furthest_block = @dom.element("p")
  parser.stack.push(original_b)
  parser.stack.push(late_i)
  parser.stack.push(loose_one)
  parser.stack.push(loose_two)
  parser.stack.push(top_em)
  parser.stack.push(furthest_block)
  parser.active_formatting.push({
    marker: false,
    name: "b",
    ns: "html",
    attrs: original_b.attrs.copy(),
    node: original_b,
  })
  parser.active_formatting.push({
    marker: false,
    name: "i",
    ns: "html",
    attrs: late_i.attrs.copy(),
    node: late_i,
  })
  parser.active_formatting.push({
    marker: false,
    name: "em",
    ns: "html",
    attrs: top_em.attrs.copy(),
    node: top_em,
  })
  parser.adoption_agency("b", 0)
  assert_eq(parser.errors.length(), 1)
  assert_eq(parser.errors[0].code, "adoption-agency-1.3")
  assert_eq(parser.stack_index_by_node(late_i), -1)
  assert_eq(parser.stack_index_by_node(loose_one), -1)
  assert_eq(parser.stack_index_by_node(loose_two), -1)
  assert_eq(parser.stack_index_by_node(original_b), -1)
  assert_eq(
    @ser.to_html(parser.root, pretty=false),
    "<em data-top=\"keep\"><p><b data-origin=\"start\"></b></p></em>",
  )
  assert_eq(parser.active_formatting.length(), 1)
  let remaining = parser.active_formatting[0]
  assert_eq(remaining.name, "em")
  assert_true(!physical_equal(remaining.node, top_em))
}
