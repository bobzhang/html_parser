///|
test "public parser error modes and document scaffolding stay stable" {
  let collected = @html_parser.parse(
    "<title>T</title><main><p>Body</p></main>",
    collect_errors=true,
  )
  assert_eq(
    collected.to_html(pretty=false),
    "<html><head><title>T</title></head><body><main><p>Body</p></main></body></html>",
  )
  assert_eq(collected.errors.length(), 1)
  assert_eq(collected.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(collected.errors[0].category, "treebuilder")

  let loose = @html_parser.parse("<p>x</p>")
  assert_eq(loose.errors.length(), 0)
  let strict_result : Result[@html_parser.ParsedHtml, @html_parser.HtmlError] = try? @html_parser.parse(
    "<p>x</p>",
    strict=true,
  )
  match strict_result {
    Err(StrictMode(error)) =>
      assert_eq(error.code, "expected-doctype-but-got-start-tag")
    _ => fail("expected strict document parse to raise StrictMode")
  }
}

///|
test "parser ignores unmatched end tags without closing current element" {
  let doc = @html_parser.parse_fragment(
    "<div><p>open</span>after</div>",
    collect_errors=true,
  )
  assert_eq(doc.errors.length(), 1)
  assert_eq(doc.errors[0].code, "unexpected-end-tag")
  assert_eq(doc.to_html(pretty=false), "<div><p>openafter</p></div>")
}

///|
test "parser creates empty paragraph for stray p end tags" {
  let root = @html_parser.parse_fragment("</p>after", collect_errors=true)
  assert_eq(root.to_html(pretty=false), "<p></p>after")
  assert_eq(root.errors.length(), 1)
  assert_eq(root.errors[0].code, "unexpected-end-tag")
  let nested = @html_parser.parse_fragment("<div></p>after</div>")
  assert_eq(nested.to_html(pretty=false), "<div><p></p>after</div>")
}

///|
test "parser reports early ancestor end tags after implied end tags" {
  let implied = @html_parser.parse_fragment(
    "<div><p>x</div>after",
    collect_errors=true,
  )
  assert_eq(implied.to_html(pretty=false), "<div><p>x</p></div>after")
  assert_eq(implied.errors.length(), 0)
  let early = @html_parser.parse_fragment(
    "<div><span>x</div>after",
    collect_errors=true,
  )
  assert_eq(early.to_html(pretty=false), "<div><span>x</span></div>after")
  assert_eq(early.errors.length(), 1)
  assert_eq(early.errors[0].code, "end-tag-too-early")
}

///|
test "parser closes open headings for mismatched heading end tags" {
  let doc = @html_parser.parse_fragment(
    "<h1><span>one</h2>after",
    collect_errors=true,
  )
  assert_eq(doc.to_html(pretty=false), "<h1><span>one</span></h1>after")
  assert_eq(doc.errors.length(), 1)
  assert_eq(doc.errors[0].code, "end-tag-too-early")
  let stray = @html_parser.parse_fragment("</h1>after", collect_errors=true)
  assert_eq(stray.to_html(pretty=false), "after")
  assert_eq(stray.errors[0].code, "unexpected-end-tag")
}

///|
test "parser treats br end tags as recovered br elements" {
  let paragraph = @html_parser.parse_fragment(
    "<p>one</br>two",
    collect_errors=true,
  )
  assert_eq(paragraph.to_html(pretty=false), "<p>one</p><br>two")
  assert_eq(paragraph.errors.length(), 1)
  assert_eq(paragraph.errors[0].code, "unexpected-end-tag")
  let loose = @html_parser.parse_fragment("a</br>b")
  assert_eq(loose.to_html(pretty=false), "a<br>b")
}

///|
test "parser treats image start tags as img elements" {
  let doc = @html_parser.parse_fragment(
    "<p>a<image src=x>b</p>",
    collect_errors=true,
  )
  assert_eq(doc.to_html(pretty=false), "<p>a<img src=\"x\">b</p>")
  assert_eq(doc.errors.length(), 1)
  assert_eq(doc.errors[0].code, "image-start-tag")
  let loose = @html_parser.parse_fragment("<image>text</image>")
  assert_eq(loose.to_html(pretty=false), "<img>text")
}

///|
test "strict mode raises on first parse error" {
  let fragment_result : Result[@html_parser.ParsedHtml, @html_parser.HtmlError] = try? @html_parser.parse_fragment(
    "<p>open</span>",
    strict=true,
  )
  match fragment_result {
    Err(StrictMode(error)) => assert_eq(error.code, "unexpected-end-tag")
    _ => fail("expected strict fragment parse to raise StrictMode")
  }
  let document_result : Result[@html_parser.ParsedHtml, @html_parser.HtmlError] = try? @html_parser.parse(
    "<p>x",
    strict=true,
  )
  match document_result {
    Err(StrictMode(error)) => {
      assert_eq(error.code, "expected-doctype-but-got-start-tag")
      guard error.column is Some(3) else {
        fail("expected strict document error at initial start tag")
      }
    }
    _ => fail("expected strict document parse to raise StrictMode")
  }
}

///|
test "parser error collection is opt in and keeps line columns" {
  let loose = @html_parser.parse("<p>\u{0000}</p>")
  assert_eq(loose.errors.length(), 0)
  let collected = @html_parser.parse("<p>\u{0000}</p>", collect_errors=true)
  assert_true(collected.errors.length() > 0)
  assert_eq(collected.errors[0].code, "expected-doctype-but-got-start-tag")
  let mut saw_null = false
  for error in collected.errors {
    if error.code == "unexpected-null-character" {
      saw_null = true
      guard error.line is Some(1) else {
        fail("expected inline null error on line 1")
      }
      guard error.column is Some(4) else {
        fail("expected inline null error at column 4")
      }
    }
  }
  assert_true(saw_null)
  let multiline = @html_parser.parse(
    "line1\nline2\u{0000}",
    collect_errors=true,
  )
  let mut saw_multiline_null = false
  for error in multiline.errors {
    if error.code == "unexpected-null-character" {
      saw_multiline_null = true
      guard error.line is Some(2) else {
        fail("expected multiline null error on line 2")
      }
      guard error.column is Some(6) else {
        fail("expected multiline null error at column 6")
      }
    }
  }
  assert_true(saw_multiline_null)
  let strict_valid : Result[@html_parser.ParsedHtml, @html_parser.HtmlError] = try? @html_parser.parse(
    "<!DOCTYPE html><html><head><title>Test</title></head><body></body></html>",
    strict=true,
  )
  match strict_valid {
    Ok(doc) => assert_eq(doc.errors.length(), 0)
    Err(_) => fail("expected strict valid document to parse")
  }
}

///|
test "parser reports treebuilder error positions after newlines" {
  let stray = @html_parser.parse(
    "<!DOCTYPE html>\n<html>\n<body>\n</span>",
    collect_errors=true,
  )
  assert_eq(stray.errors.length(), 1)
  assert_eq(stray.errors[0].code, "unexpected-end-tag")
  guard stray.errors[0].line is Some(4) else {
    fail("expected stray end tag error on line 4")
  }
  guard stray.errors[0].column is Some(7) else {
    fail("expected stray end tag error at tag close")
  }
  let attr_before_name = @html_parser.parse(
    "<div\n   \n   class='test'>content</div>",
    collect_errors=true,
  )
  assert_eq(attr_before_name.errors.length(), 1)
  assert_eq(
    attr_before_name.errors[0].code,
    "expected-doctype-but-got-start-tag",
  )
  guard attr_before_name.errors[0].line is Some(3) else {
    fail("expected multiline attr name start tag on line 3")
  }
  guard attr_before_name.errors[0].column is Some(16) else {
    fail("expected multiline attr name start tag at column 16")
  }
  let attr_before_equals = @html_parser.parse(
    "<div class\n   \n   ='test'>content</div>",
    collect_errors=true,
  )
  assert_eq(attr_before_equals.errors.length(), 1)
  assert_eq(
    attr_before_equals.errors[0].code,
    "expected-doctype-but-got-start-tag",
  )
  guard attr_before_equals.errors[0].line is Some(3) else {
    fail("expected multiline attr equals start tag on line 3")
  }
  guard attr_before_equals.errors[0].column is Some(11) else {
    fail("expected multiline attr equals start tag at column 11")
  }
  let quoted_attr = @html_parser.parse(
    "<div data-content=\"line1\nline2\nline3\">text</div>",
    collect_errors=true,
  )
  assert_eq(quoted_attr.errors.length(), 1)
  assert_eq(quoted_attr.errors[0].code, "expected-doctype-but-got-start-tag")
  guard quoted_attr.errors[0].line is Some(3) else {
    fail("expected quoted multiline attr error on line 3")
  }
  guard quoted_attr.errors[0].column is Some(7) else {
    fail("expected quoted multiline attr error at column 7")
  }
  let cr_attr = @html_parser.parse(
    "<div data-x=\"a\r\nb\rc\">text</div>",
    collect_errors=true,
  )
  assert_eq(cr_attr.errors.length(), 1)
  assert_eq(cr_attr.errors[0].code, "expected-doctype-but-got-start-tag")
  guard cr_attr.errors[0].line is Some(3) else {
    fail("expected CR-normalized attr error on line 3")
  }
  guard cr_attr.errors[0].column is Some(3) else {
    fail("expected CR-normalized attr error at column 3")
  }
}

///|
test "parse errors expose tokenizer treebuilder and default categories" {
  let direct : @html_parser.ParseError = ParseError("custom-error")
  assert_eq(direct.category, "parse")
  assert_eq(direct.message, "custom-error")
  let tokenized = @html_parser.tokenize("<", collect_errors=true)
  assert_eq(tokenized.errors.length(), 1)
  assert_eq(tokenized.errors[0].code, "eof-before-tag-name")
  assert_eq(tokenized.errors[0].category, "tokenizer")
  let document = @html_parser.parse("<div>x", collect_errors=true)
  assert_eq(document.errors.length(), 2)
  assert_eq(document.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(document.errors[0].category, "treebuilder")
  assert_eq(document.errors[1].code, "expected-closing-tag-but-got-eof")
  assert_eq(document.errors[1].category, "treebuilder")
  let malformed = @html_parser.parse_fragment("<*foo>", collect_errors=true)
  assert_eq(malformed.errors.length(), 1)
  assert_eq(malformed.errors[0].code, "invalid-first-character-of-tag-name")
  assert_eq(malformed.errors[0].category, "tokenizer")
  let mixed = @html_parser.parse("<p>\u{0000}</p>", collect_errors=true)
  assert_eq(mixed.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(mixed.errors[0].category, "treebuilder")
  let mut saw_null = false
  for error in mixed.errors {
    if error.code == "unexpected-null-character" {
      saw_null = true
      assert_eq(error.category, "tokenizer")
    }
  }
  assert_true(saw_null)
}

///|
test "parse error values preserve location message and equality" {
  let first : @html_parser.ParseError = ParseError(
    "error-code",
    line=1,
    column=5,
  )
  let same : @html_parser.ParseError = ParseError(
    "error-code",
    line=1,
    column=5,
  )
  let other : @html_parser.ParseError = ParseError(
    "other-error",
    line=1,
    column=5,
  )
  assert_true(first == same)
  assert_true(first != other)
  guard first.line is Some(1) else {
    fail("expected explicit parse error line")
  }
  guard first.column is Some(5) else {
    fail("expected explicit parse error column")
  }
  assert_eq(first.category, "parse")
  assert_eq(first.message, "error-code")
  let detailed : @html_parser.ParseError = ParseError(
    "test-error",
    line=5,
    column=10,
    category="treebuilder",
    message="Detailed error",
  )
  assert_eq(detailed.code, "test-error")
  assert_eq(detailed.category, "treebuilder")
  assert_eq(detailed.message, "Detailed error")
  guard detailed.line is Some(5) else {
    fail("expected detailed parse error line")
  }
  guard detailed.column is Some(10) else {
    fail("expected detailed parse error column")
  }
  let without_location : @html_parser.ParseError = ParseError(
    "test-error",
    message="This is a test error",
  )
  assert_true(without_location.line is None)
  assert_true(without_location.column is None)
  assert_eq(without_location.category, "parse")
  assert_eq(without_location.message, "This is a test error")
}

///|
test "collect_errors records malformed markup without raising" {
  let doc = @html_parser.parse_fragment("<p>open</span>", collect_errors=true)
  assert_eq(doc.errors.length(), 1)
  assert_eq(doc.errors[0].code, "unexpected-end-tag")
  assert_eq(doc.to_html(pretty=false), "<p>open</p>")
  let invalid_open = @html_parser.parse_fragment("<*foo>", collect_errors=true)
  assert_eq(invalid_open.to_html(pretty=false), "&lt;*foo&gt;")
  assert_eq(invalid_open.errors.length(), 1)
  assert_eq(invalid_open.errors[0].code, "invalid-first-character-of-tag-name")
  guard invalid_open.errors[0].column is Some(2) else {
    fail("expected invalid tag-open error at second character")
  }
  let empty_end = @html_parser.parse_fragment("</>", collect_errors=true)
  assert_eq(empty_end.to_html(pretty=false), "")
  assert_eq(empty_end.errors.length(), 1)
  assert_eq(empty_end.errors[0].code, "empty-end-tag")
  guard empty_end.errors[0].column is Some(3) else {
    fail("expected empty end tag error at >")
  }
  let invalid_end = @html_parser.parse_fragment("</ >", collect_errors=true)
  assert_eq(invalid_end.to_html(pretty=false), "<!-- -->")
  assert_eq(invalid_end.errors.length(), 1)
  assert_eq(invalid_end.errors[0].code, "invalid-first-character-of-tag-name")
  guard invalid_end.errors[0].column is Some(3) else {
    fail("expected invalid end tag error after slash")
  }
  let lt = @html_parser.parse_fragment("<", collect_errors=true)
  assert_eq(lt.to_html(pretty=false), "&lt;")
  assert_eq(lt.errors.length(), 1)
  assert_eq(lt.errors[0].code, "eof-before-tag-name")
  guard lt.errors[0].column is Some(1) else {
    fail("expected bare < EOF at the < character")
  }
  let end_open = @html_parser.parse_fragment("</", collect_errors=true)
  assert_eq(end_open.to_html(pretty=false), "&lt;/")
  assert_eq(end_open.errors.length(), 1)
  assert_eq(end_open.errors[0].code, "eof-before-tag-name")
  guard end_open.errors[0].column is Some(2) else {
    fail("expected bare </ EOF at the slash")
  }
}

///|
test "parser recovers malformed ordinary end tags" {
  let solidus = @html_parser.parse_fragment(
    "<div>x</div/foo>y",
    collect_errors=true,
  )
  assert_eq(solidus.to_html(pretty=false), "<div>x</div>y")
  assert_eq(solidus.errors.length(), 1)
  assert_eq(solidus.errors[0].code, "unexpected-character-after-solidus-in-tag")
  guard solidus.errors[0].column is Some(13) else {
    fail("expected ordinary end-tag bad solidus at recovered attr")
  }
  let eof = @html_parser.parse_fragment("<div>x</div/foo", collect_errors=true)
  assert_eq(eof.to_html(pretty=false), "<div>x</div>")
  assert_eq(eof.errors.length(), 3)
  assert_eq(eof.errors[0].code, "unexpected-character-after-solidus-in-tag")
  assert_eq(eof.errors[1].code, "eof-in-tag")
  assert_eq(eof.errors[2].code, "expected-closing-tag-but-got-eof")
  guard eof.errors[1].column is Some(15) else {
    fail("expected EOF in malformed ordinary end tag at final name char")
  }
  guard eof.errors[2].column is Some(15) else {
    fail("expected tree EOF after malformed ordinary end tag")
  }
  let null_name = @html_parser.parse_fragment(
    "<div>x</d\u{0000}iv>y",
    collect_errors=true,
  )
  assert_eq(null_name.to_html(pretty=false), "<div>xy</div>")
  assert_eq(null_name.errors.length(), 3)
  assert_eq(null_name.errors[0].code, "unexpected-null-character")
  assert_eq(null_name.errors[1].code, "unexpected-end-tag")
  assert_eq(null_name.errors[2].code, "expected-closing-tag-but-got-eof")
  guard null_name.errors[0].column is Some(10) else {
    fail("expected null in ordinary end tag at column 10")
  }
  guard null_name.errors[1].column is Some(13) else {
    fail("expected mismatched null end tag at the tag close")
  }
  guard null_name.errors[2].column is Some(14) else {
    fail("expected EOF for still-open element after null end tag")
  }
}

///|
test "parser reports EOF for unclosed non-implied elements" {
  let unfinished_start = @html_parser.parse_fragment(
    "<div foo=\"",
    collect_errors=true,
  )
  assert_eq(unfinished_start.to_html(pretty=false), "")
  assert_eq(unfinished_start.errors.length(), 1)
  assert_eq(unfinished_start.errors[0].code, "eof-in-tag")
  guard unfinished_start.errors[0].column is Some(10) else {
    fail("expected incomplete start tag EOF at final quote")
  }
  let unfinished_end = @html_parser.parse_fragment(
    "<p>x</span",
    collect_errors=true,
  )
  assert_eq(unfinished_end.to_html(pretty=false), "<p>x</p>")
  assert_eq(unfinished_end.errors.length(), 1)
  assert_eq(unfinished_end.errors[0].code, "eof-in-tag")
  guard unfinished_end.errors[0].column is Some(10) else {
    fail("expected incomplete end tag EOF at final name character")
  }
  let div = @html_parser.parse_fragment("<div>x", collect_errors=true)
  assert_eq(div.to_html(pretty=false), "<div>x</div>")
  assert_eq(div.errors.length(), 1)
  assert_eq(div.errors[0].code, "expected-closing-tag-but-got-eof")
  guard div.errors[0].column is Some(6) else {
    fail("expected EOF error at final input column")
  }
  let paragraph = @html_parser.parse_fragment("<p>x", collect_errors=true)
  assert_eq(paragraph.to_html(pretty=false), "<p>x</p>")
  assert_eq(paragraph.errors.length(), 0)
  let list = @html_parser.parse_fragment("<ul><li>x", collect_errors=true)
  assert_eq(list.to_html(pretty=false), "<ul><li>x</li></ul>")
  assert_eq(list.errors.length(), 1)
  assert_eq(list.errors[0].code, "expected-closing-tag-but-got-eof")
  guard list.errors[0].column is Some(9) else {
    fail("expected list EOF error at final input column")
  }
  let doc = @html_parser.parse("<!doctype html><div>x", collect_errors=true)
  assert_eq(
    doc.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body><div>x</div></body></html>",
  )
  assert_eq(doc.errors.length(), 1)
  assert_eq(doc.errors[0].code, "expected-closing-tag-but-got-eof")
  let unicode_tail = @html_parser.parse_fragment(
    "<div>😀",
    collect_errors=true,
  )
  assert_eq(unicode_tail.errors[0].code, "expected-closing-tag-but-got-eof")
  guard unicode_tail.errors[0].column is Some(6) else {
    fail("expected EOF position to use the final character boundary")
  }
}
