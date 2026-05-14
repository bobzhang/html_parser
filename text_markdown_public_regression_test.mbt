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
