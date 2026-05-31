// Snapshot-style blackbox tests for the basic token shapes, attribute
// edge cases, and raw end-tag recovery now live in
// `tokenizer/tokenize_tags_test.mbt`, `tokenizer/tokenize_errors_test.mbt`,
// and `tokenizer/tokenize_doctype_and_comment_test.mbt`. Cases below cover
// behavior that those snapshots do not.

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
test "parser matches end tags before self closing solidus" {
  let div = @html_parser.parse_fragment("<div>x</div/>y", collect_errors=true)
  assert_eq(div.to_html(pretty=false), "<div>x</div>y")
  assert_eq(div.errors.length(), 0)
  let script = @html_parser.tokenize("<script>x</script/>after")
  guard script.tokens[1] is Characters("x") else {
    fail("expected script text before slash end tag")
  }
  guard script.tokens[2] is Tag(end_script) else {
    fail("expected script end tag before slash")
  }
  assert_true(end_script.kind is EndTag)
  assert_eq(end_script.name, "script")
  assert_eq(end_script.self_closing, true)
  guard script.tokens[3] is Characters("after") else {
    fail("expected text after slash end tag")
  }
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
test "tokenize preserves rawtext and rcdata element contents" {
  let script = @html_parser.tokenize("<script><!--a--<b</script>")
  assert_eq(script.tokens.length(), 4)
  guard script.tokens[1] is Characters("<!--a--<<b") else {
    fail("expected raw script text")
  }
  guard script.tokens[2] is Tag(end_script) else { fail("expected script end") }
  assert_true(end_script.kind is EndTag)
  assert_eq(end_script.name, "script")
  let escaped_end = @html_parser.tokenize("<script><!--a--</script>")
  guard escaped_end.tokens[1] is Characters("<!--a--<") else {
    fail("expected escaped script end-tag boundary text")
  }
  let escaped_eof = @html_parser.tokenize("<script><!--a--<")
  guard escaped_eof.tokens[1] is Characters("<!--a--<<") else {
    fail("expected escaped EOF less-than text")
  }
  let comment_end = @html_parser.tokenize("<script><!--a--></script>")
  guard comment_end.tokens[1] is Characters("<!--a-->") else {
    fail("expected script comment close to return to raw text")
  }
  let nul_script = @html_parser.tokenize(
    "<script>a\u{0000}b</script>",
    collect_errors=true,
  )
  guard nul_script.tokens[1] is Characters("a\u{FFFD}b") else {
    fail("expected replacement char in script text")
  }
  assert_eq(nul_script.errors.length(), 1)
  assert_eq(nul_script.errors[0].code, "unexpected-null-character")
  guard nul_script.errors[0].column is Some(10) else {
    fail("expected script text null at column 10")
  }
  let nul_style = @html_parser.tokenize(
    "<style>a\u{0000}b</style>",
    collect_errors=true,
  )
  guard nul_style.tokens[1] is Characters("a\u{FFFD}b") else {
    fail("expected replacement char in style text")
  }
  assert_eq(nul_style.errors.length(), 1)
  assert_eq(nul_style.errors[0].code, "unexpected-null-character")
  let nul_title = @html_parser.tokenize(
    "<title>a\u{0000} &lt; b</title>",
    collect_errors=true,
  )
  guard nul_title.tokens[1] is Characters("a\u{FFFD} < b") else {
    fail("expected replacement char and entity decoding in title text")
  }
  assert_eq(nul_title.errors.length(), 1)
  assert_eq(nul_title.errors[0].code, "unexpected-null-character")
  let nul_plaintext = @html_parser.tokenize(
    "<plaintext>a\u{0000}b",
    collect_errors=true,
  )
  guard nul_plaintext.tokens[1] is Characters("a\u{FFFD}b") else {
    fail("expected replacement char in plaintext")
  }
  assert_eq(nul_plaintext.errors.length(), 1)
  assert_eq(nul_plaintext.errors[0].code, "unexpected-null-character")
  let double_escaped = @html_parser.tokenize(
    "<script><!--<script>x</script>y</script>",
  )
  guard double_escaped.tokens[1] is Characters("<!--<script>x</script>y") else {
    fail("expected inner script end tag to stay in double-escaped text")
  }
  guard double_escaped.tokens[2] is Tag(double_end) else {
    fail("expected final script end")
  }
  assert_eq(double_end.name, "script")
  let not_double_escaped = @html_parser.tokenize(
    "<script><!--<scripty>x</script>-->z</script>",
  )
  guard not_double_escaped.tokens[1] is Characters("<!--<scripty>x") else {
    fail("expected non-script word to avoid double-escaped state")
  }
  guard not_double_escaped.tokens[3] is Characters("-->z") else {
    fail("expected text after the first script end tag")
  }
  let textarea = @html_parser.tokenize("<textarea>a &lt; b</textarea>")
  guard textarea.tokens[1] is Characters("a < b") else {
    fail("expected decoded textarea text")
  }
  let textarea_lf = @html_parser.tokenize("<textarea>\nline</textarea>")
  guard textarea_lf.tokens[1] is Characters("\nline") else {
    fail("expected tokenizer to preserve textarea leading newline")
  }
  let xmp = @html_parser.tokenize("<xmp><b>x</b></xmp>")
  guard xmp.tokens[1] is Characters("<b>x</b>") else {
    fail("expected xmp raw text")
  }
  let plaintext = @html_parser.tokenize("<plaintext><b>x</b></plaintext>")
  guard plaintext.tokens[1] is Characters("<b>x</b></plaintext>") else {
    fail("expected plaintext through EOF")
  }
  let iframe = @html_parser.tokenize("<iframe><b>x</b></iframe>")
  guard iframe.tokens[1] is Characters("<b>x</b>") else {
    fail("expected iframe raw text")
  }
  let empty_title = @html_parser.tokenize("<title></title>")
  guard empty_title.tokens[1] is Tag(empty_title_end) else {
    fail("expected immediate title end tag")
  }
  assert_true(empty_title_end.kind is EndTag)
  let eof_title = @html_parser.tokenize("<title>")
  guard eof_title.tokens[1] is Eof else {
    fail("expected EOF after empty unclosed title")
  }
  let empty_plaintext = @html_parser.tokenize("<plaintext>")
  guard empty_plaintext.tokens[1] is Eof else {
    fail("expected EOF after empty plaintext")
  }
  let xml_title = @html_parser.tokenize(
    "<title>\u{000C}\u{FDD0}</title>",
    xml_coercion=true,
  )
  guard xml_title.tokens[1] is Characters(" �") else {
    fail("expected XML coercion in RCDATA text")
  }
}

///|
test "tokenize keeps similarly named special end tags in text" {
  let title = @html_parser.tokenize("<title>a</titlex></title>")
  guard title.tokens[1] is Characters("a</titlex>") else {
    fail("expected title suffix end tag to stay in text")
  }
  guard title.tokens[2] is Tag(end_title) else {
    fail("expected final title end tag")
  }
  assert_true(end_title.kind is EndTag)
  assert_eq(end_title.name, "title")
  let style = @html_parser.tokenize("<style>a</stylex></style>")
  guard style.tokens[1] is Characters("a</stylex>") else {
    fail("expected style suffix end tag to stay in text")
  }
  guard style.tokens[2] is Tag(end_style) else {
    fail("expected final style end tag")
  }
  assert_true(end_style.kind is EndTag)
  assert_eq(end_style.name, "style")
}

///|
test "tokenize does not report special text EOF tree errors" {
  let script = @html_parser.tokenize("<script>x", collect_errors=true)
  guard script.tokens[1] is Characters("x") else {
    fail("expected unclosed script text")
  }
  assert_eq(script.errors.length(), 0)
  let plaintext = @html_parser.tokenize("<plaintext>x", collect_errors=true)
  guard plaintext.tokens[1] is Characters("x") else {
    fail("expected unclosed plaintext text")
  }
  assert_eq(plaintext.errors.length(), 0)
  let title = @html_parser.tokenize("<title>x", collect_errors=true)
  guard title.tokens[1] is Characters("x") else {
    fail("expected unclosed title text")
  }
  assert_eq(title.errors.length(), 0)
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

///|
test "tokenize reports unquoted attribute value fixture errors" {
  let less = @html_parser.tokenize("<div a=b<c>", collect_errors=true)
  guard less.tokens[0] is Tag(tag) else { fail("expected div tag") }
  guard tag.attrs["a"] is Some("b<c") else {
    fail("expected < in unquoted attr value")
  }
  assert_eq(less.errors.length(), 1)
  assert_eq(
    less.errors[0].code,
    "unexpected-character-in-unquoted-attribute-value",
  )
  guard less.errors[0].column is Some(9) else {
    fail("expected unquoted attr value error at column 9")
  }
  let backtick = @html_parser.tokenize("<div a=b`c>", collect_errors=true)
  guard backtick.tokens[0] is Tag(backtick_tag) else {
    fail("expected div tag")
  }
  guard backtick_tag.attrs["a"] is Some("b`c") else {
    fail("expected backtick in unquoted attr value")
  }
  assert_eq(backtick.errors.length(), 1)
  assert_eq(
    backtick.errors[0].code,
    "unexpected-character-in-unquoted-attribute-value",
  )
}

///|
test "tokenize reports missing whitespace after quoted attribute value" {
  let result = @html_parser.tokenize("<div a=\"b\"c=d>", collect_errors=true)
  guard result.tokens[0] is Tag(tag) else { fail("expected div tag") }
  guard tag.attrs["a"] is Some("b") else { fail("expected quoted attr") }
  guard tag.attrs["c"] is Some("d") else { fail("expected adjacent attr") }
  assert_eq(result.errors.length(), 1)
  assert_eq(result.errors[0].code, "missing-whitespace-between-attributes")
  guard result.errors[0].column is Some(11) else {
    fail("expected missing whitespace at adjacent attr name")
  }
}

///|
test "tokenize reports attribute name fixture errors" {
  let equals = @html_parser.tokenize("<div\r=abc>", collect_errors=true)
  guard equals.tokens[0] is Tag(eq_tag) else { fail("expected div tag") }
  guard eq_tag.attrs["=abc"] is Some("") else { fail("expected =abc attr") }
  assert_eq(equals.errors.length(), 1)
  assert_eq(
    equals.errors[0].code,
    "unexpected-equals-sign-before-attribute-name",
  )
  guard equals.errors[0].line is Some(2) else {
    fail("expected equals error on line 2")
  }
  guard equals.errors[0].column is Some(1) else {
    fail("expected equals error at column 1")
  }
  let invalid_char = @html_parser.tokenize("<div a<b>", collect_errors=true)
  guard invalid_char.tokens[0] is Tag(bad_tag) else { fail("expected div tag") }
  guard bad_tag.attrs["a<b"] is Some("") else { fail("expected a<b attr") }
  assert_eq(invalid_char.errors.length(), 1)
  assert_eq(
    invalid_char.errors[0].code,
    "unexpected-character-in-attribute-name",
  )
  guard invalid_char.errors[0].column is Some(7) else {
    fail("expected bad attr char at column 7")
  }
  let quote = @html_parser.tokenize("<div a\"b>", collect_errors=true)
  guard quote.tokens[0] is Tag(quote_tag) else { fail("expected div tag") }
  guard quote_tag.attrs["a\"b"] is Some("") else {
    fail("expected quote in attr name")
  }
  assert_eq(quote.errors.length(), 1)
  assert_eq(quote.errors[0].code, "unexpected-character-in-attribute-name")
  guard quote.errors[0].column is Some(7) else {
    fail("expected quote attr error at column 7")
  }
}

///|
test "tokenize keeps first duplicate attribute value" {
  let tokens = @html_parser.tokenize("<div a=1 a=2 a=3>", collect_errors=true)
  guard tokens.tokens[0] is Tag(tag) else { fail("expected div tag") }
  guard tag.attrs["a"] is Some("1") else {
    fail("expected first duplicate value")
  }
  assert_eq(tokens.errors.length(), 2)
  assert_eq(tokens.errors[0].code, "duplicate-attribute")
  assert_eq(tokens.errors[1].code, "duplicate-attribute")
}

///|
test "tokenize recovers invalid self closing start tag fixture case" {
  let result = @html_parser.tokenize("<div /a>", collect_errors=true)
  guard result.tokens[0] is Tag(tag) else { fail("expected div tag") }
  assert_eq(tag.name, "div")
  assert_eq(tag.self_closing, false)
  guard tag.attrs["a"] is Some("") else { fail("expected recovered a attr") }
  assert_eq(result.errors.length(), 1)
  assert_eq(result.errors[0].code, "unexpected-character-after-solidus-in-tag")
  guard result.errors[0].column is Some(7) else {
    fail("expected invalid self closing char at column 7")
  }
}

///|
test "tokenize start tag solidus does not skip following whitespace" {
  let tokenized = @html_parser.tokenize("<div/ >", collect_errors=true)
  guard tokenized.tokens[0] is Tag(tag) else { fail("expected div tag") }
  assert_eq(tag.name, "div")
  assert_eq(tag.self_closing, false)
  assert_eq(tokenized.errors.length(), 1)
  assert_eq(
    tokenized.errors[0].code,
    "unexpected-character-after-solidus-in-tag",
  )
  guard tokenized.errors[0].column is Some(6) else {
    fail("expected whitespace after solidus at column 6")
  }
  let img = @html_parser.tokenize("<img />", collect_errors=true)
  guard img.tokens[0] is Tag(img_tag) else { fail("expected img tag") }
  assert_eq(img_tag.self_closing, true)
  assert_eq(img.errors.length(), 0)
}

///|
test "tokenize normalizes BOM and CRLF edge cases" {
  let bom = @html_parser.tokenize("\u{FEFF}<div>")
  guard bom.tokens[0] is Tag(tag) else { fail("expected div start tag") }
  assert_eq(tag.name, "div")
  let text = @html_parser.tokenize("abc\r\ndef\rghi")
  guard text.tokens[0] is Characters(data) else {
    fail("expected character token")
  }
  assert_eq(data, "abc\ndef\nghi")
  let comment = @html_parser.tokenize("<!-- a\rb -->")
  guard comment.tokens[0] is CommentToken(data) else {
    fail("expected comment")
  }
  assert_eq(data, " a\nb ")
  let attr = @html_parser.tokenize("<div title=\"a\rb\">")
  guard attr.tokens[0] is Tag(attr_tag) else { fail("expected attr tag") }
  guard attr_tag.attrs["title"] is Some("a\nb") else {
    fail("expected normalized attr")
  }
}

///|
test "tokenize matches upstream CR and LF normalization fixtures" {
  let bom = @html_parser.tokenize("\u{FEFF}<div>", collect_errors=true)
  guard bom.tokens[0] is Tag(bom_tag) else {
    fail("expected BOM-stripped div start tag")
  }
  assert_eq(bom_tag.name, "div")
  assert_eq(bom.errors.length(), 0)
  let cr_text = @html_parser.tokenize("abc\rdef", collect_errors=true)
  guard cr_text.tokens[0] is Characters("abc\ndef") else {
    fail("expected CR in text to normalize to LF")
  }
  assert_eq(cr_text.errors.length(), 0)
  let crlf_text = @html_parser.tokenize("\r\n", collect_errors=true)
  guard crlf_text.tokens[0] is Characters("\n") else {
    fail("expected CRLF in text to collapse to one LF")
  }
  assert_eq(crlf_text.errors.length(), 0)
  let cr_after_name = @html_parser.tokenize("<div\r>", collect_errors=true)
  guard cr_after_name.tokens[0] is Tag(cr_after_name_tag) else {
    fail("expected CR after tag name to close div")
  }
  assert_eq(cr_after_name_tag.name, "div")
  assert_eq(cr_after_name_tag.attrs.length(), 0)
  assert_eq(cr_after_name.errors.length(), 0)
  let crlf_before_attr = @html_parser.tokenize(
    "<div\r\nattr>",
    collect_errors=true,
  )
  guard crlf_before_attr.tokens[0] is Tag(crlf_before_attr_tag) else {
    fail("expected CRLF before attribute name")
  }
  guard crlf_before_attr_tag.attrs["attr"] is Some("") else {
    fail("expected empty attr after CRLF")
  }
  assert_eq(crlf_before_attr.errors.length(), 0)
  let cr_after_attr = @html_parser.tokenize("<div attr\r>", collect_errors=true)
  guard cr_after_attr.tokens[0] is Tag(cr_after_attr_tag) else {
    fail("expected CR after attribute name")
  }
  guard cr_after_attr_tag.attrs["attr"] is Some("") else {
    fail("expected empty attr after CR")
  }
  assert_eq(cr_after_attr.errors.length(), 0)
  let cr_space_after_attr = @html_parser.tokenize(
    "<div attr\r >",
    collect_errors=true,
  )
  guard cr_space_after_attr.tokens[0] is Tag(cr_space_after_attr_tag) else {
    fail("expected CR space after attribute name")
  }
  guard cr_space_after_attr_tag.attrs["attr"] is Some("") else {
    fail("expected empty attr after CR space")
  }
  assert_eq(cr_space_after_attr.errors.length(), 0)
  let crlf_after_attr = @html_parser.tokenize(
    "<div attr\r\n>",
    collect_errors=true,
  )
  guard crlf_after_attr.tokens[0] is Tag(crlf_after_attr_tag) else {
    fail("expected CRLF after attribute name")
  }
  guard crlf_after_attr_tag.attrs["attr"] is Some("") else {
    fail("expected empty attr after CRLF")
  }
  assert_eq(crlf_after_attr.errors.length(), 0)
  let cr_tab_after_attr = @html_parser.tokenize(
    "<div attr\r\t>",
    collect_errors=true,
  )
  guard cr_tab_after_attr.tokens[0] is Tag(cr_tab_after_attr_tag) else {
    fail("expected CR tab after attribute name")
  }
  guard cr_tab_after_attr_tag.attrs["attr"] is Some("") else {
    fail("expected empty attr after CR tab")
  }
  assert_eq(cr_tab_after_attr.errors.length(), 0)
  let double_attr = @html_parser.tokenize(
    "<div attr=\"a\rb\">",
    collect_errors=true,
  )
  guard double_attr.tokens[0] is Tag(double_attr_tag) else {
    fail("expected double-quoted attr with CR")
  }
  guard double_attr_tag.attrs["attr"] is Some("a\nb") else {
    fail("expected normalized CR in double-quoted attr")
  }
  assert_eq(double_attr.errors.length(), 0)
  let single_attr = @html_parser.tokenize(
    "<div attr='a\rb'>",
    collect_errors=true,
  )
  guard single_attr.tokens[0] is Tag(single_attr_tag) else {
    fail("expected single-quoted attr with CR")
  }
  guard single_attr_tag.attrs["attr"] is Some("a\nb") else {
    fail("expected normalized CR in single-quoted attr")
  }
  assert_eq(single_attr.errors.length(), 0)
  let unquoted = @html_parser.tokenize("<div attr=abc>", collect_errors=true)
  guard unquoted.tokens[0] is Tag(unquoted_tag) else {
    fail("expected unquoted attr")
  }
  guard unquoted_tag.attrs["attr"] is Some("abc") else {
    fail("expected unquoted attr value")
  }
  assert_eq(unquoted.errors.length(), 0)
  let lf_after_name = @html_parser.tokenize("<div\n>", collect_errors=true)
  guard lf_after_name.tokens[0] is Tag(lf_after_name_tag) else {
    fail("expected LF after tag name")
  }
  assert_eq(lf_after_name_tag.name, "div")
  assert_eq(lf_after_name_tag.attrs.length(), 0)
  assert_eq(lf_after_name.errors.length(), 0)
  let lf_after_attr = @html_parser.tokenize("<div attr\n>", collect_errors=true)
  guard lf_after_attr.tokens[0] is Tag(lf_after_attr_tag) else {
    fail("expected LF after attribute name")
  }
  guard lf_after_attr_tag.attrs["attr"] is Some("") else {
    fail("expected empty attr after LF")
  }
  assert_eq(lf_after_attr.errors.length(), 0)
  let double_lf_attr = @html_parser.tokenize(
    "<div attr=\"a\nb\">",
    collect_errors=true,
  )
  guard double_lf_attr.tokens[0] is Tag(double_lf_attr_tag) else {
    fail("expected double-quoted attr with LF")
  }
  guard double_lf_attr_tag.attrs["attr"] is Some("a\nb") else {
    fail("expected LF in double-quoted attr")
  }
  assert_eq(double_lf_attr.errors.length(), 0)
  let single_lf_attr = @html_parser.tokenize(
    "<div attr='a\nb'>",
    collect_errors=true,
  )
  guard single_lf_attr.tokens[0] is Tag(single_lf_attr_tag) else {
    fail("expected single-quoted attr with LF")
  }
  guard single_lf_attr_tag.attrs["attr"] is Some("a\nb") else {
    fail("expected LF in single-quoted attr")
  }
  assert_eq(single_lf_attr.errors.length(), 0)
  let crlf_space_attr = @html_parser.tokenize(
    "<div \r\n attr>",
    collect_errors=true,
  )
  guard crlf_space_attr.tokens[0] is Tag(crlf_space_attr_tag) else {
    fail("expected CRLF space before attr")
  }
  guard crlf_space_attr_tag.attrs["attr"] is Some("") else {
    fail("expected empty attr after CRLF space")
  }
  assert_eq(crlf_space_attr.errors.length(), 0)
  let comment = @html_parser.tokenize(
    "<!-- test\rcomment -->",
    collect_errors=true,
  )
  guard comment.tokens[0] is CommentToken(" test\ncomment ") else {
    fail("expected CR in comment to normalize to LF")
  }
  assert_eq(comment.errors.length(), 0)
}

///|
test "tokenize handles comment dash EOF and null edge cases" {
  let crlf_eof = @html_parser.tokenize("<!----!\r\n", collect_errors=true)
  guard crlf_eof.tokens[0] is CommentToken("--!\n") else {
    fail("expected CRLF EOF comment data")
  }
  assert_eq(crlf_eof.errors.length(), 1)
  assert_eq(crlf_eof.errors[0].code, "eof-in-comment")
  guard crlf_eof.errors[0].line is Some(2) else {
    fail("expected EOF comment error on line 2")
  }
  guard crlf_eof.errors[0].column is Some(0) else {
    fail("expected EOF comment error at column 0")
  }
  let bang_null = @html_parser.tokenize(
    "<!--x--!\u{0000}-->",
    collect_errors=true,
  )
  guard bang_null.tokens[0] is CommentToken("x--!�") else {
    fail("expected replacement after --! null")
  }
  assert_eq(bang_null.errors.length(), 1)
  assert_eq(bang_null.errors[0].code, "unexpected-null-character")
  guard bang_null.errors[0].column is Some(9) else {
    fail("expected --! null error at column 9")
  }
  let incorrectly_closed = @html_parser.tokenize(
    "<!--x---a-->",
    collect_errors=true,
  )
  guard incorrectly_closed.tokens[0] is CommentToken("x---a") else {
    fail("expected incorrectly closed dash run data")
  }
  assert_eq(incorrectly_closed.errors.length(), 1)
  assert_eq(incorrectly_closed.errors[0].code, "incorrectly-closed-comment")
  guard incorrectly_closed.errors[0].column is Some(9) else {
    fail("expected incorrect close error at column 9")
  }
  let dash_null = @html_parser.tokenize("<!--x--\u{0000}>", collect_errors=true)
  guard dash_null.tokens[0] is CommentToken("x--�>") else {
    fail("expected replacement after -- null")
  }
  assert_eq(dash_null.errors.length(), 2)
  assert_eq(dash_null.errors[0].code, "unexpected-null-character")
  assert_eq(dash_null.errors[1].code, "eof-in-comment")
}

///|
test "tokenize handles comment EOF branch variants" {
  let empty = @html_parser.tokenize("<!--", collect_errors=true)
  guard empty.tokens[0] is CommentToken("") else {
    fail("expected empty EOF comment")
  }
  assert_eq(empty.errors.length(), 1)
  assert_eq(empty.errors[0].code, "eof-in-comment")
  guard empty.errors[0].column is Some(4) else {
    fail("expected empty comment EOF at column 4")
  }
  let bang_eof = @html_parser.tokenize("<!--x--!", collect_errors=true)
  guard bang_eof.tokens[0] is CommentToken("x") else {
    fail("expected --! EOF comment data")
  }
  assert_eq(bang_eof.errors.length(), 1)
  assert_eq(bang_eof.errors[0].code, "eof-in-comment")
  guard bang_eof.errors[0].column is Some(8) else {
    fail("expected --! EOF at column 8")
  }
  let dash_eof = @html_parser.tokenize("<!--x--", collect_errors=true)
  guard dash_eof.tokens[0] is CommentToken("x") else {
    fail("expected -- EOF comment data")
  }
  assert_eq(dash_eof.errors.length(), 1)
  assert_eq(dash_eof.errors[0].code, "eof-in-comment")
  guard dash_eof.errors[0].column is Some(7) else {
    fail("expected -- EOF at column 7")
  }
  let null_eof = @html_parser.tokenize("<!--x\u{0000}", collect_errors=true)
  guard null_eof.tokens[0] is CommentToken("x�") else {
    fail("expected null EOF comment data")
  }
  assert_eq(null_eof.errors.length(), 2)
  assert_eq(null_eof.errors[0].code, "unexpected-null-character")
  assert_eq(null_eof.errors[1].code, "eof-in-comment")
  guard null_eof.errors[0].column is Some(6) else {
    fail("expected comment null at column 6")
  }
  guard null_eof.errors[1].column is Some(6) else {
    fail("expected null EOF at column 6")
  }
}

///|
test "tokenize reports noncharacters in input stream" {
  let tokens = @html_parser.tokenize("ab\u{FDD0}cd", collect_errors=true)
  guard tokens.tokens[0] is Characters("ab\u{FDD0}cd") else {
    fail("expected noncharacter to stay in character token")
  }
  assert_eq(tokens.errors.length(), 1)
  assert_eq(tokens.errors[0].code, "noncharacter-in-input-stream")
  guard tokens.errors[0].column is Some(3) else {
    fail("expected data-state noncharacter at column 3")
  }
  let multiline = @html_parser.tokenize("a\nb\u{FDD0}c", collect_errors=true)
  assert_eq(multiline.errors.length(), 1)
  assert_eq(multiline.errors[0].code, "noncharacter-in-input-stream")
  guard multiline.errors[0].line is Some(2) else {
    fail("expected multiline noncharacter on line 2")
  }
  guard multiline.errors[0].column is Some(2) else {
    fail("expected multiline noncharacter at column 2")
  }
  let invalid_open = @html_parser.tokenize("<\u{FDD0}", collect_errors=true)
  guard invalid_open.tokens[0] is Characters("<\u{FDD0}") else {
    fail("expected invalid tag open as text")
  }
  assert_eq(invalid_open.errors.length(), 3)
  assert_eq(invalid_open.errors[0].code, "noncharacter-in-input-stream")
  assert_eq(invalid_open.errors[1].code, "invalid-first-character-of-tag-name")
  assert_eq(invalid_open.errors[2].code, "noncharacter-in-input-stream")
  let invalid_xml = @html_parser.tokenize(
    "<\u{000C}\u{FDD0}&lt;",
    collect_errors=true,
    xml_coercion=true,
  )
  guard invalid_xml.tokens[0] is Characters("< �<") else {
    fail("expected invalid tag-open text to decode and XML-coerce")
  }
  assert_eq(invalid_xml.errors.length(), 2)
  assert_eq(invalid_xml.errors[0].code, "invalid-first-character-of-tag-name")
  assert_eq(invalid_xml.errors[1].code, "noncharacter-in-input-stream")
  let invalid_null = @html_parser.tokenize("<\u{0000}", collect_errors=true)
  guard invalid_null.tokens[0] is Characters("<\u{0000}") else {
    fail("expected invalid tag-open null text")
  }
  assert_eq(invalid_null.errors.length(), 2)
  assert_eq(invalid_null.errors[0].code, "invalid-first-character-of-tag-name")
  assert_eq(invalid_null.errors[1].code, "unexpected-null-character")
}
