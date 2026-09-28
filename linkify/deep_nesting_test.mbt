// Regression test: `linkify_dom` walks with an explicit stack, so trees nested
// far deeper than the native call stack allows must not overflow it.

///|
test "linkify_dom handles deeply nested trees and skipped ancestors" {
  let mut cur = @dom.element("p", children=[@dom.text("see www.example.com")])
  for i in 0..<50000 {
    cur = @dom.element(if i == 100 { "code" } else { "b" }, children=[
      cur,
      @dom.text(if i == 99 { "inside www.skip.com" } else { "www.top.com" }),
    ])
  }
  let root = @linkify.linkify_dom(@dom.fragment(children=[cur]))
  // Count anchors iteratively: every level above the `code` element gets one,
  // while the text nodes nested inside it stay untouched.
  let mut anchors = 0
  let mut www_texts = 0
  let stack = [root]
  while stack.pop() is Some(node) {
    if node.kind == Element && node.name == "a" {
      anchors += 1
    }
    if node.kind == Text && node.data.contains("www.") {
      www_texts += 1
    }
    for child in node.children {
      stack.push(child)
    }
  }
  inspect(anchors, content="49899")
  // 49899 anchor texts plus 102 untouched texts inside `code` (levels 0..=100
  // and the innermost paragraph).
  inspect(
    www_texts,
    content=(
      #|50001
    ),
  )
}
