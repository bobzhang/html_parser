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

///|
test "parser handles ruby annotation start exclusions" {
  let rtc_text = @html_parser.parse_fragment(
    "<ruby><rtc>a<rt>b</ruby>",
    collect_errors=true,
  )
  assert_eq(
    rtc_text.to_html(pretty=false),
    "<ruby><rtc>a<rt>b</rt></rtc></ruby>",
  )
  assert_eq(rtc_text.errors.length(), 1)
  assert_eq(rtc_text.errors[0].code, "end-tag-too-early")
  let paragraph_rt = @html_parser.parse_fragment("<p>a<rt>b")
  assert_eq(paragraph_rt.to_html(pretty=false), "<p>a</p><rt>b</rt>")
  let paragraph_rb = @html_parser.parse_fragment("<p>a<rb>b")
  assert_eq(paragraph_rb.to_html(pretty=false), "<p>a<rb>b</rb></p>")
  let loose = @html_parser.parse_fragment("<rb>a<rt>b<rtc>c<rb>d")
  assert_eq(
    loose.to_html(pretty=false),
    "<rb>a</rb><rt>b</rt><rtc>c</rtc><rb>d</rb>",
  )
  let special = @html_parser.parse_fragment(
    "<ruby><div>x</ruby>y</div>",
    collect_errors=true,
  )
  assert_eq(special.to_html(pretty=false), "<ruby><div>xy</div></ruby>")
  assert_eq(special.errors.length(), 2)
  assert_eq(special.errors[0].code, "unexpected-end-tag")
  assert_eq(special.errors[1].code, "expected-closing-tag-but-got-eof")
  let inline = @html_parser.parse_fragment(
    "<ruby><span>x</ruby>y</span>",
    collect_errors=true,
  )
  assert_eq(inline.to_html(pretty=false), "<ruby><span>x</span></ruby>y")
  assert_eq(inline.errors.length(), 2)
  assert_eq(inline.errors[0].code, "end-tag-too-early")
  assert_eq(inline.errors[1].code, "unexpected-end-tag")
  let stray = @html_parser.parse_fragment("x</ruby>y", collect_errors=true)
  assert_eq(stray.to_html(pretty=false), "xy")
  assert_eq(stray.errors.length(), 1)
  assert_eq(stray.errors[0].code, "unexpected-end-tag")
}
