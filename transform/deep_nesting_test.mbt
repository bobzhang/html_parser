// Regression tests: transform walks use explicit stacks, so trees nested far
// deeper than the native call stack allows must not overflow it.

///|
let deep_nesting_depth : Int = 50000

///|
/// `<b><div><b>...<p>www.example.com <i></i><!--c--></p>...</b></div></b>`
/// inside a document, with a comment and whitespace text at every level.
fn deep_nested_document() -> @dom.Node {
  let mut cur = @dom.element("p", children=[
    @dom.text("x  www.example.com "),
    @dom.element("i"),
    @dom.comment("c"),
  ])
  for i in 0..<deep_nesting_depth {
    cur = @dom.element(if i % 2 == 0 { "b" } else { "div" }, children=[
      cur,
      @dom.comment("z"),
      @dom.text("  "),
    ])
  }
  @dom.document(children=[@dom.element("body", children=[cur])])
}

///|
/// Iteratively count element names, comments, anchors' text, and max depth.
fn deep_nesting_summary(root : @dom.Node) -> String {
  let mut max_depth = 0
  let mut b = 0
  let mut div = 0
  let mut i = 0
  let mut a = 0
  let mut comments = 0
  let mut texts = 0
  let stack : Array[(@dom.Node, Int)] = [(root, 0)]
  while stack.pop() is Some((node, depth)) {
    if depth > max_depth {
      max_depth = depth
    }
    match node.kind {
      Element =>
        match node.name {
          "b" => b += 1
          "div" => div += 1
          "i" => i += 1
          "a" => a += 1
          _ => ()
        }
      Comment => comments += 1
      Text => texts += 1
      _ => ()
    }
    for child in node.children {
      stack.push((child, depth + 1))
    }
  }
  "depth=\{max_depth} b=\{b} div=\{div} i=\{i} a=\{a} comments=\{comments} texts=\{texts}"
}

///|
test "deeply nested trees do not overflow selector transforms" {
  let reports = Ref(0)
  let out = @transform.apply_transforms(deep_nested_document(), [
    @transform.TransformSpec::unwrap("b", report=(_, _) => reports.val += 1),
    @transform.TransformSpec::set_attrs("div", { "x": Some("1") }),
  ])
  inspect(
    deep_nesting_summary(out),
    content="depth=25003 b=0 div=25000 i=1 a=0 comments=50001 texts=50001",
  )
  inspect(reports.val, content="25000")
}

///|
test "deeply nested trees do not overflow decide and node-kind transforms" {
  let out = @transform.apply_transforms(deep_nested_document(), [
    @transform.TransformSpec::decide("*", n => {
      if n.name == "div" {
        Unwrap
      } else {
        Keep
      }
    }),
    @transform.TransformSpec::drop_comments(),
    @transform.TransformSpec::drop_foreign_namespaces(),
  ])
  inspect(
    deep_nesting_summary(out),
    content="depth=25003 b=25000 div=0 i=1 a=0 comments=0 texts=50001",
  )
}

///|
test "deeply nested trees do not overflow cleanup and linkify transforms" {
  let out = @transform.apply_transforms(deep_nested_document(), [
    @transform.TransformSpec::collapse_whitespace(),
    @transform.TransformSpec::prune_empty("i"),
    @transform.TransformSpec::linkify(),
  ])
  inspect(
    deep_nesting_summary(out),
    content=(
      #|depth=50004 b=25000 div=25000 i=0 a=1 comments=50001 texts=50003
    ),
  )
}
