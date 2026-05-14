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
