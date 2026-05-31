// Blackbox snapshot tests for the per-element action transforms:
// drop, unwrap, escape, empty, and the `decide` callback variant.
//
// Each test starts from a small DOM built with @dom.* constructors
// and snapshots the result via @ser.to_html, since transforms
// produce DOM trees (large to debug-dump verbatim).

///|
test "drop removes matching elements" {
  let frag = @dom.fragment(children=[
    @dom.element("p", children=[@dom.text("keep")]),
    @dom.element("script", children=[@dom.text("alert(1)")]),
    @dom.element("p", children=[@dom.text("also keep")]),
  ])
  let out = @transform.apply_transforms(frag, [
    @transform.TransformSpec::drop("script"),
  ])
  inspect(
    @ser.to_html(out, pretty=false),
    content=(
      #|<p>keep</p><p>also keep</p>
    ),
  )
}

///|
test "unwrap removes the tag but keeps children" {
  let frag = @dom.fragment(children=[
    @dom.element("font", attrs={ "color": Some("red") }, children=[
      @dom.text("loud"),
    ]),
  ])
  let out = @transform.apply_transforms(frag, [
    @transform.TransformSpec::unwrap("font"),
  ])
  inspect(
    @ser.to_html(out, pretty=false),
    content=(
      #|loud
    ),
  )
}

///|
test "escape converts a tag to its text representation" {
  let frag = @dom.fragment(children=[
    @dom.element("code", children=[@dom.text("<x>")]),
  ])
  let out = @transform.apply_transforms(frag, [
    @transform.TransformSpec::escape("code"),
  ])
  inspect(
    @ser.to_html(out, pretty=false),
    content=(
      #|&lt;code&gt;&lt;x&gt;&lt;/code&gt;
    ),
  )
}

///|
test "empty drops all children of matching elements" {
  let frag = @dom.fragment(children=[
    @dom.element("div", children=[
      @dom.element("p", children=[@dom.text("inner")]),
      @dom.text(" trailing "),
    ]),
  ])
  let out = @transform.apply_transforms(frag, [
    @transform.TransformSpec::empty("div"),
  ])
  inspect(
    @ser.to_html(out, pretty=false),
    content=(
      #|<div></div>
    ),
  )
}

///|
test "decide picks an action per matching node" {
  // Drop links to example.com; unwrap all other links.
  let frag = @dom.fragment(children=[
    @dom.element("a", attrs={ "href": Some("https://example.com") }, children=[
      @dom.text("bad"),
    ]),
    @dom.element("a", attrs={ "href": Some("/local") }, children=[
      @dom.text("good"),
    ]),
  ])
  let out = @transform.apply_transforms(frag, [
    @transform.TransformSpec::decide("a", node => {
      match node.attrs().get("href") {
        Some(Some(href)) =>
          if href.contains("example.com") {
            Drop
          } else {
            Unwrap
          }
        _ => Keep
      }
    }),
  ])
  inspect(
    @ser.to_html(out, pretty=false),
    content=(
      #|good
    ),
  )
}
