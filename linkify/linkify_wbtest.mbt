///|
test "linkify helper edge contracts fail closed" {
  let bracketed = "http://example.com/a>"
  assert_eq(
    linkify_trim_trailing_end(bracketed, 0, bracketed.length()),
    bracketed.length() - 1,
  )
  assert_true(linkify_find_substring("x", "long") is None)
  assert_eq(linkify_broken_schema_context("bad://example.com", 6), true)
  assert_eq(string_view_contains("abc", ""), false)
  assert_eq(string_view_contains("abc", "abcd"), false)
  assert_eq(
    linkify_validate_candidate(
      "example.com",
      "bad://example.com",
      6,
      LinkifyConfig(),
    ),
    false,
  )
  assert_true(linkify_after_url_scheme("mailto:user@example.com") is None)
  assert_true(linkify_split_domain_for_tld(".") is None)
  guard linkify_split_domain_for_tld("..example.com..") is Some((base, tld)) else {
    fail("expected edge dots to be stripped before splitting TLD")
  }
  assert_eq(base, "example")
  assert_eq(tld, "com")
  assert_true(linkify_parse_uint("") is None)
  assert_eq(linkify_starts_with_digit(""), false)
  assert_eq(linkify_all_digits_or_dots(""), false)
  assert_eq(linkify_valid_ipv4("127.0.0.1"), true)
  assert_eq(linkify_valid_ipv4("255.255.255.255"), true)
  for
    host in [
      "", "1.2.3", "1.2.3.4.5", "1.2.3.400", "1..2.3", "1.2.3.", "a.2.3.4", "1.2.3.𠀀",
    ] {
    guard !linkify_valid_ipv4(host) else {
      fail("expected invalid IPv4 host: " + host)
    }
  }
}
