///|
test "htmlfmt renders pretty html by default" {
  let result = run_htmlfmt(["<article><p>Hello <b>MoonBit</b></p></article>"])
  assert_eq(result.exit_code, 0)
  assert_eq(
    result.stdout,
    "<article>\n  <p>Hello <b>MoonBit</b></p>\n</article>",
  )
}

///|
test "htmlfmt renders compact html when requested" {
  let result = run_htmlfmt([
    "--compact", "<p class='intro'>Hello <b>MoonBit</b></p>",
  ])
  assert_eq(result.exit_code, 0)
  assert_eq(result.stdout, "<p class=\"intro\">Hello <b>MoonBit</b></p>")
}

///|
test "htmlfmt reports missing input parse failures" {
  let result = run_htmlfmt([])
  assert_eq(result.exit_code, 2)
  assert_true(result.stderr.contains("'html' requires at least 1 values"))
  assert_true(result.stderr.contains("Usage: htmlfmt"))
}

///|
test "htmlfmt reports argparse failures" {
  let result = run_htmlfmt(["<p>one</p>", "<p>two</p>"])
  assert_eq(result.exit_code, 2)
  assert_true(result.stderr.contains("unexpected value '<p>two</p>'"))
  assert_true(result.stderr.contains("Usage: htmlfmt"))
}
