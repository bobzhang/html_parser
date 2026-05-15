///|
test "public pretty printer keeps block inline and raw layout stable" {
  let doc = @html_parser.parse_fragment(
    "<main><article><h2>Title</h2><p>A <em>B</em> C</p><ul><li>One</li><li><a href=/two>Two</a></li></ul><pre>x\n  y</pre><!--tail--></article></main>",
    sanitize=false,
  )
  assert_eq(
    doc.to_html(pretty=false),
    "<main><article><h2>Title</h2><p>A <em>B</em> C</p><ul><li>One</li><li><a href=\"/two\">Two</a></li></ul><pre>x\n  y</pre><!--tail--></article></main>",
  )
  assert_eq(
    doc.to_html(pretty=true, indent_size=2),
    "<main>\n  <article><h2>Title</h2><p>A <em>B</em> C</p><ul><li>One</li><li><a href=\"/two\">Two</a></li></ul><pre>x\n  y</pre><!--tail--></article>\n</main>",
  )
}

///|
test "pretty serializer collapses ordinary text-only elements" {
  let heading = @html_parser.parse_fragment(
    "<h3>\n\nSorry to interrupt, but we're short on time to hit our goal.\n</h3>",
  )
  guard heading.query_one("h3") is Some(h3) else { fail("expected h3") }
  assert_eq(
    h3.to_html(pretty=true),
    "<h3>Sorry to interrupt, but we're short on time to hit our goal.</h3>",
  )
  let div = @html_parser.element(
    "div",
    attrs={ "class": Some("overlay-banner-main-footer-cta") },
    children=[
      @html_parser.text(
        "\n\nWe ask you, sincerely: don't skip this, join the 2% of readers who give.\n",
      ),
    ],
  )
  assert_eq(
    div.to_html(pretty=true),
    "<div class=\"overlay-banner-main-footer-cta\">We ask you, sincerely: don't skip this, join the 2% of readers who give.</div>",
  )
  let vertical_tab = @html_parser.element("div", children=[
    @html_parser.text("  a  \u{000B}  b  "),
  ])
  assert_eq(vertical_tab.to_html(pretty=true), "<div>a \u{000B} b</div>")
  let empty = @html_parser.element("h3", children=[@html_parser.text("")])
  assert_eq(empty.to_html(pretty=true), "<h3></h3>")
}

///|
test "pretty serializer preserves raw and preformatted text-only elements" {
  let script = @html_parser.parse_fragment(
    "<script>\n  var x = 1;\n\n  var y = 2;\n</script>",
  )
  guard script.query_one("script") is Some(script_node) else {
    fail("expected script")
  }
  assert_eq(
    script_node.to_html(pretty=true),
    "<script>\n  var x = 1;\n\n  var y = 2;\n</script>",
  )
  let pre = @html_parser.element("pre", children=[
    @html_parser.text("\n  keep  spacing\n"),
  ])
  assert_eq(pre.to_html(pretty=true), "<pre>\n  keep  spacing\n</pre>")
  let textarea = @html_parser.element("textarea", children=[
    @html_parser.text("<x>\n"),
  ])
  assert_eq(textarea.to_html(pretty=true), "<textarea>&lt;x&gt;\n</textarea>")
  let mixed_script = @html_parser.element("script", children=[
    @html_parser.text("a\nb"),
    @html_parser.element("span"),
  ])
  assert_eq(
    mixed_script.to_html(pretty=true),
    "<script>a\nb<span></span></script>",
  )
  let mixed_style = @html_parser.element("style", children=[
    @html_parser.text("a {\n  b: c; }"),
    @html_parser.element("span"),
  ])
  assert_eq(
    mixed_style.to_html(pretty=true),
    "<style>a {\n  b: c; }<span></span></style>",
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
test "pretty serializer keeps inline mixed content compact" {
  let mixed = @html_parser.parse_fragment("<div>Text <span>Span</span></div>")
  guard mixed.query_one("div") is Some(div) else { fail("expected div") }
  assert_eq(div.to_html(pretty=true), "<div>Text <span>Span</span></div>")
  let newlines = @html_parser.parse_fragment(
    "<span>100+\n <span class='jsl10n'>articles</span></span>",
  )
  guard newlines.query_one("span") is Some(outer) else {
    fail("expected outer span")
  }
  assert_eq(
    outer.to_html(pretty=true),
    "<span>100+ <span class=\"jsl10n\">articles</span></span>",
  )
  let spaces = @html_parser.parse_fragment("<p>Hello  <b>world</b></p>")
  guard spaces.query_one("p") is Some(paragraph) else {
    fail("expected paragraph")
  }
  assert_eq(paragraph.to_html(pretty=true), "<p>Hello  <b>world</b></p>")
  let code = @html_parser.parse_fragment(
    "<code><span class='methodname'>BApplication</span>(<span class='methodparam'><span class='modifier'>const </span><span class='type'>char* </span><span class='parameter'>signature</span></span>);</code>",
  )
  guard code.query_one("code") is Some(code_node) else { fail("expected code") }
  assert_eq(
    code_node.to_html(pretty=true),
    "<code><span class=\"methodname\">BApplication</span>(<span class=\"methodparam\"><span class=\"modifier\">const </span><span class=\"type\">char* </span><span class=\"parameter\">signature</span></span>);</code>",
  )
  assert_eq(code_node.to_html(pretty=true).contains("</span>(<span"), true)
}

///|
test "pretty serializer keeps block descendants multiline" {
  let block_child = @html_parser.element("div", children=[
    @html_parser.text("Main menu  Navigation  "),
    @html_parser.element("ul", children=[
      @html_parser.element("li", children=[@html_parser.text("Item")]),
    ]),
  ])
  assert_eq(
    block_child.to_html(pretty=true),
    "<div>\n  Main menu  Navigation\n  <ul>\n    <li>Item</li>\n  </ul>\n</div>",
  )
  let formatted_text_before_block = @html_parser.element("div", children=[
    @html_parser.text("Main menu  \n Navigation  "),
    @html_parser.element("ul", children=[
      @html_parser.element("li", children=[@html_parser.text("Item")]),
    ]),
  ])
  assert_eq(
    formatted_text_before_block.to_html(pretty=true),
    "<div>\n  Main menu Navigation\n  <ul>\n    <li>Item</li>\n  </ul>\n</div>",
  )
  let only_inline_elements = @html_parser.element("div", children=[
    @html_parser.element("span"),
    @html_parser.element("em"),
  ])
  assert_eq(
    only_inline_elements.to_html(pretty=true),
    "<div>\n  <span></span>\n  <em></em>\n</div>",
  )
  let inline_wrapper = @html_parser.element("p", children=[
    @html_parser.text("Link "),
    @html_parser.element("a", children=[
      @html_parser.element("summary", children=[@html_parser.text("S")]),
    ]),
  ])
  assert_eq(
    inline_wrapper.to_html(pretty=true),
    "<p>\n  Link\n  <a>\n    <summary>S</summary>\n  </a>\n</p>",
  )
}

///|
test "pretty serializer compacts inline whitespace separators" {
  let inline = @html_parser.element("span", children=[
    @html_parser.element("span"),
    @html_parser.text("\n  \t"),
    @html_parser.element("span"),
  ])
  assert_eq(
    inline.to_html(pretty=true),
    "<span><span></span> <span></span></span>",
  )
  let large_gap = @html_parser.element("span", children=[
    @html_parser.element("span"),
    @html_parser.text("     "),
    @html_parser.element("span"),
  ])
  assert_eq(
    large_gap.to_html(pretty=true),
    "<span><span></span> <span></span></span>",
  )
  let edge_gap = @html_parser.element("span", children=[
    @html_parser.text(" \n"),
    @html_parser.element("a"),
    @html_parser.text("\t"),
  ])
  assert_eq(edge_gap.to_html(pretty=true), "<span><a></a></span>")
  let block = @html_parser.element("div", children=[
    @html_parser.element("span"),
    @html_parser.text("  "),
    @html_parser.element("span"),
  ])
  assert_eq(
    block.to_html(pretty=true),
    "<div>\n  <span></span>\n  <span></span>\n</div>",
  )
}

///|
test "pretty serializer splits formatted inline runs in block containers" {
  let small_spacing = @html_parser.element("div", children=[
    @html_parser.element("span"),
    @html_parser.text("\n  "),
    @html_parser.text("Hello"),
    @html_parser.text(" "),
    @html_parser.element("em"),
    @html_parser.text(" world"),
    @html_parser.text("\n"),
    @html_parser.element("a"),
  ])
  assert_eq(
    small_spacing.to_html(pretty=true),
    "<div>\n  <span></span>\n  Hello <em></em> world\n  <a></a>\n</div>",
  )
  let edge_spacing = @html_parser.element("div", children=[
    @html_parser.text("\n"),
    @html_parser.element("span"),
    @html_parser.text("\n"),
    @html_parser.element("a"),
    @html_parser.text(" "),
    @html_parser.text("Tail"),
    @html_parser.text("\n"),
  ])
  assert_eq(
    edge_spacing.to_html(pretty=true),
    "<div>\n  <span></span>\n  <a></a> Tail\n</div>",
  )
  let empty_run = @html_parser.element("div", children=[
    @html_parser.text(""),
    @html_parser.text("\n"),
    @html_parser.element("span"),
    @html_parser.text("Tail"),
  ])
  assert_eq(
    empty_run.to_html(pretty=true),
    "<div>\n  <span></span>Tail\n</div>",
  )
  let consecutive_separators = @html_parser.element("div", children=[
    @html_parser.element("span"),
    @html_parser.text("\n"),
    @html_parser.text("\n  \t"),
    @html_parser.element("a"),
    @html_parser.text(" Tail"),
  ])
  assert_eq(
    consecutive_separators.to_html(pretty=true),
    "<div>\n  <span></span>\n  <a></a> Tail\n</div>",
  )
}

///|
test "pretty serializer keeps comment child runs compact" {
  let commented = @html_parser.element("div", children=[
    @html_parser.element("span"),
    @html_parser.text(" "),
    @html_parser.comment("x"),
    @html_parser.text(" "),
    @html_parser.element("span"),
  ])
  assert_eq(
    commented.to_html(pretty=true),
    "<div><span></span> <!--x--> <span></span></div>",
  )
  let edge_whitespace = @html_parser.element("div", children=[
    @html_parser.text(" \n"),
    @html_parser.element("a"),
    @html_parser.comment("x"),
    @html_parser.text(" \t\n"),
  ])
  assert_eq(edge_whitespace.to_html(pretty=true), "<div><a></a><!--x--></div>")
  let block_child = @html_parser.element("div", children=[
    @html_parser.comment("x"),
    @html_parser.element("p"),
  ])
  assert_eq(block_child.to_html(pretty=true), "<div><!--x--><p></p></div>")
}

///|
test "pretty serializer filters whitespace-only fragments" {
  assert_eq(@html_parser.text("\n\t").to_html(pretty=true), "")
  let whitespace = @html_parser.fragment(children=[@html_parser.text("   ")])
  assert_eq(whitespace.to_html(pretty=true), "")
  let visible = @html_parser.fragment(children=[@html_parser.text("  hi  ")])
  assert_eq(visible.to_html(pretty=true), "hi")
  let nested_visible = @html_parser.element("div", children=[
    @html_parser.fragment(children=[@html_parser.text("  hi  ")]),
  ])
  assert_eq(nested_visible.to_html(pretty=true), "<div>\n  hi\n</div>")
  let inner_empty_lines = @html_parser.element("div", children=[
    @html_parser.fragment(children=[@html_parser.text("  ")]),
    @html_parser.text(" "),
    @html_parser.fragment(children=[@html_parser.text("\n")]),
  ])
  assert_eq(inner_empty_lines.to_html(pretty=true), "<div> </div>")
}

///|
test "public serializer contexts keep escaping stable" {
  let raw_text = @html_parser.text("\"<&>")
  assert_eq(raw_text.to_html(pretty=false), "\"&lt;&amp;&gt;")
  assert_eq(
    raw_text.to_html(pretty=false, context=HtmlAttrValue, quote='"'),
    "&quot;&amp;lt;&amp;amp;&amp;gt;",
  )
  assert_eq(
    raw_text.to_html(pretty=false, context=JsString, quote='"'),
    "\\\"&lt;&amp;&gt;",
  )
  assert_eq(
    @html_parser.text("https://ex ample.test/€?x=<y>").to_html(
      pretty=false,
      context=Url,
    ),
    "https://ex%20ample.test/%E2%82%AC?x=%3Cy%3E",
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
test "public serializer rejects unsafe programmatic output" {
  let bad_element = @html_parser.element("bad tag", children=[
    @html_parser.text("x"),
  ])
  let element_result : Result[String, @html_parser.HtmlError] = try? bad_element.to_html(
    pretty=false,
  )
  match element_result {
    Err(InvalidSerialization(message)) =>
      assert_true(message.contains("Unsafe element name"))
    _ => fail("expected unsafe element name to raise InvalidSerialization")
  }

  let bad_attr = @html_parser.element("div", attrs={
    "onload bad": Some("run()"),
  })
  let attr_result : Result[String, @html_parser.HtmlError] = try? bad_attr.to_html(
    pretty=false,
  )
  match attr_result {
    Err(InvalidSerialization(message)) =>
      assert_true(message.contains("Unsafe attribute name"))
    _ => fail("expected unsafe attribute name to raise InvalidSerialization")
  }

  let quote_result : Result[String, @html_parser.HtmlError] = try? @html_parser.text(
    "x",
  ).to_html(pretty=false, context=HtmlAttrValue, quote='`')
  match quote_result {
    Err(InvalidSerialization(message)) =>
      assert_eq(message, "quote must be ' or \"")
    _ => fail("expected invalid quote to raise InvalidSerialization")
  }
}

///|
test "public serializer doctype edge output stays stable" {
  assert_eq(@html_parser.doctype().to_html(pretty=false), "<!DOCTYPE html>")
  let svg = @html_parser.doctype(
    name="svg",
    public_id="-//W3C//DTD SVG 1.1//EN",
    system_id="https://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd",
  )
  assert_eq(
    svg.to_html(pretty=false),
    "<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.1//EN\" \"https://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd\">",
  )
  assert_eq(
    @html_parser.doctype(name="", system_id="about:legacy-compat").to_html(
      pretty=false,
    ),
    "<!DOCTYPE SYSTEM \"about:legacy-compat\">",
  )

  let bad_doctype = @html_parser.doctype(name="html><img")
  let result : Result[String, @html_parser.HtmlError] = try? bad_doctype.to_html(
    pretty=false,
  )
  match result {
    Err(InvalidSerialization(message)) =>
      assert_true(message.contains("Unsafe element name"))
    _ => fail("expected unsafe doctype name to raise InvalidSerialization")
  }
}

///|
test "builder serializes doctype identifiers" {
  assert_eq(@html_parser.doctype().to_html(pretty=false), "<!DOCTYPE html>")
  let svg = @html_parser.doctype(
    name="svg",
    public_id="-//W3C//DTD SVG 1.1//EN",
    system_id="https://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd",
  )
  assert_eq(
    svg.to_html(pretty=false),
    "<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.1//EN\" \"https://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd\">",
  )
  assert_eq(
    @html_parser.doctype(name="", system_id="about:legacy-compat").to_html(
      pretty=false,
    ),
    "<!DOCTYPE SYSTEM \"about:legacy-compat\">",
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
test "public serializer top-level helper and single quote output stay stable" {
  let node = @html_parser.element("div", attrs={ "title": Some("a>b'c") }, children=[
    @html_parser.text("x>y"),
    @html_parser.element("br"),
  ])
  assert_eq(
    node.to_html(pretty=false, quote='\''),
    "<div title='a&gt;b&#39;c'>x&gt;y<br></div>",
  )
  assert_eq(
    @html_parser.to_html(node, pretty=true, indent_size=4, quote='\''),
    "<div title='a&gt;b&#39;c'>\n    x&gt;y\n    <br>\n</div>",
  )
  assert_eq(
    node.to_html(pretty=false, context=HtmlAttrValue, quote='\''),
    "&lt;div title=&#39;a&amp;gt;b&amp;#39;c&#39;&gt;x&amp;gt;y&lt;br&gt;&lt;/div&gt;",
  )
}

///|
test "public serializer quote validation is context sensitive" {
  assert_eq(
    @html_parser.text("x").to_html(pretty=false, context=Html, quote='x'),
    "x",
  )
  let js_quote : Result[String, @html_parser.HtmlError] = try? @html_parser.text(
    "x",
  ).to_html(pretty=false, context=JsString, quote='x')
  match js_quote {
    Err(InvalidSerialization(message)) =>
      assert_eq(message, "quote must be ' or \"")
    _ => fail("expected invalid JavaScript quote to raise InvalidSerialization")
  }
}

///|
test "serializer rejects unsafe programmatic names and invalid context quotes" {
  let bad_attr = @html_parser.element("div", attrs={
    "title> <img src=x": Some("y"),
  })
  let attr_result : Result[String, @html_parser.HtmlError] = try? bad_attr.to_html(
    pretty=false,
  )
  match attr_result {
    Err(InvalidSerialization(message)) =>
      assert_true(message.contains("Unsafe attribute name"))
    _ => fail("expected unsafe attribute name to raise InvalidSerialization")
  }
  let bad_attr_start = @html_parser.element("div", attrs={ "1title": Some("y") })
  let attr_start_result : Result[String, @html_parser.HtmlError] = try? bad_attr_start.to_html(
    pretty=false,
  )
  match attr_start_result {
    Err(InvalidSerialization(message)) =>
      assert_true(message.contains("Unsafe attribute name"))
    _ =>
      fail(
        "expected leading digit attribute name to raise InvalidSerialization",
      )
  }
  let bad_element = @html_parser.element("div><img")
  let element_result : Result[String, @html_parser.HtmlError] = try? bad_element.to_html(
    pretty=false,
  )
  match element_result {
    Err(InvalidSerialization(message)) =>
      assert_true(message.contains("Unsafe element name"))
    _ => fail("expected unsafe element name to raise InvalidSerialization")
  }
  let bad_element_start = @html_parser.element("1div")
  let element_start_result : Result[String, @html_parser.HtmlError] = try? bad_element_start.to_html(
    pretty=false,
  )
  match element_start_result {
    Err(InvalidSerialization(message)) =>
      assert_true(message.contains("Unsafe element name"))
    _ =>
      fail("expected leading digit element name to raise InvalidSerialization")
  }
  let bad_doctype = @html_parser.doctype(name="html><img")
  let doctype_result : Result[String, @html_parser.HtmlError] = try? bad_doctype.to_html(
    pretty=false,
  )
  match doctype_result {
    Err(InvalidSerialization(message)) =>
      assert_true(message.contains("Unsafe element name"))
    _ => fail("expected unsafe doctype name to raise InvalidSerialization")
  }
  let bad_doctype_start = @html_parser.doctype(name="1html")
  let doctype_start_result : Result[String, @html_parser.HtmlError] = try? bad_doctype_start.to_html(
    pretty=false,
  )
  match doctype_start_result {
    Err(InvalidSerialization(message)) =>
      assert_true(message.contains("Unsafe element name"))
    _ =>
      fail("expected leading digit doctype name to raise InvalidSerialization")
  }
  let attr_quote : Result[String, @html_parser.HtmlError] = try? @html_parser.text(
    "x",
  ).to_html(pretty=false, context=HtmlAttrValue, quote='x')
  match attr_quote {
    Err(InvalidSerialization(message)) =>
      assert_eq(message, "quote must be ' or \"")
    _ => fail("expected invalid attribute quote to raise InvalidSerialization")
  }
  let js_quote : Result[String, @html_parser.HtmlError] = try? @html_parser.text(
    "x",
  ).to_html(pretty=false, context=JsString, quote='x')
  match js_quote {
    Err(InvalidSerialization(message)) =>
      assert_eq(message, "quote must be ' or \"")
    _ => fail("expected invalid JavaScript quote to raise InvalidSerialization")
  }
  assert_eq(
    @html_parser.text("x").to_html(pretty=false, context=Html, quote='x'),
    "x",
  )
}

///|
test "serializer handles pretty output quote contexts and comment guards" {
  let node = @html_parser.element("div", attrs={ "title": Some("a>b'c") }, children=[
    @html_parser.text("x>y"),
    @html_parser.element("br"),
  ])
  assert_eq(
    node.to_html(pretty=false, quote='\''),
    "<div title='a&gt;b&#39;c'>x&gt;y<br></div>",
  )
  assert_eq(
    @html_parser.to_html(node, pretty=true, indent_size=4, quote='\''),
    "<div title='a&gt;b&#39;c'>\n    x&gt;y\n    <br>\n</div>",
  )
  assert_eq(
    node.to_html(pretty=false, context=HtmlAttrValue, quote='\''),
    "&lt;div title=&#39;a&amp;gt;b&amp;#39;c&#39;&gt;x&amp;gt;y&lt;br&gt;&lt;/div&gt;",
  )
  assert_eq(
    @html_parser.text("\"<>").to_html(pretty=false, context=JsString, quote='"'),
    "\\\"&lt;&gt;",
  )
  let guarded = @html_parser.fragment(children=[
    node,
    @html_parser.comment(">x-"),
    @html_parser.comment("->x<!-"),
  ])
  assert_eq(
    guarded.to_html(pretty=true, indent_size=2, quote='\''),
    "<div title='a&gt;b&#39;c'>\n  x&gt;y\n  <br>\n</div>\n<!-- >x- -->\n<!-- ->x<!- -->",
  )
}
