///|
test "fragment parser ignores shell start tags in body mode" {
  let head = @html_parser.parse_fragment(
    "<p>a<head>b</head>c",
    collect_errors=true,
  )
  assert_eq(head.to_html(pretty=false), "<p>abc</p>")
  assert_eq(head.errors.length(), 2)
  assert_eq(head.errors[0].code, "unexpected-start-tag")
  assert_eq(head.errors[1].code, "unexpected-end-tag")
  let body = @html_parser.parse_fragment(
    "<p>a<body class=x>b</body>c",
    collect_errors=true,
  )
  assert_eq(body.to_html(pretty=false), "<p>abc</p>")
  assert_eq(body.errors.length(), 1)
  assert_eq(body.errors[0].code, "unexpected-start-tag")
  let html = @html_parser.parse_fragment(
    "<p>a<html lang=en>b</html>c",
    collect_errors=true,
  )
  assert_eq(html.to_html(pretty=false), "<p>abc</p>")
  assert_eq(html.errors.length(), 1)
  assert_eq(html.errors[0].code, "unexpected-start-tag")
}

///|
test "fragment parser preserves ignored head children" {
  let root = @html_parser.parse_fragment(
    "<head><title>T</title></head>x",
    collect_errors=true,
  )
  assert_eq(root.to_html(pretty=false), "<title>T</title>x")
  assert_eq(root.errors.length(), 2)
  assert_eq(root.errors[0].code, "unexpected-start-tag")
  assert_eq(root.errors[1].code, "unexpected-end-tag")
  let nested = @html_parser.parse_fragment(
    "<div><head><title>T</title></head>x</div>",
    collect_errors=true,
  )
  assert_eq(nested.to_html(pretty=false), "<div><title>T</title>x</div>")
  assert_eq(nested.errors.length(), 2)
  assert_eq(nested.errors[0].code, "unexpected-start-tag")
  assert_eq(nested.errors[1].code, "unexpected-end-tag")
}
