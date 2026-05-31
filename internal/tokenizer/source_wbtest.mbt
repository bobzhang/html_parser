///|
test "tokenizer eof helper reports empty input origin" {
  let tokenizer = SourceTokenizer::new(
    "",
    collect_errors=true,
    xml_coercion=false,
  )
  assert_true(tokenizer.advance_char() is None)
  assert_eq(tokenizer.pos, 0)
  assert_eq(tokenizer.step(), true)
  tokenizer.parse_characters()
  assert_eq(tokenizer.tokens.length(), 0)
  tokenizer.error_at_eof("eof-before-tag-name")
  assert_eq(tokenizer.errors.length(), 1)
  assert_eq(tokenizer.errors[0].code, "eof-before-tag-name")
  guard tokenizer.errors[0].line is Some(1) else {
    fail("expected empty input EOF line")
  }
  guard tokenizer.errors[0].column is Some(0) else {
    fail("expected empty input EOF column")
  }
}

///|
test "tokenizer attribute helper tolerates delimiter at eof" {
  let tokenizer = SourceTokenizer::new(
    ">",
    collect_errors=true,
    xml_coercion=false,
  )
  let attrs : Map[String, String?] = {}
  tokenizer.parse_attribute(attrs)
  assert_eq(attrs.length(), 0)
  assert_eq(tokenizer.pos, 1)
  assert_eq(tokenizer.errors.length(), 0)
}
