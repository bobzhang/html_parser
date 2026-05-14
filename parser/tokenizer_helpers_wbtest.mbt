// Whitebox regressions for tokenizer helpers used by the parser package.

///|
test "entity helpers preserve unresolved names and attribute boundaries" {
  assert_true(
    @tok.consume_named_entity_with_errors("&unknown;", 0, in_attribute=false)
    is None,
  )
  assert_true(
    @tok.consume_named_entity_with_errors("&unknown", 0, in_attribute=false)
    is None,
  )
  guard @tok.consume_named_entity_with_errors("&copy.", 0, in_attribute=true)
    is Some(decoded_attr) else {
    fail("expected punctuation-delimited legacy attribute entity")
  }
  assert_eq(decoded_attr.value, "\u{00A9}")
  assert_eq(decoded_attr.next, 5)
  assert_eq(decoded_attr.errors.length(), 1)
  assert_true(
    @tok.legacy_entity_blocked_in_attribute("&copyx", 5, in_attribute=true),
  )
  assert_true(
    @tok.legacy_entity_blocked_in_attribute("&copy0", 5, in_attribute=true),
  )
  assert_true(
    @tok.legacy_entity_blocked_in_attribute("&copy=", 5, in_attribute=true),
  )
  assert_eq(
    @tok.legacy_entity_blocked_in_attribute("&copyx", 5, in_attribute=false),
    false,
  )
  assert_eq(
    @tok.legacy_entity_blocked_in_attribute("&copy.", 5, in_attribute=true),
    false,
  )
  let unresolved = @tok.tokenize("&unknown; &unknown", collect_errors=true)
  guard unresolved.tokens[0] is Characters("&unknown; &unknown") else {
    fail("expected unresolved named references to stay literal")
  }
  assert_eq(unresolved.errors.length(), 0)
}

///|
test "doctype helpers keep empty eof and unquoted identifiers distinct" {
  assert_eq(eof_error_pos(""), 0)
  assert_eq(@tok.doctype_eof_error_offset(""), 0)
  let errors : Array[@tok.DoctypeExternalError] = []
  let (value, next, closed) = @tok.parse_quoted_doctype_value_at(
    "identifier", 0, errors,
  )
  assert_true(value is None)
  assert_eq(next, 0)
  assert_eq(closed, false)
  assert_eq(errors.length(), 0)
  let external = @tok.parse_doctype_external("", true)
  assert_true(external.public_id is None)
  assert_true(external.system_id is None)
  assert_eq(external.force_quirks, false)
  assert_eq(external.errors.length(), 0)
}
