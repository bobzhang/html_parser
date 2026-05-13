///|
test "source helpers preserve UTF-16 offsets and normalize CRLF" {
  assert_eq(eof_error_pos("a😀"), 1)
  assert_eq(eof_error_pos("a😀\n"), 4)

  let (line, col) = line_col_at("a😀\nb", 4)
  assert_eq(line, 2)
  assert_eq(col, 1)

  let (eof_line, eof_col) = eof_line_col("a😀\n")
  assert_eq(eof_line, 2)
  assert_eq(eof_col, 0)

  assert_eq(normalize_newlines("a\r\n😀\rb"), "a\n😀\nb")
  assert_eq(
    normalize_bogus_comment_data("a\u{0000}\r\n😀"),
    "a\u{FFFD}\n😀",
  )

  let out = StringBuilder::new()
  assert_eq(write_normalized_char("x😀>", 2, out), 2)
  assert_eq(out.to_string(), "")

  assert_eq(strip_leading_bom("\u{FEFF}<p>").to_owned(), "<p>")
  assert_true(view_starts_with_at("ab😀", 2, "😀"))
  assert_true(!view_starts_with_at("ab😀", 3, "😀"))
}
