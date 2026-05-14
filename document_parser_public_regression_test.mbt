///|
test "document parser scaffolds explicit html children into head and body" {
  let implicit = @html_parser.parse("<html><p>x</p></html>")
  assert_eq(
    implicit.to_html(pretty=false),
    "<html><head></head><body><p>x</p></body></html>",
  )
  let existing = @html_parser.parse(
    "<html><head><title>T</title></head><p>x</p></html>",
  )
  assert_eq(
    existing.to_html(pretty=false),
    "<html><head><title>T</title></head><body><p>x</p></body></html>",
  )
}

///|
test "document parser routes initial head elements into head" {
  let doc = @html_parser.parse(
    "\n<meta charset=utf-8><title>T</title><style>b{}</style><script>h</script><p>x</p>",
  )
  assert_eq(
    doc.to_html(pretty=false),
    "<html><head><meta charset=\"utf-8\"><title>T</title><style>b{}</style><script>h</script></head><body><p>x</p></body></html>",
  )
  let explicit = @html_parser.parse(
    "<html><head></head><title>T</title><p>x</p></html>",
  )
  assert_eq(
    explicit.to_html(pretty=false),
    "<html><head><title>T</title></head><body><p>x</p></body></html>",
  )
  let late = @html_parser.parse("<html><body>x</body><title>T</title></html>")
  assert_eq(
    late.to_html(pretty=false),
    "<html><head></head><body>x<title>T</title></body></html>",
  )
}

///|
test "document parser promotes explicit root head and body elements" {
  let doc = @html_parser.parse(
    "<head><title>T</title></head><body class=x><p>p</p></body>",
  )
  assert_eq(
    doc.to_html(pretty=false),
    "<html><head><title>T</title></head><body class=\"x\"><p>p</p></body></html>",
  )
  let extra_head = @html_parser.parse(
    "<head><meta charset=utf-8></head><title>T</title><body><p>p</p></body>",
  )
  assert_eq(
    extra_head.to_html(pretty=false),
    "<html><head><meta charset=\"utf-8\"><title>T</title></head><body><p>p</p></body></html>",
  )
  let late_head_item = @html_parser.parse(
    "<body class=x><p>p</p></body><title>T</title>",
  )
  assert_eq(
    late_head_item.to_html(pretty=false),
    "<html><head></head><body class=\"x\"><p>p</p><title>T</title></body></html>",
  )
  let text_in_head = @html_parser.parse(
    "<head>x</head><p>y",
    collect_errors=true,
  )
  assert_eq(
    text_in_head.to_html(pretty=false),
    "<html><head></head><body>x<p>y</p></body></html>",
  )
  assert_eq(text_in_head.errors.length(), 2)
  assert_eq(text_in_head.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(text_in_head.errors[1].code, "unexpected-end-tag")
  let duplicate_head = @html_parser.parse(
    "<head><head><title>T</title>",
    collect_errors=true,
  )
  assert_eq(
    duplicate_head.to_html(pretty=false),
    "<html><head></head><body><title>T</title></body></html>",
  )
  assert_eq(duplicate_head.errors.length(), 2)
  assert_eq(duplicate_head.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(duplicate_head.errors[1].code, "unexpected-start-tag")
  let duplicate_head_body_start = @html_parser.parse(
    "<head><head><p>x",
    collect_errors=true,
  )
  assert_eq(
    duplicate_head_body_start.to_html(pretty=false),
    "<html><head></head><body><p>x</p></body></html>",
  )
  assert_eq(duplicate_head_body_start.errors.length(), 2)
  assert_eq(
    duplicate_head_body_start.errors[0].code,
    "expected-doctype-but-got-start-tag",
  )
  assert_eq(duplicate_head_body_start.errors[1].code, "unexpected-start-tag")
  let closed_duplicate_head = @html_parser.parse(
    "<head><head></head><title>T</title>",
    collect_errors=true,
  )
  assert_eq(
    closed_duplicate_head.to_html(pretty=false),
    "<html><head></head><body><title>T</title></body></html>",
  )
  assert_eq(closed_duplicate_head.errors.length(), 3)
  assert_eq(
    closed_duplicate_head.errors[0].code,
    "expected-doctype-but-got-start-tag",
  )
  assert_eq(closed_duplicate_head.errors[1].code, "unexpected-start-tag")
  assert_eq(closed_duplicate_head.errors[2].code, "unexpected-end-tag")
  let root_duplicate_head = @html_parser.parse(
    "<head></head><head><title>T</title>",
    collect_errors=true,
  )
  assert_eq(
    root_duplicate_head.to_html(pretty=false),
    "<html><head></head><body><title>T</title></body></html>",
  )
  assert_eq(root_duplicate_head.errors.length(), 2)
  assert_eq(
    root_duplicate_head.errors[0].code,
    "expected-doctype-but-got-start-tag",
  )
  assert_eq(root_duplicate_head.errors[1].code, "unexpected-start-tag")
}

///|
test "document parser merges repeated body tags" {
  let repeated = @html_parser.parse(
    "<body class=a><p>one</p><body id=b><p>two</p>",
  )
  assert_eq(
    repeated.to_html(pretty=false),
    "<html><head></head><body class=\"a\" id=\"b\"><p>one</p><p>two</p></body></html>",
  )
  let first_wins = @html_parser.parse("<body class=a><body class=b id=x>text")
  assert_eq(
    first_wins.to_html(pretty=false),
    "<html><head></head><body class=\"a\" id=\"x\">text</body></html>",
  )
  let closed_siblings = @html_parser.parse(
    "<body class=a>one</body><body id=b>two</body>",
  )
  assert_eq(
    closed_siblings.to_html(pretty=false),
    "<html><head></head><body class=\"a\" id=\"b\">onetwo</body></html>",
  )
  let after_head = @html_parser.parse(
    "<head><title>T</title></head><body class=a>one</body><body id=b>two</body>",
  )
  assert_eq(
    after_head.to_html(pretty=false),
    "<html><head><title>T</title></head><body class=\"a\" id=\"b\">onetwo</body></html>",
  )
}

///|
test "document parser ignores early body end after explicit html" {
  let doc = @html_parser.parse(
    "<!doctype html><html></body><p>x",
    collect_errors=true,
  )
  assert_eq(
    doc.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body><p>x</p></body></html>",
  )
  assert_eq(doc.errors.length(), 0)
  let after_head = @html_parser.parse(
    "<!doctype html><html><head></head></body><p>x",
    collect_errors=true,
  )
  assert_eq(
    after_head.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body><p>x</p></body></html>",
  )
  assert_eq(after_head.errors.length(), 0)
}

///|
test "document parser merges nested repeated html tags" {
  let nested = @html_parser.parse(
    "<html lang=en><html dir=ltr><body>x</body></html>",
  )
  assert_eq(
    nested.to_html(pretty=false),
    "<html lang=\"en\" dir=\"ltr\"><head></head><body>x</body></html>",
  )
  let after_body = @html_parser.parse(
    "<html lang=en><body>x</body><html dir=ltr><body>y</body></html>",
  )
  assert_eq(
    after_body.to_html(pretty=false),
    "<html lang=\"en\" dir=\"ltr\"><head></head><body>xy</body></html>",
  )
  let first_wins = @html_parser.parse(
    "<html lang=en><html lang=fr dir=ltr><head><title>T</title></head><body>x</body></html>",
  )
  assert_eq(
    first_wins.to_html(pretty=false),
    "<html lang=\"en\" dir=\"ltr\"><head><title>T</title></head><body>x</body></html>",
  )
  let body_repeated = @html_parser.parse(
    "<html><body><html attr=\"test\">",
    collect_errors=true,
  )
  assert_eq(
    body_repeated.to_html(pretty=false),
    "<html attr=\"test\"><head></head><body></body></html>",
  )
  assert_eq(body_repeated.errors.length(), 2)
  assert_eq(body_repeated.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(body_repeated.errors[1].code, "unexpected-start-tag")
}

///|
test "document parser merges root repeated html tags" {
  let repeated = @html_parser.parse(
    "<html lang=en></html><html dir=ltr><body>x</body></html>",
  )
  assert_eq(
    repeated.to_html(pretty=false),
    "<html lang=\"en\" dir=\"ltr\"><head></head><body>x</body></html>",
  )
  let with_existing_body = @html_parser.parse(
    "<html lang=en><body>x</body></html><html dir=ltr><body>y</body></html>",
  )
  assert_eq(
    with_existing_body.to_html(pretty=false),
    "<html lang=\"en\" dir=\"ltr\"><head></head><body>xy</body></html>",
  )
}

///|
test "document parser preserves shell scaffolding edge ordering" {
  let leading_text = @html_parser.parse(
    "<html> \n\tBody</html>",
    collect_errors=true,
  )
  assert_eq(
    leading_text.to_html(pretty=false),
    "<html><head></head><body>Body</body></html>",
  )
  assert_eq(leading_text.errors.length(), 1)
  assert_eq(leading_text.errors[0].code, "expected-doctype-but-got-start-tag")
  let leading_space_only = @html_parser.parse(
    "<!doctype html><html>   </html>",
    collect_errors=true,
  )
  assert_eq(
    leading_space_only.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body></body></html>",
  )
  assert_eq(leading_space_only.errors.length(), 0)
  let explicit_head_whitespace = @html_parser.parse(
    "<html><title>T</title> \t\n<p>x</p></html>",
  )
  assert_eq(
    explicit_head_whitespace.to_html(pretty=false),
    "<html><head><title>T</title> \t\n</head><body><p>x</p></body></html>",
  )
  let explicit_head_trailing_whitespace = @html_parser.parse(
    "<html><title>T</title> \t\n</html>",
  )
  assert_eq(
    explicit_head_trailing_whitespace.to_html(pretty=false),
    "<html><head><title>T</title> \t\n</head><body></body></html>",
  )
  let explicit_after_head_text = @html_parser.parse(
    "<html><head></head>Body</html>",
  )
  assert_eq(
    explicit_after_head_text.to_html(pretty=false),
    "<html><head></head><body>Body</body></html>",
  )
  let implicit_head_trailing_whitespace = @html_parser.parse(
    "<title>T</title> \t\n",
  )
  assert_eq(
    implicit_head_trailing_whitespace.to_html(pretty=false),
    "<html><head><title>T</title> \t\n</head><body></body></html>",
  )
  let late_head = @html_parser.parse(
    "<html><body>x</body><head><title>T</title></head></html>",
    collect_errors=true,
  )
  assert_eq(
    late_head.to_html(pretty=false),
    "<html><head></head><body>x<title>T</title></body></html>",
  )
  assert_eq(late_head.errors.length(), 3)
  assert_eq(late_head.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(late_head.errors[1].code, "unexpected-start-tag")
  assert_eq(late_head.errors[2].code, "unexpected-end-tag")
  let frameset_tail = @html_parser.parse(
    "<html><frameset></frameset>   <!--tail--></html>",
    collect_errors=true,
  )
  assert_eq(
    frameset_tail.to_html(pretty=false),
    "<html><head></head><frameset></frameset>   <!--tail--></html>",
  )
  assert_eq(frameset_tail.errors.length(), 1)
  assert_eq(frameset_tail.errors[0].code, "expected-doctype-but-got-start-tag")
  let recursive_html = @html_parser.parse(
    "<html lang=en></html><html dir=ltr><html data-x=1><body>x</body></html></html>",
    collect_errors=true,
  )
  assert_eq(
    recursive_html.to_html(pretty=false),
    "<html lang=\"en\" dir=\"ltr\" data-x=\"1\"><head></head><body>x</body></html>",
  )
  assert_eq(recursive_html.errors.length(), 5)
  assert_eq(recursive_html.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(recursive_html.errors[1].code, "unexpected-start-tag")
  assert_eq(recursive_html.errors[2].code, "unexpected-start-tag")
  assert_eq(recursive_html.errors[3].code, "unexpected-start-tag")
  assert_eq(recursive_html.errors[4].code, "unexpected-token-after-body")
}

///|
test "document parser places comments around implicit head like reference" {
  let before = @html_parser.parse("<!--c--><title>T</title><p>x</p>")
  assert_eq(
    before.to_html(pretty=false),
    "<!--c--><html><head><title>T</title></head><body><p>x</p></body></html>",
  )
  let inside = @html_parser.parse("<title>T</title><!--c--><p>x</p>")
  assert_eq(
    inside.to_html(pretty=false),
    "<html><head><title>T</title><!--c--></head><body><p>x</p></body></html>",
  )
  let after_body = @html_parser.parse("<p>x</p><!--c--><title>T</title>")
  assert_eq(
    after_body.to_html(pretty=false),
    "<html><head></head><body><p>x</p><!--c--><title>T</title></body></html>",
  )
}

///|
test "document parser preserves head-side whitespace like reference" {
  let implicit = @html_parser.parse("<!doctype html><title>T</title>  text")
  assert_eq(
    implicit.to_html(pretty=false),
    "<!DOCTYPE html><html><head><title>T</title>  </head><body>text</body></html>",
  )
  let implicit_trailing_space = @html_parser.parse(
    "<!doctype html><title>T</title>  ",
    collect_errors=true,
  )
  assert_eq(
    implicit_trailing_space.to_html(pretty=false),
    "<!DOCTYPE html><html><head><title>T</title>  </head><body></body></html>",
  )
  assert_eq(implicit_trailing_space.errors.length(), 0)
  let open_head = @html_parser.parse(
    "<!doctype html><head><title>T</title>  text",
  )
  assert_eq(
    open_head.to_html(pretty=false),
    "<!DOCTYPE html><html><head><title>T</title>  </head><body>text</body></html>",
  )
  let coerced_head_space = @html_parser.parse(
    "<!doctype html><head><title>T</title>\u{000C} x",
    xml_coercion=true,
  )
  assert_eq(
    coerced_head_space.to_html(pretty=false),
    "<!DOCTYPE html><html><head><title>T</title>  </head><body>x</body></html>",
  )
  let explicit = @html_parser.parse(
    "<!doctype html><head></head><!--c-->  <meta name=x><p>y",
  )
  assert_eq(
    explicit.to_html(pretty=false),
    "<!DOCTYPE html><html><head><meta name=\"x\"></head><!--c-->  <body><p>y</p></body></html>",
  )
  let explicit_html_implicit_head = @html_parser.parse(
    "<html><title>T</title>  text</html>",
  )
  assert_eq(
    explicit_html_implicit_head.to_html(pretty=false),
    "<html><head><title>T</title>  </head><body>text</body></html>",
  )
  let explicit_html_closed_head = @html_parser.parse(
    "<html><head></head>  <p>x</p></html>",
  )
  assert_eq(
    explicit_html_closed_head.to_html(pretty=false),
    "<html><head></head>  <body><p>x</p></body></html>",
  )
}
