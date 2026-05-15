///|
test "tokenize exposes stable token data structures" {
  let result = @html_parser.tokenize("<p class='x'>Hi<br><!--ok--></p>")
  assert_eq(result.tokens.length(), 6)
  guard result.tokens[0] is Tag(start) else { fail("expected start tag") }
  assert_true(start.kind is StartTag)
  assert_eq(start.name, "p")
  guard start.attrs["class"] is Some("x") else { fail("expected class attr") }
  guard result.tokens[1] is Characters("Hi") else {
    fail("expected text token")
  }
  guard result.tokens[2] is Tag(br) else { fail("expected br tag") }
  assert_eq(br.self_closing, false)
  guard result.tokens[3] is CommentToken("ok") else {
    fail("expected comment token")
  }
  guard result.tokens[5] is Eof else { fail("expected EOF") }
  let explicit = @html_parser.tokenize("<img/>")
  guard explicit.tokens[0] is Tag(img) else { fail("expected img tag") }
  assert_eq(img.self_closing, true)
}

///|
test "tokenize matches upstream coverage gap fixtures" {
  let null_attr_name = @html_parser.tokenize(
    "<div a\u{0000}b='c'>",
    collect_errors=true,
  )
  guard null_attr_name.tokens[0] is Tag(null_attr_name_tag) else {
    fail("expected null attribute name start tag")
  }
  guard null_attr_name_tag.attrs["a\u{FFFD}b"] is Some("c") else {
    fail("expected replacement character in attribute name")
  }
  assert_eq(null_attr_name.errors.length(), 1)
  assert_eq(null_attr_name.errors[0].code, "unexpected-null-character")
  guard null_attr_name.errors[0].column is Some(7) else {
    fail("expected null attribute name error at column 7")
  }
  let null_double = @html_parser.tokenize(
    "<div a=\"b\u{0000}c\">",
    collect_errors=true,
  )
  guard null_double.tokens[0] is Tag(null_double_tag) else {
    fail("expected null double-quoted attribute start tag")
  }
  guard null_double_tag.attrs["a"] is Some("b\u{FFFD}c") else {
    fail("expected replacement character in double-quoted attribute value")
  }
  assert_eq(null_double.errors.length(), 1)
  assert_eq(null_double.errors[0].code, "unexpected-null-character")
  guard null_double.errors[0].column is Some(10) else {
    fail("expected double-quoted attribute null at column 10")
  }
  let null_single = @html_parser.tokenize(
    "<div a='b\u{0000}c'>",
    collect_errors=true,
  )
  guard null_single.tokens[0] is Tag(null_single_tag) else {
    fail("expected null single-quoted attribute start tag")
  }
  guard null_single_tag.attrs["a"] is Some("b\u{FFFD}c") else {
    fail("expected replacement character in single-quoted attribute value")
  }
  assert_eq(null_single.errors.length(), 1)
  assert_eq(null_single.errors[0].code, "unexpected-null-character")
  guard null_single.errors[0].column is Some(10) else {
    fail("expected single-quoted attribute null at column 10")
  }
  let missing_value = @html_parser.tokenize("<div a=>", collect_errors=true)
  guard missing_value.tokens[0] is Tag(missing_tag) else {
    fail("expected missing attribute value start tag")
  }
  guard missing_tag.attrs["a"] is Some("") else {
    fail("expected empty missing attribute value")
  }
  assert_eq(missing_value.errors.length(), 1)
  assert_eq(missing_value.errors[0].code, "missing-attribute-value")
  guard missing_value.errors[0].column is Some(8) else {
    fail("expected missing value at tag close")
  }
  let title_space = @html_parser.tokenize("<title >")
  guard title_space.tokens[0] is Tag(title_space_tag) else {
    fail("expected title start tag after attribute-name whitespace")
  }
  assert_eq(title_space_tag.name, "title")
  assert_eq(title_space_tag.attrs.length(), 0)
  let title_attr = @html_parser.tokenize("<title id>")
  guard title_attr.tokens[0] is Tag(title_attr_tag) else {
    fail("expected title start tag with empty id")
  }
  guard title_attr_tag.attrs["id"] is Some("") else {
    fail("expected empty id attribute")
  }
  let title_slow_attr = @html_parser.tokenize("<title id\\\">")
  guard title_slow_attr.tokens[0] is Tag(title_slow_attr_tag) else {
    fail("expected title start tag with quote in attribute name")
  }
  guard title_slow_attr_tag.attrs["id\\\""] is Some("") else {
    fail("expected backslash and quote in title attribute name")
  }
  let title_after_attr = @html_parser.tokenize("<title id >")
  guard title_after_attr.tokens[0] is Tag(title_after_attr_tag) else {
    fail("expected title start tag after attribute name")
  }
  guard title_after_attr_tag.attrs["id"] is Some("") else {
    fail("expected empty id after whitespace")
  }
  let title_before_value = @html_parser.tokenize("<title id=>")
  guard title_before_value.tokens[0] is Tag(title_before_value_tag) else {
    fail("expected title start tag before missing value")
  }
  guard title_before_value_tag.attrs["id"] is Some("") else {
    fail("expected empty id after equals")
  }
}

///|
test "tokenize preserves raw end tags before tree recovery" {
  let result = @html_parser.tokenize("<p>open</span>")
  assert_eq(result.tokens.length(), 4)
  guard result.tokens[0] is Tag(start) else { fail("expected p start tag") }
  assert_true(start.kind is StartTag)
  assert_eq(start.name, "p")
  guard result.tokens[2] is Tag(end_tag) else {
    fail("expected raw span end tag")
  }
  assert_true(end_tag.kind is EndTag)
  assert_eq(end_tag.name, "span")
}

///|
test "tokenize preserves end tag attributes and self closing solidus" {
  let self_closing = @html_parser.tokenize("</div/>", collect_errors=true)
  guard self_closing.tokens[0] is Tag(tag) else { fail("expected end tag") }
  assert_true(tag.kind is EndTag)
  assert_eq(tag.name, "div")
  assert_eq(tag.self_closing, true)
  assert_eq(self_closing.errors.length(), 0)
  let attrs = @html_parser.tokenize("</div attr=x>", collect_errors=true)
  guard attrs.tokens[0] is Tag(attr_tag) else {
    fail("expected attributed end tag")
  }
  assert_true(attr_tag.kind is EndTag)
  assert_eq(attr_tag.name, "div")
  guard attr_tag.attrs["attr"] is Some("x") else {
    fail("expected end tag attr")
  }
  assert_eq(attr_tag.self_closing, false)
  assert_eq(attrs.errors.length(), 0)
  let null_name = @html_parser.tokenize("</d\u{0000}iv>", collect_errors=true)
  guard null_name.tokens[0] is Tag(null_tag) else {
    fail("expected null-containing end tag")
  }
  assert_true(null_tag.kind is EndTag)
  assert_eq(null_tag.name, "d\u{FFFD}iv")
  assert_eq(null_name.errors.length(), 1)
  assert_eq(null_name.errors[0].code, "unexpected-null-character")
  let bad_solidus = @html_parser.tokenize("</div/ x>", collect_errors=true)
  guard bad_solidus.tokens[0] is Tag(bad_tag) else {
    fail("expected recovered end tag after bad solidus")
  }
  assert_true(bad_tag.kind is EndTag)
  assert_eq(bad_tag.name, "div")
  assert_eq(bad_tag.self_closing, false)
  guard bad_tag.attrs["x"] is Some("") else {
    fail("expected recovered attr after bad end-tag solidus")
  }
  assert_eq(bad_solidus.errors.length(), 1)
  assert_eq(
    bad_solidus.errors[0].code,
    "unexpected-character-after-solidus-in-tag",
  )
}

///|
test "tokenize matches rawtext and rcdata end tags before bad solidus" {
  let title = @html_parser.tokenize(
    "<title>a</title/foo><p>b",
    collect_errors=true,
  )
  guard title.tokens[1] is Characters("a") else {
    fail("expected title text before slash end tag")
  }
  guard title.tokens[2] is Tag(end_title) else {
    fail("expected title end tag before slash attribute")
  }
  assert_true(end_title.kind is EndTag)
  assert_eq(end_title.name, "title")
  guard end_title.attrs["foo"] is Some("") else {
    fail("expected recovered foo attribute on title end tag")
  }
  assert_eq(title.errors.length(), 1)
  assert_eq(title.errors[0].code, "unexpected-character-after-solidus-in-tag")
  guard title.errors[0].column is Some(17) else {
    fail("expected title solidus recovery at column 17")
  }
  let script = @html_parser.tokenize(
    "<script>a</script/foo><p>b",
    collect_errors=true,
  )
  guard script.tokens[1] is Characters("a") else {
    fail("expected script text before slash end tag")
  }
  guard script.tokens[2] is Tag(end_script) else {
    fail("expected script end tag before slash attribute")
  }
  assert_true(end_script.kind is EndTag)
  assert_eq(end_script.name, "script")
  guard end_script.attrs["foo"] is Some("") else {
    fail("expected recovered foo attribute on script end tag")
  }
  assert_eq(script.errors.length(), 1)
  assert_eq(script.errors[0].code, "unexpected-character-after-solidus-in-tag")
  guard script.errors[0].column is Some(19) else {
    fail("expected script solidus recovery at column 19")
  }
}

///|
test "tokenize reports malformed end tag errors when requested" {
  let result = @html_parser.tokenize("</>", collect_errors=true)
  assert_eq(result.tokens.length(), 1)
  assert_eq(result.errors.length(), 1)
  assert_eq(result.errors[0].code, "empty-end-tag")
  guard result.errors[0].column is Some(3) else {
    fail("expected empty end tag error at >")
  }
  let invalid = @html_parser.tokenize("</ >", collect_errors=true)
  guard invalid.tokens[0] is CommentToken(" ") else {
    fail("expected invalid end tag as bogus comment")
  }
  assert_eq(invalid.errors.length(), 1)
  assert_eq(invalid.errors[0].code, "invalid-first-character-of-tag-name")
  guard invalid.errors[0].column is Some(3) else {
    fail("expected invalid end tag error after slash")
  }
}

///|
test "tokenize handles selected bogus comment fixture cases" {
  let processing = @html_parser.tokenize("<?foo>")
  guard processing.tokens[0] is CommentToken("?foo") else {
    fail("expected bogus comment")
  }
  let invalid_end = @html_parser.tokenize("</?", collect_errors=true)
  guard invalid_end.tokens[0] is CommentToken("?") else {
    fail("expected invalid end tag as bogus comment")
  }
  assert_eq(invalid_end.errors.length(), 1)
  assert_eq(invalid_end.errors[0].code, "invalid-first-character-of-tag-name")
  let question = @html_parser.tokenize("<?foo>", collect_errors=true)
  guard question.tokens[0] is CommentToken("?foo") else {
    fail("expected question-mark markup as bogus comment")
  }
  assert_eq(question.errors.length(), 1)
  assert_eq(
    question.errors[0].code,
    "unexpected-question-mark-instead-of-tag-name",
  )
  guard question.errors[0].column is Some(2) else {
    fail("expected question-mark error at column 2")
  }
  let question_crlf = @html_parser.tokenize("<?a\r\nb>", collect_errors=true)
  guard question_crlf.tokens[0] is CommentToken("?a\nb") else {
    fail("expected CRLF-normalized question-mark bogus comment")
  }
  assert_eq(question_crlf.errors.length(), 1)
  assert_eq(
    question_crlf.errors[0].code,
    "unexpected-question-mark-instead-of-tag-name",
  )
  let declaration = @html_parser.tokenize("<!foo>", collect_errors=true)
  guard declaration.tokens[0] is CommentToken("foo") else {
    fail("expected malformed declaration as bogus comment")
  }
  assert_eq(declaration.errors.length(), 1)
  assert_eq(declaration.errors[0].code, "incorrectly-opened-comment")
  guard declaration.errors[0].column is Some(2) else {
    fail("expected malformed declaration error at bang")
  }
  let cdata = @html_parser.tokenize("<![CDATA[x]]>", collect_errors=true)
  guard cdata.tokens[0] is CommentToken("[CDATA[x]]") else {
    fail("expected HTML CDATA as bogus comment")
  }
  assert_eq(cdata.errors.length(), 1)
  assert_eq(cdata.errors[0].code, "cdata-in-html-content")
  guard cdata.errors[0].column is Some(9) else {
    fail("expected cdata error at opening bracket")
  }
  let invalid_open = @html_parser.tokenize("<*foo>", collect_errors=true)
  assert_eq(invalid_open.tokens.length(), 2)
  guard invalid_open.tokens[0] is Characters("<*foo>") else {
    fail("expected invalid tag-open sequence as text")
  }
  guard invalid_open.tokens[1] is Eof else {
    fail("expected EOF after invalid tag-open text")
  }
  assert_eq(invalid_open.errors.length(), 1)
  assert_eq(invalid_open.errors[0].code, "invalid-first-character-of-tag-name")
  guard invalid_open.errors[0].column is Some(2) else {
    fail("expected invalid tag-open error at second character")
  }
  let invalid_entity = @html_parser.tokenize("<&notit", collect_errors=true)
  guard invalid_entity.tokens[0] is Characters("<¬it") else {
    fail("expected invalid tag-open entity recovery")
  }
  assert_eq(invalid_entity.errors.length(), 2)
  assert_eq(
    invalid_entity.errors[0].code,
    "invalid-first-character-of-tag-name",
  )
  assert_eq(
    invalid_entity.errors[1].code,
    "missing-semicolon-after-character-reference",
  )
  let xml_question = @html_parser.tokenize(
    "<?a--b>",
    collect_errors=true,
    xml_coercion=true,
  )
  guard xml_question.tokens[0] is CommentToken("?a- -b") else {
    fail("expected XML-coerced bogus comment")
  }
  assert_eq(xml_question.errors.length(), 1)
  assert_eq(
    xml_question.errors[0].code,
    "unexpected-question-mark-instead-of-tag-name",
  )
}

///|
test "tokenize replaces nulls in bogus comment data" {
  let question = @html_parser.tokenize("<?a\u{0000}b>", collect_errors=true)
  guard question.tokens[0] is CommentToken("?a\u{FFFD}b") else {
    fail("expected replacement char in question-mark bogus comment")
  }
  assert_eq(question.errors.length(), 1)
  assert_eq(
    question.errors[0].code,
    "unexpected-question-mark-instead-of-tag-name",
  )
  let declaration = @html_parser.tokenize("<!a\u{0000}b>", collect_errors=true)
  guard declaration.tokens[0] is CommentToken("a\u{FFFD}b") else {
    fail("expected replacement char in malformed declaration")
  }
  assert_eq(declaration.errors.length(), 1)
  assert_eq(declaration.errors[0].code, "incorrectly-opened-comment")
  let cdata = @html_parser.tokenize(
    "<![CDATA[a\u{0000}b]]>",
    collect_errors=true,
  )
  guard cdata.tokens[0] is CommentToken("[CDATA[a\u{FFFD}b]]") else {
    fail("expected replacement char in HTML CDATA bogus comment")
  }
  assert_eq(cdata.errors.length(), 1)
  assert_eq(cdata.errors[0].code, "cdata-in-html-content")
}

///|
test "tokenize reports abrupt closing of empty comments" {
  let simple = @html_parser.tokenize("<!-->", collect_errors=true)
  guard simple.tokens[0] is CommentToken("") else {
    fail("expected empty comment")
  }
  assert_eq(simple.errors.length(), 1)
  assert_eq(simple.errors[0].code, "abrupt-closing-of-empty-comment")
  guard simple.errors[0].column is Some(5) else {
    fail("expected abrupt empty comment at >")
  }
  let dash = @html_parser.tokenize("<!--->", collect_errors=true)
  guard dash.tokens[0] is CommentToken("") else {
    fail("expected empty dash comment")
  }
  assert_eq(dash.errors.length(), 1)
  assert_eq(dash.errors[0].code, "abrupt-closing-of-empty-comment")
  guard dash.errors[0].column is Some(6) else {
    fail("expected abrupt empty dash comment at >")
  }
}

///|
test "tokenize reports incorrectly closed comments" {
  let bang = @html_parser.tokenize("<!--x--!>", collect_errors=true)
  guard bang.tokens[0] is CommentToken("x") else {
    fail("expected bang-closed comment")
  }
  assert_eq(bang.errors.length(), 1)
  assert_eq(bang.errors[0].code, "incorrectly-closed-comment")
  guard bang.errors[0].column is Some(9) else {
    fail("expected bang close error at >")
  }
  let text = @html_parser.tokenize("<!--x--y-->", collect_errors=true)
  guard text.tokens[0] is CommentToken("x--y") else {
    fail("expected recovered comment data")
  }
  assert_eq(text.errors.length(), 1)
  assert_eq(text.errors[0].code, "incorrectly-closed-comment")
  guard text.errors[0].column is Some(8) else {
    fail("expected comment close error at reconsumed text")
  }
}

///|
test "tokenize reports selected EOF and null fixture errors" {
  let lt = @html_parser.tokenize("<", collect_errors=true)
  guard lt.tokens[0] is Characters("<") else { fail("expected literal <") }
  assert_eq(lt.errors[0].code, "eof-before-tag-name")
  guard lt.errors[0].column is Some(1) else {
    fail("expected bare < EOF at the < character")
  }
  let end_open = @html_parser.tokenize("</", collect_errors=true)
  guard end_open.tokens[0] is Characters("</") else {
    fail("expected literal </")
  }
  assert_eq(end_open.errors[0].code, "eof-before-tag-name")
  guard end_open.errors[0].column is Some(2) else {
    fail("expected bare </ EOF at the slash")
  }
  let unfinished_start = @html_parser.tokenize(
    "<div foo=\"",
    collect_errors=true,
  )
  assert_eq(unfinished_start.tokens.length(), 1)
  guard unfinished_start.tokens[0] is Eof else {
    fail("expected only EOF token for incomplete quoted tag")
  }
  assert_eq(unfinished_start.errors.length(), 1)
  assert_eq(unfinished_start.errors[0].code, "eof-in-tag")
  guard unfinished_start.errors[0].column is Some(10) else {
    fail("expected incomplete quoted tag EOF at final quote")
  }
  let unfinished_single = @html_parser.tokenize(
    "<div foo='",
    collect_errors=true,
  )
  assert_eq(unfinished_single.tokens.length(), 1)
  guard unfinished_single.tokens[0] is Eof else {
    fail("expected only EOF token for incomplete single-quoted tag")
  }
  assert_eq(unfinished_single.errors.length(), 1)
  assert_eq(unfinished_single.errors[0].code, "eof-in-tag")
  guard unfinished_single.errors[0].column is Some(10) else {
    fail("expected incomplete single-quoted tag EOF at final quote")
  }
  let unfinished_unquoted = @html_parser.tokenize(
    "<div foo=bar",
    collect_errors=true,
  )
  assert_eq(unfinished_unquoted.tokens.length(), 1)
  guard unfinished_unquoted.tokens[0] is Eof else {
    fail("expected only EOF token for incomplete unquoted tag")
  }
  assert_eq(unfinished_unquoted.errors.length(), 1)
  assert_eq(unfinished_unquoted.errors[0].code, "eof-in-tag")
  guard unfinished_unquoted.errors[0].column is Some(12) else {
    fail("expected incomplete unquoted tag EOF at final value character")
  }
  let unfinished_end = @html_parser.tokenize("</span", collect_errors=true)
  assert_eq(unfinished_end.tokens.length(), 1)
  guard unfinished_end.tokens[0] is Eof else {
    fail("expected only EOF token for incomplete end tag")
  }
  assert_eq(unfinished_end.errors.length(), 1)
  assert_eq(unfinished_end.errors[0].code, "eof-in-tag")
  guard unfinished_end.errors[0].column is Some(6) else {
    fail("expected incomplete end tag EOF at final name character")
  }
  let unfinished_start_spaces = @html_parser.tokenize(
    "<div   ",
    collect_errors=true,
  )
  assert_eq(unfinished_start_spaces.tokens.length(), 1)
  guard unfinished_start_spaces.tokens[0] is Eof else {
    fail("expected only EOF token for start tag ending after whitespace")
  }
  assert_eq(unfinished_start_spaces.errors.length(), 1)
  assert_eq(unfinished_start_spaces.errors[0].code, "eof-in-tag")
  let unfinished_end_spaces = @html_parser.tokenize(
    "</span   ",
    collect_errors=true,
  )
  assert_eq(unfinished_end_spaces.tokens.length(), 1)
  guard unfinished_end_spaces.tokens[0] is Eof else {
    fail("expected only EOF token for end tag ending after whitespace")
  }
  assert_eq(unfinished_end_spaces.errors.length(), 1)
  assert_eq(unfinished_end_spaces.errors[0].code, "eof-in-tag")
  let unfinished_comment = @html_parser.tokenize("<!--x", collect_errors=true)
  assert_eq(unfinished_comment.tokens.length(), 2)
  guard unfinished_comment.tokens[0] is CommentToken("x") else {
    fail("expected comment token before EOF")
  }
  guard unfinished_comment.tokens[1] is Eof else {
    fail("expected EOF after unfinished comment token")
  }
  assert_eq(unfinished_comment.errors.length(), 1)
  assert_eq(unfinished_comment.errors[0].code, "eof-in-comment")
  guard unfinished_comment.errors[0].column is Some(5) else {
    fail("expected unfinished comment EOF at final character")
  }
  let nul_text = @html_parser.tokenize("a\u{0000}b", collect_errors=true)
  guard nul_text.tokens[0] is Characters("a\u{0000}b") else {
    fail("expected null-preserving text")
  }
  assert_eq(nul_text.errors[0].code, "unexpected-null-character")
  guard nul_text.errors[0].column is Some(2) else {
    fail("expected null text at column 2")
  }
  let nul_attr = @html_parser.tokenize(
    "<div foo=\"a\u{0000}b\">",
    collect_errors=true,
  )
  guard nul_attr.tokens[0] is Tag(tag) else { fail("expected div tag") }
  guard tag.attrs["foo"] is Some("a\u{FFFD}b") else {
    fail("expected replacement char in attr")
  }
  assert_eq(nul_attr.errors[0].code, "unexpected-null-character")
  let nul_single_attr = @html_parser.tokenize(
    "<div foo='a\u{0000}b'>",
    collect_errors=true,
  )
  guard nul_single_attr.tokens[0] is Tag(single_tag) else {
    fail("expected div tag with single-quoted null attr")
  }
  guard single_tag.attrs["foo"] is Some("a\u{FFFD}b") else {
    fail("expected replacement char in single-quoted attr")
  }
  assert_eq(nul_single_attr.errors.length(), 1)
  assert_eq(nul_single_attr.errors[0].code, "unexpected-null-character")
  guard nul_single_attr.errors[0].column is Some(12) else {
    fail("expected single-quoted null attr at column 12")
  }
  let nul_unquoted_attr = @html_parser.tokenize(
    "<div foo=a\u{0000}b>",
    collect_errors=true,
  )
  guard nul_unquoted_attr.tokens[0] is Tag(unquoted_tag) else {
    fail("expected div tag with unquoted null attr")
  }
  guard unquoted_tag.attrs["foo"] is Some("a\u{FFFD}b") else {
    fail("expected replacement char in unquoted attr")
  }
  assert_eq(nul_unquoted_attr.errors.length(), 1)
  assert_eq(nul_unquoted_attr.errors[0].code, "unexpected-null-character")
  let nul_attr_name = @html_parser.tokenize(
    "<div a\u{0000}b='c'>",
    collect_errors=true,
  )
  guard nul_attr_name.tokens[0] is Tag(attr_name_tag) else {
    fail("expected div tag")
  }
  guard attr_name_tag.attrs["a\u{FFFD}b"] is Some("c") else {
    fail("expected replacement char in attr name")
  }
  assert_eq(nul_attr_name.errors.length(), 1)
  assert_eq(nul_attr_name.errors[0].code, "unexpected-null-character")
  guard nul_attr_name.errors[0].column is Some(7) else {
    fail("expected null attr name at column 7")
  }
  let nul_tag_name = @html_parser.tokenize(
    "<script\u{0000}>x</script>",
    collect_errors=true,
  )
  guard nul_tag_name.tokens[0] is Tag(start) else {
    fail("expected script start tag")
  }
  assert_eq(start.name, "script\u{FFFD}")
  guard nul_tag_name.tokens[1] is Characters("x") else {
    fail("expected text after null-mutated script tag")
  }
  guard nul_tag_name.tokens[2] is Tag(end_tag) else {
    fail("expected script end tag")
  }
  assert_true(end_tag.kind is EndTag)
  assert_eq(end_tag.name, "script")
  assert_eq(nul_tag_name.errors.length(), 1)
  assert_eq(nul_tag_name.errors[0].code, "unexpected-null-character")
  guard nul_tag_name.errors[0].column is Some(8) else {
    fail("expected null tag name at column 8")
  }
}

///|
test "tokenize matches upstream script escaped null EOF fixture" {
  let result = @html_parser.tokenize(
    "<script><!---\u{0000}",
    collect_errors=true,
  )
  guard result.tokens[0] is Tag(start) else {
    fail("expected script start tag")
  }
  assert_eq(start.name, "script")
  guard result.tokens[1] is Characters("<!---\u{FFFD}") else {
    fail("expected escaped script text with replacement character")
  }
  guard result.tokens[2] is Eof else {
    fail("expected EOF after unclosed script text")
  }
  assert_eq(result.errors.length(), 1)
  assert_eq(result.errors[0].code, "unexpected-null-character")
  guard result.errors[0].column is Some(14) else {
    fail("expected script escaped null at column 14")
  }
}

///|
test "tokenize reports missing attribute value fixture errors" {
  let bare = @html_parser.tokenize("<div attr>", collect_errors=true)
  guard bare.tokens[0] is Tag(bare_tag) else { fail("expected div tag") }
  guard bare_tag.attrs["attr"] is Some("") else {
    fail("expected empty attr without error")
  }
  assert_eq(bare.errors.length(), 0)
  let simple = @html_parser.tokenize("<div attr=>", collect_errors=true)
  guard simple.tokens[0] is Tag(tag) else { fail("expected div tag") }
  guard tag.attrs["attr"] is Some("") else { fail("expected empty attr value") }
  assert_eq(simple.errors[0].code, "missing-attribute-value")
  guard simple.errors[0].column is Some(11) else {
    fail("expected missing value at column 11")
  }
  let crlf = @html_parser.tokenize("<div attr=\r\n>", collect_errors=true)
  assert_eq(crlf.errors[0].code, "missing-attribute-value")
  guard crlf.errors[0].line is Some(2) else {
    fail("expected CRLF normalized line")
  }
  guard crlf.errors[0].column is Some(1) else {
    fail("expected CRLF normalized column")
  }
}
