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
  let direct = @html_parser.ParseError::new("custom-error")
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
  let first = @html_parser.ParseError::new("error-code", line=1, column=5)
  let same = @html_parser.ParseError::new("error-code", line=1, column=5)
  let other = @html_parser.ParseError::new("other-error", line=1, column=5)
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
  let detailed = @html_parser.ParseError::new(
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
  let without_location = @html_parser.ParseError::new(
    "test-error",
    message="This is a test error",
  )
  assert_true(without_location.line is None)
  assert_true(without_location.column is None)
  assert_eq(without_location.category, "parse")
  assert_eq(without_location.message, "This is a test error")
}
