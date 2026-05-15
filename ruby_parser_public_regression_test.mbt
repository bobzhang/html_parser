///|
test "parser generates implied ruby annotation end tags" {
  let repeated_base = @html_parser.parse_fragment(
    "<ruby><rb>a<rb>b</ruby>",
    collect_errors=true,
  )
  assert_eq(
    repeated_base.to_html(pretty=false),
    "<ruby><rb>a</rb><rb>b</rb></ruby>",
  )
  assert_eq(repeated_base.errors.length(), 1)
  assert_eq(repeated_base.errors[0].code, "end-tag-too-early")
  let repeated_text = @html_parser.parse_fragment(
    "<ruby><rb>a<rt>b<rt>c</ruby>",
    collect_errors=true,
  )
  assert_eq(
    repeated_text.to_html(pretty=false),
    "<ruby><rb>a</rb><rt>b</rt><rt>c</rt></ruby>",
  )
  assert_eq(repeated_text.errors.length(), 1)
  assert_eq(repeated_text.errors[0].code, "end-tag-too-early")
  let rp_rt = @html_parser.parse_fragment(
    "<ruby><rp>(<rt>a<rp>)</ruby>",
    collect_errors=true,
  )
  assert_eq(
    rp_rt.to_html(pretty=false),
    "<ruby><rp>(</rp><rt>a</rt><rp>)</rp></ruby>",
  )
  assert_eq(rp_rt.errors.length(), 1)
  assert_eq(rp_rt.errors[0].code, "end-tag-too-early")
}
