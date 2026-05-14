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

///|
test "document parser accepts doctype after leading comments and whitespace" {
  let comment = @html_parser.parse(
    "<!--c-->\n<!DOCTYPE html><p>x",
    collect_errors=true,
  )
  assert_eq(
    comment.to_html(pretty=false),
    "<!--c--><!DOCTYPE html><html><head></head><body><p>x</p></body></html>",
  )
  assert_eq(comment.errors.length(), 0)
  let whitespace = @html_parser.parse(
    " \n<!doctype html><p>x",
    collect_errors=true,
  )
  assert_eq(
    whitespace.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body><p>x</p></body></html>",
  )
  assert_eq(whitespace.errors.length(), 0)
  let mixed = @html_parser.parse(
    "\t<!--a--><!doctype html><p>x",
    collect_errors=true,
  )
  assert_eq(
    mixed.to_html(pretty=false),
    "<!--a--><!DOCTYPE html><html><head></head><body><p>x</p></body></html>",
  )
  assert_eq(mixed.errors.length(), 0)
}

///|
test "document parser reports missing initial doctype" {
  let chars = @html_parser.parse("x", collect_errors=true)
  assert_eq(
    chars.to_html(pretty=false),
    "<html><head></head><body>x</body></html>",
  )
  assert_eq(chars.errors.length(), 1)
  assert_eq(chars.errors[0].code, "expected-doctype-but-got-chars")
  guard chars.errors[0].column is Some(1) else {
    fail("expected character doctype error at first column")
  }
  let start = @html_parser.parse("<div>x", collect_errors=true)
  assert_eq(
    start.to_html(pretty=false),
    "<html><head></head><body><div>x</div></body></html>",
  )
  assert_eq(start.errors.length(), 2)
  assert_eq(start.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(start.errors[1].code, "expected-closing-tag-but-got-eof")
  guard start.errors[0].column is Some(5) else {
    fail("expected start tag doctype error at tag close")
  }
  let stray_template = @html_parser.parse("</template>", collect_errors=true)
  assert_eq(
    stray_template.to_html(pretty=false),
    "<html><head></head><body></body></html>",
  )
  assert_eq(stray_template.errors.length(), 2)
  assert_eq(stray_template.errors[0].code, "expected-doctype-but-got-end-tag")
  assert_eq(stray_template.errors[1].code, "unexpected-end-tag-before-html")
  guard stray_template.errors[1].column is Some(11) else {
    fail("expected before-html end tag error at tag close")
  }
  let stray_html = @html_parser.parse("</html>", collect_errors=true)
  assert_eq(stray_html.errors.length(), 1)
  assert_eq(stray_html.errors[0].code, "expected-doctype-but-got-end-tag")
  let stray_br = @html_parser.parse("</br>", collect_errors=true)
  assert_eq(
    stray_br.to_html(pretty=false),
    "<html><head></head><body><br></body></html>",
  )
  assert_eq(stray_br.errors.length(), 2)
  assert_eq(stray_br.errors[0].code, "expected-doctype-but-got-end-tag")
  assert_eq(stray_br.errors[1].code, "unexpected-end-tag")
  guard stray_br.errors[1].column is Some(5) else {
    fail("expected before-html br error at tag close")
  }
  let after_comment = @html_parser.parse("<!--c--><div>x", collect_errors=true)
  assert_eq(
    after_comment.to_html(pretty=false),
    "<!--c--><html><head></head><body><div>x</div></body></html>",
  )
  assert_eq(after_comment.errors[0].code, "expected-doctype-but-got-start-tag")
  guard after_comment.errors[0].column is Some(13) else {
    fail("expected doctype error after initial comment")
  }
  let whitespace_eof = @html_parser.parse("   ", collect_errors=true)
  assert_eq(
    whitespace_eof.to_html(pretty=false),
    "<html><head></head><body></body></html>",
  )
  assert_eq(whitespace_eof.errors.length(), 1)
  assert_eq(whitespace_eof.errors[0].code, "expected-doctype-but-got-eof")
  guard whitespace_eof.errors[0].column is Some(3) else {
    fail("expected EOF doctype error at final whitespace")
  }
  let empty = @html_parser.parse("", collect_errors=true)
  assert_eq(empty.errors[0].code, "expected-doctype-but-got-eof")
  guard empty.errors[0].column is Some(0) else {
    fail("expected empty input EOF at column zero")
  }
  let unfinished_start = @html_parser.parse("<div foo=\"", collect_errors=true)
  assert_eq(
    unfinished_start.to_html(pretty=false),
    "<html><head></head><body></body></html>",
  )
  assert_eq(unfinished_start.errors.length(), 2)
  assert_eq(unfinished_start.errors[0].code, "eof-in-tag")
  assert_eq(unfinished_start.errors[1].code, "expected-doctype-but-got-eof")
  guard unfinished_start.errors[1].column is Some(10) else {
    fail("expected doctype EOF after unfinished start tag")
  }
  let unfinished_end = @html_parser.parse("</span", collect_errors=true)
  assert_eq(
    unfinished_end.to_html(pretty=false),
    "<html><head></head><body></body></html>",
  )
  assert_eq(unfinished_end.errors.length(), 2)
  assert_eq(unfinished_end.errors[0].code, "eof-in-tag")
  assert_eq(unfinished_end.errors[1].code, "expected-doctype-but-got-eof")
  guard unfinished_end.errors[1].column is Some(6) else {
    fail("expected doctype EOF after unfinished end tag")
  }
  let unfinished_comment = @html_parser.parse("<!--x", collect_errors=true)
  assert_eq(
    unfinished_comment.to_html(pretty=false),
    "<!--x--><html><head></head><body></body></html>",
  )
  assert_eq(unfinished_comment.errors.length(), 2)
  assert_eq(unfinished_comment.errors[0].code, "eof-in-comment")
  assert_eq(unfinished_comment.errors[1].code, "expected-doctype-but-got-eof")
  guard unfinished_comment.errors[0].column is Some(5) else {
    fail("expected unfinished comment EOF at final character")
  }
  guard unfinished_comment.errors[1].column is Some(5) else {
    fail("expected doctype EOF after unfinished comment")
  }
  let bogus_question = @html_parser.parse("<?foo", collect_errors=true)
  assert_eq(
    bogus_question.to_html(pretty=false),
    "<!--?foo--><html><head></head><body></body></html>",
  )
  assert_eq(bogus_question.errors.length(), 2)
  assert_eq(
    bogus_question.errors[0].code,
    "unexpected-question-mark-instead-of-tag-name",
  )
  assert_eq(bogus_question.errors[1].code, "expected-doctype-but-got-eof")
  guard bogus_question.errors[0].column is Some(2) else {
    fail("expected question-mark error at column 2")
  }
  guard bogus_question.errors[1].column is Some(5) else {
    fail("expected doctype EOF after bogus question-mark comment")
  }
  let question_then_text = @html_parser.parse("<?foo>x", collect_errors=true)
  assert_eq(
    question_then_text.to_html(pretty=false),
    "<!--?foo--><html><head></head><body>x</body></html>",
  )
  assert_eq(question_then_text.errors.length(), 2)
  assert_eq(
    question_then_text.errors[0].code,
    "unexpected-question-mark-instead-of-tag-name",
  )
  assert_eq(question_then_text.errors[1].code, "expected-doctype-but-got-chars")
  guard question_then_text.errors[1].column is Some(7) else {
    fail("expected doctype chars after closed bogus question-mark comment")
  }
  let malformed_declaration = @html_parser.parse("<!foo>", collect_errors=true)
  assert_eq(
    malformed_declaration.to_html(pretty=false),
    "<!--foo--><html><head></head><body></body></html>",
  )
  assert_eq(malformed_declaration.errors.length(), 2)
  assert_eq(malformed_declaration.errors[0].code, "incorrectly-opened-comment")
  assert_eq(
    malformed_declaration.errors[1].code,
    "expected-doctype-but-got-eof",
  )
  guard malformed_declaration.errors[0].column is Some(2) else {
    fail("expected malformed declaration error at bang")
  }
  guard malformed_declaration.errors[1].column is Some(6) else {
    fail("expected doctype EOF after malformed declaration")
  }
  let cdata_then_text = @html_parser.parse("<![CDATA[]]>x", collect_errors=true)
  assert_eq(
    cdata_then_text.to_html(pretty=false),
    "<!--[CDATA[]]--><html><head></head><body>x</body></html>",
  )
  assert_eq(cdata_then_text.errors.length(), 2)
  assert_eq(cdata_then_text.errors[0].code, "cdata-in-html-content")
  assert_eq(cdata_then_text.errors[1].code, "expected-doctype-but-got-chars")
  guard cdata_then_text.errors[0].column is Some(9) else {
    fail("expected cdata error at opening bracket")
  }
  guard cdata_then_text.errors[1].column is Some(13) else {
    fail("expected doctype chars after HTML cdata bogus comment")
  }
  let empty_end = @html_parser.parse("</>", collect_errors=true)
  assert_eq(
    empty_end.to_html(pretty=false),
    "<html><head></head><body></body></html>",
  )
  assert_eq(empty_end.errors.length(), 2)
  assert_eq(empty_end.errors[0].code, "empty-end-tag")
  assert_eq(empty_end.errors[1].code, "expected-doctype-but-got-eof")
  guard empty_end.errors[0].column is Some(3) else {
    fail("expected empty end tag error at >")
  }
  guard empty_end.errors[1].column is Some(3) else {
    fail("expected doctype EOF after empty end tag")
  }
  let invalid_open = @html_parser.parse("<*foo>", collect_errors=true)
  assert_eq(
    invalid_open.to_html(pretty=false),
    "<html><head></head><body>&lt;*foo&gt;</body></html>",
  )
  assert_eq(invalid_open.errors.length(), 2)
  assert_eq(invalid_open.errors[0].code, "invalid-first-character-of-tag-name")
  assert_eq(invalid_open.errors[1].code, "expected-doctype-but-got-chars")
}

///|
test "document parser defers initial doctype errors after bogus markup" {
  let start = @html_parser.parse("<!foo><div>x", collect_errors=true)
  assert_eq(
    start.to_html(pretty=false),
    "<!--foo--><html><head></head><body><div>x</div></body></html>",
  )
  assert_eq(start.errors.length(), 3)
  assert_eq(start.errors[0].code, "incorrectly-opened-comment")
  assert_eq(start.errors[1].code, "expected-doctype-but-got-start-tag")
  assert_eq(start.errors[2].code, "expected-closing-tag-but-got-eof")
  guard start.errors[1].column is Some(11) else {
    fail("expected deferred start-tag doctype error at div close")
  }
  let end_tag = @html_parser.parse("<!foo></div>", collect_errors=true)
  assert_eq(
    end_tag.to_html(pretty=false),
    "<!--foo--><html><head></head><body></body></html>",
  )
  assert_eq(end_tag.errors.length(), 3)
  assert_eq(end_tag.errors[0].code, "incorrectly-opened-comment")
  assert_eq(end_tag.errors[1].code, "expected-doctype-but-got-end-tag")
  assert_eq(end_tag.errors[2].code, "unexpected-end-tag-before-html")
  guard end_tag.errors[1].column is Some(12) else {
    fail("expected deferred end-tag doctype error at end tag close")
  }
  let bare_lt = @html_parser.parse("<!foo><", collect_errors=true)
  assert_eq(
    bare_lt.to_html(pretty=false),
    "<!--foo--><html><head></head><body>&lt;</body></html>",
  )
  assert_eq(bare_lt.errors.length(), 3)
  assert_eq(bare_lt.errors[0].code, "incorrectly-opened-comment")
  assert_eq(bare_lt.errors[1].code, "eof-before-tag-name")
  assert_eq(bare_lt.errors[2].code, "expected-doctype-but-got-chars")
  guard bare_lt.errors[2].column is Some(7) else {
    fail("expected deferred character doctype error at literal <")
  }
  let unfinished_declaration = @html_parser.parse(
    "<!foo<!",
    collect_errors=true,
  )
  assert_eq(
    unfinished_declaration.to_html(pretty=false),
    "<!--foo<!--><html><head></head><body></body></html>",
  )
  assert_eq(unfinished_declaration.errors.length(), 2)
  assert_eq(unfinished_declaration.errors[0].code, "incorrectly-opened-comment")
  assert_eq(
    unfinished_declaration.errors[1].code,
    "expected-doctype-but-got-eof",
  )
  guard unfinished_declaration.errors[1].column is Some(7) else {
    fail("expected deferred doctype EOF after unfinished declaration")
  }
  let invalid_open = @html_parser.parse("<!foo><*x>", collect_errors=true)
  assert_eq(
    invalid_open.to_html(pretty=false),
    "<!--foo--><html><head></head><body>&lt;*x&gt;</body></html>",
  )
  assert_eq(invalid_open.errors.length(), 3)
  assert_eq(invalid_open.errors[0].code, "incorrectly-opened-comment")
  assert_eq(invalid_open.errors[1].code, "invalid-first-character-of-tag-name")
  assert_eq(invalid_open.errors[2].code, "expected-doctype-but-got-chars")
  guard invalid_open.errors[2].column is Some(7) else {
    fail("expected deferred character doctype error at invalid tag open")
  }
}
