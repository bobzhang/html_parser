// Blackbox snapshot tests for `@selector` — CSS-style queries against
// a DOM tree. Tests build small DOM fragments by hand to keep inputs
// readable; `query`/`matches` are agnostic to how the tree was built.

///|
fn sample_doc() -> @dom.Node {
  // <div id="root">
  //   <p class="intro lede">first</p>
  //   <p class="intro">second</p>
  //   <p>third</p>
  //   <span data-tag="x">span content</span>
  // </div>
  @dom.element("div", attrs={ "id": Some("root") }, children=[
    @dom.element("p", attrs={ "class": Some("intro lede") }, children=[
      @dom.text("first"),
    ]),
    @dom.element("p", attrs={ "class": Some("intro") }, children=[
      @dom.text("second"),
    ]),
    @dom.element("p", children=[@dom.text("third")]),
    @dom.element("span", attrs={ "data-tag": Some("x") }, children=[
      @dom.text("span content"),
    ]),
  ])
}

///|
test "query by tag returns every matching descendant" {
  debug_inspect(
    @selector.query(sample_doc(), "p").length(),
    content=(
      #|3
    ),
  )
}

///|
test "query by class narrows to the class match" {
  debug_inspect(
    @selector.query(sample_doc(), ".intro").length(),
    content=(
      #|2
    ),
  )
}

///|
test "query searches descendants only — root itself is not considered" {
  // The root <div id="root"> matches the selector, but `query` skips
  // its own argument and only descends into children. Use `matches`
  // to test the root node itself.
  let doc = sample_doc()
  let descendant_hit = @selector.query(doc, "#root").length()
  let self_matches = @selector.matches(doc, "#root")
  debug_inspect(
    (descendant_hit, self_matches),
    content=(
      #|(0, true)
    ),
  )
}

///|
test "query by attribute selector matches presence and value" {
  let presence = @selector.query(sample_doc(), "[data-tag]").length()
  let exact = @selector.query(sample_doc(), "[data-tag='x']").length()
  debug_inspect(
    (presence, exact),
    content=(
      #|(1, 1)
    ),
  )
}

///|
test "query compound selector combines tag and class" {
  // `p.intro.lede` requires all three on the same element.
  debug_inspect(
    @selector.query(sample_doc(), "p.intro.lede").length(),
    content=(
      #|1
    ),
  )
}

///|
test "query_one returns first match or None" {
  let doc = sample_doc()
  let hit = @selector.query_one(doc, "p.lede")
  let miss = @selector.query_one(doc, "p.missing")
  debug_inspect(
    (hit is Some(_), miss is Some(_)),
    content=(
      #|(true, false)
    ),
  )
}

///|
test "matches checks one node against a selector" {
  let doc = sample_doc()
  let first_p = @selector.query_one(doc, "p").unwrap()
  let intro = @selector.matches(first_p, "p.intro")
  let lede = @selector.matches(first_p, "p.lede")
  let other = @selector.matches(first_p, "span")
  debug_inspect(
    (intro, lede, other),
    content=(
      #|(true, true, false)
    ),
  )
}

///|
test "is_valid distinguishes accepted from rejected selectors" {
  let good = @selector.is_valid("p.intro")
  let bad = @selector.is_valid("p..bad")
  let empty = @selector.is_valid("")
  debug_inspect(
    (good, bad, empty),
    content=(
      #|(true, false, false)
    ),
  )
}

///|
test "matches_with_limits returns parse error for an over-budget selector" {
  // Tiny budget guarantees the selector won't fit; we expect a
  // SelectorError raised under the budget.
  let doc = sample_doc()
  let tiny = @selector.SelectorLimits::new(max_length=1)
  try @selector.matches_with_limits(doc, "p.intro", tiny) catch {
    err =>
      debug_inspect(
        err,
        content=(
          #|SelectorError("Selector too long")
        ),
      )
  } noraise {
    _ => fail("expected SelectorError under tight budget")
  }
}
