///|
test "byte decoder helper falls back to windows1252 for unknown labels" {
  let (decoded, encoding) = decode_supported_html_encoding(
    b"<p>\x80</p>", "x-unknown",
  )
  assert_eq(encoding, "windows-1252")
  assert_eq(decoded, "<p>\u{20AC}</p>")
}
