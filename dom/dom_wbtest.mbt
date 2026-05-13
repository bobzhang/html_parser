///|
test "doctype builder preserves metadata" {
  let node = doctype(public_id="pub", system_id="sys", force_quirks=true)
  assert_true(node.kind is Doctype)
  assert_eq(node.name, "#doctype")
  assert_eq(node.data, "html")
  assert_true(node.public_id is Some("pub"))
  assert_true(node.system_id is Some("sys"))
  assert_true(node.force_quirks)
}

///|
test "node text skips sanitize escape sentinel text" {
  let hidden = text("hidden")
  hidden.sanitize_escape_only = true
  let root = fragment(children=[text("visible"), hidden])
  assert_eq(root.text(), "visible")
}
