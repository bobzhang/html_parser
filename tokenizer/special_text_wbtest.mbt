///|
test "script text char writer fails closed on surrogate-split offsets" {
  let value = "x😀>"
  let mid_surrogate = 2
  let out = StringBuilder::new()
  let errors : Array[SpecialTextError] = []
  assert_eq(
    write_script_text_char(value, mid_surrogate, out, errors),
    mid_surrogate,
  )
  assert_eq(out.to_string(), "")
  assert_eq(errors.length(), 0)
}
