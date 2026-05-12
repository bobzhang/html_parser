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

///|
test "CLI option helpers cover equals and no-path plans" {
  guard cli_option_value_from_equals("--format=", "--format") is Some(value) else {
    fail("expected empty equals-form option value")
  }
  assert_eq(value, "")
  assert_true(
    cli_option_value_from_equals("--format=text", "--selector") is None,
  )
  guard cli_read_plan(["--format=text"]) is CliImmediate(result) else {
    fail("expected no-path read plan to be immediate")
  }
  assert_eq(result.exit_code, 1)
  assert_true(result.stderr.contains("usage: justhtml"))
}
