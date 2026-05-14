///|
test "parser and tokenizer optionally coerce XML-invalid text" {
  let tokens = @html_parser.tokenize(
    "\u{000C}\u{FDD0}<script>\u{FDD0}</script><!--a--b-->",
    xml_coercion=true,
  )
  guard tokens.tokens[0] is Characters(" �") else {
    fail("expected form-feed and noncharacter coercion in text")
  }
  guard tokens.tokens[2] is Characters("�") else {
    fail("expected XML coercion in script text")
  }
  guard tokens.tokens[4] is CommentToken("a- -b") else {
    fail("expected XML comment double-hyphen coercion")
  }
  let default_tokens = @html_parser.tokenize("\u{000C}\u{FDD0}")
  guard default_tokens.tokens[0] is Characters("\u{000C}\u{FDD0}") else {
    fail("expected XML coercion to be opt-in")
  }
  let parsed = @html_parser.parse_fragment(
    "<div>a\u{000C}\u{FDD0}</div><textarea>\u{000C}\u{FDD0}</textarea>",
    xml_coercion=true,
  )
  assert_eq(
    parsed.to_html(pretty=false),
    "<div>a �</div><textarea> �</textarea>",
  )
  let raw_text = @html_parser.parse(
    "<script>\u{000C}\u{FDD0}</script><style>\u{000C}\u{FDD0}</style>",
    xml_coercion=true,
  )
  assert_eq(
    raw_text.to_html(pretty=false),
    "<html><head><script> �</script><style> �</style></head><body></body></html>",
  )
  let comments = @html_parser.parse_fragment(
    "<!--a--b--><?c--d>",
    collect_errors=true,
    xml_coercion=true,
  )
  assert_eq(comments.to_html(pretty=false), "<!--a- -b--><!--?c- -d-->")
  assert_eq(comments.errors.length(), 2)
  assert_eq(comments.errors[0].code, "incorrectly-closed-comment")
  assert_eq(
    comments.errors[1].code,
    "unexpected-question-mark-instead-of-tag-name",
  )
  let foreign_cdata = @html_parser.parse_fragment(
    "<svg><![CDATA[\u{000C}\u{FDD0}]]></svg>",
    xml_coercion=true,
  )
  assert_eq(foreign_cdata.to_html(pretty=false), "<svg> �</svg>")
}

///|
test "tokenize matches upstream XML violation coverage fixtures" {
  let form_feed = @html_parser.tokenize("\u{000C}", xml_coercion=true)
  guard form_feed.tokens[0] is Characters(" ") else {
    fail("expected XML coercion to replace form feed with space")
  }
  let noncharacter = @html_parser.tokenize("\u{FDD0}", xml_coercion=true)
  guard noncharacter.tokens[0] is Characters("\u{FFFD}") else {
    fail("expected XML coercion to replace noncharacter")
  }
}
