# `@transform`

A composable DOM rewrite pipeline. Build an array of `TransformSpec`
values and hand them to `apply_transforms` along with a node. Each
spec runs over the tree in order and can drop, unwrap, escape, edit,
or annotate matching elements.

The examples below are `mbt check` blocks and run as part of
`moon test transform`.

## The five element actions

```mbt nocheck
///|
pub(all) enum DecideAction {
  Keep // leave alone
  Drop // remove the element and its subtree
  Unwrap // remove the tag but splice children up
  Empty // keep the tag, remove the children
  Escape // serialize the tag to its HTML-escaped text form
}
```

Each action has a dedicated constructor (`drop`, `unwrap`, `escape`,
`empty`) and `decide` runs your callback to pick per node.

```mbt check
///|
test "readme transform actions" {
  let frag = @dom.fragment(children=[
    @dom.element("script", children=[@dom.text("alert(1)")]),
    @dom.element("font", children=[@dom.text("loud")]),
  ])
  let out = @transform.apply_transforms(frag, [
    @transform.TransformSpec::drop("script"),
    @transform.TransformSpec::unwrap("font"),
  ])
  inspect(
    @ser.to_html(out, pretty=false),
    content=(
      #|loud
    ),
  )
}
```

## Shaping attributes

`drop_attrs`, `set_attrs`, `allowlist_attrs`, `merge_attrs`, and
`edit_attrs` cover the common attribute changes. `merge_attrs` is
especially handy for token-list attributes like `rel`:

```mbt check
///|
test "readme transform merge_attrs" {
  let frag = @dom.fragment(children=[
    @dom.element(
      "a",
      attrs={ "href": Some("https://example.com"), "rel": Some("nofollow") },
      children=[@dom.text("link")],
    ),
  ])
  let out = @transform.apply_transforms(frag, [
    @transform.TransformSpec::merge_attrs("a", attr="rel", tokens=[
      "noopener", "noreferrer",
    ]),
  ])
  inspect(
    @ser.to_html(out, pretty=false),
    content=(
      #|<a href="https://example.com" rel="nofollow noopener noreferrer">link</a>
    ),
  )
}
```

## Composing with `stage`

`stage` bundles a set of transforms into one logical spec — useful
when you want to keep your top-level pipeline short.

```mbt check
///|
test "readme transform stage" {
  let frag = @dom.fragment(children=[
    @dom.element("script", children=[@dom.text("evil")]),
    @dom.comment(" tracking "),
    @dom.element("p", children=[@dom.text("keep")]),
  ])
  let cleanup = @transform.TransformSpec::stage([
    @transform.TransformSpec::drop("script"),
    @transform.TransformSpec::drop_comments(),
  ])
  let out = @transform.apply_transforms(frag, [cleanup])
  inspect(
    @ser.to_html(out, pretty=false),
    content=(
      #|<p>keep</p>
    ),
  )
}
```

## Feature-flagging with `enabled`

Every spec constructor accepts `enabled=false` to skip the step
without restructuring the pipeline.

```mbt check
///|
test "readme transform enabled flag" {
  let frag = @dom.fragment(children=[
    @dom.element("script", children=[@dom.text("kept")]),
  ])
  let out = @transform.apply_transforms(frag, [
    @transform.TransformSpec::drop("script", enabled=false),
  ])
  inspect(
    @ser.to_html(out, pretty=false),
    content=(
      #|<script>kept</script>
    ),
  )
}
```

## Telemetry hooks

Every spec constructor also accepts `hook=` (called per matching
node) and `report=` (called with a string code and optional node when
the spec changes something). They let you collect counters and audit
trails without altering the rewrite itself.
