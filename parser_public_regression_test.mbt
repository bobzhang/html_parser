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
test "public parser fragment contexts stay stable" {
  let table = @html_parser.parse_fragment(
    "<tr><td>A</td></tr>",
    context=@html_parser.FragmentContext::new("table"),
    collect_errors=true,
  )
  assert_eq(table.to_html(pretty=false), "<tbody><tr><td>A</td></tr></tbody>")
  assert_eq(table.errors.length(), 0)

  let textarea = @html_parser.parse_fragment(
    "<b>x</b>&lt;",
    context=@html_parser.FragmentContext::new("textarea"),
  )
  assert_eq(textarea.to_html(pretty=false), "&lt;b&gt;x&lt;/b&gt;&amp;lt;")
  assert_eq(textarea.to_text(separator="", strip=false), "<b>x</b>&lt;")
  assert_eq(textarea.query("b").length(), 0)

  let svg = @html_parser.parse_fragment(
    "<lineargradient><stop/></lineargradient>",
    context=@html_parser.FragmentContext::new("svg", ns="svg"),
    collect_errors=true,
  )
  assert_eq(
    svg.to_html(pretty=false),
    "<linearGradient><stop></stop></linearGradient>",
  )
  assert_eq(svg.errors.length(), 1)
  assert_eq(svg.errors[0].code, "expected-closing-tag-but-got-eof")
  guard svg.query_one("stop") is Some(stop) else {
    fail("expected SVG stop child")
  }
  assert_true(stop.namespace_uri() is Some("svg"))
}

///|
test "public parser source locations and scripting mode stay stable" {
  let located = @html_parser.parse_fragment(
    "lead\n<p id=x>Hi</p>",
    track_node_locations=true,
  )
  guard located.query_one("p") is Some(paragraph) else {
    fail("expected parsed paragraph")
  }
  guard paragraph.origin_offset() is Some(5) else {
    fail("expected paragraph origin offset")
  }
  guard paragraph.origin_line() is Some(2) else {
    fail("expected paragraph origin line")
  }
  guard paragraph.origin_col() is Some(1) else {
    fail("expected paragraph origin column")
  }
  let children = paragraph.children()
  assert_eq(children.length(), 1)
  guard children[0].origin_location() is Some((2, 9)) else {
    fail("expected text child origin location")
  }

  let enabled = @html_parser.parse_fragment(
    "<noscript><b>Hi</b></noscript>",
    scripting_enabled=true,
  )
  assert_eq(
    enabled.to_html(pretty=false),
    "<noscript>&lt;b&gt;Hi&lt;/b&gt;</noscript>",
  )
  assert_eq(enabled.query("b").length(), 0)
  let disabled = @html_parser.parse_fragment(
    "<noscript><b>Hi</b></noscript>",
    scripting_enabled=false,
  )
  assert_eq(disabled.to_html(pretty=false), "<noscript><b>Hi</b></noscript>")
  assert_eq(disabled.query("b").length(), 1)
}
