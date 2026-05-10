///|
test "builder serializes compact HTML" {
  let node = @html_parser.element("p", attrs={ "class": Some("intro") }, children=[
    @html_parser.text("Hello "),
    @html_parser.element("b", children=[@html_parser.text("MoonBit")]),
  ])
  assert_eq(
    node.to_html(pretty=false),
    "<p class=\"intro\">Hello <b>MoonBit</b></p>",
  )
}

///|
test "builder serializes minimized and quoted attributes like reference" {
  let disabled = @html_parser.element("input", attrs={
    "disabled": Some("DISABLED"),
  })
  assert_eq(disabled.to_html(pretty=false), "<input disabled>")
  let empty = @html_parser.element("div", attrs={ "data-val": Some("") })
  assert_eq(empty.to_html(pretty=false), "<div data-val></div>")
  let none = @html_parser.element("div", attrs={ "data-test": None })
  assert_eq(none.to_html(pretty=false), "<div data-test></div>")
  let single_quote = @html_parser.element("span", attrs={
    "title": Some("foo\"bar"),
  })
  assert_eq(
    single_quote.to_html(pretty=false),
    "<span title='foo\"bar'></span>",
  )
  let escaped_double = @html_parser.element("span", attrs={
    "title": Some("foo'bar\"baz"),
  })
  assert_eq(
    escaped_double.to_html(pretty=false),
    "<span title=\"foo'bar&quot;baz\"></span>",
  )
}

///|
test "builder neutralizes raw text end tag breakouts" {
  let script = @html_parser.element("script", children=[
    @html_parser.text("</script><img src=x onerror=alert(1)>"),
  ])
  let script_root = @html_parser.element("div", children=[script])
  assert_eq(
    script_root.to_html(pretty=false),
    "<div><script>&lt;/script><img src=x onerror=alert(1)></script></div>",
  )
  let style = @html_parser.element("style", children=[
    @html_parser.text("</style><img src=x>"),
  ])
  let style_root = @html_parser.element("div", children=[style])
  assert_eq(
    style_root.to_html(pretty=false),
    "<div><style>&lt;/style><img src=x></style></div>",
  )
}

///|
test "raw text serializer only neutralizes matching end tag boundaries" {
  let non_boundary = @html_parser.element("script", children=[
    @html_parser.text("</scriptx>ok"),
  ])
  assert_eq(non_boundary.to_html(pretty=false), "<script></scriptx>ok</script>")
  let vertical_tab = @html_parser.element("script", children=[
    @html_parser.text("</script\u{000B}>ok"),
  ])
  assert_eq(
    vertical_tab.to_html(pretty=false),
    "<script></script\u{000B}>ok</script>",
  )
  let mixed_case = @html_parser.element("script", children=[
    @html_parser.text("</ScRiPt >x"),
  ])
  assert_eq(mixed_case.to_html(pretty=false), "<script>&lt;/ScRiPt >x</script>")
  let parsed = @html_parser.parse_fragment("<script>a</scriptx>b</script>")
  assert_eq(parsed.to_html(pretty=false), "<script>a</scriptx>b</script>")
  let double_escaped = @html_parser.parse_fragment(
    "<script><!--<script>x</script>y</script>",
  )
  assert_eq(
    double_escaped.to_html(pretty=false),
    "<script><!--<script>x&lt;/script>y</script>",
  )
}

///|
test "url serialization context uses text content and utf8 percent encoding" {
  let text = @html_parser.text(" https://example.com/foo bar ")
  assert_eq(
    text.to_html(pretty=false, context=Url),
    "https://example.com/foo%20bar",
  )
  let div = @html_parser.element("div", children=[
    @html_parser.text("  /path/to/thing?q=a b  "),
  ])
  assert_eq(div.to_html(pretty=false, context=Url), "/path/to/thing?q=a%20b")
  let unicode = @html_parser.text("caf\u{00E9}/\u{2603}?x=1&y=two words%")
  assert_eq(
    unicode.to_html(pretty=false, context=Url),
    "caf%C3%A9/%E2%98%83?x=1&y=two%20words%25",
  )
}

///|
test "js string serialization context escapes special characters" {
  let markup = @html_parser.parse_fragment("<b>Hi</b>")
  assert_eq(
    markup.to_html(pretty=false, context=JsString),
    "\\u003cb\\u003eHi\\u003c/b\\u003e",
  )
  let amp = @html_parser.parse_fragment("<p>a & b</p>")
  assert_eq(
    amp.to_html(pretty=false, context=JsString),
    "\\u003cp\\u003ea &amp; b\\u003c/p\\u003e",
  )
  let special = @html_parser.text(
    "\\back\nline\rret\ttab\u{0008}bell\u{000C}form\u{2028}ls\u{2029}ps",
  )
  assert_eq(
    special.to_html(pretty=false, context=JsString),
    "\u{005C}\u{005C}back\u{005C}nline\u{005C}rret\u{005C}ttab\u{005C}bbell\u{005C}fform\u{005C}u2028ls\u{005C}u2029ps",
  )
  let single_quote = @html_parser.text("It's ok")
  assert_eq(
    single_quote.to_html(pretty=false, context=JsString, quote='\''),
    "It\\'s ok",
  )
}

///|
test "to_text can separate only block boundaries" {
  let doc = @html_parser.parse_fragment("<p>hi</p><p>Hello <b>world</b></p>")
  assert_eq(doc.to_text(separator="\n"), "hi\nHello\nworld")
  assert_eq(
    doc.to_text(separator="\n", separator_blocks_only=true),
    "hi\nHello world",
  )
  let br = @html_parser.parse_fragment("<div>A<br>   <span>B</span></div>")
  assert_eq(br.to_text(separator="|", separator_blocks_only=true), "A|B")
  let node = @html_parser.element("div", children=[
    @html_parser.text("  A  "),
    @html_parser.element("br"),
    @html_parser.text(" B "),
  ])
  assert_eq(
    node.to_text(separator="|", separator_blocks_only=true, strip=false),
    "  A  | B ",
  )
}

///|
test "to_markdown renders headings paragraphs inline formatting and links" {
  let doc = @html_parser.parse_fragment(
    "<h1>Title</h1><p>Hello <b>world</b> <em>ok</em> <a href='https://e.com'>link</a> a*b</p>",
  )
  assert_eq(
    doc.to_markdown(),
    "# Title\n\nHello **world** *ok* [link](https://e.com) a\\*b",
  )
}

///|
test "to_markdown renders code spans blocks lists and blockquotes" {
  let code = @html_parser.parse_fragment(
    "<pre>code`here\n</pre><p>inline <code>a`b</code></p>",
  )
  assert_eq(code.to_markdown(), "```\ncode`here\n```\n\ninline ``a`b``")
  let leading_tick = @html_parser.parse_fragment("<p><code>&#96;x</code></p>")
  assert_eq(leading_tick.to_markdown(), "`` `x ``")
  let trailing_tick = @html_parser.parse_fragment("<p><code>x&#96;</code></p>")
  assert_eq(trailing_tick.to_markdown(), "`` x` ``")
  let surrounded_ticks = @html_parser.parse_fragment(
    "<p><code>a&#96;b&#96;</code></p>",
  )
  assert_eq(surrounded_ticks.to_markdown(), "`` a`b` ``")
  let empty_pre = @html_parser.parse_fragment("<pre></pre>")
  assert_eq(empty_pre.to_markdown(), "```\n```")
  let trailing_space = @html_parser.parse_fragment("<pre>X   \n</pre>")
  assert_eq(trailing_space.to_markdown(), "```\nX\n```")
  let longer_fence = @html_parser.parse_fragment(
    "<pre>&#96;&#96;&#96;\n&lt;img src=x onerror=alert(1)&gt;</pre>",
  )
  assert_eq(
    longer_fence.to_markdown(),
    "````\n```\n<img src=x onerror=alert(1)>\n````",
  )
  let quote = @html_parser.parse_fragment(
    "<blockquote><p>Q<br>R</p></blockquote>",
  )
  assert_eq(quote.to_markdown(), "> Q\n> R")
  let list = @html_parser.parse_fragment(
    "<ul>\n<li>One</li>\n</ul><ol><li>A</li><li>B</li></ol>",
  )
  assert_eq(list.to_markdown(), "- One\n\n1. A\n2. B")
}

///|
test "to_markdown indents nested lists like reference" {
  let unordered = @html_parser.element("ul", children=[
    @html_parser.element("li", children=[
      @html_parser.text("One"),
      @html_parser.element("ul", children=[
        @html_parser.element("li", children=[@html_parser.text("Sub")]),
      ]),
    ]),
    @html_parser.element("li", children=[@html_parser.text("Two")]),
  ])
  assert_eq(unordered.to_markdown(), "- One\n\n  - Sub\n\n\n- Two")
  let parsed_unordered = @html_parser.parse_fragment(
    "<ul><li>One<ul><li>Sub</li></ul></li><li>Two</li></ul>",
  )
  assert_eq(parsed_unordered.to_markdown(), "- One\n\n  - Sub\n\n\n- Two")
  let ordered = @html_parser.element("ol", children=[
    @html_parser.element("li", children=[
      @html_parser.text("A"),
      @html_parser.element("ol", children=[
        @html_parser.element("li", children=[@html_parser.text("B")]),
      ]),
    ]),
    @html_parser.element("li", children=[@html_parser.text("C")]),
  ])
  assert_eq(ordered.to_markdown(), "1. A\n\n  1. B\n\n\n2. C")
  let parsed_ordered = @html_parser.parse_fragment(
    "<ol><li>A<ol><li>B</li></ol></li><li>C</li></ol>",
  )
  assert_eq(parsed_ordered.to_markdown(), "1. A\n\n  1. B\n\n\n2. C")
  let mixed = @html_parser.element("ul", children=[
    @html_parser.element("li", children=[
      @html_parser.text("One"),
      @html_parser.element("ol", children=[
        @html_parser.element("li", children=[@html_parser.text("A")]),
        @html_parser.element("li", children=[@html_parser.text("B")]),
      ]),
    ]),
  ])
  assert_eq(mixed.to_markdown(), "- One\n\n  1. A\n  2. B")
  let empty = @html_parser.element("ul", children=[@html_parser.element("li")])
  assert_eq(empty.to_markdown(), "-")
  let paragraph = @html_parser.element("ul", children=[
    @html_parser.element("li", children=[
      @html_parser.text("one"),
      @html_parser.element("p", children=[@html_parser.text("two")]),
    ]),
  ])
  assert_eq(paragraph.to_markdown(), "- one\n\ntwo")
  let block = @html_parser.element("ul", children=[
    @html_parser.element("li", children=[
      @html_parser.element("div", children=[@html_parser.text("one")]),
    ]),
    @html_parser.element("li", children=[@html_parser.text("two")]),
  ])
  assert_eq(block.to_markdown(), "- one\n\n\n- two")
}

///|
test "to_markdown separates generic block containers" {
  let doc = @html_parser.parse_fragment(
    "<div>A</div><section><span>B</span></section><aside>C</aside>",
  )
  assert_eq(doc.to_markdown(), "A\n\nB\n\nC")
  let nested = @html_parser.parse_fragment(
    "<article><p>A</p><p>B</p></article><footer>C</footer>",
  )
  assert_eq(nested.to_markdown(), "A\n\nB\n\nC")
  let inline_before_block = @html_parser.parse_fragment(
    "A<div>B</div><span>C</span>",
  )
  assert_eq(inline_before_block.to_markdown(), "AB\n\nC")
}

///|
test "to_markdown escapes text and line starting markdown markers" {
  let escaped = @html_parser.parse_fragment(
    "<p>&lt;img src=x onerror=alert(1)&gt;</p>",
  )
  assert_eq(escaped.to_markdown(), "&lt;img src=x onerror=alert(1)>")
  let markers = @html_parser.parse_fragment(
    "<p>a<br># heading<br>- item<br>+ next<br>1. ordered<br>2) ordered<br>~~~<br>```<br>---<br>===</p>",
  )
  assert_eq(
    markers.to_markdown(),
    "a\n\\# heading\n\\- item\n\\+ next\n1\\. ordered\n2\\) ordered\n\\~~~\n\\`\\`\\`\n\\---\n\\===",
  )
}

///|
test "to_markdown handles direct nodes comments doctypes and empty inline nodes" {
  assert_eq(@html_parser.text("a*b").to_markdown(), "a\\*b")
  assert_eq(@html_parser.text("a < b & c").to_markdown(), "a &lt; b &amp; c")
  assert_eq(@html_parser.text("").to_markdown(), "")
  let root = @html_parser.element("div", children=[
    @html_parser.comment("nope"),
    @html_parser.doctype(),
    @html_parser.element("i"),
    @html_parser.element("b"),
    @html_parser.text("ok"),
  ])
  assert_eq(root.to_markdown(), "ok")
}

///|
test "to_markdown preserves table and image HTML and escapes title text" {
  let doc = @html_parser.parse_fragment(
    "<p>Hi<img src=x alt=y>there</p><table><tr><td>A</td></tr></table>",
  )
  assert_eq(
    doc.to_markdown(),
    "Hi<img src=\"x\" alt=\"y\">there\n\n<table><tbody><tr><td>A</td></tr></tbody></table>",
  )
  let title = @html_parser.parse_fragment(
    "<title><script>alert(1)</script></title>",
  )
  assert_eq(title.to_markdown(), "&lt;script>alert(1)&lt;/script>")
}

///|
test "to_markdown wraps unsafe link destinations and controls raw passthrough" {
  let links = @html_parser.parse_fragment(
    "<p><a href='https://e.com/a(b)c'>x</a> <a href='https://e.com/a b'>y</a></p>",
  )
  assert_eq(
    links.to_markdown(),
    "[x](<https://e.com/a(b)c>) [y](<https://e.com/a%20b>)",
  )
  let no_href = @html_parser.parse_fragment("<p><a>text</a></p>")
  assert_eq(no_href.to_markdown(), "[text]")
  let encoded = @html_parser.element(
    "a",
    attrs={ "href": Some("https://e.com/a <b>\"q\"\\x") },
    children=[@html_parser.text("x")],
  )
  assert_eq(
    encoded.to_markdown(),
    "[x](<https://e.com/a%20%3Cb%3E%22q%22%5Cx>)",
  )
  let script = @html_parser.element("div", children=[
    @html_parser.element("script", attrs={ "data-x": Some("1&2") }),
  ])
  assert_eq(script.to_markdown(), "")
  assert_eq(
    script.to_markdown(html_passthrough=true),
    "<script data-x=\"1&amp;2\"></script>",
  )
  let inline_script = @html_parser.element("span", children=[
    @html_parser.text("A"),
    @html_parser.element("script", children=[@html_parser.text("alert(1);")]),
    @html_parser.text("B"),
  ])
  assert_eq(inline_script.to_markdown(), "A\n\nB")
  assert_eq(
    inline_script.to_markdown(html_passthrough=true),
    "A\n\n<script>alert(1);</script>\n\nB",
  )
  let textarea = @html_parser.element(
    "textarea",
    attrs={ "data-x": Some("1&2") },
    children=[@html_parser.text("</textarea><img src=x onerror=alert(1)>")],
  )
  assert_eq(
    textarea.to_markdown(html_passthrough=true),
    "<textarea data-x=\"1&amp;2\">&lt;/textarea&gt;&lt;img src=x onerror=alert(1)&gt;</textarea>",
  )
}

///|
test "to_markdown flattens block content inside links" {
  let line_break = @html_parser.element(
    "a",
    attrs={ "href": Some("https://e.com") },
    children=[
      @html_parser.text("A"),
      @html_parser.element("br"),
      @html_parser.text("B"),
      @html_parser.element("p", children=[@html_parser.text("C")]),
      @html_parser.text("D"),
    ],
  )
  assert_eq(line_break.to_markdown(), "[A BC D](https://e.com)")
  let list = @html_parser.element("ul", children=[
    @html_parser.text("\n"),
    @html_parser.element("li", children=[@html_parser.text("One")]),
    @html_parser.element("li", children=[@html_parser.text("Two")]),
  ])
  let blocks = @html_parser.element(
    "a",
    attrs={ "href": Some("https://e.com") },
    children=[
      @html_parser.element("blockquote", children=[
        @html_parser.element("p", children=[@html_parser.text("Q")]),
      ]),
      list,
    ],
  )
  assert_eq(blocks.to_markdown(), "[Q One Two](https://e.com)")
  let table_link = @html_parser.element(
    "a",
    attrs={ "href": Some("https://e.com") },
    children=[
      @html_parser.element("hr"),
      @html_parser.element("h2", children=[@html_parser.text("T")]),
      @html_parser.element("pre", children=[@html_parser.text("code")]),
      @html_parser.element("table", children=[
        @html_parser.element("tr", children=[
          @html_parser.element("td", children=[@html_parser.text("A")]),
        ]),
      ]),
    ],
  )
  assert_eq(
    table_link.to_markdown(),
    "[T`code`<table><tr><td>A</td></tr></table>](https://e.com)",
  )
  let filtered = @html_parser.element(
    "a",
    attrs={ "href": Some("https://e.com") },
    children=[
      @html_parser.element("blockquote"),
      @html_parser.element("ul", children=[
        @html_parser.text("\n"),
        @html_parser.element("li", children=[@html_parser.text("One")]),
      ]),
    ],
  )
  assert_eq(filtered.to_markdown(), "[One](https://e.com)")
}

///|
test "parser handles nested tags attributes comments and doctype" {
  let doc = @html_parser.parse(
    "<!doctype html><p id='x' class=\"intro lead\">Hi &amp; bye<!--ok--></p>",
    collect_errors=true,
  )
  assert_eq(
    doc.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body><p id=\"x\" class=\"intro lead\">Hi &amp; bye<!--ok--></p></body></html>",
  )
  assert_eq(doc.errors.length(), 0)
  assert_eq(doc.to_text(separator="", strip=false), "Hi & bye")
}

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
}

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
test "parser and tokenizer preserve doctype external ids" {
  let source = "<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01//EN\" \"http://www.w3.org/TR/html4/strict.dtd\">"
  let doc = @html_parser.parse(source)
  assert_eq(
    doc.to_html(pretty=false),
    "<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01//EN\" \"http://www.w3.org/TR/html4/strict.dtd\"><html><head></head><body></body></html>",
  )
  let tokens = @html_parser.tokenize(source)
  guard tokens.tokens[0] is @html_parser.HtmlToken::DoctypeToken(info) else {
    fail("expected doctype token")
  }
  assert_eq(info.name, "html")
  guard info.public_id is Some("-//W3C//DTD HTML 4.01//EN") else {
    fail("expected public id")
  }
  guard info.system_id is Some("http://www.w3.org/TR/html4/strict.dtd") else {
    fail("expected system id")
  }
  let system = @html_parser.tokenize(
    "<!DOCTYPE html SYSTEM \"about:legacy-compat\">",
  )
  guard system.tokens[0] is @html_parser.HtmlToken::DoctypeToken(system_info) else {
    fail("expected system doctype")
  }
  guard system_info.public_id is None else { fail("expected no public id") }
  guard system_info.system_id is Some("about:legacy-compat") else {
    fail("expected system id")
  }
}

///|
test "parser and tokenizer handle malformed doctype names" {
  let missing = @html_parser.parse("<!doctype>", collect_errors=true)
  assert_eq(
    missing.to_html(pretty=false),
    "<!DOCTYPE><html><head></head><body></body></html>",
  )
  assert_eq(missing.errors.length(), 2)
  assert_eq(
    missing.errors[0].code,
    "expected-doctype-name-but-got-right-bracket",
  )
  assert_eq(missing.errors[1].code, "unknown-doctype")
  guard missing.errors[0].column is Some(10) else {
    fail("expected missing doctype name at close bracket")
  }
  let missing_token = @html_parser.tokenize("<!doctype>", collect_errors=true)
  guard missing_token.tokens[0] is @html_parser.HtmlToken::DoctypeToken(info) else {
    fail("expected doctype token")
  }
  assert_eq(info.name, "")
  assert_eq(info.force_quirks, true)
  assert_eq(
    missing_token.errors[0].code,
    "expected-doctype-name-but-got-right-bracket",
  )
  let eof = @html_parser.parse("<!doctype", collect_errors=true)
  assert_eq(
    eof.to_html(pretty=false),
    "<!DOCTYPE><html><head></head><body></body></html>",
  )
  assert_eq(eof.errors.length(), 2)
  assert_eq(eof.errors[0].code, "eof-in-doctype")
  assert_eq(eof.errors[1].code, "unknown-doctype")
  guard eof.errors[0].column is Some(9) else {
    fail("expected doctype EOF at final character")
  }
}

///|
test "parser and tokenizer report doctype name whitespace errors" {
  let missing_before = @html_parser.parse("<!doctypehtml>", collect_errors=true)
  assert_eq(
    missing_before.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body></body></html>",
  )
  assert_eq(missing_before.errors.length(), 1)
  assert_eq(
    missing_before.errors[0].code,
    "missing-whitespace-before-doctype-name",
  )
  guard missing_before.errors[0].column is Some(10) else {
    fail("expected missing whitespace before doctype name at name start")
  }
  let missing_before_token = @html_parser.tokenize(
    "<!doctypehtml>",
    collect_errors=true,
  )
  assert_eq(
    missing_before_token.errors[0].code,
    "missing-whitespace-before-doctype-name",
  )
  guard missing_before_token.tokens[0]
    is @html_parser.HtmlToken::DoctypeToken(before_info) else {
    fail("expected doctype token")
  }
  assert_eq(before_info.name, "html")
  assert_eq(before_info.force_quirks, false)
  let junk_after_name = @html_parser.tokenize(
    "<!doctype html x>",
    collect_errors=true,
  )
  assert_eq(junk_after_name.errors.length(), 1)
  assert_eq(
    junk_after_name.errors[0].code,
    "missing-whitespace-after-doctype-name",
  )
  guard junk_after_name.errors[0].column is Some(16) else {
    fail("expected missing whitespace after doctype name at junk")
  }
  guard junk_after_name.tokens[0]
    is @html_parser.HtmlToken::DoctypeToken(junk_info) else {
    fail("expected doctype token")
  }
  assert_eq(junk_info.name, "html")
  guard junk_info.public_id is None else { fail("expected no public id") }
  assert_eq(junk_info.force_quirks, true)
  let extra_space = @html_parser.parse(
    "<!doctype html  PUBLIC \"x\">",
    collect_errors=true,
  )
  assert_eq(
    extra_space.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body></body></html>",
  )
  assert_eq(extra_space.errors.length(), 1)
  assert_eq(extra_space.errors[0].code, "missing-whitespace-after-doctype-name")
  guard extra_space.errors[0].column is Some(17) else {
    fail("expected extra-space doctype error at PUBLIC")
  }
  let fused_public = @html_parser.parse(
    "<!doctypehtml PUBLIC \"x\">",
    collect_errors=true,
  )
  assert_eq(
    fused_public.to_html(pretty=false),
    "<!DOCTYPE html PUBLIC \"x\"><html><head></head><body></body></html>",
  )
  assert_eq(fused_public.errors.length(), 2)
  assert_eq(
    fused_public.errors[0].code,
    "missing-whitespace-before-doctype-name",
  )
  assert_eq(fused_public.errors[1].code, "unknown-doctype")
}

///|
test "parser and tokenizer replace null characters in doctypes" {
  let name_null = @html_parser.tokenize(
    "<!doctype h\u{0000}tml>",
    collect_errors=true,
  )
  assert_eq(name_null.errors.length(), 1)
  assert_eq(name_null.errors[0].code, "unexpected-null-character")
  guard name_null.errors[0].column is Some(12) else {
    fail("expected null error inside doctype name")
  }
  guard name_null.tokens[0] is @html_parser.HtmlToken::DoctypeToken(name_info) else {
    fail("expected doctype token")
  }
  assert_eq(name_info.name, "h�tml")
  assert_eq(name_info.force_quirks, false)
  let public_null = @html_parser.tokenize(
    "<!doctype html PUBLIC \"x\u{0000}y\">",
    collect_errors=true,
  )
  assert_eq(public_null.errors.length(), 1)
  assert_eq(public_null.errors[0].code, "unexpected-null-character")
  guard public_null.errors[0].column is Some(25) else {
    fail("expected null error inside public identifier")
  }
  guard public_null.tokens[0]
    is @html_parser.HtmlToken::DoctypeToken(public_info) else {
    fail("expected doctype token")
  }
  guard public_info.public_id is Some("x�y") else {
    fail("expected replacement character in public id")
  }
  assert_eq(public_info.force_quirks, false)
  let system_null = @html_parser.parse(
    "<!doctype html SYSTEM \"x\u{0000}y\">",
    collect_errors=true,
  )
  assert_eq(
    system_null.to_html(pretty=false),
    "<!DOCTYPE html SYSTEM \"x�y\"><html><head></head><body></body></html>",
  )
  assert_eq(system_null.errors.length(), 2)
  assert_eq(system_null.errors[0].code, "unexpected-null-character")
  guard system_null.errors[0].column is Some(25) else {
    fail("expected null error inside system identifier")
  }
  assert_eq(system_null.errors[1].code, "unknown-doctype")
}

///|
test "parser and tokenizer report missing doctype identifiers" {
  let public = @html_parser.parse("<!doctype html PUBLIC>", collect_errors=true)
  assert_eq(
    public.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body></body></html>",
  )
  assert_eq(public.errors.length(), 1)
  assert_eq(public.errors[0].code, "missing-doctype-public-identifier")
  guard public.errors[0].column is Some(22) else {
    fail("expected missing public identifier at close bracket")
  }
  let public_token = @html_parser.tokenize(
    "<!doctype html PUBLIC >",
    collect_errors=true,
  )
  assert_eq(public_token.errors[0].code, "missing-doctype-public-identifier")
  guard public_token.tokens[0]
    is @html_parser.HtmlToken::DoctypeToken(public_info) else {
    fail("expected doctype token")
  }
  assert_eq(public_info.name, "html")
  guard public_info.public_id is None else { fail("expected no public id") }
  assert_eq(public_info.force_quirks, true)
  let system = @html_parser.parse("<!doctype html SYSTEM>", collect_errors=true)
  assert_eq(
    system.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body></body></html>",
  )
  assert_eq(system.errors.length(), 1)
  assert_eq(system.errors[0].code, "missing-doctype-system-identifier")
  guard system.errors[0].column is Some(22) else {
    fail("expected missing system identifier at close bracket")
  }
  let system_token = @html_parser.tokenize(
    "<!doctype html SYSTEM >",
    collect_errors=true,
  )
  assert_eq(system_token.errors[0].code, "missing-doctype-system-identifier")
  guard system_token.tokens[0]
    is @html_parser.HtmlToken::DoctypeToken(system_info) else {
    fail("expected doctype token")
  }
  assert_eq(system_info.name, "html")
  guard system_info.system_id is None else { fail("expected no system id") }
  assert_eq(system_info.force_quirks, true)
}

///|
test "parser and tokenizer report missing doctype identifier quotes" {
  let public_eof = @html_parser.parse(
    "<!doctype html PUBLIC",
    collect_errors=true,
  )
  assert_eq(
    public_eof.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body></body></html>",
  )
  assert_eq(public_eof.errors.length(), 1)
  assert_eq(
    public_eof.errors[0].code,
    "missing-quote-before-doctype-public-identifier",
  )
  guard public_eof.errors[0].column is Some(21) else {
    fail("expected missing public quote at EOF")
  }
  let public_unquoted = @html_parser.tokenize(
    "<!doctype html PUBLIC x>",
    collect_errors=true,
  )
  assert_eq(
    public_unquoted.errors[0].code,
    "missing-quote-before-doctype-public-identifier",
  )
  guard public_unquoted.tokens[0]
    is @html_parser.HtmlToken::DoctypeToken(public_info) else {
    fail("expected doctype token")
  }
  assert_eq(public_info.name, "html")
  guard public_info.public_id is None else { fail("expected no public id") }
  assert_eq(public_info.force_quirks, true)
  let system_eof = @html_parser.parse(
    "<!doctype html SYSTEM",
    collect_errors=true,
  )
  assert_eq(
    system_eof.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body></body></html>",
  )
  assert_eq(system_eof.errors.length(), 1)
  assert_eq(
    system_eof.errors[0].code,
    "missing-quote-before-doctype-system-identifier",
  )
  guard system_eof.errors[0].column is Some(21) else {
    fail("expected missing system quote at EOF")
  }
  let system_unquoted = @html_parser.tokenize(
    "<!doctype html SYSTEM x>",
    collect_errors=true,
  )
  assert_eq(
    system_unquoted.errors[0].code,
    "missing-quote-before-doctype-system-identifier",
  )
  guard system_unquoted.tokens[0]
    is @html_parser.HtmlToken::DoctypeToken(system_info) else {
    fail("expected doctype token")
  }
  assert_eq(system_info.name, "html")
  guard system_info.system_id is None else { fail("expected no system id") }
  assert_eq(system_info.force_quirks, true)
}

///|
test "parser and tokenizer report post-public-identifier errors" {
  let missing_space = @html_parser.parse(
    "<!doctype html PUBLIC \"x\"",
    collect_errors=true,
  )
  assert_eq(
    missing_space.to_html(pretty=false),
    "<!DOCTYPE html PUBLIC \"x\"><html><head></head><body></body></html>",
  )
  assert_eq(missing_space.errors.length(), 2)
  assert_eq(
    missing_space.errors[0].code,
    "missing-whitespace-between-doctype-public-and-system-identifiers",
  )
  assert_eq(missing_space.errors[1].code, "unknown-doctype")
  guard missing_space.errors[0].column is Some(25) else {
    fail("expected missing whitespace error at EOF")
  }
  let unexpected = @html_parser.tokenize(
    "<!doctype html PUBLIC \"x\"x>",
    collect_errors=true,
  )
  assert_eq(
    unexpected.errors[0].code,
    "unexpected-character-after-doctype-public-identifier",
  )
  guard unexpected.tokens[0] is @html_parser.HtmlToken::DoctypeToken(info) else {
    fail("expected doctype token")
  }
  assert_eq(info.name, "html")
  guard info.public_id is Some("x") else { fail("expected public id") }
  assert_eq(info.force_quirks, true)
  let known = @html_parser.parse(
    "<!doctype html PUBLIC \"-//W3C//DTD HTML 4.01//EN\"x>",
    collect_errors=true,
  )
  assert_eq(known.errors.length(), 1)
  assert_eq(
    known.errors[0].code,
    "unexpected-character-after-doctype-public-identifier",
  )
}

///|
test "parser and tokenizer report system identifier tail errors" {
  let system_extra = @html_parser.tokenize(
    "<!doctype html SYSTEM \"x\"x>",
    collect_errors=true,
  )
  assert_eq(system_extra.errors.length(), 1)
  assert_eq(
    system_extra.errors[0].code,
    "unexpected-character-after-doctype-system-identifier",
  )
  guard system_extra.errors[0].column is Some(26) else {
    fail("expected system identifier tail error at trailing character")
  }
  guard system_extra.tokens[0]
    is @html_parser.HtmlToken::DoctypeToken(system_info) else {
    fail("expected doctype token")
  }
  guard system_info.system_id is Some("x") else { fail("expected system id") }
  assert_eq(system_info.force_quirks, false)
  let system_eof = @html_parser.tokenize(
    "<!doctype html SYSTEM \"x\"",
    collect_errors=true,
  )
  assert_eq(system_eof.errors.length(), 1)
  assert_eq(system_eof.errors[0].code, "eof-in-doctype")
  guard system_eof.tokens[0]
    is @html_parser.HtmlToken::DoctypeToken(system_eof_info) else {
    fail("expected doctype token")
  }
  guard system_eof_info.system_id is Some("x") else {
    fail("expected system id at EOF")
  }
  assert_eq(system_eof_info.force_quirks, true)
  let public_system_extra = @html_parser.parse(
    "<!doctype html PUBLIC \"p\" \"s\"x>",
    collect_errors=true,
  )
  assert_eq(
    public_system_extra.to_html(pretty=false),
    "<!DOCTYPE html PUBLIC \"p\" \"s\"><html><head></head><body></body></html>",
  )
  assert_eq(public_system_extra.errors.length(), 2)
  assert_eq(
    public_system_extra.errors[0].code,
    "unexpected-character-after-doctype-system-identifier",
  )
  guard public_system_extra.errors[0].column is Some(30) else {
    fail("expected public system tail error at trailing character")
  }
  assert_eq(public_system_extra.errors[1].code, "unknown-doctype")
  let fused = @html_parser.tokenize(
    "<!doctype html PUBLIC \"p\"\"s\"x>",
    collect_errors=true,
  )
  assert_eq(fused.errors.length(), 2)
  assert_eq(
    fused.errors[0].code,
    "missing-whitespace-between-doctype-public-and-system-identifiers",
  )
  assert_eq(
    fused.errors[1].code,
    "unexpected-character-after-doctype-system-identifier",
  )
  guard fused.errors[0].column is Some(26) else {
    fail("expected missing whitespace error at system quote")
  }
  guard fused.errors[1].column is Some(29) else {
    fail("expected fused system tail error at trailing character")
  }
  guard fused.tokens[0] is @html_parser.HtmlToken::DoctypeToken(fused_info) else {
    fail("expected fused doctype token")
  }
  guard fused_info.public_id is Some("p") else { fail("expected public id") }
  guard fused_info.system_id is Some("s") else { fail("expected system id") }
  assert_eq(fused_info.force_quirks, false)
  let immediate_public = @html_parser.parse(
    "<!doctype html PUBLIC\"x\">",
    collect_errors=true,
  )
  assert_eq(immediate_public.errors.length(), 2)
  assert_eq(
    immediate_public.errors[0].code,
    "missing-whitespace-before-doctype-public-identifier",
  )
  guard immediate_public.errors[0].column is Some(22) else {
    fail("expected missing whitespace before public identifier")
  }
  assert_eq(immediate_public.errors[1].code, "unknown-doctype")
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
}

///|
test "parser reports unknown and unexpected doctypes" {
  let unknown = @html_parser.parse("<!DOCTYPE svg><p>x", collect_errors=true)
  assert_eq(
    unknown.to_html(pretty=false),
    "<!DOCTYPE svg><html><head></head><body><p>x</p></body></html>",
  )
  assert_eq(unknown.errors.length(), 1)
  assert_eq(unknown.errors[0].code, "unknown-doctype")
  guard unknown.errors[0].column is Some(14) else {
    fail("expected unknown doctype at close bracket")
  }
  let unknown_public = @html_parser.parse(
    "<!doctype html PUBLIC \"x\">",
    collect_errors=true,
  )
  assert_eq(unknown_public.errors.length(), 1)
  assert_eq(unknown_public.errors[0].code, "unknown-doctype")
  guard unknown_public.errors[0].column is Some(26) else {
    fail("expected unknown public doctype at close bracket")
  }
  let legacy_system = @html_parser.parse(
    "<!doctype html SYSTEM \"about:legacy-compat\">",
    collect_errors=true,
  )
  assert_eq(legacy_system.errors.length(), 0)
  let repeated = @html_parser.parse(
    "<!doctype html><!doctype html><p>x",
    collect_errors=true,
  )
  assert_eq(
    repeated.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body><p>x</p></body></html>",
  )
  assert_eq(repeated.errors.length(), 1)
  assert_eq(repeated.errors[0].code, "unexpected-doctype")
  guard repeated.errors[0].column is Some(30) else {
    fail("expected unexpected doctype at second close bracket")
  }
  let fragment = @html_parser.parse_fragment(
    "<!doctype html><p>x",
    collect_errors=true,
  )
  assert_eq(fragment.to_html(pretty=false), "<p>x</p>")
  assert_eq(fragment.errors.length(), 1)
  assert_eq(fragment.errors[0].code, "unexpected-doctype")
}

///|
test "parser cursor advances by unicode character length" {
  let doc = @html_parser.parse_fragment("<p>😀 &lt; ok</p>")
  assert_eq(doc.to_html(pretty=false), "<p>😀 &lt; ok</p>")
  assert_eq(doc.to_text(separator="", strip=false), "😀 < ok")
}

///|
test "fragment context seeds literal text modes" {
  let textarea = @html_parser.parse_fragment(
    "<b>x</b>&lt;",
    context=@html_parser.FragmentContext::new("textarea"),
  )
  assert_eq(textarea.to_html(pretty=false), "&lt;b&gt;x&lt;/b&gt;&amp;lt;")
  assert_eq(textarea.to_text(separator="", strip=false), "<b>x</b>&lt;")
  assert_eq(textarea.query("b").length(), 0)
  let after_end = @html_parser.parse_fragment(
    "a</textarea><b>x</b>",
    context=@html_parser.FragmentContext::new("textarea"),
    collect_errors=true,
  )
  assert_eq(after_end.to_html(pretty=false), "a<b>x</b>")
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
}

///|
test "template content keeps table structural children" {
  let row = @html_parser.parse_fragment(
    "<template><tr><td>x</td></tr></template>",
    collect_errors=true,
  )
  assert_eq(
    row.to_html(pretty=false),
    "<template><tr><td>x</td></tr></template>",
  )
  assert_eq(row.errors.length(), 1)
  assert_eq(row.errors[0].code, "unexpected-end-tag-implies-table-voodoo")
  let implicit_row_end = @html_parser.parse_fragment(
    "<template><tr><td>x</td></template>",
    collect_errors=true,
  )
  assert_eq(
    implicit_row_end.to_html(pretty=false),
    "<template><tr><td>x</td></tr></template>",
  )
  assert_eq(implicit_row_end.errors.length(), 0)
  let cells = @html_parser.parse_fragment(
    "<template><td>x</td><td>y</td></template>",
    collect_errors=true,
  )
  assert_eq(
    cells.to_html(pretty=false),
    "<template><td>x</td><td>y</td></template>",
  )
  assert_eq(cells.errors.length(), 0)
  let colgroup = @html_parser.parse_fragment(
    "<template><colgroup><col></colgroup></template>",
    collect_errors=true,
  )
  assert_eq(
    colgroup.to_html(pretty=false),
    "<template><colgroup><col></colgroup></template>",
  )
  assert_eq(colgroup.errors.length(), 1)
  assert_eq(colgroup.errors[0].code, "unexpected-end-tag-implies-table-voodoo")
  let document = @html_parser.parse(
    "<template><tr><td>x</td></tr></template><p>y</p>",
    collect_errors=true,
  )
  assert_eq(
    document.to_html(pretty=false),
    "<html><head><template><tr><td>x</td></tr></template></head><body><p>y</p></body></html>",
  )
  assert_eq(document.errors.length(), 2)
  assert_eq(document.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(document.errors[1].code, "unexpected-end-tag-implies-table-voodoo")
}

///|
test "template column group keeps columns and drops text" {
  let text = @html_parser.parse_fragment(
    "<template><col>x<col></template>",
    collect_errors=true,
  )
  assert_eq(text.to_html(pretty=false), "<template><col><col></template>")
  assert_eq(text.errors.length(), 1)
  assert_eq(
    text.errors[0].code,
    "unexpected-characters-in-template-column-group",
  )
  let whitespace = @html_parser.parse_fragment(
    "<template><col> x<col></template>",
    collect_errors=true,
  )
  assert_eq(
    whitespace.to_html(pretty=false),
    "<template><col> <col></template>",
  )
  assert_eq(whitespace.errors.length(), 1)
  assert_eq(
    whitespace.errors[0].code,
    "unexpected-characters-in-template-column-group",
  )
  let col_end = @html_parser.parse_fragment(
    "<template><col></col></template>",
    collect_errors=true,
  )
  assert_eq(col_end.to_html(pretty=false), "<template><col></template>")
  assert_eq(col_end.errors.length(), 1)
  assert_eq(col_end.errors[0].code, "unexpected-end-tag")
  let colgroup = @html_parser.parse_fragment(
    "<template><col><colgroup><col></colgroup></template>",
    collect_errors=true,
  )
  assert_eq(colgroup.to_html(pretty=false), "<template><col><col></template>")
  assert_eq(colgroup.errors.length(), 2)
  assert_eq(colgroup.errors[0].code, "unexpected-start-tag-implies-end-tag")
  assert_eq(colgroup.errors[1].code, "unexpected-end-tag")
}

///|
test "template column group reprocesses other end tags through table mode" {
  let paragraph_end = @html_parser.parse_fragment(
    "<template><col></p></template>",
    collect_errors=true,
  )
  assert_eq(
    paragraph_end.to_html(pretty=false),
    "<template><col></template><p></p>",
  )
  assert_eq(paragraph_end.errors.length(), 4)
  assert_eq(
    paragraph_end.errors[0].code,
    "unexpected-end-tag-implies-table-voodoo",
  )
  assert_eq(paragraph_end.errors[1].code, "unexpected-end-tag")
  assert_eq(
    paragraph_end.errors[2].code,
    "unexpected-end-tag-implies-table-voodoo",
  )
  assert_eq(paragraph_end.errors[3].code, "unexpected-end-tag")
  let ignored_start = @html_parser.parse_fragment(
    "<template><col><span>x</span></template>",
    collect_errors=true,
  )
  assert_eq(ignored_start.to_html(pretty=false), "<template><col></template>")
  assert_eq(ignored_start.errors.length(), 6)
  assert_eq(
    ignored_start.errors[0].code,
    "unexpected-start-tag-in-template-column-group",
  )
  assert_eq(
    ignored_start.errors[1].code,
    "unexpected-characters-in-template-column-group",
  )
  assert_eq(
    ignored_start.errors[2].code,
    "unexpected-end-tag-implies-table-voodoo",
  )
  assert_eq(ignored_start.errors[3].code, "unexpected-end-tag")
  assert_eq(
    ignored_start.errors[4].code,
    "unexpected-end-tag-implies-table-voodoo",
  )
  assert_eq(ignored_start.errors[5].code, "unexpected-end-tag")
  let recovered_col = @html_parser.parse_fragment(
    "<template><col><div>x</div><col></template>",
    collect_errors=true,
  )
  assert_eq(
    recovered_col.to_html(pretty=false),
    "<template><col></template><colgroup><col></colgroup>",
  )
  assert_eq(recovered_col.errors.length(), 4)
  assert_eq(
    recovered_col.errors[0].code,
    "unexpected-start-tag-in-template-column-group",
  )
  assert_eq(
    recovered_col.errors[1].code,
    "unexpected-characters-in-template-column-group",
  )
  assert_eq(
    recovered_col.errors[2].code,
    "unexpected-end-tag-implies-table-voodoo",
  )
  assert_eq(recovered_col.errors[3].code, "unexpected-end-tag")
}

///|
test "fragment context seeds table insertion mode" {
  let row = @html_parser.parse_fragment(
    "<tr><td>x</td></tr>",
    context=@html_parser.FragmentContext::new("table"),
    collect_errors=true,
  )
  assert_eq(row.to_html(pretty=false), "<tbody><tr><td>x</td></tr></tbody>")
  assert_eq(row.errors.length(), 0)
  let direct_cell = @html_parser.parse_fragment(
    "<td>x</td>",
    context=@html_parser.FragmentContext::new("table"),
    collect_errors=true,
  )
  assert_eq(
    direct_cell.to_html(pretty=false),
    "<tbody><tr><td>x</td></tr></tbody>",
  )
  assert_eq(direct_cell.errors.length(), 1)
  assert_eq(direct_cell.errors[0].code, "unexpected-cell-in-table-body")
  let after_caption_text = @html_parser.parse_fragment(
    "<caption>c</caption>x",
    context=@html_parser.FragmentContext::new("table"),
    collect_errors=true,
  )
  assert_eq(after_caption_text.to_html(pretty=false), "<caption>c</caption>x")
  assert_eq(after_caption_text.errors.length(), 1)
  assert_eq(after_caption_text.errors[0].code, "foster-parenting-character")
  let fostered_start = @html_parser.parse_fragment(
    "<div>x</div>",
    context=@html_parser.FragmentContext::new("table"),
    collect_errors=true,
  )
  assert_eq(fostered_start.to_html(pretty=false), "<div>x</div>")
  assert_eq(fostered_start.errors.length(), 3)
  assert_eq(fostered_start.errors[0].code, "foster-parenting-start-tag")
  assert_eq(fostered_start.errors[1].code, "foster-parenting-character")
  assert_eq(
    fostered_start.errors[2].code,
    "unexpected-end-tag-implies-table-voodoo",
  )
  let ignored_table_end = @html_parser.parse_fragment(
    "<tr><td>x</table>y",
    context=@html_parser.FragmentContext::new("table"),
    collect_errors=true,
  )
  assert_eq(
    ignored_table_end.to_html(pretty=false),
    "<tbody><tr><td>xy</td></tr></tbody>",
  )
  assert_eq(ignored_table_end.errors.length(), 1)
  assert_eq(ignored_table_end.errors[0].code, "unexpected-end-tag")
  let nested_table = @html_parser.parse_fragment(
    "<table>x</table>",
    context=@html_parser.FragmentContext::new("table"),
    collect_errors=true,
  )
  assert_eq(nested_table.to_html(pretty=false), "x")
  assert_eq(nested_table.errors.length(), 4)
  assert_eq(nested_table.errors[0].code, "unexpected-start-tag-implies-end-tag")
  assert_eq(nested_table.errors[1].code, "unexpected-end-tag")
  assert_eq(nested_table.errors[2].code, "foster-parenting-character")
  assert_eq(nested_table.errors[3].code, "unexpected-end-tag")
}

///|
test "fragment context seeds table section insertion mode" {
  let row = @html_parser.parse_fragment(
    "<tr><td>x</td></tr>",
    context=@html_parser.FragmentContext::new("tbody"),
    collect_errors=true,
  )
  assert_eq(row.to_html(pretty=false), "<tr><td>x</td></tr>")
  assert_eq(row.errors.length(), 0)
  let direct_cell = @html_parser.parse_fragment(
    "<td>x</td>",
    context=@html_parser.FragmentContext::new("tbody"),
    collect_errors=true,
  )
  assert_eq(direct_cell.to_html(pretty=false), "<tr><td>x</td></tr>")
  assert_eq(direct_cell.errors.length(), 1)
  assert_eq(direct_cell.errors[0].code, "unexpected-cell-in-table-body")
  let fostered_start = @html_parser.parse_fragment(
    "<div>x</div>",
    context=@html_parser.FragmentContext::new("tbody"),
    collect_errors=true,
  )
  assert_eq(fostered_start.to_html(pretty=false), "<div>x</div>")
  assert_eq(fostered_start.errors.length(), 3)
  assert_eq(fostered_start.errors[0].code, "foster-parenting-start-tag")
  assert_eq(fostered_start.errors[1].code, "foster-parenting-character")
  assert_eq(
    fostered_start.errors[2].code,
    "unexpected-end-tag-implies-table-voodoo",
  )
  let ignored_caption = @html_parser.parse_fragment(
    "<caption>x</caption>",
    context=@html_parser.FragmentContext::new("tbody"),
    collect_errors=true,
  )
  assert_eq(ignored_caption.to_html(pretty=false), "x")
  assert_eq(ignored_caption.errors.length(), 3)
  assert_eq(ignored_caption.errors[0].code, "unexpected-start-tag")
  assert_eq(ignored_caption.errors[1].code, "foster-parenting-character")
  assert_eq(ignored_caption.errors[2].code, "unexpected-end-tag")
  let ignored_table = @html_parser.parse_fragment(
    "<table>x</table>",
    context=@html_parser.FragmentContext::new("tfoot"),
    collect_errors=true,
  )
  assert_eq(ignored_table.to_html(pretty=false), "x")
  assert_eq(ignored_table.errors.length(), 3)
  assert_eq(ignored_table.errors[0].code, "unexpected-start-tag")
  assert_eq(ignored_table.errors[1].code, "foster-parenting-character")
  assert_eq(ignored_table.errors[2].code, "unexpected-end-tag")
}

///|
test "fragment context seeds table row insertion mode" {
  let cells = @html_parser.parse_fragment(
    "<td>x</td><td>y</td>",
    context=@html_parser.FragmentContext::new("tr"),
    collect_errors=true,
  )
  assert_eq(cells.to_html(pretty=false), "<td>x</td><td>y</td>")
  assert_eq(cells.errors.length(), 0)
  let ignored_row = @html_parser.parse_fragment(
    "<tr><td>x</td></tr>",
    context=@html_parser.FragmentContext::new("tr"),
    collect_errors=true,
  )
  assert_eq(ignored_row.to_html(pretty=false), "<td>x</td>")
  assert_eq(ignored_row.errors.length(), 2)
  assert_eq(ignored_row.errors[0].code, "unexpected-start-tag-implies-end-tag")
  assert_eq(ignored_row.errors[1].code, "unexpected-end-tag")
  let fostered_start = @html_parser.parse_fragment(
    "<div>x</div>",
    context=@html_parser.FragmentContext::new("tr"),
    collect_errors=true,
  )
  assert_eq(fostered_start.to_html(pretty=false), "<div>x</div>")
  assert_eq(fostered_start.errors.length(), 1)
  assert_eq(fostered_start.errors[0].code, "foster-parenting-character")
  let ignored_caption = @html_parser.parse_fragment(
    "<caption>x</caption>",
    context=@html_parser.FragmentContext::new("tr"),
    collect_errors=true,
  )
  assert_eq(ignored_caption.to_html(pretty=false), "x")
  assert_eq(ignored_caption.errors.length(), 3)
  assert_eq(
    ignored_caption.errors[0].code,
    "unexpected-start-tag-implies-end-tag",
  )
  assert_eq(ignored_caption.errors[1].code, "foster-parenting-character")
  assert_eq(ignored_caption.errors[2].code, "unexpected-end-tag")
}

///|
test "fragment context seeds table cell insertion mode" {
  let body_content = @html_parser.parse_fragment(
    "x<div>y</div>",
    context=@html_parser.FragmentContext::new("td"),
    collect_errors=true,
  )
  assert_eq(body_content.to_html(pretty=false), "x<div>y</div>")
  assert_eq(body_content.errors.length(), 0)
  let ignored_cell = @html_parser.parse_fragment(
    "<td>x</td>",
    context=@html_parser.FragmentContext::new("td"),
    collect_errors=true,
  )
  assert_eq(ignored_cell.to_html(pretty=false), "x")
  assert_eq(ignored_cell.errors.length(), 2)
  assert_eq(
    ignored_cell.errors[0].code,
    "unexpected-start-tag-in-cell-fragment",
  )
  assert_eq(ignored_cell.errors[1].code, "unexpected-end-tag")
  let ignored_row = @html_parser.parse_fragment(
    "<tr><td>x</td></tr>",
    context=@html_parser.FragmentContext::new("th"),
    collect_errors=true,
  )
  assert_eq(ignored_row.to_html(pretty=false), "x")
  assert_eq(ignored_row.errors.length(), 4)
  assert_eq(ignored_row.errors[0].code, "unexpected-start-tag-in-cell-fragment")
  assert_eq(ignored_row.errors[1].code, "unexpected-start-tag-in-cell-fragment")
  assert_eq(ignored_row.errors[2].code, "unexpected-end-tag")
  assert_eq(ignored_row.errors[3].code, "unexpected-end-tag")
  let nested_table = @html_parser.parse_fragment(
    "<table>x</table>",
    context=@html_parser.FragmentContext::new("td"),
    collect_errors=true,
  )
  assert_eq(nested_table.to_html(pretty=false), "x<table></table>")
  assert_eq(nested_table.errors.length(), 1)
  assert_eq(nested_table.errors[0].code, "foster-parenting-character")
}

///|
test "fragment context seeds caption insertion mode" {
  let body_content = @html_parser.parse_fragment(
    "x<div>y</div>",
    context=@html_parser.FragmentContext::new("caption"),
    collect_errors=true,
  )
  assert_eq(body_content.to_html(pretty=false), "x<div>y</div>")
  assert_eq(body_content.errors.length(), 0)
  let ignored_row = @html_parser.parse_fragment(
    "<tr><td>x</td></tr>",
    context=@html_parser.FragmentContext::new("caption"),
    collect_errors=true,
  )
  assert_eq(ignored_row.to_html(pretty=false), "x")
  assert_eq(ignored_row.errors.length(), 6)
  assert_eq(ignored_row.errors[0].code, "unexpected-start-tag-implies-end-tag")
  assert_eq(ignored_row.errors[1].code, "unexpected-end-tag")
  assert_eq(ignored_row.errors[2].code, "unexpected-start-tag-implies-end-tag")
  assert_eq(ignored_row.errors[3].code, "unexpected-end-tag")
  assert_eq(ignored_row.errors[4].code, "unexpected-end-tag")
  assert_eq(ignored_row.errors[5].code, "unexpected-end-tag")
  let ignored_caption = @html_parser.parse_fragment(
    "<caption>x</caption>",
    context=@html_parser.FragmentContext::new("caption"),
    collect_errors=true,
  )
  assert_eq(ignored_caption.to_html(pretty=false), "x")
  assert_eq(ignored_caption.errors.length(), 3)
  assert_eq(
    ignored_caption.errors[0].code,
    "unexpected-start-tag-implies-end-tag",
  )
  assert_eq(ignored_caption.errors[1].code, "unexpected-end-tag")
  assert_eq(ignored_caption.errors[2].code, "unexpected-end-tag")
  let table = @html_parser.parse_fragment(
    "<table>x</table><td>y</td>",
    context=@html_parser.FragmentContext::new("caption"),
    collect_errors=true,
  )
  assert_eq(table.to_html(pretty=false), "x<table></table>y")
  assert_eq(table.errors.length(), 5)
  assert_eq(table.errors[0].code, "unexpected-start-tag-implies-end-tag")
  assert_eq(table.errors[1].code, "unexpected-end-tag")
  assert_eq(table.errors[2].code, "foster-parenting-character")
  assert_eq(table.errors[3].code, "unexpected-start-tag-ignored")
  assert_eq(table.errors[4].code, "unexpected-end-tag")
}

///|
test "fragment context seeds column group insertion mode" {
  let cols = @html_parser.parse_fragment(
    "<col><col>",
    context=@html_parser.FragmentContext::new("colgroup"),
    collect_errors=true,
  )
  assert_eq(cols.to_html(pretty=false), "<col><col>")
  assert_eq(cols.errors.length(), 0)
  let text = @html_parser.parse_fragment(
    " x ",
    context=@html_parser.FragmentContext::new("colgroup"),
    collect_errors=true,
  )
  assert_eq(text.to_html(pretty=false), " ")
  assert_eq(text.errors.length(), 1)
  assert_eq(text.errors[0].code, "unexpected-characters-in-column-group")
  let col_text_col = @html_parser.parse_fragment(
    "<col>x<col>",
    context=@html_parser.FragmentContext::new("colgroup"),
    collect_errors=true,
  )
  assert_eq(col_text_col.to_html(pretty=false), "<col><col>")
  assert_eq(col_text_col.errors.length(), 1)
  assert_eq(
    col_text_col.errors[0].code,
    "unexpected-characters-in-column-group",
  )
  let ignored_start = @html_parser.parse_fragment(
    "<div>x</div>",
    context=@html_parser.FragmentContext::new("colgroup"),
    collect_errors=true,
  )
  assert_eq(ignored_start.to_html(pretty=false), "")
  assert_eq(ignored_start.errors.length(), 4)
  assert_eq(
    ignored_start.errors[0].code,
    "unexpected-start-tag-in-column-group",
  )
  assert_eq(
    ignored_start.errors[1].code,
    "unexpected-characters-in-column-group",
  )
  assert_eq(
    ignored_start.errors[2].code,
    "unexpected-end-tag-implies-table-voodoo",
  )
  assert_eq(ignored_start.errors[3].code, "unexpected-end-tag")
  let paragraph_end = @html_parser.parse_fragment(
    "</p>",
    context=@html_parser.FragmentContext::new("colgroup"),
    collect_errors=true,
  )
  assert_eq(paragraph_end.to_html(pretty=false), "<p></p>")
  assert_eq(paragraph_end.errors.length(), 2)
  assert_eq(
    paragraph_end.errors[0].code,
    "unexpected-end-tag-implies-table-voodoo",
  )
  assert_eq(paragraph_end.errors[1].code, "unexpected-end-tag")
  let nested_colgroup = @html_parser.parse_fragment(
    "<colgroup><col></colgroup>",
    context=@html_parser.FragmentContext::new("colgroup"),
    collect_errors=true,
  )
  assert_eq(nested_colgroup.to_html(pretty=false), "<col>")
  assert_eq(nested_colgroup.errors.length(), 2)
  assert_eq(
    nested_colgroup.errors[0].code,
    "unexpected-start-tag-implies-end-tag",
  )
  assert_eq(nested_colgroup.errors[1].code, "unexpected-end-tag")
}

///|
test "query supports tag class id and tag class selectors" {
  let doc = @html_parser.parse_fragment(
    "<div><p id='first' class='intro lead first'>One</p><p>Two</p></div>",
  )
  assert_eq(doc.query("p").length(), 2)
  assert_eq(doc.query(".intro").length(), 1)
  assert_eq(doc.query(".intro.first").length(), 1)
  assert_eq(doc.query(".intro.missing").length(), 0)
  assert_eq(doc.query("#first").length(), 1)
  assert_eq(doc.query("p#first").length(), 1)
  assert_eq(doc.query("div#first").length(), 0)
  assert_eq(doc.query("p.intro.first").length(), 1)
  assert_eq(doc.query("div.intro").length(), 0)
  assert_eq(doc.query("*").length(), 3)
  assert_eq(doc.query("*.intro").length(), 1)
  let first = doc.query_one("p.lead")
  guard first is Some(node) else { fail("expected p.lead") }
  assert_eq(node.to_text(separator="", strip=false), "One")
  assert_true(@html_parser.matches(node, "*"))
  assert_true(@html_parser.matches(node, "p#first.lead"))
  assert_eq(doc.query("p#first.lead").length(), 1)
  let spaced = @html_parser.fragment(children=[
    @html_parser.element("p", attrs={
      "class": Some("alpha\tbeta\ngamma\u{000C}delta\repsilon"),
    }),
  ])
  assert_eq(spaced.query(".beta").length(), 1)
  assert_eq(spaced.query("p.gamma").length(), 1)
  assert_eq(spaced.query(".delta").length(), 1)
  assert_eq(spaced.query(".epsilon").length(), 1)
  assert_eq(spaced.query(".alpha.epsilon").length(), 1)
  assert_eq(spaced.query("p.beta.delta").length(), 1)
  assert_eq(spaced.query(".ta").length(), 0)
  let compound = @html_parser.parse_fragment(
    "<div id='main' class='container featured'><p>Text</p></div>",
  )
  assert_eq(compound.query("div#main").length(), 1)
  assert_eq(compound.query("span#main").length(), 0)
  assert_eq(compound.query("*.container").length(), 1)
  assert_eq(compound.query("div.container#main").length(), 1)
  assert_eq(compound.query("#main.container.featured").length(), 1)
  assert_eq(compound.query("div#main.missing").length(), 0)
}

///|
test "query supports attribute presence and exact selectors" {
  let doc = @html_parser.parse_fragment(
    "<div id='main' data-id='123'><a href='http://example.com' data-id='link'>Link</a><button disabled>Push</button></div>",
  )
  assert_eq(doc.query("[href]").length(), 1)
  assert_eq(doc.query("a[href]").length(), 1)
  assert_eq(doc.query("[id]").length(), 1)
  assert_eq(doc.query("[data-id]").length(), 2)
  assert_eq(doc.query("[id=\"main\"]").length(), 1)
  assert_eq(doc.query("[id='main']").length(), 1)
  assert_eq(doc.query("[id=main]").length(), 1)
  assert_eq(doc.query("[ id = 'main' ]").length(), 1)
  assert_eq(doc.query("[id=wrong]").length(), 0)
  assert_eq(doc.query("a[href][data-id='link']").length(), 1)
  assert_eq(doc.query("button[disabled='']").length(), 1)
  let upper = @html_parser.fragment(children=[
    @html_parser.element("a", attrs={ "DATA-ID": Some("42") }),
  ])
  assert_eq(upper.query("[data-id='42']").length(), 1)
}

///|
test "query supports attribute operator selectors" {
  let doc = @html_parser.parse_fragment(
    "<div class='container secondary' lang='en-US' data-tags='alpha\tbeta' data-name='example item'><a href='http://example.com'>Link</a><p data-empty=''></p></div>",
  )
  assert_eq(doc.query("[class~='container']").length(), 1)
  assert_eq(doc.query("[class~='contain']").length(), 0)
  assert_eq(doc.query("[data-tags~=beta]").length(), 1)
  assert_eq(doc.query("[lang|=en]").length(), 1)
  assert_eq(doc.query("[lang|=eng]").length(), 0)
  assert_eq(doc.query("[href^='http']").length(), 1)
  assert_eq(doc.query("[href^='https']").length(), 0)
  assert_eq(doc.query("[href$='.com']").length(), 1)
  assert_eq(doc.query("[href$='.org']").length(), 0)
  assert_eq(doc.query("[href*='example']").length(), 1)
  assert_eq(doc.query("[href *= 'example']").length(), 1)
  assert_eq(doc.query("[href*='google']").length(), 0)
  assert_eq(doc.query("[href^='']").length(), 0)
  assert_eq(doc.query("[href$='']").length(), 0)
  assert_eq(doc.query("[href*='']").length(), 0)
}

///|
test "query supports comma selector lists" {
  let doc = @html_parser.parse_fragment(
    "<section><h1>Title</h1><p class='intro'>One</p><p>Two</p><a href='a,b'>Link</a></section>",
  )
  assert_eq(doc.query("h1, a").length(), 2)
  assert_eq(doc.query("h1, p, a").length(), 4)
  assert_eq(doc.query(".intro, [href]").length(), 2)
  assert_eq(doc.query("p, p").length(), 2)
  assert_eq(doc.query("[href='a,b'], p").length(), 3)
  assert_eq(doc.query("p,").length(), 0)
  let ordered = doc.query("a, h1")
  assert_eq(ordered.length(), 2)
  assert_eq(ordered[0].name(), "h1")
  assert_eq(ordered[1].name(), "a")
  guard doc.query_one("a, h1") is Some(first) else {
    fail("expected selector list query_one")
  }
  assert_eq(first.name(), "h1")
}

///|
test "query supports descendant selectors" {
  let doc = @html_parser.parse_fragment(
    "<div id='main'><p class='intro'>One</p><section><a href='x'>Link</a><span data-name='a b'>Span</span></section></div><aside><p>Two</p></aside>",
  )
  assert_eq(doc.query("div p").length(), 1)
  assert_eq(doc.query("div   p").length(), 1)
  assert_eq(doc.query("#main a").length(), 1)
  assert_eq(doc.query("div [href]").length(), 1)
  assert_eq(doc.query("div [data-name='a b']").length(), 1)
  assert_eq(doc.query("aside a").length(), 0)
  assert_eq(doc.query("#main p, aside p").length(), 2)
  guard doc.query_one("p.intro") is Some(intro) else {
    fail("expected intro paragraph")
  }
  assert_true(@html_parser.matches(intro, "div p"))
  assert_eq(@html_parser.matches(intro, "aside p"), false)
}

///|
test "query supports child selectors" {
  let doc = @html_parser.parse_fragment(
    "<div id='main'><h1>Top</h1><section><h1>Nested</h1><a href='x'>Link</a></section><span data-name='a > b'>Span</span></div>",
  )
  assert_eq(doc.query("div > h1").length(), 1)
  assert_eq(doc.query("div>h1").length(), 1)
  assert_eq(doc.query("#main > section > a").length(), 1)
  assert_eq(doc.query("#main > a").length(), 0)
  assert_eq(doc.query("div > [data-name='a > b']").length(), 1)
  assert_eq(doc.query("div > section a").length(), 1)
  guard doc.query_one("a") is Some(link) else { fail("expected link") }
  assert_true(@html_parser.matches(link, "#main > section > a"))
  assert_eq(@html_parser.matches(link, "#main > a"), false)
}

///|
test "query supports adjacent sibling selectors" {
  let doc = @html_parser.parse_fragment(
    "<div><h1>Heading</h1>\n<p class='first'>First</p><p class='second'>Second</p><span>Other</span><p class='third'>Third</p></div>",
  )
  assert_eq(doc.query("h1 + p").length(), 1)
  assert_eq(doc.query(".first + p").length(), 1)
  assert_eq(doc.query(".first + span").length(), 0)
  assert_eq(doc.query("span + p").length(), 1)
  assert_eq(doc.query("h1+p").length(), 1)
  guard doc.query_one(".second") is Some(second) else {
    fail("expected second paragraph")
  }
  assert_true(@html_parser.matches(second, ".first + p"))
  assert_eq(@html_parser.matches(second, "h1 + p"), false)
}

///|
test "query supports general sibling selectors" {
  let doc = @html_parser.parse_fragment(
    "<div><h1>Heading</h1><p class='first'><span>Inside</span></p><p class='second'>Second</p><span>Other</span><p class='third'>Third</p></div>",
  )
  assert_eq(doc.query("h1 ~ p").length(), 3)
  assert_eq(doc.query(".first ~ p").length(), 2)
  assert_eq(doc.query(".second ~ span").length(), 1)
  assert_eq(doc.query("span ~ h1").length(), 0)
  assert_eq(doc.query("h1~p").length(), 3)
  assert_eq(doc.query("h1 ~ p span").length(), 1)
  guard doc.query_one(".third") is Some(third) else {
    fail("expected third paragraph")
  }
  assert_true(@html_parser.matches(third, "h1 ~ p"))
  assert_true(@html_parser.matches(third, ".second ~ p"))
}

///|
test "query supports first and last child pseudo selectors" {
  let doc = @html_parser.parse_fragment(
    "<ul><li class='first'>One</li><li class='middle'>Two</li><li class='last'>Three</li></ul><div><span>Only</span></div>",
  )
  assert_eq(doc.query("li:first-child").length(), 1)
  assert_eq(doc.query("li:last-child").length(), 1)
  assert_eq(doc.query(".middle:first-child").length(), 0)
  assert_eq(doc.query(".middle:last-child").length(), 0)
  assert_eq(doc.query("div > :first-child").length(), 1)
  assert_eq(doc.query("span:first-child").length(), 1)
  assert_eq(doc.query("span:last-child").length(), 1)
  guard doc.query_one("li.first") is Some(first) else {
    fail("expected first list item")
  }
  assert_true(@html_parser.matches(first, "ul > li:first-child"))
  assert_eq(@html_parser.matches(first, "li:last-child"), false)
}

///|
test "query supports only child pseudo selector" {
  let doc = @html_parser.parse_fragment(
    "<div><span>Only</span></div><ul><li>One</li><li>Two</li></ul>",
  )
  assert_eq(doc.query("span:only-child").length(), 1)
  assert_eq(doc.query("li:only-child").length(), 0)
  guard doc.query_one("span") is Some(span) else { fail("expected span") }
  assert_true(@html_parser.matches(span, "div > span:only-child"))
}

///|
test "query supports empty pseudo selector" {
  let doc = @html_parser.parse_fragment(
    "<div class='empty'></div><div class='whitespace'>   </div><div class='text'>content</div><div class='nested'><span></span></div><!-- ignored -->",
  )
  assert_eq(doc.query(".empty:empty").length(), 1)
  assert_eq(doc.query(".whitespace:empty").length(), 1)
  assert_eq(doc.query(".text:empty").length(), 0)
  assert_eq(doc.query(".nested:empty").length(), 0)
}

///|
test "query supports root pseudo selector" {
  let doc = @html_parser.parse("<!doctype html><p>x</p>")
  assert_eq(doc.query(":root").length(), 1)
  assert_eq(doc.query("html:root").length(), 1)
  assert_eq(doc.query("body:root").length(), 0)
  let fragment = @html_parser.parse_fragment("<div>x</div>")
  assert_eq(fragment.query(":root").length(), 1)
  assert_eq(fragment.query("div:root").length(), 1)
}

///|
test "query supports first and last of type pseudo selectors" {
  let doc = @html_parser.parse_fragment(
    "<div><h1>Heading</h1><p class='first'>First</p><p class='second'>Second</p><span>Other</span><p class='third'>Third</p></div>",
  )
  assert_eq(doc.query("p:first-of-type").length(), 1)
  assert_eq(doc.query("p:last-of-type").length(), 1)
  assert_eq(doc.query("h1:first-of-type").length(), 1)
  assert_eq(doc.query("h1:last-of-type").length(), 1)
  assert_eq(doc.query(".second:first-of-type").length(), 0)
  assert_eq(doc.query(".second:last-of-type").length(), 0)
  guard doc.query_one(".first") is Some(first) else {
    fail("expected first paragraph")
  }
  assert_true(@html_parser.matches(first, "p:first-of-type"))
  assert_eq(@html_parser.matches(first, "p:last-of-type"), false)
}

///|
test "query supports only of type pseudo selector" {
  let doc = @html_parser.parse_fragment(
    "<div><h1>Heading</h1><p>First</p><p>Second</p><span>Other</span></div>",
  )
  assert_eq(doc.query("h1:only-of-type").length(), 1)
  assert_eq(doc.query("span:only-of-type").length(), 1)
  assert_eq(doc.query("p:only-of-type").length(), 0)
  guard doc.query_one("h1") is Some(heading) else { fail("expected heading") }
  assert_true(@html_parser.matches(heading, "div > h1:only-of-type"))
}

///|
test "query supports nth child pseudo selector" {
  let doc = @html_parser.parse_fragment(
    "<ul><li>1</li><li class='special'>2</li><li>3</li><li>4</li><li>5</li></ul>",
  )
  assert_eq(doc.query("li:nth-child(2)").length(), 1)
  assert_eq(doc.query("li:nth-child(odd)").length(), 3)
  assert_eq(doc.query("li:nth-child(even)").length(), 2)
  assert_eq(doc.query("li:nth-child(2n+1)").length(), 3)
  assert_eq(doc.query("li:nth-child(2n)").length(), 2)
  assert_eq(doc.query("li:nth-child(n)").length(), 5)
  assert_eq(doc.query("li:nth-child(-n+3)").length(), 3)
  assert_eq(doc.query("li:nth-child( 2n + 1 )").length(), 3)
  assert_eq(doc.query("li:nth-child(abc)").length(), 0)
  guard doc.query_one(".special") is Some(special) else {
    fail("expected special list item")
  }
  assert_true(@html_parser.matches(special, "li:nth-child(2)"))
  assert_eq(@html_parser.matches(special, "li:nth-child(odd)"), false)
}

///|
test "query supports nth of type pseudo selector" {
  let doc = @html_parser.parse_fragment(
    "<div><h1>Heading</h1><p class='first'>First</p><p class='second'>Second</p><span>Other</span><p class='third'>Third</p></div>",
  )
  assert_eq(doc.query("p:nth-of-type(2)").length(), 1)
  assert_eq(doc.query("p:nth-of-type(odd)").length(), 2)
  assert_eq(doc.query("p:nth-of-type(even)").length(), 1)
  assert_eq(doc.query("p:nth-of-type(2n+1)").length(), 2)
  assert_eq(doc.query("h1:nth-of-type(1)").length(), 1)
  assert_eq(doc.query("span:nth-of-type(n)").length(), 1)
  guard doc.query_one(".second") is Some(second) else {
    fail("expected second paragraph")
  }
  assert_true(@html_parser.matches(second, "p:nth-of-type(2)"))
  assert_eq(@html_parser.matches(second, "p:nth-of-type(odd)"), false)
}

///|
test "query supports not pseudo selector" {
  let doc = @html_parser.parse_fragment(
    "<div id='main'><p class='intro'>One</p><p class='content'>Two</p></div><div id='sidebar'><p>Side</p></div>",
  )
  assert_eq(doc.query("div:not(#sidebar)").length(), 1)
  assert_eq(doc.query("p:not(.intro)").length(), 2)
  assert_eq(doc.query("div > p:not(.content)").length(), 2)
  assert_eq(doc.query("p:not(.intro, .content)").length(), 1)
  assert_eq(doc.query("p:not()").length(), 3)
  guard doc.query_one(".intro") is Some(intro) else {
    fail("expected intro paragraph")
  }
  assert_true(@html_parser.matches(intro, "p:not(.content)"))
  assert_eq(@html_parser.matches(intro, "p:not(.intro)"), false)
}

///|
test "query supports comment pseudo selector" {
  let doc = @html_parser.parse_fragment(
    "<div>Before<!-- first --><span>Inside</span><!-- second --></div><!-- outside -->",
  )
  assert_eq(doc.query(":comment").length(), 3)
  assert_eq(doc.query("div > :comment").length(), 2)
  assert_eq(doc.query("div :comment").length(), 2)
  assert_eq(doc.query("div, :comment").length(), 4)
  guard doc.query_one(":comment") is Some(comment) else {
    fail("expected comment")
  }
  assert_eq(comment.name(), "#comment")
  assert_true(@html_parser.matches(comment, ":comment"))
  assert_eq(@html_parser.matches(comment, "*"), false)
}

///|
test "query supports contains pseudo selector" {
  let doc = @html_parser.parse_fragment(
    "<div id='a'><button>click me</button></div><div id='b'><button>do not click</button></div><div id='c'><span>click</span> me</div>",
  )
  assert_eq(doc.query("button:contains(\"click me\")").length(), 1)
  assert_eq(doc.query("button:contains(click)").length(), 2)
  assert_eq(doc.query("div:contains(\"click me\")").length(), 2)
  assert_eq(doc.query("button:contains(\"Click\")").length(), 0)
  assert_eq(doc.query("button:contains(\"\")").length(), 2)
  assert_eq(doc.query("button:contains()").length(), 0)
  guard doc.query_one("#a") is Some(first) else { fail("expected first div") }
  assert_true(@html_parser.matches(first, "div:contains(\"click me\")"))
}

///|
test "query and matches support complex selector combinations" {
  let doc = @html_parser.parse_fragment(
    "<div id='main' class='container'><h1>Title</h1><p class='intro'>One</p><p class='content'>Two</p><ul><li>Item 1</li><li class='special'>Item 2</li></ul><a href='x' data-id='123'>Link</a></div><aside id='sidebar'><a href='y'>Side</a></aside>",
  )
  assert_eq(doc.query("div.container#main").length(), 1)
  assert_eq(doc.query("a[href][data-id]").length(), 1)
  assert_eq(doc.query("div.container > ul li.special").length(), 1)
  assert_eq(doc.query("div > p:first-child").length(), 0)
  assert_eq(doc.query("#main p, #sidebar a").length(), 3)
  guard doc.query_one("p.intro") is Some(intro) else {
    fail("expected intro paragraph")
  }
  assert_true(@html_parser.matches(intro, "div p"))
  assert_true(@html_parser.matches(intro, "#main p"))
  assert_eq(@html_parser.matches(intro, "#sidebar p"), false)
}

///|
test "node query searches descendants only" {
  let root = @html_parser.element("div", children=[
    @html_parser.element("p", children=[@html_parser.text("One")]),
  ])
  assert_eq(root.query("div").length(), 0)
  assert_eq(root.query("p").length(), 1)
  assert_true(@html_parser.matches(root, "div"))
  let doc = @html_parser.parse_fragment("<div id='main'><p>One</p></div>")
  guard doc.query_one("#main") is Some(main) else { fail("expected main div") }
  assert_eq(main.query("div").length(), 0)
  assert_eq(main.query("p").length(), 1)
}

///|
test "dom child mutation follows node ownership rules" {
  let leaf = @html_parser.comment("comment")
  let ignored = @html_parser.element("span")
  leaf.append_child(ignored)
  assert_eq(leaf.children().length(), 0)
  assert_eq(leaf.query("span").length(), 0)
  assert_eq(@html_parser.matches(ignored, "span"), true)
  assert_eq(@html_parser.matches(ignored, ":root"), false)
  let first = @html_parser.element("div")
  let second = @html_parser.element("section")
  let child = @html_parser.element("p")
  first.append_child(child)
  assert_eq(first.query("p").length(), 1)
  assert_true(@html_parser.matches(child, "div > p"))
  second.append_child(child)
  assert_eq(first.query("p").length(), 0)
  assert_eq(second.query("p").length(), 1)
  assert_eq(@html_parser.matches(child, "div > p"), false)
  assert_true(@html_parser.matches(child, "section > p"))
  second.remove_child(child)
  assert_eq(second.query("p").length(), 0)
  assert_eq(@html_parser.matches(child, "section > p"), false)
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
test "parser closes open paragraphs before plaintext and xmp starts" {
  let xmp = @html_parser.parse_fragment("<p>a<xmp>b</xmp>c")
  assert_eq(xmp.to_html(pretty=false), "<p>a</p><xmp>b</xmp>c")
  let plaintext = @html_parser.parse_fragment(
    "<p>a<plaintext>b</plaintext>c",
    collect_errors=true,
  )
  assert_eq(
    plaintext.to_html(pretty=false),
    "<p>a</p><plaintext>b&lt;/plaintext&gt;c</plaintext>",
  )
  assert_eq(plaintext.errors.length(), 1)
  assert_eq(plaintext.errors[0].code, "expected-closing-tag-but-got-eof")
  let textarea = @html_parser.parse_fragment("<p>a<textarea>b</textarea>c")
  assert_eq(textarea.to_html(pretty=false), "<p>a<textarea>b</textarea>c</p>")
  let title = @html_parser.parse_fragment("<p>a<title>b</title>c")
  assert_eq(title.to_html(pretty=false), "<p>a<title>b</title>c</p>")
}

///|
test "parser closes open buttons before repeated button starts" {
  let nested = @html_parser.parse_fragment(
    "<button>one<button>two</button>three</button>",
    collect_errors=true,
  )
  assert_eq(
    nested.to_html(pretty=false),
    "<button>one</button><button>two</button>three",
  )
  assert_eq(nested.errors.length(), 2)
  assert_eq(nested.errors[0].code, "unexpected-start-tag-implies-end-tag")
  assert_eq(nested.errors[1].code, "unexpected-end-tag")
  let with_formatting = @html_parser.parse_fragment(
    "<button><b>one</b><button>two</button></button>",
    collect_errors=true,
  )
  assert_eq(
    with_formatting.to_html(pretty=false),
    "<button><b>one</b></button><button>two</button>",
  )
  assert_eq(with_formatting.errors.length(), 2)
  assert_eq(
    with_formatting.errors[0].code,
    "unexpected-start-tag-implies-end-tag",
  )
  assert_eq(with_formatting.errors[1].code, "unexpected-end-tag")
}

///|
test "parser ignores nested form starts and clears form element on end" {
  let nested = @html_parser.parse_fragment(
    "<form><form>x</form>y</form>",
    collect_errors=true,
  )
  assert_eq(nested.to_html(pretty=false), "<form>x</form>y")
  assert_eq(nested.errors.length(), 2)
  assert_eq(nested.errors[0].code, "unexpected-start-tag")
  assert_eq(nested.errors[1].code, "unexpected-end-tag")
  let paragraph = @html_parser.parse_fragment(
    "<form><p>a<form>b</form>",
    collect_errors=true,
  )
  assert_eq(paragraph.to_html(pretty=false), "<form><p>ab</p></form>")
  assert_eq(paragraph.errors.length(), 1)
  assert_eq(paragraph.errors[0].code, "unexpected-start-tag")
}

///|
test "parser handles form end tags through stored form element" {
  let closes_p = @html_parser.parse_fragment("<p>a<form>b</form>c")
  assert_eq(closes_p.to_html(pretty=false), "<p>a</p><form>b</form>c")
  let stray = @html_parser.parse_fragment("</form>x", collect_errors=true)
  assert_eq(stray.to_html(pretty=false), "x")
  assert_eq(stray.errors.length(), 1)
  assert_eq(stray.errors[0].code, "unexpected-end-tag")
  let removed_by_ancestor = @html_parser.parse_fragment(
    "<div><form><p>x</div>after</form>",
    collect_errors=true,
  )
  assert_eq(
    removed_by_ancestor.to_html(pretty=false),
    "<div><form><p>x</p></form></div>after",
  )
  assert_eq(removed_by_ancestor.errors.length(), 2)
  assert_eq(removed_by_ancestor.errors[0].code, "end-tag-too-early")
  assert_eq(removed_by_ancestor.errors[1].code, "unexpected-end-tag")
}

///|
test "parser generates implied ruby annotation end tags" {
  let repeated_base = @html_parser.parse_fragment(
    "<ruby><rb>a<rb>b</ruby>",
    collect_errors=true,
  )
  assert_eq(
    repeated_base.to_html(pretty=false),
    "<ruby><rb>a</rb><rb>b</rb></ruby>",
  )
  assert_eq(repeated_base.errors.length(), 1)
  assert_eq(repeated_base.errors[0].code, "end-tag-too-early")
  let repeated_text = @html_parser.parse_fragment(
    "<ruby><rb>a<rt>b<rt>c</ruby>",
    collect_errors=true,
  )
  assert_eq(
    repeated_text.to_html(pretty=false),
    "<ruby><rb>a</rb><rt>b</rt><rt>c</rt></ruby>",
  )
  assert_eq(repeated_text.errors.length(), 1)
  assert_eq(repeated_text.errors[0].code, "end-tag-too-early")
  let rp_rt = @html_parser.parse_fragment(
    "<ruby><rp>(<rt>a<rp>)</ruby>",
    collect_errors=true,
  )
  assert_eq(
    rp_rt.to_html(pretty=false),
    "<ruby><rp>(</rp><rt>a</rt><rp>)</rp></ruby>",
  )
  assert_eq(rp_rt.errors.length(), 1)
  assert_eq(rp_rt.errors[0].code, "end-tag-too-early")
}

///|
test "parser handles ruby annotation start exclusions" {
  let rtc_text = @html_parser.parse_fragment(
    "<ruby><rtc>a<rt>b</ruby>",
    collect_errors=true,
  )
  assert_eq(
    rtc_text.to_html(pretty=false),
    "<ruby><rtc>a<rt>b</rt></rtc></ruby>",
  )
  assert_eq(rtc_text.errors.length(), 1)
  assert_eq(rtc_text.errors[0].code, "end-tag-too-early")
  let paragraph_rt = @html_parser.parse_fragment("<p>a<rt>b")
  assert_eq(paragraph_rt.to_html(pretty=false), "<p>a</p><rt>b</rt>")
  let paragraph_rb = @html_parser.parse_fragment("<p>a<rb>b")
  assert_eq(paragraph_rb.to_html(pretty=false), "<p>a<rb>b</rb></p>")
  let loose = @html_parser.parse_fragment("<rb>a<rt>b<rtc>c<rb>d")
  assert_eq(
    loose.to_html(pretty=false),
    "<rb>a</rb><rt>b</rt><rtc>c</rtc><rb>d</rb>",
  )
  let special = @html_parser.parse_fragment(
    "<ruby><div>x</ruby>y</div>",
    collect_errors=true,
  )
  assert_eq(special.to_html(pretty=false), "<ruby><div>xy</div></ruby>")
  assert_eq(special.errors.length(), 2)
  assert_eq(special.errors[0].code, "unexpected-end-tag")
  assert_eq(special.errors[1].code, "expected-closing-tag-but-got-eof")
  let inline = @html_parser.parse_fragment(
    "<ruby><span>x</ruby>y</span>",
    collect_errors=true,
  )
  assert_eq(inline.to_html(pretty=false), "<ruby><span>x</span></ruby>y")
  assert_eq(inline.errors.length(), 2)
  assert_eq(inline.errors[0].code, "end-tag-too-early")
  assert_eq(inline.errors[1].code, "unexpected-end-tag")
}

///|
test "parser inserts keygen and fragment frame as empty non-void elements" {
  let keygen = @html_parser.parse_fragment(
    "<p>a<keygen>b</p><keygen>x</keygen>",
    collect_errors=true,
  )
  assert_eq(
    keygen.to_html(pretty=false),
    "<p>a<keygen></keygen>b</p><keygen></keygen>x",
  )
  assert_eq(keygen.errors.length(), 1)
  assert_eq(keygen.errors[0].code, "unexpected-end-tag")
  let self_closing_keygen = @html_parser.parse_fragment("<keygen/>x")
  assert_eq(self_closing_keygen.to_html(pretty=false), "<keygen></keygen>x")
  let frame = @html_parser.parse_fragment(
    "<p>a<frame>b</p><frame>x</frame>",
    collect_errors=true,
  )
  assert_eq(
    frame.to_html(pretty=false),
    "<p>a<frame></frame>b</p><frame></frame>x",
  )
  assert_eq(frame.errors.length(), 1)
  assert_eq(frame.errors[0].code, "unexpected-end-tag")
}

///|
test "document parser ignores frame starts in body mode" {
  let paragraph = @html_parser.parse(
    "<!doctype html><p>a<frame>b</p>",
    collect_errors=true,
  )
  assert_eq(
    paragraph.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body><p>ab</p></body></html>",
  )
  assert_eq(paragraph.errors.length(), 1)
  assert_eq(paragraph.errors[0].code, "unexpected-start-tag-ignored")
  let root = @html_parser.parse(
    "<!doctype html><frame>x</frame>",
    collect_errors=true,
  )
  assert_eq(
    root.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body>x</body></html>",
  )
  assert_eq(root.errors.length(), 2)
  assert_eq(root.errors[0].code, "unexpected-start-tag-ignored")
  assert_eq(root.errors[1].code, "unexpected-end-tag")
}

///|
test "document parser scaffolds framesets outside body" {
  let frameset = @html_parser.parse(
    "<!doctype html><html><head></head><frameset></frameset>",
    collect_errors=true,
  )
  assert_eq(
    frameset.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><frameset></frameset></html>",
  )
  assert_eq(frameset.errors.length(), 0)
  let nested = @html_parser.parse(
    "<!doctype html><frameset><frame src=x><frameset></frameset></frameset>",
    collect_errors=true,
  )
  assert_eq(
    nested.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><frameset><frame src=\"x\"></frame><frameset></frameset></frameset></html>",
  )
  assert_eq(nested.errors.length(), 0)
  let trailing_space = @html_parser.parse(
    "<!doctype html><frameset></frameset>   ",
    collect_errors=true,
  )
  assert_eq(
    trailing_space.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><frameset></frameset>   </html>",
  )
  assert_eq(trailing_space.errors.length(), 0)
  let noframes = @html_parser.parse(
    "<!doctype html><frameset><noframes><p>x</p></noframes></frameset>",
    collect_errors=true,
  )
  assert_eq(
    noframes.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><frameset><noframes>&lt;p&gt;x&lt;/p&gt;</noframes></frameset></html>",
  )
  assert_eq(noframes.errors.length(), 0)
}

///|
test "document parser ignores tokens after frameset" {
  let text = @html_parser.parse(
    "<!doctype html><html><head></head><frameset></frameset>abc",
    collect_errors=true,
  )
  assert_eq(
    text.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><frameset></frameset></html>",
  )
  assert_eq(text.errors.length(), 1)
  assert_eq(text.errors[0].code, "unexpected-token-after-frameset")
  let paired = @html_parser.parse(
    "<!doctype html><frameset></frameset><p>x</p>",
    collect_errors=true,
  )
  assert_eq(
    paired.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><frameset></frameset></html>",
  )
  assert_eq(paired.errors.length(), 3)
  assert_eq(paired.errors[0].code, "unexpected-token-after-frameset")
  assert_eq(paired.errors[1].code, "unexpected-token-in-frameset")
  assert_eq(paired.errors[2].code, "unexpected-token-in-frameset")
  let void_start = @html_parser.parse(
    "<!doctype html><frameset></frameset><br>",
    collect_errors=true,
  )
  assert_eq(
    void_start.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><frameset></frameset></html>",
  )
  assert_eq(void_start.errors.length(), 2)
  assert_eq(void_start.errors[0].code, "unexpected-token-after-frameset")
  assert_eq(void_start.errors[1].code, "unexpected-token-in-frameset")
  let noframes = @html_parser.parse(
    "<!doctype html><frameset></frameset><noframes>x</noframes>",
    collect_errors=true,
  )
  assert_eq(
    noframes.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><frameset></frameset><noframes>x</noframes></html>",
  )
  assert_eq(noframes.errors.length(), 0)
  let body = @html_parser.parse(
    "<!doctype html><body>x</body><frameset></frameset>",
    collect_errors=true,
  )
  assert_eq(
    body.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body>x</body></html>",
  )
  assert_eq(body.errors.length(), 2)
  assert_eq(body.errors[0].code, "unexpected-start-tag-ignored")
  assert_eq(body.errors[1].code, "unexpected-end-tag")
}

///|
test "document parser ignores col starts outside tables" {
  let paragraph = @html_parser.parse(
    "<!doctype html><p>a<col>b</p>",
    collect_errors=true,
  )
  assert_eq(
    paragraph.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body><p>ab</p></body></html>",
  )
  assert_eq(paragraph.errors.length(), 1)
  assert_eq(paragraph.errors[0].code, "unexpected-start-tag-ignored")
  let root = @html_parser.parse(
    "<!doctype html><col>x</col>",
    collect_errors=true,
  )
  assert_eq(
    root.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body>x</body></html>",
  )
  assert_eq(root.errors.length(), 2)
  assert_eq(root.errors[0].code, "unexpected-start-tag-ignored")
  assert_eq(root.errors[1].code, "unexpected-end-tag")
  let select_col = @html_parser.parse(
    "<!doctype html><select><col>x</col></select>",
    collect_errors=true,
  )
  assert_eq(
    select_col.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body><select></select>x</body></html>",
  )
  assert_eq(select_col.errors.length(), 4)
  assert_eq(select_col.errors[0].code, "unexpected-start-tag-in-select")
  assert_eq(select_col.errors[1].code, "unexpected-start-tag-ignored")
  assert_eq(select_col.errors[2].code, "unexpected-end-tag")
  assert_eq(select_col.errors[3].code, "unexpected-end-tag")
}

///|
test "fragment parser keeps col starts outside tables" {
  let paragraph = @html_parser.parse_fragment(
    "<p>a<col>b</p>",
    collect_errors=true,
  )
  assert_eq(paragraph.to_html(pretty=false), "<p>a<col>b</p>")
  assert_eq(paragraph.errors.length(), 0)
  let root = @html_parser.parse_fragment("<col>x</col>", collect_errors=true)
  assert_eq(root.to_html(pretty=false), "<col>x")
  assert_eq(root.errors.length(), 1)
  assert_eq(root.errors[0].code, "unexpected-end-tag")
}

///|
test "parser handles keygen and frame starts in select mode" {
  let keygen = @html_parser.parse_fragment(
    "<select><keygen>x</keygen></select>",
    collect_errors=true,
  )
  assert_eq(keygen.to_html(pretty=false), "<select><keygen></keygen>x</select>")
  assert_eq(keygen.errors.length(), 1)
  assert_eq(keygen.errors[0].code, "unexpected-end-tag")
  let frame = @html_parser.parse_fragment(
    "<select><frame>x</frame></select>",
    collect_errors=true,
  )
  assert_eq(frame.to_html(pretty=false), "<select>x</select>")
  assert_eq(frame.errors.length(), 2)
  assert_eq(frame.errors[0].code, "unexpected-start-tag-in-select")
  assert_eq(frame.errors[1].code, "unexpected-end-tag")
}

///|
test "parser reports select hr br and img starts" {
  let hr = @html_parser.parse_fragment(
    "<select><option>a<hr>b</option></select>",
    collect_errors=true,
  )
  assert_eq(
    hr.to_html(pretty=false),
    "<select><option>a</option><hr>b</select>",
  )
  assert_eq(hr.errors.length(), 2)
  assert_eq(hr.errors[0].code, "unexpected-start-tag-in-select")
  assert_eq(hr.errors[1].code, "unexpected-end-tag-in-select")
  let group_hr = @html_parser.parse_fragment(
    "<select><optgroup><option>a<hr>b</optgroup>c</select>",
    collect_errors=true,
  )
  assert_eq(
    group_hr.to_html(pretty=false),
    "<select><optgroup><option>a</option></optgroup><hr>bc</select>",
  )
  assert_eq(group_hr.errors.length(), 2)
  assert_eq(group_hr.errors[0].code, "unexpected-start-tag-in-select")
  assert_eq(group_hr.errors[1].code, "unexpected-end-tag-in-select")
  let br = @html_parser.parse_fragment(
    "<select><br>x</select>",
    collect_errors=true,
  )
  assert_eq(br.to_html(pretty=false), "<select><br>x</select>")
  assert_eq(br.errors.length(), 1)
  assert_eq(br.errors[0].code, "unexpected-start-tag-in-select")
  let img = @html_parser.parse_fragment(
    "<select><img src=x>x</select>",
    collect_errors=true,
  )
  assert_eq(img.to_html(pretty=false), "<select><img src=\"x\">x</select>")
  assert_eq(img.errors.length(), 1)
  assert_eq(img.errors[0].code, "unexpected-start-tag-in-select")
}

///|
test "parser reports select common element starts and ends" {
  let div = @html_parser.parse_fragment(
    "<select><div>x</div>y</select>",
    collect_errors=true,
  )
  assert_eq(div.to_html(pretty=false), "<select><div>x</div>y</select>")
  assert_eq(div.errors.length(), 2)
  assert_eq(div.errors[0].code, "unexpected-start-tag-in-select")
  assert_eq(div.errors[1].code, "unexpected-end-tag-in-select")
  let button = @html_parser.parse_fragment(
    "<select><button>x</button>y</select>",
    collect_errors=true,
  )
  assert_eq(
    button.to_html(pretty=false),
    "<select><button>x</button>y</select>",
  )
  assert_eq(button.errors.length(), 2)
  assert_eq(button.errors[0].code, "unexpected-start-tag-in-select")
  assert_eq(button.errors[1].code, "unexpected-end-tag-in-select")
  let menuitem = @html_parser.parse_fragment(
    "<select><menuitem>x</menuitem>y</select>",
    collect_errors=true,
  )
  assert_eq(
    menuitem.to_html(pretty=false),
    "<select><menuitem>xy</menuitem></select>",
  )
  assert_eq(menuitem.errors.length(), 2)
  assert_eq(menuitem.errors[0].code, "unexpected-start-tag-in-select")
  assert_eq(menuitem.errors[1].code, "unexpected-end-tag")
}

///|
test "parser reports select plaintext start and keeps current container" {
  let plain = @html_parser.parse_fragment(
    "<select><plaintext>x</select>y",
    collect_errors=true,
  )
  assert_eq(
    plain.to_html(pretty=false),
    "<select><plaintext>x&lt;/select&gt;y</plaintext></select>",
  )
  assert_eq(plain.errors.length(), 2)
  assert_eq(plain.errors[0].code, "unexpected-start-tag-in-select")
  assert_eq(plain.errors[1].code, "expected-closing-tag-but-got-eof")
  let in_p = @html_parser.parse_fragment(
    "<select><p>x<plaintext>y</select>z",
    collect_errors=true,
  )
  assert_eq(
    in_p.to_html(pretty=false),
    "<select><p>x<plaintext>y&lt;/select&gt;z</plaintext></p></select>",
  )
  assert_eq(in_p.errors.length(), 3)
  assert_eq(in_p.errors[0].code, "unexpected-start-tag-in-select")
  assert_eq(in_p.errors[1].code, "unexpected-start-tag-in-select")
  assert_eq(in_p.errors[2].code, "expected-closing-tag-but-got-eof")
}

///|
test "parser closes open list items before repeated li starts" {
  let fragment = @html_parser.parse_fragment(
    "<ul><li>one<li><p>two<li>three</ul>",
  )
  assert_eq(
    fragment.to_html(pretty=false),
    "<ul><li>one</li><li><p>two</p></li><li>three</li></ul>",
  )
  let loose = @html_parser.parse_fragment("<li>loose<li>item")
  assert_eq(loose.to_html(pretty=false), "<li>loose</li><li>item</li>")
}

///|
test "parser closes open definition items before repeated dt and dd starts" {
  let fragment = @html_parser.parse_fragment(
    "<dl><dt>term<dt>next<dd><p>def<dd>again</dl>",
  )
  assert_eq(
    fragment.to_html(pretty=false),
    "<dl><dt>term</dt><dt>next</dt><dd><p>def</p></dd><dd>again</dd></dl>",
  )
  let loose = @html_parser.parse_fragment("<dt>term<dd>def<dt>next")
  assert_eq(
    loose.to_html(pretty=false),
    "<dt>term</dt><dd>def</dd><dt>next</dt>",
  )
  let nested_terms = @html_parser.parse_fragment(
    "<dl><dt>A<dl><dt>B</dt></dl></dt><dt>C</dt></dl>",
    collect_errors=true,
  )
  assert_eq(
    nested_terms.to_html(pretty=false),
    "<dl><dt>A<dl><dt>B</dt></dl></dt><dt>C</dt></dl>",
  )
  assert_eq(nested_terms.errors.length(), 0)
  let nested_definitions = @html_parser.parse_fragment(
    "<dl><dd>A<dl><dd>B</dd></dl></dd><dd>C</dd></dl>",
    collect_errors=true,
  )
  assert_eq(
    nested_definitions.to_html(pretty=false),
    "<dl><dd>A<dl><dd>B</dd></dl></dd><dd>C</dd></dl>",
  )
  assert_eq(nested_definitions.errors.length(), 0)
  let nested_mixed = @html_parser.parse_fragment(
    "<dl><dt>A<dl><dd>B</dd></dl></dt><dd>C</dd></dl>",
    collect_errors=true,
  )
  assert_eq(
    nested_mixed.to_html(pretty=false),
    "<dl><dt>A<dl><dd>B</dd></dl></dt><dd>C</dd></dl>",
  )
  assert_eq(nested_mixed.errors.length(), 0)
}

///|
test "parser closes repeated option and select optgroup starts" {
  let options = @html_parser.parse_fragment(
    "<select><option>one<option>two</select>",
  )
  assert_eq(
    options.to_html(pretty=false),
    "<select><option>one</option><option>two</option></select>",
  )
  let groups = @html_parser.parse_fragment(
    "<select><optgroup><option>one<optgroup><option>two</select>",
  )
  assert_eq(
    groups.to_html(pretty=false),
    "<select><optgroup><option>one</option></optgroup><optgroup><option>two</option></optgroup></select>",
  )
  let nested_select = @html_parser.parse_fragment(
    "<select><select><option>x</select>",
    collect_errors=true,
  )
  assert_eq(
    nested_select.to_html(pretty=false),
    "<select></select><option>x</option>",
  )
  assert_eq(nested_select.errors.length(), 2)
  assert_eq(nested_select.errors[0].code, "unexpected-select-in-select")
  assert_eq(nested_select.errors[1].code, "unexpected-end-tag")
  let stray_group = @html_parser.parse_fragment(
    "<select><option>1</option></optgroup></select>",
    collect_errors=true,
  )
  assert_eq(
    stray_group.to_html(pretty=false),
    "<select><option>1</option></select>",
  )
  assert_eq(stray_group.errors.length(), 1)
  assert_eq(stray_group.errors[0].code, "unexpected-end-tag-in-select")
  let stray_option = @html_parser.parse_fragment(
    "<select></option></select>",
    collect_errors=true,
  )
  assert_eq(stray_option.to_html(pretty=false), "<select></select>")
  assert_eq(stray_option.errors.length(), 1)
  assert_eq(stray_option.errors[0].code, "unexpected-end-tag-in-select")
  let input = @html_parser.parse_fragment(
    "<select><input name=x></select>",
    collect_errors=true,
  )
  assert_eq(input.to_html(pretty=false), "<select></select><input name=\"x\">")
  assert_eq(input.errors.length(), 2)
  assert_eq(input.errors[0].code, "unexpected-start-tag-in-select")
  assert_eq(input.errors[1].code, "unexpected-end-tag")
  let textarea = @html_parser.parse_fragment(
    "<select><textarea>hi</textarea></select>",
    collect_errors=true,
  )
  assert_eq(
    textarea.to_html(pretty=false),
    "<select></select><textarea>hi</textarea>",
  )
  assert_eq(textarea.errors.length(), 2)
  assert_eq(textarea.errors[0].code, "unexpected-start-tag-in-select")
  assert_eq(textarea.errors[1].code, "unexpected-end-tag")
  let table = @html_parser.parse_fragment(
    "<select><table><tr><td>x</td></tr></table></select>",
    collect_errors=true,
  )
  assert_eq(
    table.to_html(pretty=false),
    "<select></select><table><tbody><tr><td>x</td></tr></tbody></table>",
  )
  assert_eq(table.errors.length(), 2)
  assert_eq(table.errors[0].code, "unexpected-start-tag-in-select")
  assert_eq(table.errors[1].code, "unexpected-end-tag")
  let table_cell = @html_parser.parse_fragment(
    "<select><td>x</td></select>",
    collect_errors=true,
  )
  assert_eq(table_cell.to_html(pretty=false), "<select></select>x")
  assert_eq(table_cell.errors.length(), 4)
  assert_eq(table_cell.errors[0].code, "unexpected-start-tag-in-select")
  assert_eq(table_cell.errors[1].code, "unexpected-start-tag-ignored")
  assert_eq(table_cell.errors[2].code, "unexpected-end-tag")
  assert_eq(table_cell.errors[3].code, "unexpected-end-tag")
  let table_col = @html_parser.parse_fragment(
    "<select><col>x</col></select>",
    collect_errors=true,
  )
  assert_eq(table_col.to_html(pretty=false), "<select></select><col>x")
  assert_eq(table_col.errors.length(), 3)
  assert_eq(table_col.errors[0].code, "unexpected-start-tag-in-select")
  assert_eq(table_col.errors[1].code, "unexpected-end-tag")
  assert_eq(table_col.errors[2].code, "unexpected-end-tag")
}

///|
test "parser populates selectedcontent from selected option" {
  let first = @html_parser.parse_fragment(
    "<select><option>one</option><option>two</option><selectedcontent></selectedcontent></select>",
    collect_errors=true,
  )
  assert_eq(
    first.to_html(pretty=false),
    "<select><option>one</option><option>two</option><selectedcontent>one</selectedcontent></select>",
  )
  assert_eq(first.errors.length(), 2)
  assert_eq(first.errors[0].code, "unexpected-start-tag-in-select")
  assert_eq(first.errors[1].code, "unexpected-end-tag-in-select")
  let selected = @html_parser.parse_fragment(
    "<select><option>one</option><option selected>two <b>bold</b></option><selectedcontent></selectedcontent></select>",
    collect_errors=true,
  )
  assert_eq(
    selected.to_html(pretty=false),
    "<select><option>one</option><option selected>two <b>bold</b></option><selectedcontent>two <b>bold</b></selectedcontent></select>",
  )
  assert_eq(selected.errors.length(), 2)
  let existing = @html_parser.parse_fragment(
    "<select><option selected>one</option><selectedcontent>old</selectedcontent></select>",
    collect_errors=true,
  )
  assert_eq(
    existing.to_html(pretty=false),
    "<select><option selected>one</option><selectedcontent>oldone</selectedcontent></select>",
  )
  assert_eq(existing.errors.length(), 2)
  let nested = @html_parser.parse_fragment(
    "<select><optgroup><option selected><span>x</span></option></optgroup><selectedcontent></selectedcontent></select>",
    collect_errors=true,
  )
  assert_eq(
    nested.to_html(pretty=false),
    "<select><optgroup><option selected><span>x</span></option></optgroup><selectedcontent><span>x</span></selectedcontent></select>",
  )
  assert_eq(nested.errors.length(), 4)
  assert_eq(nested.errors[0].code, "unexpected-start-tag-in-select")
  assert_eq(nested.errors[1].code, "unexpected-end-tag-in-select")
  assert_eq(nested.errors[2].code, "unexpected-start-tag-in-select")
  assert_eq(nested.errors[3].code, "unexpected-end-tag-in-select")
  let two_selects = @html_parser.parse_fragment(
    "<select><option selected>a</option><selectedcontent></selectedcontent></select><select><option>b</option><selectedcontent></selectedcontent></select>",
    collect_errors=true,
  )
  assert_eq(
    two_selects.to_html(pretty=false),
    "<select><option selected>a</option><selectedcontent>a</selectedcontent></select><select><option>b</option><selectedcontent>b</selectedcontent></select>",
  )
  assert_eq(two_selects.errors.length(), 4)
}

///|
test "parser inserts basic table row groups and rows" {
  let rows = @html_parser.parse_fragment("<table><tr><td>x</td></tr></table>")
  assert_eq(
    rows.to_html(pretty=false),
    "<table><tbody><tr><td>x</td></tr></tbody></table>",
  )
  let cells = @html_parser.parse_fragment("<table><td>x<td>y</table>")
  assert_eq(
    cells.to_html(pretty=false),
    "<table><tbody><tr><td>x</td><td>y</td></tr></tbody></table>",
  )
  let after_head = @html_parser.parse_fragment(
    "<table><thead><tr><td>h</td></tr></thead><tr><td>b</td></tr></table>",
  )
  assert_eq(
    after_head.to_html(pretty=false),
    "<table><thead><tr><td>h</td></tr></thead><tbody><tr><td>b</td></tr></tbody></table>",
  )
  let section_cells = @html_parser.parse_fragment(
    "<table><tbody><td>x<th>y</tbody></table>",
  )
  assert_eq(
    section_cells.to_html(pretty=false),
    "<table><tbody><tr><td>x</td><th>y</th></tr></tbody></table>",
  )
}

///|
test "parser reports cells started directly in table body context" {
  let table_cell = @html_parser.parse_fragment(
    "<table><td>x<td>y</table>",
    collect_errors=true,
  )
  assert_eq(
    table_cell.to_html(pretty=false),
    "<table><tbody><tr><td>x</td><td>y</td></tr></tbody></table>",
  )
  assert_eq(table_cell.errors.length(), 1)
  assert_eq(table_cell.errors[0].code, "unexpected-cell-in-table-body")
  let section_cell = @html_parser.parse_fragment(
    "<table><tbody><td>x<th>y</tbody></table>",
    collect_errors=true,
  )
  assert_eq(
    section_cell.to_html(pretty=false),
    "<table><tbody><tr><td>x</td><th>y</th></tr></tbody></table>",
  )
  assert_eq(section_cell.errors.length(), 1)
  assert_eq(section_cell.errors[0].code, "unexpected-cell-in-table-body")
  let head_cell = @html_parser.parse_fragment(
    "<table><thead><td>x</td></thead></table>",
    collect_errors=true,
  )
  assert_eq(
    head_cell.to_html(pretty=false),
    "<table><thead><tr><td>x</td></tr></thead></table>",
  )
  assert_eq(head_cell.errors.length(), 1)
  assert_eq(head_cell.errors[0].code, "unexpected-cell-in-table-body")
  let row_cell = @html_parser.parse_fragment(
    "<table><tr><td>x<th>y</table>",
    collect_errors=true,
  )
  assert_eq(
    row_cell.to_html(pretty=false),
    "<table><tbody><tr><td>x</td><th>y</th></tr></tbody></table>",
  )
  assert_eq(row_cell.errors.length(), 0)
  let open_cell = @html_parser.parse_fragment(
    "<table><tbody><td>x</table>",
    collect_errors=true,
  )
  assert_eq(
    open_cell.to_html(pretty=false),
    "<table><tbody><tr><td>x</td></tr></tbody></table>",
  )
  assert_eq(open_cell.errors.length(), 1)
  assert_eq(open_cell.errors[0].code, "unexpected-cell-in-table-body")
}

///|
test "parser closes row groups before table structure starts" {
  let nested_body = @html_parser.parse_fragment(
    "<table><tbody><tbody><tr><td>x</td></tr></tbody></table>",
    collect_errors=true,
  )
  assert_eq(
    nested_body.to_html(pretty=false),
    "<table><tbody></tbody><tbody><tr><td>x</td></tr></tbody></table>",
  )
  assert_eq(nested_body.errors.length(), 0)
  let head = @html_parser.parse_fragment(
    "<table><tbody><thead><tr><td>x</td></tr></thead></table>",
    collect_errors=true,
  )
  assert_eq(
    head.to_html(pretty=false),
    "<table><tbody></tbody><thead><tr><td>x</td></tr></thead></table>",
  )
  assert_eq(head.errors.length(), 0)
  let caption = @html_parser.parse_fragment(
    "<table><tbody><caption>x</caption></table>",
    collect_errors=true,
  )
  assert_eq(
    caption.to_html(pretty=false),
    "<table><tbody></tbody><caption>x</caption></table>",
  )
  assert_eq(caption.errors.length(), 0)
  let colgroup = @html_parser.parse_fragment(
    "<table><tbody><colgroup><col></colgroup></table>",
    collect_errors=true,
  )
  assert_eq(
    colgroup.to_html(pretty=false),
    "<table><tbody></tbody><colgroup><col></colgroup></table>",
  )
  assert_eq(colgroup.errors.length(), 0)
}

///|
test "parser wraps table col starts in implied colgroups" {
  let single = @html_parser.parse_fragment(
    "<table><col></table>",
    collect_errors=true,
  )
  assert_eq(
    single.to_html(pretty=false),
    "<table><colgroup><col></colgroup></table>",
  )
  assert_eq(single.errors.length(), 0)
  let adjacent = @html_parser.parse_fragment(
    "<table><col><col></table>",
    collect_errors=true,
  )
  assert_eq(
    adjacent.to_html(pretty=false),
    "<table><colgroup><col><col></colgroup></table>",
  )
  assert_eq(adjacent.errors.length(), 0)
  let after_explicit = @html_parser.parse_fragment(
    "<table><colgroup><col></colgroup><col></table>",
    collect_errors=true,
  )
  assert_eq(
    after_explicit.to_html(pretty=false),
    "<table><colgroup><col></colgroup><colgroup><col></colgroup></table>",
  )
  assert_eq(after_explicit.errors.length(), 0)
  let row_group = @html_parser.parse_fragment(
    "<table><tbody><col><tr><td>x</td></tr></table>",
    collect_errors=true,
  )
  assert_eq(
    row_group.to_html(pretty=false),
    "<table><tbody></tbody><colgroup><col></colgroup><tbody><tr><td>x</td></tr></tbody></table>",
  )
  assert_eq(row_group.errors.length(), 0)
}

///|
test "parser handles text in column group context" {
  let explicit_text = @html_parser.parse_fragment(
    "<table><colgroup>x</colgroup></table>",
    collect_errors=true,
  )
  assert_eq(
    explicit_text.to_html(pretty=false),
    "x<table><colgroup></colgroup></table>",
  )
  assert_eq(explicit_text.errors.length(), 3)
  assert_eq(
    explicit_text.errors[0].code,
    "unexpected-characters-in-column-group",
  )
  assert_eq(explicit_text.errors[1].code, "foster-parenting-character")
  assert_eq(explicit_text.errors[2].code, "unexpected-end-tag")
  let explicit_space = @html_parser.parse_fragment(
    "<table><colgroup> </colgroup></table>",
    collect_errors=true,
  )
  assert_eq(
    explicit_space.to_html(pretty=false),
    "<table><colgroup> </colgroup></table>",
  )
  assert_eq(explicit_space.errors.length(), 2)
  assert_eq(
    explicit_space.errors[0].code,
    "unexpected-characters-in-column-group",
  )
  assert_eq(explicit_space.errors[1].code, "unexpected-end-tag")
  let implicit_text = @html_parser.parse_fragment(
    "<table><col>x</table>",
    collect_errors=true,
  )
  assert_eq(
    implicit_text.to_html(pretty=false),
    "x<table><colgroup><col></colgroup></table>",
  )
  assert_eq(implicit_text.errors.length(), 2)
  assert_eq(
    implicit_text.errors[0].code,
    "unexpected-characters-in-column-group",
  )
  assert_eq(implicit_text.errors[1].code, "foster-parenting-character")
  let implicit_space = @html_parser.parse_fragment(
    "<table><col> </table>",
    collect_errors=true,
  )
  assert_eq(
    implicit_space.to_html(pretty=false),
    "<table><colgroup><col> </colgroup></table>",
  )
  assert_eq(implicit_space.errors.length(), 1)
  assert_eq(
    implicit_space.errors[0].code,
    "unexpected-characters-in-column-group",
  )
}

///|
test "parser closes column groups before non-col starts" {
  let row = @html_parser.parse_fragment(
    "<table><colgroup><tr><td>x</td></tr></table>",
    collect_errors=true,
  )
  assert_eq(
    row.to_html(pretty=false),
    "<table><colgroup></colgroup><tbody><tr><td>x</td></tr></tbody></table>",
  )
  assert_eq(row.errors.length(), 0)
  let caption = @html_parser.parse_fragment(
    "<table><colgroup><caption>x</caption></table>",
    collect_errors=true,
  )
  assert_eq(
    caption.to_html(pretty=false),
    "<table><colgroup></colgroup><caption>x</caption></table>",
  )
  assert_eq(caption.errors.length(), 0)
  let nested = @html_parser.parse_fragment(
    "<table><colgroup><colgroup><col></colgroup></table>",
    collect_errors=true,
  )
  assert_eq(
    nested.to_html(pretty=false),
    "<table><colgroup></colgroup><colgroup><col></colgroup></table>",
  )
  assert_eq(nested.errors.length(), 1)
  assert_eq(nested.errors[0].code, "unexpected-start-tag-implies-end-tag")
  let div = @html_parser.parse_fragment(
    "<table><colgroup><div>x</div></table>",
    collect_errors=true,
  )
  assert_eq(
    div.to_html(pretty=false),
    "<div>x</div><table><colgroup></colgroup></table>",
  )
  assert_eq(div.errors.length(), 3)
  assert_eq(div.errors[0].code, "foster-parenting-start-tag")
  assert_eq(div.errors[1].code, "foster-parenting-character")
  assert_eq(div.errors[2].code, "unexpected-end-tag-implies-table-voodoo")
  let form = @html_parser.parse_fragment(
    "<table><colgroup><form id=f></form></table>",
    collect_errors=true,
  )
  assert_eq(
    form.to_html(pretty=false),
    "<table><colgroup></colgroup><form id=\"f\"></form></table>",
  )
  assert_eq(form.errors.length(), 3)
  assert_eq(form.errors[0].code, "unexpected-form-in-table")
  assert_eq(form.errors[1].code, "unexpected-end-tag-implies-table-voodoo")
  assert_eq(form.errors[2].code, "unexpected-end-tag")
}

///|
test "parser closes column groups before non-colgroup end tags" {
  let div = @html_parser.parse_fragment(
    "<table><colgroup></div></table>",
    collect_errors=true,
  )
  assert_eq(div.to_html(pretty=false), "<table><colgroup></colgroup></table>")
  assert_eq(div.errors.length(), 2)
  assert_eq(div.errors[0].code, "unexpected-end-tag-implies-table-voodoo")
  assert_eq(div.errors[1].code, "unexpected-end-tag")
  let paragraph = @html_parser.parse_fragment(
    "<table><colgroup></p></table>",
    collect_errors=true,
  )
  assert_eq(
    paragraph.to_html(pretty=false),
    "<p></p><table><colgroup></colgroup></table>",
  )
  assert_eq(paragraph.errors.length(), 2)
  assert_eq(paragraph.errors[0].code, "unexpected-end-tag-implies-table-voodoo")
  assert_eq(paragraph.errors[1].code, "unexpected-end-tag")
  let row_group = @html_parser.parse_fragment(
    "<table><colgroup></tbody></table>",
    collect_errors=true,
  )
  assert_eq(
    row_group.to_html(pretty=false),
    "<table><colgroup></colgroup></table>",
  )
  assert_eq(row_group.errors.length(), 1)
  assert_eq(row_group.errors[0].code, "unexpected-end-tag")
  let table = @html_parser.parse_fragment(
    "<table><colgroup></table>",
    collect_errors=true,
  )
  assert_eq(table.to_html(pretty=false), "<table><colgroup></colgroup></table>")
  assert_eq(table.errors.length(), 0)
  let col = @html_parser.parse_fragment(
    "<table><colgroup></col></colgroup></table>",
    collect_errors=true,
  )
  assert_eq(col.to_html(pretty=false), "<table><colgroup></colgroup></table>")
  assert_eq(col.errors.length(), 1)
  assert_eq(col.errors[0].code, "unexpected-end-tag")
}

///|
test "parser closes rows before table structure starts" {
  let next_row = @html_parser.parse_fragment(
    "<table><tr><tr><td>x</td></tr></table>",
    collect_errors=true,
  )
  assert_eq(
    next_row.to_html(pretty=false),
    "<table><tbody><tr></tr><tr><td>x</td></tr></tbody></table>",
  )
  assert_eq(next_row.errors.length(), 0)
  let row_group = @html_parser.parse_fragment(
    "<table><tbody><tr><tbody><tr><td>x</td></tr></tbody></table>",
    collect_errors=true,
  )
  assert_eq(
    row_group.to_html(pretty=false),
    "<table><tbody><tr></tr></tbody><tbody><tr><td>x</td></tr></tbody></table>",
  )
  assert_eq(row_group.errors.length(), 0)
  let caption = @html_parser.parse_fragment(
    "<table><tr><caption>x</caption></table>",
    collect_errors=true,
  )
  assert_eq(
    caption.to_html(pretty=false),
    "<table><tbody><tr></tr></tbody><caption>x</caption></table>",
  )
  assert_eq(caption.errors.length(), 0)
  let col = @html_parser.parse_fragment(
    "<table><tr><col><tr><td>x</td></tr></table>",
    collect_errors=true,
  )
  assert_eq(
    col.to_html(pretty=false),
    "<table><tbody><tr></tr></tbody><colgroup><col></colgroup><tbody><tr><td>x</td></tr></tbody></table>",
  )
  assert_eq(col.errors.length(), 0)
}

///|
test "parser closes cells before table structure starts" {
  let next_row = @html_parser.parse_fragment(
    "<table><tr><td>x<tr><td>y</td></tr></table>",
    collect_errors=true,
  )
  assert_eq(
    next_row.to_html(pretty=false),
    "<table><tbody><tr><td>x</td></tr><tr><td>y</td></tr></tbody></table>",
  )
  assert_eq(next_row.errors.length(), 0)
  let row_group = @html_parser.parse_fragment(
    "<table><tbody><tr><td>x<tbody><tr><td>y</td></tr></tbody></table>",
    collect_errors=true,
  )
  assert_eq(
    row_group.to_html(pretty=false),
    "<table><tbody><tr><td>x</td></tr></tbody><tbody><tr><td>y</td></tr></tbody></table>",
  )
  assert_eq(row_group.errors.length(), 0)
  let caption = @html_parser.parse_fragment(
    "<table><tr><td>x<caption>c</caption></table>",
    collect_errors=true,
  )
  assert_eq(
    caption.to_html(pretty=false),
    "<table><tbody><tr><td>x</td></tr></tbody><caption>c</caption></table>",
  )
  assert_eq(caption.errors.length(), 0)
  let next_cell = @html_parser.parse_fragment(
    "<table><tr><td>x<th>y</th></tr></table>",
    collect_errors=true,
  )
  assert_eq(
    next_cell.to_html(pretty=false),
    "<table><tbody><tr><td>x</td><th>y</th></tr></tbody></table>",
  )
  assert_eq(next_cell.errors.length(), 0)
}

///|
test "parser closes captions before table structure starts and ends" {
  let row = @html_parser.parse_fragment(
    "<table><caption>x<tr><td>y</td></tr></table>",
    collect_errors=true,
  )
  assert_eq(
    row.to_html(pretty=false),
    "<table><caption>x</caption><tbody><tr><td>y</td></tr></tbody></table>",
  )
  assert_eq(row.errors.length(), 1)
  assert_eq(row.errors[0].code, "unexpected-start-tag-implies-end-tag")
  let row_group = @html_parser.parse_fragment(
    "<table><caption>x<tbody><tr><td>y</td></tr></tbody></table>",
    collect_errors=true,
  )
  assert_eq(
    row_group.to_html(pretty=false),
    "<table><caption>x</caption><tbody><tr><td>y</td></tr></tbody></table>",
  )
  assert_eq(row_group.errors.length(), 1)
  assert_eq(row_group.errors[0].code, "unexpected-start-tag-implies-end-tag")
  let caption = @html_parser.parse_fragment(
    "<table><caption>x<caption>y</caption></table>",
    collect_errors=true,
  )
  assert_eq(
    caption.to_html(pretty=false),
    "<table><caption>x</caption><caption>y</caption></table>",
  )
  assert_eq(caption.errors.length(), 1)
  assert_eq(caption.errors[0].code, "unexpected-start-tag-implies-end-tag")
  let col = @html_parser.parse_fragment(
    "<table><caption>x<col></table>",
    collect_errors=true,
  )
  assert_eq(
    col.to_html(pretty=false),
    "<table><caption>x</caption><colgroup><col></colgroup></table>",
  )
  assert_eq(col.errors.length(), 1)
  assert_eq(col.errors[0].code, "unexpected-start-tag-implies-end-tag")
  let cell = @html_parser.parse_fragment(
    "<table><caption>x<td>y</td></table>",
    collect_errors=true,
  )
  assert_eq(
    cell.to_html(pretty=false),
    "<table><caption>x</caption><tbody><tr><td>y</td></tr></tbody></table>",
  )
  assert_eq(cell.errors.length(), 2)
  assert_eq(cell.errors[0].code, "unexpected-start-tag-implies-end-tag")
  assert_eq(cell.errors[1].code, "unexpected-cell-in-table-body")
  let nested_table = @html_parser.parse_fragment(
    "<table><caption>x<table><tr><td>y</td></tr></table>",
    collect_errors=true,
  )
  assert_eq(
    nested_table.to_html(pretty=false),
    "<table><caption>x</caption></table><table><tbody><tr><td>y</td></tr></tbody></table>",
  )
  assert_eq(nested_table.errors.length(), 2)
  assert_eq(nested_table.errors[0].code, "unexpected-start-tag-implies-end-tag")
  assert_eq(nested_table.errors[1].code, "unexpected-start-tag-implies-end-tag")
  let table_end = @html_parser.parse_fragment(
    "<table><caption>x</table>",
    collect_errors=true,
  )
  assert_eq(
    table_end.to_html(pretty=false),
    "<table><caption>x</caption></table>",
  )
  assert_eq(table_end.errors.length(), 0)
  let row_group_end = @html_parser.parse_fragment(
    "<table><caption>x</tbody></caption></table>",
    collect_errors=true,
  )
  assert_eq(
    row_group_end.to_html(pretty=false),
    "<table><caption>x</caption></table>",
  )
  assert_eq(row_group_end.errors.length(), 1)
  assert_eq(row_group_end.errors[0].code, "unexpected-end-tag")
}

///|
test "parser clears nested table stack before structure starts" {
  let cell_paragraph = @html_parser.parse_fragment(
    "<table><td><p>x<tr><td>y</td></tr></table>",
    collect_errors=true,
  )
  assert_eq(
    cell_paragraph.to_html(pretty=false),
    "<table><tbody><tr><td><p>x</p></td></tr><tr><td>y</td></tr></tbody></table>",
  )
  assert_eq(cell_paragraph.errors.length(), 1)
  assert_eq(cell_paragraph.errors[0].code, "unexpected-cell-in-table-body")
  let cell_div = @html_parser.parse_fragment(
    "<table><tr><td><div>x<td>y</td></tr></table>",
    collect_errors=true,
  )
  assert_eq(
    cell_div.to_html(pretty=false),
    "<table><tbody><tr><td><div>x</div></td><td>y</td></tr></tbody></table>",
  )
  assert_eq(cell_div.errors.length(), 0)
  let row_div = @html_parser.parse_fragment(
    "<table><tr><div>x<tr><td>y</td></tr></table>",
    collect_errors=true,
  )
  assert_eq(
    row_div.to_html(pretty=false),
    "<div>x</div><table><tbody><tr></tr><tr><td>y</td></tr></tbody></table>",
  )
  assert_eq(row_div.errors.length(), 1)
  assert_eq(row_div.errors[0].code, "foster-parenting-character")
  let section_div = @html_parser.parse_fragment(
    "<table><tbody><div>x<tbody><tr><td>y</td></tr></tbody></table>",
    collect_errors=true,
  )
  assert_eq(
    section_div.to_html(pretty=false),
    "<div>x</div><table><tbody></tbody><tbody><tr><td>y</td></tr></tbody></table>",
  )
  assert_eq(section_div.errors.length(), 2)
  assert_eq(section_div.errors[0].code, "foster-parenting-start-tag")
  assert_eq(section_div.errors[1].code, "foster-parenting-character")
  let caption_div = @html_parser.parse_fragment(
    "<table><caption><div>x<tr><td>y</td></tr></table>",
    collect_errors=true,
  )
  assert_eq(
    caption_div.to_html(pretty=false),
    "<table><caption><div>x</div></caption><tbody><tr><td>y</td></tr></tbody></table>",
  )
  assert_eq(caption_div.errors.length(), 1)
  assert_eq(caption_div.errors[0].code, "unexpected-start-tag-implies-end-tag")
}

///|
test "parser closes current table before nested table starts" {
  let direct = @html_parser.parse_fragment(
    "<table><table><tr><td>x</td></tr></table>",
    collect_errors=true,
  )
  assert_eq(
    direct.to_html(pretty=false),
    "<table></table><table><tbody><tr><td>x</td></tr></tbody></table>",
  )
  assert_eq(direct.errors.length(), 1)
  assert_eq(direct.errors[0].code, "unexpected-start-tag-implies-end-tag")
  let text = @html_parser.parse_fragment(
    "<table><table>text</table>",
    collect_errors=true,
  )
  assert_eq(text.to_html(pretty=false), "<table></table>text<table></table>")
  assert_eq(text.errors.length(), 5)
  assert_eq(text.errors[0].code, "unexpected-start-tag-implies-end-tag")
  for index in 1..<text.errors.length() {
    assert_eq(text.errors[index].code, "foster-parenting-character")
  }
  let section = @html_parser.parse_fragment(
    "<table><tbody><table><tr><td>x</td></tr></table>",
    collect_errors=true,
  )
  assert_eq(
    section.to_html(pretty=false),
    "<table><tbody></tbody></table><table><tbody><tr><td>x</td></tr></tbody></table>",
  )
  assert_eq(section.errors.length(), 1)
  assert_eq(section.errors[0].code, "unexpected-start-tag-implies-end-tag")
  let cell = @html_parser.parse_fragment(
    "<table><tr><td><table>x</table></td></tr></table>",
    collect_errors=true,
  )
  assert_eq(
    cell.to_html(pretty=false),
    "<table><tbody><tr><td>x<table></table></td></tr></tbody></table>",
  )
  assert_eq(cell.errors.length(), 1)
  assert_eq(cell.errors[0].code, "foster-parenting-character")
}

///|
test "parser foster parents non-whitespace table text" {
  let direct = @html_parser.parse_fragment(
    "<table>text</table>",
    collect_errors=true,
  )
  assert_eq(direct.to_html(pretty=false), "text<table></table>")
  assert_eq(direct.errors.length(), 4)
  for error in direct.errors {
    assert_eq(error.code, "foster-parenting-character")
  }
  let spaced = @html_parser.parse_fragment(
    "<table> a b </table>",
    collect_errors=true,
  )
  assert_eq(spaced.to_html(pretty=false), " a b <table></table>")
  assert_eq(spaced.errors.length(), 2)
  for error in spaced.errors {
    assert_eq(error.code, "foster-parenting-character")
  }
  let whitespace = @html_parser.parse_fragment(
    "<table> </table>",
    collect_errors=true,
  )
  assert_eq(whitespace.to_html(pretty=false), "<table> </table>")
  assert_eq(whitespace.errors.length(), 0)
  let caption = @html_parser.parse_fragment(
    "<table><caption>text</caption></table>",
    collect_errors=true,
  )
  assert_eq(
    caption.to_html(pretty=false),
    "<table><caption>text</caption></table>",
  )
  assert_eq(caption.errors.length(), 0)
  let cell = @html_parser.parse_fragment(
    "<table><tr><td>text</td></tr></table>",
    collect_errors=true,
  )
  assert_eq(
    cell.to_html(pretty=false),
    "<table><tbody><tr><td>text</td></tr></tbody></table>",
  )
  assert_eq(cell.errors.length(), 0)
  let section = @html_parser.parse_fragment(
    "<table><tbody>text</tbody></table>",
    collect_errors=true,
  )
  assert_eq(section.to_html(pretty=false), "text<table><tbody></tbody></table>")
  assert_eq(section.errors.length(), 4)
  for error in section.errors {
    assert_eq(error.code, "foster-parenting-character")
  }
  let doc = @html_parser.parse(
    "<!doctype html><div><table>text</table></div>",
    collect_errors=true,
  )
  assert_eq(
    doc.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body><div>text<table></table></div></body></html>",
  )
  assert_eq(doc.errors.length(), 4)
  for error in doc.errors {
    assert_eq(error.code, "foster-parenting-character")
  }
}

///|
test "parser foster parents table-context start tags" {
  let direct = @html_parser.parse_fragment(
    "<table><div>x</div></table>",
    collect_errors=true,
  )
  assert_eq(direct.to_html(pretty=false), "<div>x</div><table></table>")
  assert_eq(direct.errors.length(), 3)
  assert_eq(direct.errors[0].code, "foster-parenting-start-tag")
  assert_eq(direct.errors[1].code, "foster-parenting-character")
  assert_eq(direct.errors[2].code, "unexpected-end-tag-implies-table-voodoo")
  let section = @html_parser.parse_fragment(
    "<table><tbody><div>x</div></tbody></table>",
    collect_errors=true,
  )
  assert_eq(
    section.to_html(pretty=false),
    "<div>x</div><table><tbody></tbody></table>",
  )
  assert_eq(section.errors.length(), 3)
  assert_eq(section.errors[0].code, "foster-parenting-start-tag")
  assert_eq(section.errors[1].code, "foster-parenting-character")
  assert_eq(section.errors[2].code, "unexpected-end-tag-implies-table-voodoo")
  let row = @html_parser.parse_fragment(
    "<table><tr><div>x</div></tr></table>",
    collect_errors=true,
  )
  assert_eq(
    row.to_html(pretty=false),
    "<div>x</div><table><tbody><tr></tr></tbody></table>",
  )
  assert_eq(row.errors.length(), 1)
  assert_eq(row.errors[0].code, "foster-parenting-character")
  let cell = @html_parser.parse_fragment(
    "<table><tr><td><div>x</div></td></tr></table>",
    collect_errors=true,
  )
  assert_eq(
    cell.to_html(pretty=false),
    "<table><tbody><tr><td><div>x</div></td></tr></tbody></table>",
  )
  assert_eq(cell.errors.length(), 0)
  let doc = @html_parser.parse(
    "<!doctype html><div><table><p>x</p></table></div>",
    collect_errors=true,
  )
  assert_eq(
    doc.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body><div><p>x</p><table></table></div></body></html>",
  )
  assert_eq(doc.errors.length(), 3)
  assert_eq(doc.errors[0].code, "foster-parenting-start-tag")
  assert_eq(doc.errors[1].code, "foster-parenting-character")
  assert_eq(doc.errors[2].code, "unexpected-end-tag-implies-table-voodoo")
}

///|
test "parser handles hidden input and form starts in table context" {
  let hidden = @html_parser.parse_fragment(
    "<table><input type=hidden name=x value=y></table>",
    collect_errors=true,
  )
  assert_eq(
    hidden.to_html(pretty=false),
    "<table><input type=\"hidden\" name=\"x\" value=\"y\"></table>",
  )
  assert_eq(hidden.errors.length(), 1)
  assert_eq(hidden.errors[0].code, "unexpected-hidden-input-in-table")
  let uppercase_hidden = @html_parser.parse_fragment(
    "<table><input TYPE=HIDDEN></table>",
    collect_errors=true,
  )
  assert_eq(
    uppercase_hidden.to_html(pretty=false),
    "<table><input type=\"HIDDEN\"></table>",
  )
  assert_eq(uppercase_hidden.errors.length(), 1)
  assert_eq(uppercase_hidden.errors[0].code, "unexpected-hidden-input-in-table")
  let ordinary_input = @html_parser.parse_fragment(
    "<table><input name=x></table>",
    collect_errors=true,
  )
  assert_eq(
    ordinary_input.to_html(pretty=false),
    "<input name=\"x\"><table></table>",
  )
  assert_eq(ordinary_input.errors.length(), 1)
  assert_eq(ordinary_input.errors[0].code, "foster-parenting-start-tag")
  let form = @html_parser.parse_fragment(
    "<table><form id=f></form></table>",
    collect_errors=true,
  )
  assert_eq(form.to_html(pretty=false), "<table><form id=\"f\"></form></table>")
  assert_eq(form.errors.length(), 3)
  assert_eq(form.errors[0].code, "unexpected-form-in-table")
  assert_eq(form.errors[1].code, "unexpected-end-tag-implies-table-voodoo")
  assert_eq(form.errors[2].code, "unexpected-end-tag")
  let row_form = @html_parser.parse_fragment(
    "<table><tr><form id=f></form></tr></table>",
    collect_errors=true,
  )
  assert_eq(
    row_form.to_html(pretty=false),
    "<form id=\"f\"></form><table><tbody><tr></tr></tbody></table>",
  )
  assert_eq(row_form.errors.length(), 0)
  let stray_form_end = @html_parser.parse_fragment(
    "<table></form></table>",
    collect_errors=true,
  )
  assert_eq(stray_form_end.to_html(pretty=false), "<table></table>")
  assert_eq(stray_form_end.errors.length(), 2)
  assert_eq(
    stray_form_end.errors[0].code,
    "unexpected-end-tag-implies-table-voodoo",
  )
  assert_eq(stray_form_end.errors[1].code, "unexpected-end-tag")
}

///|
test "parser keeps style and script starts in table context" {
  let style = @html_parser.parse_fragment(
    "<table><style>x</style></table>",
    collect_errors=true,
  )
  assert_eq(style.to_html(pretty=false), "<table><style>x</style></table>")
  assert_eq(style.errors.length(), 0)
  let script = @html_parser.parse_fragment(
    "<table><script>x</script></table>",
    collect_errors=true,
  )
  assert_eq(script.to_html(pretty=false), "<table><script>x</script></table>")
  assert_eq(script.errors.length(), 0)
  let section = @html_parser.parse_fragment(
    "<table><tbody><style>x</style></tbody></table>",
    collect_errors=true,
  )
  assert_eq(
    section.to_html(pretty=false),
    "<table><tbody><style>x</style></tbody></table>",
  )
  assert_eq(section.errors.length(), 0)
  let row = @html_parser.parse_fragment(
    "<table><tr><style>x</style></tr></table>",
    collect_errors=true,
  )
  assert_eq(
    row.to_html(pretty=false),
    "<table><tbody><tr><style>x</style></tr></tbody></table>",
  )
  assert_eq(row.errors.length(), 0)
}

///|
test "parser reports stray table-context end tags" {
  let div = @html_parser.parse_fragment(
    "<table></div></table>",
    collect_errors=true,
  )
  assert_eq(div.to_html(pretty=false), "<table></table>")
  assert_eq(div.errors.length(), 2)
  assert_eq(div.errors[0].code, "unexpected-end-tag-implies-table-voodoo")
  assert_eq(div.errors[1].code, "unexpected-end-tag")
  let paragraph = @html_parser.parse_fragment(
    "<table></p></table>",
    collect_errors=true,
  )
  assert_eq(paragraph.to_html(pretty=false), "<p></p><table></table>")
  assert_eq(paragraph.errors.length(), 2)
  assert_eq(paragraph.errors[0].code, "unexpected-end-tag-implies-table-voodoo")
  assert_eq(paragraph.errors[1].code, "unexpected-end-tag")
  let row_group = @html_parser.parse_fragment(
    "<table></tbody></table>",
    collect_errors=true,
  )
  assert_eq(row_group.to_html(pretty=false), "<table></table>")
  assert_eq(row_group.errors.length(), 1)
  assert_eq(row_group.errors[0].code, "unexpected-end-tag")
  let body = @html_parser.parse_fragment(
    "<table></body></table>",
    collect_errors=true,
  )
  assert_eq(body.to_html(pretty=false), "<table></table>")
  assert_eq(body.errors.length(), 1)
  assert_eq(body.errors[0].code, "unexpected-end-tag")
  let proper_row_group = @html_parser.parse_fragment(
    "<table><tbody></tbody></table>",
    collect_errors=true,
  )
  assert_eq(
    proper_row_group.to_html(pretty=false),
    "<table><tbody></tbody></table>",
  )
  assert_eq(proper_row_group.errors.length(), 0)
}

///|
test "parser ignores table structure starts outside table" {
  let cell = @html_parser.parse_fragment("<td>x</td>", collect_errors=true)
  assert_eq(cell.to_html(pretty=false), "x")
  assert_eq(cell.errors.length(), 2)
  assert_eq(cell.errors[0].code, "unexpected-start-tag-ignored")
  assert_eq(cell.errors[1].code, "unexpected-end-tag")
  let row = @html_parser.parse_fragment(
    "<tr><td>x</td></tr>",
    collect_errors=true,
  )
  assert_eq(row.to_html(pretty=false), "x")
  assert_eq(row.errors.length(), 4)
  assert_eq(row.errors[0].code, "unexpected-start-tag-ignored")
  assert_eq(row.errors[1].code, "unexpected-start-tag-ignored")
  assert_eq(row.errors[2].code, "unexpected-end-tag")
  assert_eq(row.errors[3].code, "unexpected-end-tag")
  let caption = @html_parser.parse_fragment(
    "<caption>x</caption>",
    collect_errors=true,
  )
  assert_eq(caption.to_html(pretty=false), "x")
  assert_eq(caption.errors.length(), 2)
  assert_eq(caption.errors[0].code, "unexpected-start-tag")
  assert_eq(caption.errors[1].code, "unexpected-end-tag")
  let colgroup = @html_parser.parse_fragment(
    "<colgroup><col></colgroup>",
    collect_errors=true,
  )
  assert_eq(colgroup.to_html(pretty=false), "<col>")
  assert_eq(colgroup.errors.length(), 2)
  assert_eq(colgroup.errors[0].code, "unexpected-start-tag-ignored")
  assert_eq(colgroup.errors[1].code, "unexpected-end-tag")
}

///|
test "parser closes current heading before another heading start" {
  let fragment = @html_parser.parse_fragment("<p>intro<h1>head<h2>next")
  assert_eq(
    fragment.to_html(pretty=false),
    "<p>intro</p><h1>head</h1><h2>next</h2>",
  )
  let nested_block = @html_parser.parse_fragment("<h1>head<div>body</div>")
  assert_eq(nested_block.to_html(pretty=false), "<h1>head<div>body</div></h1>")
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
test "parser ignores self closing slash on non void html elements" {
  let div = @html_parser.parse_fragment("<div/>x")
  assert_eq(div.to_html(pretty=false), "<div>x</div>")
  let paragraph = @html_parser.parse_fragment("<p/>x")
  assert_eq(paragraph.to_html(pretty=false), "<p>x</p>")
  let script = @html_parser.parse_fragment("<script/>x</script>")
  assert_eq(script.to_html(pretty=false), "<script>x</script>")
  let voids = @html_parser.parse_fragment("<br/>x<img/>")
  assert_eq(voids.to_html(pretty=false), "<br>x<img>")
}

///|
test "strict mode raises on first parse error" {
  let result : Result[@html_parser.ParsedHtml, Error] = try? @html_parser.parse_fragment(
    "<p>open</span>",
    strict=true,
  )
  guard result is Err(_) else { fail("expected strict parse to raise") }
}

///|
test "parse_bytes decodes explicit utf8 and records encoding" {
  let bytes = @utf8.encode("<p>bytes</p>")
  let doc = @html_parser.parse_bytes(bytes, encoding="utf-8")
  assert_eq(
    doc.to_html(pretty=false),
    "<html><head></head><body><p>bytes</p></body></html>",
  )
  guard doc.encoding is Some("utf-8") else { fail("expected utf-8 encoding") }
}

///|
test "parse_bytes defaults to windows1252 and normalizes compatible labels" {
  let bytes = b"\x3c\x70\x3e\x80\x3c\x2f\x70\x3e"
  let doc = @html_parser.parse_bytes(bytes)
  assert_eq(
    doc.to_html(pretty=false),
    "<html><head></head><body><p>\u{20AC}</p></body></html>",
  )
  guard doc.encoding is Some("windows-1252") else {
    fail("expected default windows-1252 encoding")
  }
  let latin1 = @html_parser.parse_bytes(bytes, encoding="iso-8859-1")
  assert_eq(
    latin1.to_html(pretty=false),
    "<html><head></head><body><p>\u{20AC}</p></body></html>",
  )
  guard latin1.encoding is Some("windows-1252") else {
    fail("expected latin1 label to normalize to windows-1252")
  }
  let utf7 = @html_parser.parse_bytes(bytes, encoding="utf7")
  assert_eq(
    utf7.to_html(pretty=false),
    "<html><head></head><body><p>\u{20AC}</p></body></html>",
  )
  guard utf7.encoding is Some("windows-1252") else {
    fail("expected utf7 label to normalize to windows-1252")
  }
}

///|
test "parse_bytes decodes iso8859-2 labels" {
  let explicit = b"<p>\xa1\xb1</p>"
  let doc = @html_parser.parse_bytes(explicit, encoding="iso8859-2")
  assert_eq(doc.to_text(separator="", strip=false), "\u{0104}\u{0105}")
  guard doc.encoding is Some("iso-8859-2") else {
    fail("expected explicit iso-8859-2 encoding")
  }
  let meta = b"<meta charset=latin2><p>\xc6\xe6</p>"
  let meta_doc = @html_parser.parse_bytes(meta)
  assert_eq(meta_doc.to_text(separator="", strip=false), "\u{0106}\u{0107}")
  guard meta_doc.encoding is Some("iso-8859-2") else {
    fail("expected meta latin2 encoding")
  }
}

///|
test "parse_bytes ignores invalid transport encoding labels" {
  let bytes = b"<p>\x80</p>"
  let doc = @html_parser.parse_bytes(bytes, encoding="koi8-r")
  assert_eq(doc.to_text(separator="", strip=false), "\u{20AC}")
  guard doc.encoding is Some("windows-1252") else {
    fail("expected invalid transport label to fall back")
  }
  let meta = @utf8.encode("<meta charset=utf-8><p>\u{20AC}</p>")
  let meta_doc = @html_parser.parse_bytes(meta, encoding="bogus")
  assert_eq(meta_doc.to_text(separator="", strip=false), "\u{20AC}")
  guard meta_doc.encoding is Some("utf-8") else {
    fail("expected invalid transport label to allow meta sniff")
  }
}

///|
test "parse_bytes valid transport encoding overrides sniffing" {
  let meta = b"<meta charset=utf-8><p>\x80</p>"
  let meta_doc = @html_parser.parse_bytes(meta, encoding="windows-1252")
  assert_eq(meta_doc.to_text(separator="", strip=false), "\u{20AC}")
  guard meta_doc.encoding is Some("windows-1252") else {
    fail("expected transport encoding to override meta")
  }
  let utf16_bom = b"\xff\xfe\x3c\x00\x70\x00\x3e\x00\x80\x00\x3c\x00\x2f\x00\x70\x00\x3e\x00"
  let bom_doc = @html_parser.parse_bytes(utf16_bom, encoding="windows-1252")
  guard bom_doc.encoding is Some("windows-1252") else {
    fail("expected transport encoding to override bom")
  }
}

///|
test "parse_bytes sniffs utf8 bom before windows1252 fallback" {
  let bytes = b"\xef\xbb\xbf\x3c\x70\x3e\x62\x6f\x6d\x3c\x2f\x70\x3e"
  let doc = @html_parser.parse_bytes(bytes)
  assert_eq(
    doc.to_html(pretty=false),
    "<html><head></head><body><p>bom</p></body></html>",
  )
  guard doc.encoding is Some("utf-8") else {
    fail("expected utf-8 bom encoding")
  }
}

///|
test "parse_bytes prescans direct meta charset" {
  let utf8 = b"\x3c\x6d\x65\x74\x61\x20\x63\x68\x61\x72\x73\x65\x74\x3d\x75\x74\x66\x2d\x38\x3e\x3c\x70\x3e\xe2\x82\xac\x3c\x2f\x70\x3e"
  let doc = @html_parser.parse_bytes(utf8)
  assert_eq(doc.to_text(separator="", strip=false), "\u{20AC}")
  guard doc.encoding is Some("utf-8") else {
    fail("expected meta utf-8 encoding")
  }
  let quoted = b"\x3c\x6d\x65\x74\x61\x20\x63\x68\x61\x72\x73\x65\x74\x3d\x22\x6c\x61\x74\x69\x6e\x31\x22\x3e\x3c\x70\x3e\x80\x3c\x2f\x70\x3e"
  let quoted_doc = @html_parser.parse_bytes(quoted)
  assert_eq(quoted_doc.to_text(separator="", strip=false), "\u{20AC}")
  guard quoted_doc.encoding is Some("windows-1252") else {
    fail("expected meta latin1 to normalize to windows-1252")
  }
  let meta_utf16 = b"\x3c\x6d\x65\x74\x61\x20\x63\x68\x61\x72\x73\x65\x74\x3d\x75\x74\x66\x2d\x31\x36\x3e\x3c\x70\x3e\x6f\x6b\x3c\x2f\x70\x3e"
  let meta_utf16_doc = @html_parser.parse_bytes(meta_utf16)
  assert_eq(meta_utf16_doc.to_text(separator="", strip=false), "ok")
  guard meta_utf16_doc.encoding is Some("utf-8") else {
    fail("expected meta utf-16 declaration to become utf-8")
  }
}

///|
test "parse_bytes meta prescan skips comments and quoted non-meta tags" {
  let comment = b"\x3c\x21\x2d\x2d\x20\x3c\x6d\x65\x74\x61\x20\x63\x68\x61\x72\x73\x65\x74\x3d\x75\x74\x66\x2d\x38\x3e\x20\x2d\x2d\x3e\x3c\x70\x3e\x80\x3c\x2f\x70\x3e"
  let comment_doc = @html_parser.parse_bytes(comment)
  assert_eq(comment_doc.to_text(separator="", strip=false), "\u{20AC}")
  guard comment_doc.encoding is Some("windows-1252") else {
    fail("expected charset inside comment to be ignored")
  }
  let quoted_tag = b"\x3c\x70\x20\x74\x69\x74\x6c\x65\x3d\x22\x78\x3e\x3c\x6d\x65\x74\x61\x20\x63\x68\x61\x72\x73\x65\x74\x3d\x75\x74\x66\x2d\x38\x22\x3e\x3c\x2f\x70\x3e\x3c\x70\x3e\x80\x3c\x2f\x70\x3e"
  let quoted_tag_doc = @html_parser.parse_bytes(quoted_tag)
  assert_eq(quoted_tag_doc.to_text(separator="", strip=false), "\u{20AC}")
  guard quoted_tag_doc.encoding is Some("windows-1252") else {
    fail("expected meta-like bytes inside non-meta tag attribute to be ignored")
  }
}

///|
test "parse_bytes meta prescan ignores incomplete constructs" {
  let unfinished_comment = b"\x3c\x21\x2d\x2d\x3c\x6d\x65\x74\x61\x20\x63\x68\x61\x72\x73\x65\x74\x3d\x75\x74\x66\x2d\x38\x3e"
  let unfinished_comment_doc = @html_parser.parse_bytes(unfinished_comment)
  guard unfinished_comment_doc.encoding is Some("windows-1252") else {
    fail("expected unfinished comment to prevent meta sniff")
  }
  let end_tag = b"\x3c\x2f\x61\x20\x74\x69\x74\x6c\x65\x3d\x27\x78\x27\x3e\x3c\x70\x3e\x80\x3c\x2f\x70\x3e"
  let end_tag_doc = @html_parser.parse_bytes(end_tag)
  assert_eq(end_tag_doc.to_text(separator="", strip=false), "\u{20AC}")
  guard end_tag_doc.encoding is Some("windows-1252") else {
    fail("expected end tag to be skipped during meta sniff")
  }
  let unclosed_quote = b"\x3c\x6d\x65\x74\x61\x20\x63\x68\x61\x72\x73\x65\x74\x3d\x22\x75\x74\x66\x2d\x38\x3c\x70\x3e\x80\x3c\x2f\x70\x3e"
  let unclosed_quote_doc = @html_parser.parse_bytes(unclosed_quote)
  guard unclosed_quote_doc.encoding is Some("windows-1252") else {
    fail("expected unclosed meta attribute quote to be ignored")
  }
  let missing_value = @html_parser.parse_bytes(b"<meta charset")
  guard missing_value.encoding is Some("windows-1252") else {
    fail("expected incomplete charset attribute to fall back")
  }
  let missing_gt = @html_parser.parse_bytes(b"<meta charset=utf-8")
  guard missing_gt.encoding is Some("windows-1252") else {
    fail("expected unclosed meta tag to fall back")
  }
}

///|
test "parse_bytes prescans http equiv content charset" {
  let utf8 = @utf8.encode(
    "<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\"><p>\u{20AC}</p>",
  )
  let doc = @html_parser.parse_bytes(utf8)
  assert_eq(doc.to_text(separator="", strip=false), "\u{20AC}")
  guard doc.encoding is Some("utf-8") else {
    fail("expected http-equiv content charset utf-8")
  }
  let single_quoted = @utf8.encode(
    "<meta content=\"TEXT/HTML; CHARSET='UTF-8'\" http-equiv=\"content-type\"><p>\u{20AC}</p>",
  )
  let single_quoted_doc = @html_parser.parse_bytes(single_quoted)
  assert_eq(single_quoted_doc.to_text(separator="", strip=false), "\u{20AC}")
  guard single_quoted_doc.encoding is Some("utf-8") else {
    fail("expected quoted content charset utf-8")
  }
  let spaced_equals = @utf8.encode(
    "<meta http-equiv=\"Content-Type\" content=\"charset   =utf-8\"><p>\u{20AC}</p>",
  )
  let spaced_equals_doc = @html_parser.parse_bytes(spaced_equals)
  assert_eq(spaced_equals_doc.to_text(separator="", strip=false), "\u{20AC}")
  guard spaced_equals_doc.encoding is Some("utf-8") else {
    fail("expected content charset with spaced equals")
  }
  let spaced_value = @utf8.encode(
    "<meta http-equiv=\"Content-Type\" content=\"charset=   utf-8\"><p>\u{20AC}</p>",
  )
  let spaced_value_doc = @html_parser.parse_bytes(spaced_value)
  assert_eq(spaced_value_doc.to_text(separator="", strip=false), "\u{20AC}")
  guard spaced_value_doc.encoding is Some("utf-8") else {
    fail("expected content charset with spaced value")
  }
  let invalid_direct = @utf8.encode(
    "<meta charset=bogus http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\"><p>\u{20AC}</p>",
  )
  let invalid_direct_doc = @html_parser.parse_bytes(invalid_direct)
  assert_eq(invalid_direct_doc.to_text(separator="", strip=false), "\u{20AC}")
  guard invalid_direct_doc.encoding is Some("utf-8") else {
    fail("expected http-equiv charset after invalid direct charset")
  }
  let invalid = b"<meta http-equiv=\"Content-Type\" content=\"text/html; charset=bogus\"><p>\x80</p>"
  let invalid_doc = @html_parser.parse_bytes(invalid)
  assert_eq(invalid_doc.to_text(separator="", strip=false), "\u{20AC}")
  guard invalid_doc.encoding is Some("windows-1252") else {
    fail("expected invalid http-equiv charset to fall back")
  }
  let missing_equals = b"<meta http-equiv=\"Content-Type\" content=\"charset   utf-8\"><p>\x80</p>"
  let missing_equals_doc = @html_parser.parse_bytes(missing_equals)
  assert_eq(missing_equals_doc.to_text(separator="", strip=false), "\u{20AC}")
  guard missing_equals_doc.encoding is Some("windows-1252") else {
    fail("expected malformed content charset to fall back")
  }
  let unterminated = b"<meta http-equiv=\"Content-Type\" content=\"text/html; charset='utf-8\"><p>\x80</p>"
  let unterminated_doc = @html_parser.parse_bytes(unterminated)
  assert_eq(unterminated_doc.to_text(separator="", strip=false), "\u{20AC}")
  guard unterminated_doc.encoding is Some("windows-1252") else {
    fail("expected unterminated content charset quote to fall back")
  }
}

///|
test "parse_bytes decodes utf16 bom and explicit encodings" {
  let little = b"\xff\xfe\x3c\x00\x70\x00\x3e\x00\x68\x00\x69\x00\x3c\x00\x2f\x00\x70\x00\x3e\x00"
  let little_doc = @html_parser.parse_bytes(little)
  assert_eq(
    little_doc.to_html(pretty=false),
    "<html><head></head><body><p>hi</p></body></html>",
  )
  guard little_doc.encoding is Some("utf-16le") else {
    fail("expected utf-16le encoding")
  }
  let big = b"\xfe\xff\x00\x3c\x00\x70\x00\x3e\x00\x68\x00\x69\x00\x3c\x00\x2f\x00\x70\x00\x3e"
  let big_doc = @html_parser.parse_bytes(big)
  assert_eq(
    big_doc.to_html(pretty=false),
    "<html><head></head><body><p>hi</p></body></html>",
  )
  guard big_doc.encoding is Some("utf-16be") else {
    fail("expected utf-16be encoding")
  }
  let explicit = @html_parser.parse_bytes(little, encoding="utf-16")
  assert_eq(
    explicit.to_html(pretty=false),
    "<html><head></head><body><p>hi</p></body></html>",
  )
  guard explicit.encoding is Some("utf-16") else {
    fail("expected explicit utf-16 encoding")
  }
  let explicit_big = b"\x00\x3c\x00\x70\x00\x3e\x00\x62\x00\x65\x00\x3c\x00\x2f\x00\x70\x00\x3e"
  let explicit_big_doc = @html_parser.parse_bytes(
    explicit_big,
    encoding="UTF16BE",
  )
  assert_eq(
    explicit_big_doc.to_html(pretty=false),
    "<html><head></head><body><p>be</p></body></html>",
  )
  guard explicit_big_doc.encoding is Some("utf-16be") else {
    fail("expected explicit utf-16be encoding")
  }
}

///|
test "tokenize exposes stable token data structures" {
  let result = @html_parser.tokenize("<p class='x'>Hi<br><!--ok--></p>")
  assert_eq(result.tokens.length(), 6)
  guard result.tokens[0] is @html_parser.HtmlToken::Tag(start) else {
    fail("expected start tag")
  }
  assert_true(start.kind is @html_parser.TagKind::StartTag)
  assert_eq(start.name, "p")
  guard start.attrs["class"] is Some("x") else { fail("expected class attr") }
  guard result.tokens[1] is @html_parser.HtmlToken::Characters("Hi") else {
    fail("expected text token")
  }
  guard result.tokens[2] is @html_parser.HtmlToken::Tag(br) else {
    fail("expected br tag")
  }
  assert_eq(br.self_closing, false)
  guard result.tokens[3] is @html_parser.HtmlToken::CommentToken("ok") else {
    fail("expected comment token")
  }
  guard result.tokens[5] is @html_parser.HtmlToken::Eof else {
    fail("expected EOF")
  }
  let explicit = @html_parser.tokenize("<img/>")
  guard explicit.tokens[0] is @html_parser.HtmlToken::Tag(img) else {
    fail("expected img tag")
  }
  assert_eq(img.self_closing, true)
}

///|
test "entity decoding covers upstream fixture cases" {
  let numeric = @html_parser.parse_fragment("&#65")
  assert_eq(numeric.to_text(separator="", strip=false), "A")
  let control = @html_parser.parse_fragment("&#x80")
  assert_eq(control.to_text(separator="", strip=false), "\u{20AC}")
  let legacy = @html_parser.parse_fragment("&notit; &not &amp")
  assert_eq(legacy.to_text(separator="", strip=false), "¬it; ¬ &")
}

///|
test "tokenize preserves raw end tags before tree recovery" {
  let result = @html_parser.tokenize("<p>open</span>")
  assert_eq(result.tokens.length(), 4)
  guard result.tokens[0] is @html_parser.HtmlToken::Tag(start) else {
    fail("expected p start tag")
  }
  assert_true(start.kind is @html_parser.TagKind::StartTag)
  assert_eq(start.name, "p")
  guard result.tokens[2] is @html_parser.HtmlToken::Tag(end_tag) else {
    fail("expected raw span end tag")
  }
  assert_true(end_tag.kind is @html_parser.TagKind::EndTag)
  assert_eq(end_tag.name, "span")
}

///|
test "tokenize preserves end tag attributes and self closing solidus" {
  let self_closing = @html_parser.tokenize("</div/>", collect_errors=true)
  guard self_closing.tokens[0] is @html_parser.HtmlToken::Tag(tag) else {
    fail("expected end tag")
  }
  assert_true(tag.kind is @html_parser.TagKind::EndTag)
  assert_eq(tag.name, "div")
  assert_eq(tag.self_closing, true)
  assert_eq(self_closing.errors.length(), 0)
  let attrs = @html_parser.tokenize("</div attr=x>", collect_errors=true)
  guard attrs.tokens[0] is @html_parser.HtmlToken::Tag(attr_tag) else {
    fail("expected attributed end tag")
  }
  assert_true(attr_tag.kind is @html_parser.TagKind::EndTag)
  assert_eq(attr_tag.name, "div")
  guard attr_tag.attrs["attr"] is Some("x") else {
    fail("expected end tag attr")
  }
  assert_eq(attr_tag.self_closing, false)
  assert_eq(attrs.errors.length(), 0)
}

///|
test "parser matches end tags before self closing solidus" {
  let div = @html_parser.parse_fragment("<div>x</div/>y", collect_errors=true)
  assert_eq(div.to_html(pretty=false), "<div>x</div>y")
  assert_eq(div.errors.length(), 0)
  let script = @html_parser.tokenize("<script>x</script/>after")
  guard script.tokens[1] is @html_parser.HtmlToken::Characters("x") else {
    fail("expected script text before slash end tag")
  }
  guard script.tokens[2] is @html_parser.HtmlToken::Tag(end_script) else {
    fail("expected script end tag before slash")
  }
  assert_true(end_script.kind is @html_parser.TagKind::EndTag)
  assert_eq(end_script.name, "script")
  assert_eq(end_script.self_closing, true)
  guard script.tokens[3] is @html_parser.HtmlToken::Characters("after") else {
    fail("expected text after slash end tag")
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
  guard invalid.tokens[0] is @html_parser.HtmlToken::CommentToken(" ") else {
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
  guard processing.tokens[0] is @html_parser.HtmlToken::CommentToken("?foo") else {
    fail("expected bogus comment")
  }
  let invalid_end = @html_parser.tokenize("</?", collect_errors=true)
  guard invalid_end.tokens[0] is @html_parser.HtmlToken::CommentToken("?") else {
    fail("expected invalid end tag as bogus comment")
  }
  assert_eq(invalid_end.errors.length(), 1)
  assert_eq(invalid_end.errors[0].code, "invalid-first-character-of-tag-name")
  let question = @html_parser.tokenize("<?foo>", collect_errors=true)
  guard question.tokens[0] is @html_parser.HtmlToken::CommentToken("?foo") else {
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
  let declaration = @html_parser.tokenize("<!foo>", collect_errors=true)
  guard declaration.tokens[0] is @html_parser.HtmlToken::CommentToken("foo") else {
    fail("expected malformed declaration as bogus comment")
  }
  assert_eq(declaration.errors.length(), 1)
  assert_eq(declaration.errors[0].code, "incorrectly-opened-comment")
  guard declaration.errors[0].column is Some(2) else {
    fail("expected malformed declaration error at bang")
  }
  let cdata = @html_parser.tokenize("<![CDATA[x]]>", collect_errors=true)
  guard cdata.tokens[0] is @html_parser.HtmlToken::CommentToken("[CDATA[x]]") else {
    fail("expected HTML CDATA as bogus comment")
  }
  assert_eq(cdata.errors.length(), 1)
  assert_eq(cdata.errors[0].code, "cdata-in-html-content")
  guard cdata.errors[0].column is Some(9) else {
    fail("expected cdata error at opening bracket")
  }
  let invalid_open = @html_parser.tokenize("<*foo>", collect_errors=true)
  assert_eq(invalid_open.tokens.length(), 2)
  guard invalid_open.tokens[0] is @html_parser.HtmlToken::Characters("<*foo>") else {
    fail("expected invalid tag-open sequence as text")
  }
  guard invalid_open.tokens[1] is @html_parser.HtmlToken::Eof else {
    fail("expected EOF after invalid tag-open text")
  }
  assert_eq(invalid_open.errors.length(), 1)
  assert_eq(invalid_open.errors[0].code, "invalid-first-character-of-tag-name")
  guard invalid_open.errors[0].column is Some(2) else {
    fail("expected invalid tag-open error at second character")
  }
}

///|
test "tokenize replaces nulls in bogus comment data" {
  let question = @html_parser.tokenize("<?a\u{0000}b>", collect_errors=true)
  guard question.tokens[0]
    is @html_parser.HtmlToken::CommentToken("?a\u{FFFD}b") else {
    fail("expected replacement char in question-mark bogus comment")
  }
  assert_eq(question.errors.length(), 1)
  assert_eq(
    question.errors[0].code,
    "unexpected-question-mark-instead-of-tag-name",
  )
  let declaration = @html_parser.tokenize("<!a\u{0000}b>", collect_errors=true)
  guard declaration.tokens[0]
    is @html_parser.HtmlToken::CommentToken("a\u{FFFD}b") else {
    fail("expected replacement char in malformed declaration")
  }
  assert_eq(declaration.errors.length(), 1)
  assert_eq(declaration.errors[0].code, "incorrectly-opened-comment")
  let cdata = @html_parser.tokenize(
    "<![CDATA[a\u{0000}b]]>",
    collect_errors=true,
  )
  guard cdata.tokens[0]
    is @html_parser.HtmlToken::CommentToken("[CDATA[a\u{FFFD}b]]") else {
    fail("expected replacement char in HTML CDATA bogus comment")
  }
  assert_eq(cdata.errors.length(), 1)
  assert_eq(cdata.errors[0].code, "cdata-in-html-content")
}

///|
test "parser replaces nulls in bogus comment data" {
  let question = @html_parser.parse_fragment(
    "<?a\u{0000}b>",
    collect_errors=true,
  )
  assert_eq(question.to_html(pretty=false), "<!--?a\u{FFFD}b-->")
  assert_eq(question.errors.length(), 1)
  assert_eq(
    question.errors[0].code,
    "unexpected-question-mark-instead-of-tag-name",
  )
  let declaration = @html_parser.parse_fragment(
    "<!a\u{0000}b>",
    collect_errors=true,
  )
  assert_eq(declaration.to_html(pretty=false), "<!--a\u{FFFD}b-->")
  assert_eq(declaration.errors.length(), 1)
  assert_eq(declaration.errors[0].code, "incorrectly-opened-comment")
}

///|
test "tokenize reports abrupt closing of empty comments" {
  let simple = @html_parser.tokenize("<!-->", collect_errors=true)
  guard simple.tokens[0] is @html_parser.HtmlToken::CommentToken("") else {
    fail("expected empty comment")
  }
  assert_eq(simple.errors.length(), 1)
  assert_eq(simple.errors[0].code, "abrupt-closing-of-empty-comment")
  guard simple.errors[0].column is Some(5) else {
    fail("expected abrupt empty comment at >")
  }
  let dash = @html_parser.tokenize("<!--->", collect_errors=true)
  guard dash.tokens[0] is @html_parser.HtmlToken::CommentToken("") else {
    fail("expected empty dash comment")
  }
  assert_eq(dash.errors.length(), 1)
  assert_eq(dash.errors[0].code, "abrupt-closing-of-empty-comment")
  guard dash.errors[0].column is Some(6) else {
    fail("expected abrupt empty dash comment at >")
  }
}

///|
test "parser reports abrupt closing of empty comments" {
  let simple = @html_parser.parse_fragment("<!-->", collect_errors=true)
  assert_eq(simple.to_html(pretty=false), "<!---->")
  assert_eq(simple.errors.length(), 1)
  assert_eq(simple.errors[0].code, "abrupt-closing-of-empty-comment")
  guard simple.errors[0].column is Some(5) else {
    fail("expected abrupt empty comment at >")
  }
  let dash = @html_parser.parse_fragment("<!--->", collect_errors=true)
  assert_eq(dash.to_html(pretty=false), "<!---->")
  assert_eq(dash.errors.length(), 1)
  assert_eq(dash.errors[0].code, "abrupt-closing-of-empty-comment")
  guard dash.errors[0].column is Some(6) else {
    fail("expected abrupt empty dash comment at >")
  }
}

///|
test "tokenize reports incorrectly closed comments" {
  let bang = @html_parser.tokenize("<!--x--!>", collect_errors=true)
  guard bang.tokens[0] is @html_parser.HtmlToken::CommentToken("x") else {
    fail("expected bang-closed comment")
  }
  assert_eq(bang.errors.length(), 1)
  assert_eq(bang.errors[0].code, "incorrectly-closed-comment")
  guard bang.errors[0].column is Some(9) else {
    fail("expected bang close error at >")
  }
  let text = @html_parser.tokenize("<!--x--y-->", collect_errors=true)
  guard text.tokens[0] is @html_parser.HtmlToken::CommentToken("x--y") else {
    fail("expected recovered comment data")
  }
  assert_eq(text.errors.length(), 1)
  assert_eq(text.errors[0].code, "incorrectly-closed-comment")
  guard text.errors[0].column is Some(8) else {
    fail("expected comment close error at reconsumed text")
  }
}

///|
test "parser reports incorrectly closed comments" {
  let bang = @html_parser.parse_fragment("<!--x--!>", collect_errors=true)
  assert_eq(bang.to_html(pretty=false), "<!--x-->")
  assert_eq(bang.errors.length(), 1)
  assert_eq(bang.errors[0].code, "incorrectly-closed-comment")
  guard bang.errors[0].column is Some(9) else {
    fail("expected bang close error at >")
  }
  let text = @html_parser.parse_fragment("<!--x--y-->", collect_errors=true)
  assert_eq(text.to_html(pretty=false), "<!--x- -y-->")
  assert_eq(text.errors.length(), 1)
  assert_eq(text.errors[0].code, "incorrectly-closed-comment")
  guard text.errors[0].column is Some(8) else {
    fail("expected comment close error at reconsumed text")
  }
}

///|
test "tokenize reports selected EOF and null fixture errors" {
  let lt = @html_parser.tokenize("<", collect_errors=true)
  guard lt.tokens[0] is @html_parser.HtmlToken::Characters("<") else {
    fail("expected literal <")
  }
  assert_eq(lt.errors[0].code, "eof-before-tag-name")
  guard lt.errors[0].column is Some(1) else {
    fail("expected bare < EOF at the < character")
  }
  let end_open = @html_parser.tokenize("</", collect_errors=true)
  guard end_open.tokens[0] is @html_parser.HtmlToken::Characters("</") else {
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
  guard unfinished_start.tokens[0] is @html_parser.HtmlToken::Eof else {
    fail("expected only EOF token for incomplete quoted tag")
  }
  assert_eq(unfinished_start.errors.length(), 1)
  assert_eq(unfinished_start.errors[0].code, "eof-in-tag")
  guard unfinished_start.errors[0].column is Some(10) else {
    fail("expected incomplete quoted tag EOF at final quote")
  }
  let unfinished_unquoted = @html_parser.tokenize(
    "<div foo=bar",
    collect_errors=true,
  )
  assert_eq(unfinished_unquoted.tokens.length(), 1)
  guard unfinished_unquoted.tokens[0] is @html_parser.HtmlToken::Eof else {
    fail("expected only EOF token for incomplete unquoted tag")
  }
  assert_eq(unfinished_unquoted.errors.length(), 1)
  assert_eq(unfinished_unquoted.errors[0].code, "eof-in-tag")
  guard unfinished_unquoted.errors[0].column is Some(12) else {
    fail("expected incomplete unquoted tag EOF at final value character")
  }
  let unfinished_end = @html_parser.tokenize("</span", collect_errors=true)
  assert_eq(unfinished_end.tokens.length(), 1)
  guard unfinished_end.tokens[0] is @html_parser.HtmlToken::Eof else {
    fail("expected only EOF token for incomplete end tag")
  }
  assert_eq(unfinished_end.errors.length(), 1)
  assert_eq(unfinished_end.errors[0].code, "eof-in-tag")
  guard unfinished_end.errors[0].column is Some(6) else {
    fail("expected incomplete end tag EOF at final name character")
  }
  let unfinished_comment = @html_parser.tokenize("<!--x", collect_errors=true)
  assert_eq(unfinished_comment.tokens.length(), 2)
  guard unfinished_comment.tokens[0]
    is @html_parser.HtmlToken::CommentToken("x") else {
    fail("expected comment token before EOF")
  }
  guard unfinished_comment.tokens[1] is @html_parser.HtmlToken::Eof else {
    fail("expected EOF after unfinished comment token")
  }
  assert_eq(unfinished_comment.errors.length(), 1)
  assert_eq(unfinished_comment.errors[0].code, "eof-in-comment")
  guard unfinished_comment.errors[0].column is Some(5) else {
    fail("expected unfinished comment EOF at final character")
  }
  let nul_text = @html_parser.tokenize("a\u{0000}b", collect_errors=true)
  guard nul_text.tokens[0] is @html_parser.HtmlToken::Characters("a\u{0000}b") else {
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
  guard nul_attr.tokens[0] is @html_parser.HtmlToken::Tag(tag) else {
    fail("expected div tag")
  }
  guard tag.attrs["foo"] is Some("a\u{FFFD}b") else {
    fail("expected replacement char in attr")
  }
  assert_eq(nul_attr.errors[0].code, "unexpected-null-character")
  let nul_attr_name = @html_parser.tokenize(
    "<div a\u{0000}b='c'>",
    collect_errors=true,
  )
  guard nul_attr_name.tokens[0] is @html_parser.HtmlToken::Tag(attr_name_tag) else {
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
  guard nul_tag_name.tokens[0] is @html_parser.HtmlToken::Tag(start) else {
    fail("expected script start tag")
  }
  assert_eq(start.name, "script\u{FFFD}")
  guard nul_tag_name.tokens[1] is @html_parser.HtmlToken::Characters("x") else {
    fail("expected text after null-mutated script tag")
  }
  guard nul_tag_name.tokens[2] is @html_parser.HtmlToken::Tag(end_tag) else {
    fail("expected script end tag")
  }
  assert_true(end_tag.kind is @html_parser.TagKind::EndTag)
  assert_eq(end_tag.name, "script")
  assert_eq(nul_tag_name.errors.length(), 1)
  assert_eq(nul_tag_name.errors[0].code, "unexpected-null-character")
  guard nul_tag_name.errors[0].column is Some(8) else {
    fail("expected null tag name at column 8")
  }
}

///|
test "tokenize reports missing attribute value fixture errors" {
  let bare = @html_parser.tokenize("<div attr>", collect_errors=true)
  guard bare.tokens[0] is @html_parser.HtmlToken::Tag(bare_tag) else {
    fail("expected div tag")
  }
  guard bare_tag.attrs["attr"] is Some("") else {
    fail("expected empty attr without error")
  }
  assert_eq(bare.errors.length(), 0)
  let simple = @html_parser.tokenize("<div attr=>", collect_errors=true)
  guard simple.tokens[0] is @html_parser.HtmlToken::Tag(tag) else {
    fail("expected div tag")
  }
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
test "parser reports missing attribute value after equals only" {
  let bare = @html_parser.parse_fragment("<div attr>", collect_errors=true)
  assert_eq(bare.to_html(pretty=false), "<div attr></div>")
  assert_eq(bare.errors.length(), 1)
  assert_eq(bare.errors[0].code, "expected-closing-tag-but-got-eof")
  let missing = @html_parser.parse_fragment("<div attr=>", collect_errors=true)
  assert_eq(missing.to_html(pretty=false), "<div attr></div>")
  assert_eq(missing.errors.length(), 2)
  assert_eq(missing.errors[0].code, "missing-attribute-value")
  assert_eq(missing.errors[1].code, "expected-closing-tag-but-got-eof")
  guard missing.errors[0].column is Some(11) else {
    fail("expected missing value at column 11")
  }
}

///|
test "tokenize reports unquoted attribute value fixture errors" {
  let less = @html_parser.tokenize("<div a=b<c>", collect_errors=true)
  guard less.tokens[0] is @html_parser.HtmlToken::Tag(tag) else {
    fail("expected div tag")
  }
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
  guard backtick.tokens[0] is @html_parser.HtmlToken::Tag(backtick_tag) else {
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
  guard result.tokens[0] is @html_parser.HtmlToken::Tag(tag) else {
    fail("expected div tag")
  }
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
  guard equals.tokens[0] is @html_parser.HtmlToken::Tag(eq_tag) else {
    fail("expected div tag")
  }
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
  guard invalid_char.tokens[0] is @html_parser.HtmlToken::Tag(bad_tag) else {
    fail("expected div tag")
  }
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
  guard quote.tokens[0] is @html_parser.HtmlToken::Tag(quote_tag) else {
    fail("expected div tag")
  }
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
test "parser and tokenizer keep first duplicate attribute value" {
  let doc = @html_parser.parse_fragment(
    "<p id=first id=second class=a class=b>text</p>",
    collect_errors=true,
  )
  assert_eq(doc.to_html(pretty=false), "<p id=\"first\" class=\"a\">text</p>")
  assert_eq(doc.errors.length(), 2)
  assert_eq(doc.errors[0].code, "duplicate-attribute")
  assert_eq(doc.errors[1].code, "duplicate-attribute")
  let tokens = @html_parser.tokenize("<div a=1 a=2 a=3>", collect_errors=true)
  guard tokens.tokens[0] is @html_parser.HtmlToken::Tag(tag) else {
    fail("expected div tag")
  }
  guard tag.attrs["a"] is Some("1") else {
    fail("expected first duplicate value")
  }
  assert_eq(tokens.errors.length(), 2)
  assert_eq(tokens.errors[0].code, "duplicate-attribute")
  assert_eq(tokens.errors[1].code, "duplicate-attribute")
}

///|
test "parser reports attribute name fixture errors" {
  let equals = @html_parser.parse_fragment("<div =abc>", collect_errors=true)
  guard equals.query_one("div") is Some(eq_node) else { fail("expected div") }
  assert_true(eq_node.attrs().contains("=abc"))
  assert_eq(equals.errors.length(), 2)
  assert_eq(
    equals.errors[0].code,
    "unexpected-equals-sign-before-attribute-name",
  )
  assert_eq(equals.errors[1].code, "expected-closing-tag-but-got-eof")
  guard equals.errors[0].column is Some(6) else {
    fail("expected equals attr error at column 6")
  }
  let bad_char = @html_parser.parse_fragment("<div a\"b>", collect_errors=true)
  guard bad_char.query_one("div") is Some(bad_node) else {
    fail("expected div")
  }
  assert_true(bad_node.attrs().contains("a\"b"))
  assert_eq(bad_char.errors.length(), 2)
  assert_eq(bad_char.errors[0].code, "unexpected-character-in-attribute-name")
  assert_eq(bad_char.errors[1].code, "expected-closing-tag-but-got-eof")
  guard bad_char.errors[0].column is Some(7) else {
    fail("expected quote attr error at column 7")
  }
}

///|
test "parser reports unquoted attribute value fixture errors" {
  let less = @html_parser.parse_fragment("<div a=b<c>", collect_errors=true)
  assert_eq(less.to_html(pretty=false), "<div a=\"b&lt;c\"></div>")
  assert_eq(less.errors.length(), 2)
  assert_eq(
    less.errors[0].code,
    "unexpected-character-in-unquoted-attribute-value",
  )
  assert_eq(less.errors[1].code, "expected-closing-tag-but-got-eof")
  guard less.errors[0].column is Some(9) else {
    fail("expected unquoted attr value error at column 9")
  }
}

///|
test "parser reports missing whitespace after quoted attribute value" {
  let result = @html_parser.parse_fragment(
    "<div a=\"b\"c=d>",
    collect_errors=true,
  )
  assert_eq(result.to_html(pretty=false), "<div a=\"b\" c=\"d\"></div>")
  assert_eq(result.errors.length(), 2)
  assert_eq(result.errors[0].code, "missing-whitespace-between-attributes")
  assert_eq(result.errors[1].code, "expected-closing-tag-but-got-eof")
  guard result.errors[0].column is Some(11) else {
    fail("expected missing whitespace at adjacent attr name")
  }
}

///|
test "tokenize recovers invalid self closing start tag fixture case" {
  let result = @html_parser.tokenize("<div /a>", collect_errors=true)
  guard result.tokens[0] is @html_parser.HtmlToken::Tag(tag) else {
    fail("expected div tag")
  }
  assert_eq(tag.name, "div")
  assert_eq(tag.self_closing, false)
  guard tag.attrs["a"] is Some("") else { fail("expected recovered a attr") }
  assert_eq(result.errors.length(), 1)
  assert_eq(result.errors[0].code, "unexpected-character-after-solidus-in-tag")
  guard result.errors[0].column is Some(7) else {
    fail("expected invalid self closing char at column 7")
  }
  let fragment = @html_parser.parse_fragment("<div /a>", collect_errors=true)
  assert_eq(fragment.to_html(pretty=false), "<div a></div>")
  assert_eq(fragment.errors.length(), 2)
  assert_eq(
    fragment.errors[0].code,
    "unexpected-character-after-solidus-in-tag",
  )
  assert_eq(fragment.errors[1].code, "expected-closing-tag-but-got-eof")
}

///|
test "start tag solidus does not skip following whitespace" {
  let tokenized = @html_parser.tokenize("<div/ >", collect_errors=true)
  guard tokenized.tokens[0] is @html_parser.HtmlToken::Tag(tag) else {
    fail("expected div tag")
  }
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
  guard img.tokens[0] is @html_parser.HtmlToken::Tag(img_tag) else {
    fail("expected img tag")
  }
  assert_eq(img_tag.self_closing, true)
  assert_eq(img.errors.length(), 0)
  let fragment = @html_parser.parse_fragment("<div/ >", collect_errors=true)
  assert_eq(fragment.to_html(pretty=false), "<div></div>")
  assert_eq(fragment.errors.length(), 2)
  assert_eq(
    fragment.errors[0].code,
    "unexpected-character-after-solidus-in-tag",
  )
  assert_eq(fragment.errors[1].code, "expected-closing-tag-but-got-eof")
  guard fragment.errors[0].column is Some(6) else {
    fail("expected parser whitespace after solidus at column 6")
  }
}

///|
test "tokenize normalizes BOM and CRLF edge cases" {
  let bom = @html_parser.tokenize("\u{FEFF}<div>")
  guard bom.tokens[0] is @html_parser.HtmlToken::Tag(tag) else {
    fail("expected div start tag")
  }
  assert_eq(tag.name, "div")
  let text = @html_parser.tokenize("abc\r\ndef\rghi")
  guard text.tokens[0] is @html_parser.HtmlToken::Characters(data) else {
    fail("expected character token")
  }
  assert_eq(data, "abc\ndef\nghi")
  let comment = @html_parser.tokenize("<!-- a\rb -->")
  guard comment.tokens[0] is @html_parser.HtmlToken::CommentToken(data) else {
    fail("expected comment")
  }
  assert_eq(data, " a\nb ")
  let attr = @html_parser.tokenize("<div title=\"a\rb\">")
  guard attr.tokens[0] is @html_parser.HtmlToken::Tag(attr_tag) else {
    fail("expected attr tag")
  }
  guard attr_tag.attrs["title"] is Some("a\nb") else {
    fail("expected normalized attr")
  }
}

///|
test "parser normalizes leading BOM and CRLF in text comment and attr" {
  let doc = @html_parser.parse_fragment(
    "\u{FEFF}<p title='a\rb'>a\r\nb<!--x\ry--></p>",
  )
  assert_eq(doc.to_html(pretty=false), "<p title=\"a\nb\">a\nb<!--x\ny--></p>")
  assert_eq(doc.to_text(separator="", strip=false), "a\nb")
}

///|
test "parser handles null characters in text attributes and text modes" {
  let text = @html_parser.parse_fragment("a\u{0000}b", collect_errors=true)
  assert_eq(text.to_html(pretty=false), "ab")
  assert_eq(text.to_text(separator="", strip=false), "ab")
  assert_eq(text.errors.length(), 1)
  assert_eq(text.errors[0].code, "unexpected-null-character")
  guard text.errors[0].column is Some(2) else {
    fail("expected text null at column 2")
  }
  let attr = @html_parser.parse_fragment(
    "<div title=\"a\u{0000}b\">x</div>",
    collect_errors=true,
  )
  assert_eq(attr.to_html(pretty=false), "<div title=\"a�b\">x</div>")
  assert_eq(attr.errors.length(), 1)
  assert_eq(attr.errors[0].code, "unexpected-null-character")
  let raw = @html_parser.parse_fragment(
    "<script>a\u{0000}b</script><title>a\u{0000}b</title>",
    collect_errors=true,
  )
  assert_eq(
    raw.to_html(pretty=false),
    "<script>a�b</script><title>a�b</title>",
  )
  assert_eq(raw.errors.length(), 2)
  assert_eq(raw.errors[0].code, "unexpected-null-character")
  assert_eq(raw.errors[1].code, "unexpected-null-character")
  let textarea = @html_parser.parse_fragment(
    "<textarea>\n\u{0000}b</textarea>",
    collect_errors=true,
  )
  assert_eq(textarea.to_html(pretty=false), "<textarea>�b</textarea>")
  assert_eq(textarea.errors[0].code, "unexpected-null-character")
}

///|
test "parser treats script style title textarea content as text" {
  let doc = @html_parser.parse_fragment(
    "<script><!--a--<b</script><title>a &lt; b</title>",
  )
  assert_eq(
    doc.to_html(pretty=false),
    "<script><!--a--<<b</script><title>a &lt; b</title>",
  )
  assert_eq(doc.query("b").length(), 0)
  assert_eq(doc.to_text(separator="|", strip=false), "<!--a--<<b|a < b")
  let escaped_end = @html_parser.parse_fragment("<script><!--a--</script>")
  assert_eq(escaped_end.to_html(pretty=false), "<script><!--a--<</script>")
  let comment_end = @html_parser.parse_fragment("<script><!--a--></script>")
  assert_eq(comment_end.to_html(pretty=false), "<script><!--a--></script>")
  let raw_after_comment = @html_parser.parse_fragment(
    "<script><!--a-->x--</script>",
  )
  assert_eq(
    raw_after_comment.to_html(pretty=false),
    "<script><!--a-->x--</script>",
  )
  let double_escaped = @html_parser.parse_fragment(
    "<script><!--<script>x</script>y</script>",
  )
  assert_eq(
    double_escaped.to_text(separator="|", strip=false),
    "<!--<script>x</script>y",
  )
}

///|
test "parser treats xmp and plaintext content as text" {
  let xmp = @html_parser.parse_fragment("<xmp><b>x</b></xmp>after")
  assert_eq(xmp.to_html(pretty=false), "<xmp>&lt;b&gt;x&lt;/b&gt;</xmp>after")
  assert_eq(xmp.query("b").length(), 0)
  let plaintext = @html_parser.parse_fragment(
    "<plaintext><b>x</b></plaintext>after",
    collect_errors=true,
  )
  assert_eq(
    plaintext.to_html(pretty=false),
    "<plaintext>&lt;b&gt;x&lt;/b&gt;&lt;/plaintext&gt;after</plaintext>",
  )
  assert_eq(plaintext.errors[0].code, "expected-closing-tag-but-got-eof")
}

///|
test "parser reports special text EOF like tree builder" {
  let script = @html_parser.parse_fragment("<script>x", collect_errors=true)
  assert_eq(script.to_html(pretty=false), "<script>x</script>")
  assert_eq(script.errors.length(), 1)
  assert_eq(script.errors[0].code, "expected-named-closing-tag-but-got-eof")
  guard script.errors[0].column is Some(9) else {
    fail("expected script EOF at final text column")
  }
  let textarea = @html_parser.parse_fragment(
    "<textarea>\nx",
    collect_errors=true,
  )
  assert_eq(textarea.to_html(pretty=false), "<textarea>x</textarea>")
  assert_eq(textarea.errors.length(), 1)
  assert_eq(textarea.errors[0].code, "expected-closing-tag-but-got-eof")
  guard textarea.errors[0].line is Some(2) else {
    fail("expected textarea EOF on second line")
  }
  guard textarea.errors[0].column is Some(1) else {
    fail("expected textarea EOF at final text column")
  }
  let xmp = @html_parser.parse_fragment("<xmp>x", collect_errors=true)
  assert_eq(xmp.errors[0].code, "expected-named-closing-tag-but-got-eof")
  let iframe = @html_parser.parse_fragment("<iframe>x", collect_errors=true)
  assert_eq(iframe.errors[0].code, "expected-closing-tag-but-got-eof")
}

///|
test "parser treats legacy raw text elements as text" {
  let doc = @html_parser.parse_fragment(
    "<iframe><b>x</b></iframe><noembed><i>y</i></noembed><noscript><em>z</em></noscript>",
  )
  assert_eq(
    doc.to_html(pretty=false),
    "<iframe>&lt;b&gt;x&lt;/b&gt;</iframe><noembed>&lt;i&gt;y&lt;/i&gt;</noembed><noscript>&lt;em&gt;z&lt;/em&gt;</noscript>",
  )
  assert_eq(doc.query("b").length(), 0)
  assert_eq(doc.query("i").length(), 0)
  assert_eq(doc.query("em").length(), 0)
}

///|
test "parser honors scripting enabled for noscript text mode" {
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

///|
test "parser ignores one initial newline in pre listing and textarea" {
  let pre = @html_parser.parse_fragment(
    "<pre>\r\nline</pre><listing>\nitem</listing>",
  )
  assert_eq(pre.to_html(pretty=false), "<pre>line</pre><listing>item</listing>")
  let textarea = @html_parser.parse_fragment("<textarea>\nline</textarea>")
  assert_eq(textarea.to_html(pretty=false), "<textarea>line</textarea>")
  let title = @html_parser.parse_fragment("<title>\nline</title>")
  assert_eq(title.to_html(pretty=false), "<title>\nline</title>")
}

///|
test "tokenize preserves rawtext and rcdata element contents" {
  let script = @html_parser.tokenize("<script><!--a--<b</script>")
  assert_eq(script.tokens.length(), 4)
  guard script.tokens[1] is @html_parser.HtmlToken::Characters("<!--a--<<b") else {
    fail("expected raw script text")
  }
  guard script.tokens[2] is @html_parser.HtmlToken::Tag(end_script) else {
    fail("expected script end")
  }
  assert_true(end_script.kind is @html_parser.TagKind::EndTag)
  assert_eq(end_script.name, "script")
  let escaped_end = @html_parser.tokenize("<script><!--a--</script>")
  guard escaped_end.tokens[1] is @html_parser.HtmlToken::Characters("<!--a--<") else {
    fail("expected escaped script end-tag boundary text")
  }
  let escaped_eof = @html_parser.tokenize("<script><!--a--<")
  guard escaped_eof.tokens[1] is @html_parser.HtmlToken::Characters("<!--a--<<") else {
    fail("expected escaped EOF less-than text")
  }
  let comment_end = @html_parser.tokenize("<script><!--a--></script>")
  guard comment_end.tokens[1] is @html_parser.HtmlToken::Characters("<!--a-->") else {
    fail("expected script comment close to return to raw text")
  }
  let nul_script = @html_parser.tokenize(
    "<script>a\u{0000}b</script>",
    collect_errors=true,
  )
  guard nul_script.tokens[1] is @html_parser.HtmlToken::Characters("a\u{FFFD}b") else {
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
  guard nul_style.tokens[1] is @html_parser.HtmlToken::Characters("a\u{FFFD}b") else {
    fail("expected replacement char in style text")
  }
  assert_eq(nul_style.errors.length(), 1)
  assert_eq(nul_style.errors[0].code, "unexpected-null-character")
  let nul_title = @html_parser.tokenize(
    "<title>a\u{0000} &lt; b</title>",
    collect_errors=true,
  )
  guard nul_title.tokens[1]
    is @html_parser.HtmlToken::Characters("a\u{FFFD} < b") else {
    fail("expected replacement char and entity decoding in title text")
  }
  assert_eq(nul_title.errors.length(), 1)
  assert_eq(nul_title.errors[0].code, "unexpected-null-character")
  let nul_plaintext = @html_parser.tokenize(
    "<plaintext>a\u{0000}b",
    collect_errors=true,
  )
  guard nul_plaintext.tokens[1]
    is @html_parser.HtmlToken::Characters("a\u{FFFD}b") else {
    fail("expected replacement char in plaintext")
  }
  assert_eq(nul_plaintext.errors.length(), 1)
  assert_eq(nul_plaintext.errors[0].code, "unexpected-null-character")
  let double_escaped = @html_parser.tokenize(
    "<script><!--<script>x</script>y</script>",
  )
  guard double_escaped.tokens[1]
    is @html_parser.HtmlToken::Characters("<!--<script>x</script>y") else {
    fail("expected inner script end tag to stay in double-escaped text")
  }
  guard double_escaped.tokens[2] is @html_parser.HtmlToken::Tag(double_end) else {
    fail("expected final script end")
  }
  assert_eq(double_end.name, "script")
  let not_double_escaped = @html_parser.tokenize(
    "<script><!--<scripty>x</script>-->z</script>",
  )
  guard not_double_escaped.tokens[1]
    is @html_parser.HtmlToken::Characters("<!--<scripty>x") else {
    fail("expected non-script word to avoid double-escaped state")
  }
  guard not_double_escaped.tokens[3]
    is @html_parser.HtmlToken::Characters("-->z") else {
    fail("expected text after the first script end tag")
  }
  let textarea = @html_parser.tokenize("<textarea>a &lt; b</textarea>")
  guard textarea.tokens[1] is @html_parser.HtmlToken::Characters("a < b") else {
    fail("expected decoded textarea text")
  }
  let textarea_lf = @html_parser.tokenize("<textarea>\nline</textarea>")
  guard textarea_lf.tokens[1] is @html_parser.HtmlToken::Characters("\nline") else {
    fail("expected tokenizer to preserve textarea leading newline")
  }
  let xmp = @html_parser.tokenize("<xmp><b>x</b></xmp>")
  guard xmp.tokens[1] is @html_parser.HtmlToken::Characters("<b>x</b>") else {
    fail("expected xmp raw text")
  }
  let plaintext = @html_parser.tokenize("<plaintext><b>x</b></plaintext>")
  guard plaintext.tokens[1]
    is @html_parser.HtmlToken::Characters("<b>x</b></plaintext>") else {
    fail("expected plaintext through EOF")
  }
  let iframe = @html_parser.tokenize("<iframe><b>x</b></iframe>")
  guard iframe.tokens[1] is @html_parser.HtmlToken::Characters("<b>x</b>") else {
    fail("expected iframe raw text")
  }
}

///|
test "tokenize does not report special text EOF tree errors" {
  let script = @html_parser.tokenize("<script>x", collect_errors=true)
  guard script.tokens[1] is @html_parser.HtmlToken::Characters("x") else {
    fail("expected unclosed script text")
  }
  assert_eq(script.errors.length(), 0)
  let plaintext = @html_parser.tokenize("<plaintext>x", collect_errors=true)
  guard plaintext.tokens[1] is @html_parser.HtmlToken::Characters("x") else {
    fail("expected unclosed plaintext text")
  }
  assert_eq(plaintext.errors.length(), 0)
  let title = @html_parser.tokenize("<title>x", collect_errors=true)
  guard title.tokens[1] is @html_parser.HtmlToken::Characters("x") else {
    fail("expected unclosed title text")
  }
  assert_eq(title.errors.length(), 0)
}
