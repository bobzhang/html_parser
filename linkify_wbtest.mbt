///|
test "linkify helper edge contracts fail closed" {
  let bracketed = "http://example.com/a>"
  assert_eq(
    linkify_trim_trailing_end(bracketed, 0, bracketed.length()),
    bracketed.length() - 1,
  )
  assert_true(linkify_find_substring("x", "long") is None)
  assert_eq(linkify_broken_schema_context("bad://example.com", 6), true)
  assert_eq(
    linkify_validate_candidate(
      "example.com",
      "bad://example.com",
      6,
      LinkifyConfig::new(),
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
}
