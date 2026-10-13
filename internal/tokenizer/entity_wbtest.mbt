///|
test "decode_entities_with_errors reports invalid numeric reference" {
  let result = decode_entities_with_errors("&#xZZZ;", in_attribute=false)
  debug_inspect(
    result,
    content=(
      #|{ data: <StringView: "&#xZZZ;">, errors: [] }
    ),
  )
}

///|
test "semicolon named entity table is sorted for binary search" {
  for i in 1..<semicolon_named_entities.length() {
    let (prev, _) = semicolon_named_entities[i - 1]
    let (next, _) = semicolon_named_entities[i]
    assert_true(compare_entity_name(prev, next) < 0)
  }
}

///|
test "semicolon named entity lookup finds the ends and rejects near misses" {
  assert_eq(semicolon_named_entities.length(), 2125)
  assert_eq(semicolon_named_entity_value("AElig"), Some("\u{00C6}"))
  assert_eq(semicolon_named_entity_value("zwnj"), Some("\u{200C}"))
  assert_eq(semicolon_named_entity_value("amp"), Some("&"))
  assert_eq(semicolon_named_entity_value("AMP"), Some("&"))
  assert_eq(semicolon_named_entity_value("am"), None)
  assert_eq(semicolon_named_entity_value("ampx"), None)
  assert_eq(semicolon_named_entity_value("Amp"), None)
  assert_eq(semicolon_named_entity_value(""), None)
}
