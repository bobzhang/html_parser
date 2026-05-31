# `@selector`

CSS-style queries against a DOM tree. Supports tag, class, id,
attribute, compound, descendant/child combinators, selector lists, and
the common pseudo-classes.

The examples below are `mbt check` blocks and run as part of
`moon test selector`.

## Query vs match vs root

`query` and `query_one` return matching **descendants** of the node
you pass — the root itself is not considered. To test the root,
use `matches`.

```mbt check
///|
test "readme selector descendants only" {
  let div = @dom.element("div", attrs={ "id": Some("r") }, children=[
    @dom.element("p", attrs={ "class": Some("hit") }),
    @dom.element("p"),
  ])
  debug_inspect(
    (
      @selector.query(div, "p").length(), // descendants
      @selector.query(div, "#r").length(), // root excluded
      @selector.matches(div, "#r"), // root included
    ),
    content=(
      #|(2, 0, true)
    ),
  )
}
```

## Selector grammar at a glance

```mbt check
///|
test "readme selector grammar" {
  let div = @dom.element("div", children=[
    @dom.element("p", attrs={ "class": Some("intro lede") }, children=[
      @dom.text("first"),
    ]),
    @dom.element("p", attrs={ "class": Some("intro") }, children=[
      @dom.text("second"),
    ]),
    @dom.element("p", children=[@dom.text("third")]),
  ])
  // Tag, class, attribute presence, compound (tag+class), and list.
  debug_inspect(
    (
      @selector.query(div, "p").length(),
      @selector.query(div, ".intro").length(),
      @selector.query(div, "[class]").length(),
      @selector.query(div, "p.intro.lede").length(),
      @selector.query(div, "p.lede, p:not(.intro)").length(),
    ),
    content=(
      #|(3, 2, 2, 1, 2)
    ),
  )
}
```

## Validating a selector before using it

`is_valid` runs the parser without touching any DOM — useful for
sanitizing user-supplied selectors.

```mbt check
///|
test "readme is_valid" {
  debug_inspect(
    (@selector.is_valid("p.intro"), @selector.is_valid("p..bad")),
    content=(
      #|(true, false)
    ),
  )
}
```

## Budgeted matching

`matches_with_limits` raises `SelectorError` when a selector or its
match work exceeds the budget you pass — useful when the selector
comes from untrusted input.

```mbt nocheck
match @selector.matches_with_limits(node, sel, @selector.SelectorLimits::new())
catch {
  err => log("rejected: \{err}")
}
```
