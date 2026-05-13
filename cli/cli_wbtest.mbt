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

///|
test "CLI sanitize and cleanup error paths report transform errors" {
  let raising_policy = @san.SanitizationPolicy::new(
    ["p"],
    unsafe_handling=Raise,
  )
  guard cli_sanitize_or_error(
      @dom.fragment(children=[
        @dom.element("script", children=[@dom.text("bad")]),
      ]),
      Some(raising_policy),
    )
    is Some(sanitize_result) else {
    fail("expected sanitize helper to catch unsafe HTML")
  }
  assert_eq(sanitize_result.exit_code, 2)
  assert_true(sanitize_result.stderr.contains("Unsafe tag 'script'"))
  guard cli_apply_cleanup_or_error(
      @dom.fragment(children=[
        @dom.element("script", children=[@dom.text("bad")]),
      ]),
      true,
      Some(raising_policy),
    )
    is Some(cleanup_result) else {
    fail("expected cleanup helper to catch unsafe HTML")
  }
  assert_eq(cleanup_result.exit_code, 2)
  assert_true(cleanup_result.stderr.contains("Unsafe tag 'script'"))
  let sanitize_options = cli_default_options()
  sanitize_options.path = Some("-")
  let sanitize_pipeline = cli_run_parsed(
    @dom.fragment(children=[@dom.element("script", children=[@dom.text("bad")])]),
    sanitize_options,
    true,
    Some(raising_policy),
  )
  assert_eq(sanitize_pipeline.exit_code, 2)
  assert_true(sanitize_pipeline.stderr.contains("Unsafe tag 'script'"))
  let cleanup_options = cli_default_options()
  cleanup_options.path = Some("-")
  cleanup_options.cleanup = true
  let cleanup_pipeline = cli_run_parsed(
    @dom.fragment(children=[@dom.element("script", children=[@dom.text("bad")])]),
    cleanup_options,
    true,
    Some(raising_policy),
  )
  assert_eq(cleanup_pipeline.exit_code, 2)
  assert_true(cleanup_pipeline.stderr.contains("Unsafe tag 'script'"))
}
