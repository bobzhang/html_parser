///|
test "public text extraction modes stay stable" {
  let doc = @html_parser.parse_fragment(
    "<article><h1>Title</h1><p>Alpha <strong>Beta</strong><br> Gamma</p><p>  Delta  </p></article>",
    sanitize=false,
  )
  assert_eq(
    doc.to_text(separator="|", strip=true),
    "Title|Alpha|Beta|Gamma|Delta",
  )
  assert_eq(
    doc.to_text(separator="|", strip=true, separator_blocks_only=true),
    "Title|Alpha Beta|Gamma|Delta",
  )
  assert_eq(
    doc.to_text(separator="|", strip=false, separator_blocks_only=true),
    "Title|Alpha Beta| Gamma|  Delta  ",
  )
}

///|
test "to_text handles empty whitespace and strip options" {
  let root = @html_parser.element("div", children=[
    @html_parser.text(""),
    @html_parser.text("   "),
    @html_parser.text("A"),
  ])
  assert_eq(root.to_text(), "A")
  assert_eq(@html_parser.element("div").to_text(), "")
  let spaced = @html_parser.text("  A  ")
  assert_eq(spaced.to_text(strip=false), "  A  ")
  assert_eq(spaced.to_text(strip=true), "A")
  let whitespace_root = @html_parser.element("div", children=[
    @html_parser.text("   "),
  ])
  assert_eq(
    whitespace_root.to_text(separator="\n", separator_blocks_only=true),
    "",
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
test "public markdown document workflow stays stable" {
  let doc = @html_parser.parse_fragment(
    "<article><h1>Title</h1><p>Hello <strong>MoonBit</strong> &amp; <code>x`y</code></p><blockquote><p>Quote</p><p>More</p></blockquote><ol><li>One</li><li>Two <a href='https://example.com/a b'>link</a></li></ol></article>",
    sanitize=false,
  )
  assert_eq(
    doc.to_markdown(),
    "# Title\n\nHello **MoonBit** &amp; ``x`y``\n\n> Quote\n> \n> More\n\n1. One\n2. Two [link](<https://example.com/a%20b>)",
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
  let newline_only_pre = @html_parser.parse_fragment("<pre>\n\n</pre>")
  assert_eq(newline_only_pre.to_markdown(), "```\n\n```")
  let space_only_pre = @html_parser.parse_fragment("<pre>   \n</pre>")
  assert_eq(space_only_pre.to_markdown(), "```\n\n```")
  let trailing_space = @html_parser.parse_fragment("<pre>X   \n</pre>")
  assert_eq(trailing_space.to_markdown(), "```\nX\n```")
  let longer_fence = @html_parser.parse_fragment(
    "<pre>&#96;&#96;&#96;\n&lt;img src=x onerror=alert(1)&gt;</pre>",
  )
  assert_eq(
    longer_fence.to_markdown(),
    "````\n```\n<img src=x onerror=alert(1)>\n````",
  )
  let longest_fence = @html_parser.parse_fragment(
    "<pre>&#96;&#96;&#96;&#96;\n&lt;img src=x onerror=alert(1)&gt;</pre>",
  )
  assert_eq(
    longest_fence.to_markdown(),
    "`````\n````\n<img src=x onerror=alert(1)>\n`````",
  )
  let quote = @html_parser.parse_fragment(
    "<blockquote><p>Q<br>R</p></blockquote>",
  )
  assert_eq(quote.to_markdown(), "> Q\n> R")
  let list = @html_parser.parse_fragment(
    "<ul>\n<li>One</li>\n</ul><ol><li>A</li><li>B</li></ol>",
  )
  assert_eq(list.to_markdown(), "- One\n\n1. A\n2. B")
  let simple_list = @html_parser.parse_fragment(
    "<ul><li>One</li><li>Two</li></ul>",
  )
  assert_eq(simple_list.to_markdown(), "- One\n- Two")
}

///|
test "to_markdown renders empty blocks headings and horizontal rules" {
  let empty_blocks = @html_parser.parse_fragment(
    "<hr><h2></h2><p></p><pre></pre><blockquote></blockquote>",
  )
  assert_eq(empty_blocks.to_markdown(), "---\n\n##\n\n```\n```")
  let deep_heading = @html_parser.parse_fragment("<h4>Deep</h4>")
  assert_eq(deep_heading.to_markdown(), "#### Deep")
  let deeper_headings = @html_parser.fragment(children=[
    @html_parser.element("h5", children=[@html_parser.text("Small")]),
    @html_parser.element("h6", children=[@html_parser.text("Tiny")]),
  ])
  assert_eq(deeper_headings.to_markdown(), "##### Small\n\n###### Tiny")
  let head = @html_parser.fragment(children=[
    @html_parser.element("h3", children=[@html_parser.text("Sub")]),
    @html_parser.element("head", children=[@html_parser.text("X")]),
    @html_parser.element("p", children=[@html_parser.text("body")]),
  ])
  assert_eq(head.to_markdown(), "### Sub\n\nbody")
  let empty_quote = @html_parser.parse_fragment("<blockquote></blockquote><hr>")
  assert_eq(empty_quote.to_markdown(), "---")
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
  let skips_non_items = @html_parser.parse_fragment(
    "<ul><div>skip</div><li>One</li><span>skip</span></ul>",
  )
  assert_eq(skips_non_items.to_markdown(), "- One")
}

///|
test "to_markdown treats orphan list items as block content" {
  let orphan = @html_parser.parse_fragment("<li>One</li><li>Two</li>")
  assert_eq(orphan.to_markdown(), "One\n\nTwo")
  let menu = @html_parser.parse_fragment(
    "<menu><li>One</li><li>Two</li></menu>",
  )
  assert_eq(menu.to_markdown(), "One\n\nTwo")
  let link = @html_parser.parse_fragment(
    "<a href='https://e.com'><li>One</li><li>Two</li></a>",
  )
  assert_eq(link.to_markdown(), "[One Two](https://e.com)")
  let link_menu = @html_parser.parse_fragment(
    "<a href='https://e.com'><menu><li>One</li><li>Two</li></menu></a>",
  )
  assert_eq(link_menu.to_markdown(), "[One Two](https://e.com)")
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
    "<p>a<br># heading<br>&gt; quote<br>- item<br>+ next<br>1. ordered<br>2) ordered<br>12. multi<br>~~~<br>```<br>---<br>===</p>",
  )
  assert_eq(
    markers.to_markdown(),
    "a\n\\# heading\n\\> quote\n\\- item\n\\+ next\n1\\. ordered\n2\\) ordered\n12\\. multi\n\\~~~\n\\`\\`\\`\n\\---\n\\===",
  )
  let digit_prefixes = @html_parser.parse_fragment(
    "<p>a<br>3x plain<br>4.no space<br>5)no space<br>6. ordered<br>7) ordered</p>",
  )
  assert_eq(
    digit_prefixes.to_markdown(),
    "a\n3x plain\n4.no space\n5)no space\n6\\. ordered\n7\\) ordered",
  )
  let non_markers = @html_parser.parse_fragment(
    "<p>a<br>#heading<br>-x<br>+item<br>~~<br>=x<br>plain text</p>",
  )
  assert_eq(
    non_markers.to_markdown(),
    "a\n#heading\n-x\n+item\n~~\n=x\nplain text",
  )
  let thematic_spacing = @html_parser.parse_fragment(
    "<p>a<br>- - -<br>=<br>= =<br>=x</p>",
  )
  assert_eq(thematic_spacing.to_markdown(), "a\n\\- - -\n\\=\n\\= =\n=x")
}

///|
test "to_markdown handles direct nodes comments doctypes and empty inline nodes" {
  assert_eq(@html_parser.text("a*b").to_markdown(), "a\\*b")
  assert_eq(@html_parser.text("a < b & c").to_markdown(), "a &lt; b &amp; c")
  assert_eq(@html_parser.text("").to_markdown(), "")
  let empty_breaks = @html_parser.parse_fragment("<br><br><br>")
  assert_eq(empty_breaks.to_markdown(), "")
  let unknown_inline = @html_parser.parse_fragment("<span>Hi</span>")
  assert_eq(unknown_inline.to_markdown(), "Hi")
  let document_text = @html_parser.document(children=[@html_parser.text("Hi")])
  assert_eq(document_text.to_markdown(), "Hi")
  let document_empty = @html_parser.document(children=[
    @html_parser.element("p"),
  ])
  assert_eq(document_empty.to_markdown(), "")
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
test "to_markdown covers builder whitespace and raw newline branches" {
  assert_eq(@html_parser.text("   a").to_markdown(), "a")
  let pre = @html_parser.element("pre", children=[@html_parser.text("a\nb")])
  assert_eq(pre.to_markdown(), "```\na\nb\n```")
  let pending_raw = @html_parser.element("p", children=[
    @html_parser.text("a "),
    @html_parser.element("strong", children=[@html_parser.text("b")]),
  ])
  assert_eq(pending_raw.to_markdown(), "a **b**")
  let raw_newline = @html_parser.element("div", children=[
    @html_parser.text("a "),
    @html_parser.element("style", children=[
      @html_parser.text("\nbody { color: red; }"),
    ]),
  ])
  assert_eq(
    raw_newline.to_markdown(html_passthrough=true),
    "a\n\n<style>\nbody { color: red; }</style>",
  )
}

///|
test "to_markdown preserves table image HTML and title text parity" {
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
  let parsed_head = @html_parser.parse_fragment("<head><title>T</title></head>")
  assert_eq(parsed_head.to_markdown(), "T")
  let direct_title = @html_parser.element("title", children=[
    @html_parser.text("T"),
  ])
  assert_eq(direct_title.to_markdown(), "")
  let direct_head = @html_parser.element("head", children=[
    @html_parser.element("title", children=[@html_parser.text("T")]),
  ])
  assert_eq(direct_head.to_markdown(), "")
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
  let empty_href = @html_parser.parse_fragment("<p><a href=''>text</a></p>")
  assert_eq(empty_href.to_markdown(), "[text]")
  let whitespace_href = @html_parser.parse_fragment(
    "<p><a href='   '>text</a></p>",
  )
  assert_eq(whitespace_href.to_markdown(), "[text]()")
  let encoded = @html_parser.element(
    "a",
    attrs={ "href": Some("https://e.com/a <b>\"q\"\\x") },
    children=[@html_parser.text("x")],
  )
  assert_eq(
    encoded.to_markdown(),
    "[x](<https://e.com/a%20%3Cb%3E%22q%22%5Cx>)",
  )
  let control_destinations = @html_parser.element("p", children=[
    @html_parser.element("a", attrs={ "href": Some("https://e.com/a\tb") }, children=[
      @html_parser.text("tab"),
    ]),
    @html_parser.text(" "),
    @html_parser.element("a", attrs={ "href": Some("https://e.com/a\nb") }, children=[
      @html_parser.text("lf"),
    ]),
    @html_parser.text(" "),
    @html_parser.element("a", attrs={ "href": Some("https://e.com/a\rb") }, children=[
      @html_parser.text("cr"),
    ]),
    @html_parser.text(" "),
    @html_parser.element(
      "a",
      attrs={ "href": Some("https://e.com/a\u{000C}b") },
      children=[@html_parser.text("ff")],
    ),
    @html_parser.text(" "),
    @html_parser.element(
      "a",
      attrs={ "href": Some("https://e.com/a\u{000B}b") },
      children=[@html_parser.text("vt")],
    ),
  ])
  assert_eq(
    control_destinations.to_markdown(),
    "[tab](<https://e.com/a%09b>) [lf](<https://e.com/a%0Ab>) [cr](<https://e.com/a%0Db>) [ff](https://e.com/a\u{000C}b) [vt](https://e.com/a\u{000B}b)",
  )
  let script = @html_parser.element("div", children=[
    @html_parser.element("script", attrs={ "data-x": Some("1&2") }),
  ])
  assert_eq(script.to_markdown(), "")
  assert_eq(
    script.to_markdown(html_passthrough=true),
    "<script data-x=\"1&amp;2\"></script>",
  )
  let script_content = @html_parser.element("div", children=[
    @html_parser.element("script", children=[
      @html_parser.text("var x = 1;\nvar y = 2;\n"),
    ]),
  ])
  assert_eq(script_content.to_markdown(), "")
  assert_eq(
    script_content.to_markdown(html_passthrough=true),
    "<script>var x = 1;\nvar y = 2;\n</script>",
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
  let parsed_title = @html_parser.parse_fragment(
    "<a href='https://e.com'><title>T</title></a>",
  )
  assert_eq(parsed_title.to_markdown(), "[T](https://e.com)")
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
test "to_markdown keeps inline and raw variants inside links" {
  let formatted = @html_parser.element(
    "a",
    attrs={ "href": Some("https://e.com") },
    children=[
      @html_parser.element("strong", children=[@html_parser.text("B")]),
      @html_parser.text(" "),
      @html_parser.element("em", children=[@html_parser.text("I")]),
      @html_parser.text(" "),
      @html_parser.element("img", attrs={ "src": Some("x"), "alt": Some("y") }),
      @html_parser.text(" "),
      @html_parser.element("section", children=[@html_parser.text("S")]),
      @html_parser.text(" "),
      @html_parser.element("foo", children=[@html_parser.text("F")]),
      @html_parser.comment("skip"),
    ],
  )
  assert_eq(
    formatted.to_markdown(),
    "[**B** *I* <img src=\"x\" alt=\"y\"> S F](https://e.com)",
  )
  let template = @html_parser.element("template", children=[
    @html_parser.text("T"),
  ])
  assert_eq(template.to_markdown(), "T")
  let passthrough = @html_parser.element(
    "a",
    attrs={ "href": Some("https://e.com") },
    children=[
      @html_parser.element("script", children=[@html_parser.text("alert(1);")]),
      @html_parser.text("x"),
      @html_parser.element("style", children=[@html_parser.text("body{}")]),
      @html_parser.element("textarea", children=[@html_parser.text("T")]),
    ],
  )
  assert_eq(passthrough.to_markdown(), "[x](https://e.com)")
  assert_eq(
    passthrough.to_markdown(html_passthrough=true),
    "[<script>alert(1);</script>x<style>body{}</style><textarea>T</textarea>](https://e.com)",
  )
  let style = @html_parser.element("style", children=[
    @html_parser.text("a {\n  b: c; }"),
  ])
  assert_eq(
    style.to_markdown(html_passthrough=true),
    "<style>a {\n  b: c; }</style>",
  )
  let fragment_child = @html_parser.element(
    "a",
    attrs={ "href": Some("https://e.com") },
    children=[
      @html_parser.fragment(children=[
        @html_parser.text("Hi"),
        @html_parser.element("strong", children=[@html_parser.text("B")]),
      ]),
    ],
  )
  assert_eq(fragment_child.to_markdown(), "[Hi**B**](https://e.com)")
  let document_child = @html_parser.element(
    "a",
    attrs={ "href": Some("https://e.com") },
    children=[@html_parser.document(children=[@html_parser.text("Doc")])],
  )
  assert_eq(document_child.to_markdown(), "[Doc](https://e.com)")
}

///|
test "to_markdown dispatches mixed-case builder tag names like Python" {
  let root = @html_parser.element("DIV", children=[
    @html_parser.element("P", children=[@html_parser.text("One")]),
    @html_parser.element("DIV", children=[@html_parser.text("Two")]),
    @html_parser.element("A", attrs={ "href": Some("https://e.com/a b") }, children=[
      @html_parser.element("STRONG", children=[@html_parser.text("B")]),
      @html_parser.text(" "),
      @html_parser.element("EM", children=[@html_parser.text("I")]),
    ]),
    @html_parser.element("UL", children=[
      @html_parser.element("LI", children=[@html_parser.text("Item")]),
    ]),
    @html_parser.element("BLOCKQUOTE", children=[
      @html_parser.element("P", children=[@html_parser.text("Q")]),
    ]),
    @html_parser.element("PRE", children=[@html_parser.text("code")]),
    @html_parser.element("HR"),
    @html_parser.element("SPAN", children=[@html_parser.text("Tail")]),
  ])
  assert_eq(
    root.to_markdown(),
    "One\n\nTwo\n\n[**B** *I*](<https://e.com/a%20b>)\n\n- Item\n\n> Q\n\n```\ncode\n```\n\n---\n\nTail",
  )
}

///|
test "public markdown passthrough mode stays stable" {
  let doc = @html_parser.parse_fragment(
    "<p>Before</p><table><tr><td>A</td></tr></table><script data-x='1&2'>if (a < b) alert(1)</script><p>After</p>",
    sanitize=false,
  )
  assert_eq(
    doc.to_markdown(),
    "Before\n\n<table><tbody><tr><td>A</td></tr></tbody></table>\n\nAfter",
  )
  assert_eq(
    doc.to_markdown(html_passthrough=true),
    "Before\n\n<table><tbody><tr><td>A</td></tr></tbody></table>\n\n<script data-x=\"1&amp;2\">if (a < b) alert(1)</script>\n\nAfter",
  )
}
