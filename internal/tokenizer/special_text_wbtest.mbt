///|
test "script text char skipper fails closed on surrogate-split offsets" {
  let value = "x😀>"
  let mid_surrogate = 2
  let errors : Array[SpecialTextError] = []
  assert_eq(skip_script_text_char(value, mid_surrogate, errors), mid_surrogate)
  assert_eq(errors.length(), 0)
}

///|
test "script text char writer fails closed on surrogate-split offsets" {
  let value = "x😀>"
  let mid_surrogate = 2
  let out = StringBuilder()
  let errors : Array[SpecialTextError] = []
  assert_eq(
    write_script_text_char(value, mid_surrogate, out, errors),
    mid_surrogate,
  )
  assert_eq(out.to_string(), "")
  assert_eq(errors.length(), 0)
}

///|
test "special_text_decodes_entities reports per-element behavior" {
  let title = special_text_decodes_entities("title")
  let script = special_text_decodes_entities("script")
  let textarea = special_text_decodes_entities("textarea")
  let style = special_text_decodes_entities("style")
  debug_inspect(
    (title, script, textarea, style),
    content=(
      #|(true, false, true, false)
    ),
  )
}
