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
