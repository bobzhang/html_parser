///|
fn default_selector_limits() -> SelectorLimits {
  SelectorLimits()
}

///|
test "pseudo matcher rejects unknown and blank contains pseudos" {
  let note = @dom.comment("note")
  assert_eq(pseudo_selector_matches(note, "hover"), false)
  assert_eq(pseudo_selector_matches(note, "hover(2)"), false)
  assert_eq(pseudo_selector_matches(note, "contains(   )"), false)
}

///|
test "limited selector matcher keeps pseudo parity" {
  let root = @dom.fragment(children=[
    @dom.comment("note"),
    @dom.element("section", children=[
      @dom.element("h1", children=[@dom.text("Title")]),
      @dom.element("p", attrs={ "class": Some("first") }, children=[
        @dom.text("alpha"),
      ]),
      @dom.element("p", attrs={ "class": Some("second"), "disabled": None }, children=[
        @dom.text("needle"),
      ]),
    ]),
  ])
  let note = root.children[0]
  let section = root.children[1]
  let heading = section.children[0]
  let first = section.children[1]
  let second = section.children[2]
  let empty = @dom.element("span", children=[
    @dom.text("  "),
    @dom.comment("blank"),
  ])
  let limits = default_selector_limits()
  assert_true(matches_with_limits(note, ":comment", limits))
  assert_true(matches_with_limits(note, ":comment(any)", limits))
  assert_eq(matches_with_limits(note, ":not(:comment)", limits), false)
  assert_true(matches_with_limits(heading, "h1:first-child", limits))
  assert_true(matches_with_limits(second, "p:last-child", limits))
  assert_eq(matches_with_limits(first, "p:first-child", limits), false)
  assert_eq(matches_with_limits(second, "p:only-child", limits), false)
  assert_true(matches_with_limits(first, "p:first-of-type", limits))
  assert_true(matches_with_limits(second, "p:last-of-type", limits))
  assert_true(matches_with_limits(heading, "h1:only-of-type", limits))
  assert_eq(matches_with_limits(first, "p:only-of-type", limits), false)
  assert_true(matches_with_limits(second, "*.second", limits))
  assert_true(matches_with_limits(second, "p.second[disabled]", limits))
  assert_true(matches_with_limits(empty, "span:empty", limits))
  assert_true(matches_with_limits(section, "section:root", limits))
  assert_eq(matches_with_limits(second, "*foo", limits), false)
  assert_true(matches_with_limits(second, "section > p:nth-of-type(2)", limits))
  assert_true(
    matches_with_limits(
      second,
      "p:contains(needle)",
      SelectorLimits(max_match_bytes=1000),
    ),
  )
  let context = SelectorMatchContext(limits)
  context.tick(0)
  assert_eq(
    pseudo_selector_matches_with_context(second, "hover(2)", context, 0),
    false,
  )
  assert_eq(
    pseudo_selector_matches_with_context(second, "hover", context, 0),
    false,
  )
}

///|
test "limited selector context fails closed on malformed branches" {
  let root = @dom.fragment(children=[
    @dom.element("section", children=[
      @dom.element("p", attrs={ "class": Some("first") }, children=[
        @dom.text("alpha"),
      ]),
      @dom.element("p", attrs={ "id": Some("second") }, children=[
        @dom.text("beta"),
      ]),
    ]),
  ])
  let section = root.children[0]
  let first = section.children[0]
  let second = section.children[1]
  let context = SelectorMatchContext(default_selector_limits())
  assert_eq(matches_simple_selector_with_context(second, "", context, 0), false)
  assert_eq(
    matches_simple_selector_with_context(second, "*foo", context, 0),
    false,
  )
  assert_eq(
    matches_simple_selector_with_context(second, "p[href]*", context, 0),
    false,
  )
  assert_eq(
    matches_simple_selector_with_context(second, "p[", context, 0),
    false,
  )
  assert_eq(
    matches_simple_selector_with_context(second, "p[id]*", context, 0),
    false,
  )
  assert_eq(
    matches_simple_selector_with_context(second, "p.", context, 0),
    false,
  )
  assert_eq(
    matches_complex_selector_with_context(second, "", context, 0),
    false,
  )
  assert_eq(
    matches_complex_selector_with_context(section, "main > section", context, 0),
    false,
  )
  assert_eq(
    matches_complex_selector_with_context(
      @dom.element("section"),
      "main > section",
      context,
      0,
    ),
    false,
  )
  assert_eq(
    matches_complex_selector_with_context(first, "h1 + p", context, 0),
    false,
  )
  let cyclic_root = @dom.element("div")
  let cyclic_child = @dom.element("span")
  cyclic_root.append_child(cyclic_child)
  cyclic_child.children.push(cyclic_root)
  cyclic_root.parent = Some(cyclic_child)
  assert_eq(
    matches_complex_selector_with_context(cyclic_child, "em span", context, 0),
    false,
  )
  selector_validate_simple_parse_depth("", default_selector_limits(), 0)
  assert_eq(
    previous_element_sibling_with_context(@dom.element("p"), context) is None,
    true,
  )
  assert_eq(
    previous_matching_sibling_with_context(@dom.element("p"), "p", context, 0)
    is None,
    true,
  )
  try
    matches_complex_selector_with_context(
      second,
      "p",
      SelectorMatchContext(SelectorLimits(max_match_depth=0)),
      1,
    )
  catch {
    SelectorError(message) => assert_eq(message, "Selector nesting is too deep")
    _ => fail("expected selector match depth error")
  } noraise {
    _ => fail("expected selector match depth error")
  }
}

///|
test "nth selector helpers reject empty signed integer fragments" {
  assert_true(parse_signed_int_view("") is None)
  guard parse_signed_int_view("+12") is Some(positive) else {
    fail("expected signed positive integer")
  }
  assert_eq(positive, 12)
  guard parse_signed_int_view("-3") is Some(negative) else {
    fail("expected signed negative integer")
  }
  assert_true(negative == -3)
  assert_true(parse_nth_expression("") is None)
  assert_true(parse_nth_expression("2n+") is None)
  guard parse_nth_expression("n") is Some((plain_a, plain_b)) else {
    fail("expected plain n formula")
  }
  assert_eq(plain_a, 1)
  assert_eq(plain_b, 0)
  guard parse_nth_expression("-n+3") is Some((a, b)) else {
    fail("expected negative nth coefficient")
  }
  assert_true(a == -1)
  assert_eq(b, 3)
}

///|
test "selector helper fragments fail closed on malformed syntax" {
  let node = @dom.element("div", attrs={
    "class": Some("alpha beta"),
    "href": Some("http://example.com"),
    "id": Some("main"),
  })
  assert_eq(attribute_selector_matches(node, ""), false)
  assert_eq(attribute_selector_matches(node, "href!=http://example.com"), false)
  assert_eq(
    attribute_selector_matches(node, "href=http://example.com bad"),
    false,
  )
  assert_eq(matches_simple_selector(node, ""), false)
  assert_eq(matches_simple_selector(node, "*div"), false)
  assert_eq(matches_simple_selector(node, "div["), false)
  assert_eq(matches_simple_selector(node, "div."), false)
  assert_eq(matches_simple_selector(node, "div[href]*"), false)
  assert_eq(simple_selector_is_valid(""), false)
  assert_eq(simple_selector_is_valid("div["), false)
  assert_eq(simple_selector_is_valid("div[href]*"), false)
  assert_true(split_complex_selector("") is None)
  assert_eq(matches_complex_selector(node, ""), false)
}
