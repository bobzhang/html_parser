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

///|
test "parser reports EOF in unfinished tables" {
  let table = @html_parser.parse_fragment(
    "<table><tr><td>x",
    collect_errors=true,
  )
  assert_eq(
    table.to_html(pretty=false),
    "<table><tbody><tr><td>x</td></tr></tbody></table>",
  )
  assert_eq(table.errors.length(), 1)
  assert_eq(table.errors[0].code, "eof-in-table")
  guard table.errors[0].column is Some(16) else {
    fail("expected table EOF error at final input column")
  }
  let caption = @html_parser.parse_fragment(
    "<table><caption>x",
    collect_errors=true,
  )
  assert_eq(
    caption.to_html(pretty=false),
    "<table><caption>x</caption></table>",
  )
  assert_eq(caption.errors.length(), 1)
  assert_eq(caption.errors[0].code, "expected-closing-tag-but-got-eof")
  guard caption.errors[0].column is Some(17) else {
    fail("expected caption EOF to follow body-mode EOF reporting")
  }
  let nested = @html_parser.parse_fragment(
    "<table><caption><div>x",
    collect_errors=true,
  )
  assert_eq(
    nested.to_html(pretty=false),
    "<table><caption><div>x</div></caption></table>",
  )
  assert_eq(nested.errors.length(), 1)
  assert_eq(nested.errors[0].code, "expected-closing-tag-but-got-eof")
}

///|
test "parser closes open paragraphs before paragraph and block starts" {
  let fragment = @html_parser.parse_fragment("<p>one<p>two<div>three</div>")
  assert_eq(
    fragment.to_html(pretty=false),
    "<p>one</p><p>two</p><div>three</div>",
  )
  let doc = @html_parser.parse("<p>one<div>two</div>")
  assert_eq(
    doc.to_html(pretty=false),
    "<html><head></head><body><p>one</p><div>two</div></body></html>",
  )
}

///|
test "parser reconstructs active formatting across paragraph recovery" {
  let split = @html_parser.parse_fragment(
    "<p><b>one<p>two</b>",
    track_node_locations=true,
  )
  assert_eq(split.to_html(pretty=false), "<p><b>one</b></p><p><b>two</b></p>")
  let split_bold = split.root.query("b")
  guard split_bold.length() == 2 else { fail("expected reconstructed bold") }
  assert_node_origin(split_bold[0], 3, 1, 4)
  assert_node_origin(split_bold[1], 3, 1, 4)
  let trailing = @html_parser.parse_fragment(
    "<p><b>one</p>two",
    track_node_locations=true,
  )
  assert_eq(trailing.to_html(pretty=false), "<p><b>one</b></p><b>two</b>")
  let trailing_bold = trailing.root.query("b")
  guard trailing_bold.length() == 2 else {
    fail("expected trailing reconstructed bold")
  }
  assert_node_origin(trailing_bold[0], 3, 1, 4)
  assert_node_origin(trailing_bold[1], 3, 1, 4)
  let inline_start = @html_parser.parse_fragment(
    "<p><b>one</p><span>two</span>",
    track_node_locations=true,
  )
  assert_eq(
    inline_start.to_html(pretty=false),
    "<p><b>one</b></p><b><span>two</span></b>",
  )
  let inline_bold = inline_start.root.query("b")
  guard inline_bold.length() == 2 else {
    fail("expected inline reconstructed bold")
  }
  assert_node_origin(inline_bold[0], 3, 1, 4)
  assert_node_origin(inline_bold[1], 3, 1, 4)
  let block_start = @html_parser.parse_fragment(
    "<p><b>one</p><div>two</div>",
    track_node_locations=true,
  )
  assert_eq(
    block_start.to_html(pretty=false),
    "<p><b>one</b></p><div><b>two</b></div>",
  )
  let block_bold = block_start.root.query("b")
  guard block_bold.length() == 2 else {
    fail("expected block reconstructed bold")
  }
  assert_node_origin(block_bold[0], 3, 1, 4)
  assert_node_origin(block_bold[1], 3, 1, 4)
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
