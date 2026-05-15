///|
test "parser normalizes leading BOM and CRLF in text comment and attr" {
  let doc = @html_parser.parse_fragment(
    "\u{FEFF}<p title='a\rb'>a\r\nb<!--x\ry--></p>",
  )
  assert_eq(doc.to_html(pretty=false), "<p title=\"a\nb\">a\nb<!--x\ny--></p>")
  assert_eq(doc.to_text(separator="", strip=false), "a\nb")
}
