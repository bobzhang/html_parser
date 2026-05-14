///|
test "fragment parser ignores shell start tags in body mode" {
  let head = @html_parser.parse_fragment(
    "<p>a<head>b</head>c",
    collect_errors=true,
  )
  assert_eq(head.to_html(pretty=false), "<p>abc</p>")
  assert_eq(head.errors.length(), 2)
  assert_eq(head.errors[0].code, "unexpected-start-tag")
  assert_eq(head.errors[1].code, "unexpected-end-tag")
  let body = @html_parser.parse_fragment(
    "<p>a<body class=x>b</body>c",
    collect_errors=true,
  )
  assert_eq(body.to_html(pretty=false), "<p>abc</p>")
  assert_eq(body.errors.length(), 1)
  assert_eq(body.errors[0].code, "unexpected-start-tag")
  let html = @html_parser.parse_fragment(
    "<p>a<html lang=en>b</html>c",
    collect_errors=true,
  )
  assert_eq(html.to_html(pretty=false), "<p>abc</p>")
  assert_eq(html.errors.length(), 1)
  assert_eq(html.errors[0].code, "unexpected-start-tag")
}

///|
test "fragment parser preserves ignored head children" {
  let root = @html_parser.parse_fragment(
    "<head><title>T</title></head>x",
    collect_errors=true,
  )
  assert_eq(root.to_html(pretty=false), "<title>T</title>x")
  assert_eq(root.errors.length(), 2)
  assert_eq(root.errors[0].code, "unexpected-start-tag")
  assert_eq(root.errors[1].code, "unexpected-end-tag")
  let nested = @html_parser.parse_fragment(
    "<div><head><title>T</title></head>x</div>",
    collect_errors=true,
  )
  assert_eq(nested.to_html(pretty=false), "<div><title>T</title>x</div>")
  assert_eq(nested.errors.length(), 2)
  assert_eq(nested.errors[0].code, "unexpected-start-tag")
  assert_eq(nested.errors[1].code, "unexpected-end-tag")
}

///|
test "fragment context seeds literal text modes" {
  let empty_script = @html_parser.parse_fragment(
    "",
    context=@html_parser.FragmentContext::new("script"),
    collect_errors=true,
  )
  assert_eq(empty_script.to_html(pretty=false), "")
  assert_eq(empty_script.errors.length(), 0)
  let textarea = @html_parser.parse_fragment(
    "<b>x</b>&lt;",
    context=@html_parser.FragmentContext::new("textarea"),
  )
  assert_eq(textarea.to_html(pretty=false), "&lt;b&gt;x&lt;/b&gt;&amp;lt;")
  assert_eq(textarea.to_text(separator="", strip=false), "<b>x</b>&lt;")
  assert_eq(textarea.query("b").length(), 0)
  let textarea_newlines = @html_parser.parse_fragment(
    "a\rb\r\nc",
    context=@html_parser.FragmentContext::new("textarea"),
  )
  assert_eq(textarea_newlines.to_html(pretty=false), "a\nb\nc")
  assert_eq(textarea_newlines.to_text(separator="", strip=false), "a\nb\nc")
  let after_end = @html_parser.parse_fragment(
    "a\r</textarea><b>x</b>",
    context=@html_parser.FragmentContext::new("textarea"),
    collect_errors=true,
  )
  assert_eq(after_end.to_html(pretty=false), "a\n<b>x</b>")
  assert_eq(after_end.errors[0].code, "unexpected-end-tag")
  let script = @html_parser.parse_fragment(
    "a</script><b>x</b>",
    context=@html_parser.FragmentContext::new("script"),
  )
  assert_eq(
    script.to_html(pretty=false),
    "a&lt;/script&gt;&lt;b&gt;x&lt;/b&gt;",
  )
  assert_eq(script.query("b").length(), 0)
  let script_newlines = @html_parser.parse_fragment(
    "a\rb\r\nc",
    context=@html_parser.FragmentContext::new("script"),
  )
  assert_eq(script_newlines.to_html(pretty=false), "a\nb\nc")
  let style_null = @html_parser.parse_fragment(
    "a\u{0000}b",
    context=@html_parser.FragmentContext::new("style"),
    collect_errors=true,
  )
  assert_eq(style_null.to_html(pretty=false), "a\u{FFFD}b")
  assert_eq(style_null.errors.length(), 1)
  assert_eq(style_null.errors[0].code, "unexpected-null-character")
  let div = @html_parser.parse_fragment(
    "<b>x</b>",
    context=@html_parser.FragmentContext::new("div"),
  )
  assert_eq(div.to_html(pretty=false), "<b>x</b>")
}

///|
test "fragment context seeds html insertion mode" {
  let empty = @html_parser.parse_fragment(
    "",
    context=@html_parser.FragmentContext::new("html"),
    collect_errors=true,
  )
  assert_eq(empty.to_html(pretty=false), "<head></head><body></body>")
  assert_eq(empty.errors.length(), 0)
  let title = @html_parser.parse_fragment(
    "<title>T</title><div>x</div>",
    context=@html_parser.FragmentContext::new("html"),
    collect_errors=true,
  )
  assert_eq(
    title.to_html(pretty=false),
    "<head><title>T</title></head><body><div>x</div></body>",
  )
  assert_eq(title.errors.length(), 0)
  let explicit = @html_parser.parse_fragment(
    "<head id=h><title>T</title></head><body id=b>x</body>",
    context=@html_parser.FragmentContext::new("html"),
    collect_errors=true,
  )
  assert_eq(
    explicit.to_html(pretty=false),
    "<head id=\"h\"><title>T</title></head><body id=\"b\">x</body>",
  )
  assert_eq(explicit.errors.length(), 0)
  let explicit_html = @html_parser.parse_fragment(
    "<html lang=en><title>T</title><p>x</p>",
    context=@html_parser.FragmentContext::new("html"),
    collect_errors=true,
  )
  assert_eq(
    explicit_html.to_html(pretty=false),
    "<head><title>T</title></head><body><p>x</p></body>",
  )
  assert_eq(explicit_html.errors.length(), 0)
  let comment_before_body = @html_parser.parse_fragment(
    "<!--c-->\n<body id=b>x",
    context=@html_parser.FragmentContext::new("html"),
    collect_errors=true,
  )
  assert_eq(
    comment_before_body.to_html(pretty=false),
    "<!--c--><head></head><body id=\"b\">x</body>",
  )
  assert_eq(comment_before_body.errors.length(), 0)
  let text_before_body = @html_parser.parse_fragment(
    "x<body id=b>y",
    context=@html_parser.FragmentContext::new("html"),
    collect_errors=true,
  )
  assert_eq(
    text_before_body.to_html(pretty=false),
    "<head></head><body id=\"b\">xy</body>",
  )
  assert_eq(text_before_body.errors.length(), 1)
  assert_eq(text_before_body.errors[0].code, "unexpected-start-tag")
  let nested_html_before_body = @html_parser.parse_fragment(
    "<html><title>T</title></html><body id=b>x",
    context=@html_parser.FragmentContext::new("html"),
    collect_errors=true,
  )
  assert_eq(
    nested_html_before_body.to_html(pretty=false),
    "<head><title>T</title></head><body id=\"b\">x</body>",
  )
  assert_eq(nested_html_before_body.errors.length(), 2)
  assert_eq(
    nested_html_before_body.errors[0].code,
    "unexpected-token-after-body",
  )
  assert_eq(nested_html_before_body.errors[1].code, "unexpected-start-tag")
  let nested_html_shell = @html_parser.parse_fragment(
    "<html><title>T</title></html><html><p>x",
    context=@html_parser.FragmentContext::new("html"),
    collect_errors=true,
  )
  assert_eq(
    nested_html_shell.to_html(pretty=false),
    "<head><title>T</title></head><body><p>x</p></body>",
  )
  assert_eq(nested_html_shell.errors.length(), 1)
  assert_eq(nested_html_shell.errors[0].code, "unexpected-start-tag")
  let table = @html_parser.parse_fragment(
    "<table><tr><td>x</td></tr></table>",
    context=@html_parser.FragmentContext::new("html"),
    collect_errors=true,
  )
  assert_eq(
    table.to_html(pretty=false),
    "<head></head><body><table><tbody><tr><td>x</td></tr></tbody></table></body>",
  )
  assert_eq(table.errors.length(), 0)
  let late_head = @html_parser.parse_fragment(
    "<body>x</body><head><meta name=y></head>",
    context=@html_parser.FragmentContext::new("html"),
    collect_errors=true,
  )
  assert_eq(
    late_head.to_html(pretty=false),
    "<head></head><body>x<meta name=\"y\"></body>",
  )
  assert_eq(late_head.errors.length(), 2)
  assert_eq(late_head.errors[0].code, "unexpected-start-tag")
  assert_eq(late_head.errors[1].code, "unexpected-end-tag")
  let inferred_head_comment = @html_parser.parse_fragment(
    "<!--before--><title>T</title><!--in--><p>x</p>",
    context=@html_parser.FragmentContext::new("html"),
    collect_errors=true,
  )
  assert_eq(
    inferred_head_comment.to_html(pretty=false),
    "<!--before--><head><title>T</title><!--in--></head><body><p>x</p></body>",
  )
  assert_eq(inferred_head_comment.errors.length(), 0)
  let explicit_head_comment = @html_parser.parse_fragment(
    "<head><title>T</title></head><!--after--><p>x</p>",
    context=@html_parser.FragmentContext::new("html"),
    collect_errors=true,
  )
  assert_eq(
    explicit_head_comment.to_html(pretty=false),
    "<head><title>T</title></head><!--after--><body><p>x</p></body>",
  )
  assert_eq(explicit_head_comment.errors.length(), 0)
  let late_body = @html_parser.parse_fragment(
    "<p>x</p><body id=b>y",
    context=@html_parser.FragmentContext::new("html"),
    collect_errors=true,
  )
  assert_eq(
    late_body.to_html(pretty=false),
    "<head></head><body id=\"b\"><p>x</p>y</body>",
  )
  assert_eq(late_body.errors.length(), 1)
  assert_eq(late_body.errors[0].code, "unexpected-start-tag")
  let body_markers = [
    ("x<body id=b>y", 1, 1, 2),
    ("<p>x</p><body id=b>y", 8, 1, 9),
  ]
  for marker in body_markers {
    let (input, offset, line, col) = marker
    let doc = @html_parser.parse_fragment(
      input,
      context=@html_parser.FragmentContext::new("html"),
      track_node_locations=true,
    )
    guard doc.query_one("body") is Some(body) else {
      fail("expected html fragment body marker")
    }
    assert_node_origin(body, offset, line, col)
  }
  let late_html = @html_parser.parse_fragment(
    "<p>x</p><html lang=en>y</html>",
    context=@html_parser.FragmentContext::new("html"),
    collect_errors=true,
  )
  assert_eq(
    late_html.to_html(pretty=false),
    "<head></head><body><p>x</p>y</body>",
  )
  assert_eq(late_html.errors.length(), 1)
  assert_eq(late_html.errors[0].code, "unexpected-start-tag")
  let late_head_after_title = @html_parser.parse_fragment(
    "<title>T</title><head><meta name=y></head>x",
    context=@html_parser.FragmentContext::new("html"),
    collect_errors=true,
  )
  assert_eq(
    late_head_after_title.to_html(pretty=false),
    "<head><title>T</title></head><body><meta name=\"y\">x</body>",
  )
  assert_eq(late_head_after_title.errors.length(), 2)
  assert_eq(late_head_after_title.errors[0].code, "unexpected-start-tag")
  assert_eq(late_head_after_title.errors[1].code, "unexpected-end-tag")
  let frameset = @html_parser.parse_fragment(
    "<frameset><frame src=x></frameset>after",
    context=@html_parser.FragmentContext::new("html"),
    collect_errors=true,
  )
  assert_eq(
    frameset.to_html(pretty=false),
    "<head></head><frameset><frame src=\"x\"></frame></frameset>",
  )
  assert_eq(frameset.errors.length(), 1)
  assert_eq(frameset.errors[0].code, "unexpected-token-after-frameset")
  let sibling_frameset = @html_parser.parse_fragment(
    "<frameset></frameset><frameset><frame></frameset>",
    context=@html_parser.FragmentContext::new("html"),
    collect_errors=true,
  )
  assert_eq(
    sibling_frameset.to_html(pretty=false),
    "<head></head><frameset></frameset><frameset><frame></frame></frameset>",
  )
  assert_eq(sibling_frameset.errors.length(), 1)
  assert_eq(sibling_frameset.errors[0].code, "unexpected-token-after-frameset")
  guard sibling_frameset.errors[0].column is Some(31) else {
    fail("expected html fragment sibling frameset error at close bracket")
  }
  let sibling_frame = @html_parser.parse_fragment(
    "<frameset></frameset><frame>x",
    context=@html_parser.FragmentContext::new("html"),
    collect_errors=true,
  )
  assert_eq(
    sibling_frame.to_html(pretty=false),
    "<head></head><frameset></frameset><frame></frame>",
  )
  assert_eq(sibling_frame.errors.length(), 1)
  assert_eq(sibling_frame.errors[0].code, "unexpected-token-after-frameset")
  guard sibling_frame.errors[0].column is Some(28) else {
    fail("expected html fragment frame error at close bracket")
  }
  let detached_end = @html_parser.parse_fragment(
    "<frameset></frameset><div></frameset>",
    context=@html_parser.FragmentContext::new("html"),
    collect_errors=true,
  )
  assert_eq(
    detached_end.to_html(pretty=false),
    "<head></head><frameset></frameset>",
  )
  assert_eq(detached_end.errors.length(), 3)
  assert_eq(detached_end.errors[0].code, "unexpected-token-after-frameset")
  assert_eq(detached_end.errors[1].code, "unexpected-token-in-frameset")
  assert_eq(detached_end.errors[2].code, "unexpected-end-tag")
  guard detached_end.errors[2].column is Some(37) else {
    fail("expected html fragment detached frameset end error")
  }
  let detached_html = @html_parser.parse_fragment(
    "<frameset></frameset><div><html id=x><frameset></frameset>",
    context=@html_parser.FragmentContext::new("html"),
    collect_errors=true,
  )
  assert_eq(
    detached_html.to_html(pretty=false),
    "<head></head><frameset></frameset>",
  )
  assert_eq(detached_html.errors.length(), 5)
  assert_eq(detached_html.errors[0].code, "unexpected-token-after-frameset")
  assert_eq(detached_html.errors[1].code, "unexpected-token-in-frameset")
  assert_eq(detached_html.errors[2].code, "unexpected-start-tag")
  assert_eq(detached_html.errors[3].code, "unexpected-start-tag-ignored")
  assert_eq(detached_html.errors[4].code, "unexpected-end-tag")
  let explicit_html_ns = @html_parser.parse_fragment(
    "<title>T</title>",
    context=@html_parser.FragmentContext::new("html", ns="html"),
    collect_errors=true,
  )
  assert_eq(
    explicit_html_ns.to_html(pretty=false),
    "<head><title>T</title></head><body></body>",
  )
  assert_eq(explicit_html_ns.errors.length(), 0)
}
