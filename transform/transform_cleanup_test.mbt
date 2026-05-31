// Blackbox snapshot tests for cleanup transforms: prune_empty,
// collapse_whitespace, drop_comments, drop_doctype, and stage
// composition.

///|
test "prune_empty removes elements with no children" {
  let frag = @dom.fragment(children=[
    @dom.element("p", children=[@dom.text("keep")]),
    @dom.element("p"),
    @dom.element("p", children=[@dom.text("also keep")]),
  ])
  let out = @transform.apply_transforms(frag, [
    @transform.TransformSpec::prune_empty("p"),
  ])
  inspect(
    @ser.to_html(out, pretty=false),
    content=(
      #|<p>keep</p><p>also keep</p>
    ),
  )
}

///|
test "collapse_whitespace normalizes runs of inter-element whitespace" {
  let frag = @dom.fragment(children=[
    @dom.text("  a   "),
    @dom.element("b", children=[@dom.text("  b  ")]),
    @dom.text("    c    "),
  ])
  let out = @transform.apply_transforms(frag, [
    @transform.TransformSpec::collapse_whitespace(),
  ])
  inspect(
    @ser.to_html(out, pretty=false),
    content=(
      #| a <b> b </b> c 
    ),
  )
}

///|
test "drop_comments removes comment nodes" {
  let frag = @dom.fragment(children=[
    @dom.element("p", children=[@dom.text("hi")]),
    @dom.comment(" tracking pixel "),
  ])
  let out = @transform.apply_transforms(frag, [
    @transform.TransformSpec::drop_comments(),
  ])
  inspect(
    @ser.to_html(out, pretty=false),
    content=(
      #|<p>hi</p>
    ),
  )
}

///|
test "drop_doctype removes the doctype node" {
  let doc = @dom.document(children=[
    @dom.doctype(),
    @dom.element("html", children=[@dom.text("body")]),
  ])
  let out = @transform.apply_transforms(doc, [
    @transform.TransformSpec::drop_doctype(),
  ])
  inspect(
    @ser.to_html(out, pretty=false),
    content=(
      #|<html>body</html>
    ),
  )
}

///|
test "stage groups transforms into a sub-pipeline" {
  // `stage` lets you bundle a set of transforms into a single spec —
  // useful when you want one logical step in a larger pipeline.
  let frag = @dom.fragment(children=[
    @dom.element("div", children=[
      @dom.element("p", children=[@dom.text("keep")]),
      @dom.element("script", children=[@dom.text("alert(1)")]),
      @dom.comment(" tracking "),
    ]),
  ])
  let cleanup = @transform.TransformSpec::stage([
    @transform.TransformSpec::drop("script"),
    @transform.TransformSpec::drop_comments(),
  ])
  let out = @transform.apply_transforms(frag, [cleanup])
  inspect(
    @ser.to_html(out, pretty=false),
    content=(
      #|<div><p>keep</p></div>
    ),
  )
}

///|
test "enabled=false skips a transform without removing it from the pipeline" {
  // Useful for feature-flagging without restructuring the pipeline.
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
