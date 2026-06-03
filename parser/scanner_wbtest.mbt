// Whitebox regressions for parser-facing scanner helpers.

///|
fn assert_script_scan(
  value : StringView,
  expected : String,
  end_start : Int?,
) -> Unit raise {
  let scan = @tok.scan_script_text(value, 0)
  assert_eq(scan.data, expected)
  match end_start {
    Some(expected_end) => {
      guard scan.end_start is Some(actual_end) else {
        fail("expected script end tag")
      }
      assert_eq(actual_end, expected_end)
    }
    None => assert_true(scan.end_start is None)
  }
  assert_eq(scan.errors.length(), 0)
}

///|
test "script text scanner covers escaped and double escaped edge states" {
  assert_script_scan("<!---x</script>", "<!---x", Some(6))
  assert_script_scan("<!---<x</script>", "<!---<x", Some(7))
  assert_script_scan("<!----x</script>", "<!----x", Some(7))
  assert_script_scan("<!-----x</script>", "<!-----x", Some(8))
  assert_script_scan("<!----<x</script>", "<!----<<x", Some(8))
  assert_script_scan("<!--</not</script>", "<!--</not", Some(9))
  assert_script_scan("<!--<!</script>", "<!--<!", Some(6))
  assert_script_scan("abc</script x", "abc", Some(3))
  assert_script_scan(
    "<!--<script>-x</script>z</script>",
    "<!--<script>-x</script>z",
    Some(24),
  )
  assert_script_scan(
    "<!--<script>-<!x</script>tail</script>",
    "<!--<script>-<!x</script>tail",
    Some(29),
  )
  assert_script_scan("<!--<script>--></script>", "<!--<script>-->", Some(15))
  assert_script_scan(
    "<!--<script>---x</script>tail</script>",
    "<!--<script>---x</script>tail",
    Some(29),
  )
  assert_script_scan(
    "<!--<script>--<x</script>tail</script>",
    "<!--<script>--<x",
    Some(16),
  )
  assert_script_scan(
    "<!--<script>--x</script>tail</script>",
    "<!--<script>--x</script>tail",
    Some(28),
  )
  assert_script_scan(
    "<!--<script><!x</script>tail</script>",
    "<!--<script><!x</script>tail",
    Some(28),
  )
  assert_script_scan(
    "<!--<script></not</script>z</script>",
    "<!--<script></not</script>z",
    Some(27),
  )
  assert_script_scan(
    "<!--<script></style x</script>tail</script>",
    "<!--<script></style x</script>tail",
    Some(34),
  )
  assert_script_scan(
    "<!--<script><x</script>z</script>",
    "<!--<script><x",
    Some(14),
  )
  assert_script_scan(
    "<!--<script x</script>tail</script>",
    "<!--<script x</script>tail",
    Some(26),
  )
  assert_script_scan(
    "<!--<script\tx</script>tail</script>",
    "<!--<script\tx</script>tail",
    Some(26),
  )
  assert_script_scan(
    "<!--<script\u{000C}>x</script>tail</script>",
    "<!--<script\u{000C}>x</script>tail",
    Some(27),
  )
  assert_script_scan(
    "<!--<script/>x</script>tail</script>",
    "<!--<script/>x</script>tail",
    Some(27),
  )
  assert_script_scan(
    "<!--<scriptx>x</script>tail</script>",
    "<!--<scriptx>x",
    Some(14),
  )
  assert_script_scan("<!--<script><", "<!--<script><", None)
}

///|
test "scanner helpers fail closed on surrogate-split offsets" {
  let value = "x😀>"
  let mid_surrogate = 2
  let comment_scan = @tok.scan_comment_data(value, mid_surrogate)
  assert_eq(comment_scan.data, "")
  assert_eq(comment_scan.end, value.length())
  assert_true(comment_scan.eof)
  assert_eq(comment_scan.errors.length(), 1)
  assert_eq(comment_scan.errors[0].code, "eof-in-comment")

  let normalized = StringBuilder()
  assert_eq(
    @syn.write_normalized_char(value, mid_surrogate, normalized),
    mid_surrogate,
  )
  assert_eq(normalized.to_string(), "")

  assert_true(find_markup_close(value, mid_surrogate) is None)
  assert_true(
    @tok.find_matching_end_tag("x😀</script>", mid_surrogate, "script")
    is None,
  )
  assert_eq(
    @tok.matching_end_tag_error_pos("x😀</script>", mid_surrogate),
    eof_error_pos("x😀</script>"),
  )

  let doctype_errors : Array[@tok.DoctypeExternalError] = []
  assert_eq(
    @tok.normalize_doctype_value(
      value,
      mid_surrogate,
      value.length(),
      doctype_errors,
    ),
    "",
  )
  assert_eq(doctype_errors.length(), 0)
  let (name, name_errors) = @tok.parse_lower_name_value_replacing_nulls(
    value,
    mid_surrogate,
    value.length(),
  )
  assert_eq(name, "")
  assert_eq(name_errors.length(), 0)
}
