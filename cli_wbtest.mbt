///|
test "CLI HTML error formatter preserves sanitizer and selector messages" {
  assert_eq(cli_html_error_message(UnsafeHtml("unsafe node")), "unsafe node")
  assert_eq(
    cli_html_error_message(SelectorError("bad selector")),
    "bad selector",
  )
  assert_eq(
    cli_html_error_message(InvalidSerialization("bad serialization")),
    "bad serialization",
  )
}
