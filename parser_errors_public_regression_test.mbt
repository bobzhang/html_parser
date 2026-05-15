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
