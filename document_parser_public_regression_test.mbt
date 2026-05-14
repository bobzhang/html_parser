///|
test "document parser scaffolds explicit html children into head and body" {
  let implicit = @html_parser.parse("<html><p>x</p></html>")
  assert_eq(
    implicit.to_html(pretty=false),
    "<html><head></head><body><p>x</p></body></html>",
  )
  let existing = @html_parser.parse(
    "<html><head><title>T</title></head><p>x</p></html>",
  )
  assert_eq(
    existing.to_html(pretty=false),
    "<html><head><title>T</title></head><body><p>x</p></body></html>",
  )
}

///|
test "document parser routes initial head elements into head" {
  let doc = @html_parser.parse(
    "\n<meta charset=utf-8><title>T</title><style>b{}</style><script>h</script><p>x</p>",
  )
  assert_eq(
    doc.to_html(pretty=false),
    "<html><head><meta charset=\"utf-8\"><title>T</title><style>b{}</style><script>h</script></head><body><p>x</p></body></html>",
  )
  let explicit = @html_parser.parse(
    "<html><head></head><title>T</title><p>x</p></html>",
  )
  assert_eq(
    explicit.to_html(pretty=false),
    "<html><head><title>T</title></head><body><p>x</p></body></html>",
  )
  let late = @html_parser.parse("<html><body>x</body><title>T</title></html>")
  assert_eq(
    late.to_html(pretty=false),
    "<html><head></head><body>x<title>T</title></body></html>",
  )
}
