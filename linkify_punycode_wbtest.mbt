// Whitebox coverage for private linkify punycode helper branches.

///|
test "punycode href helper handles passthrough and prefixless hosts" {
  assert_eq(
    linkify_punycode_href("mailto:тест@пример.рф"),
    "mailto:тест@пример.рф",
  )
  assert_eq(
    linkify_punycode_href("пример.рф/path?q=1"),
    "xn--e1afmkfd.xn--p1ai/path?q=1",
  )
  assert_eq(linkify_punycode_href("http://[::1]/x"), "http://[::1]/x")
  assert_true(linkify_punycode_label("Straße") is Some("strasse"))
}
