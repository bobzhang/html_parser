///|
test "parser inserts keygen and fragment frame as empty non-void elements" {
  let keygen = @html_parser.parse_fragment(
    "<p>a<keygen>b</p><keygen>x</keygen>",
    collect_errors=true,
  )
  assert_eq(
    keygen.to_html(pretty=false),
    "<p>a<keygen></keygen>b</p><keygen></keygen>x",
  )
  assert_eq(keygen.errors.length(), 1)
  assert_eq(keygen.errors[0].code, "unexpected-end-tag")
  let self_closing_keygen = @html_parser.parse_fragment("<keygen/>x")
  assert_eq(self_closing_keygen.to_html(pretty=false), "<keygen></keygen>x")
  let frame = @html_parser.parse_fragment(
    "<p>a<frame>b</p><frame>x</frame>",
    collect_errors=true,
  )
  assert_eq(
    frame.to_html(pretty=false),
    "<p>a<frame></frame>b</p><frame></frame>x",
  )
  assert_eq(frame.errors.length(), 1)
  assert_eq(frame.errors[0].code, "unexpected-end-tag")
}
