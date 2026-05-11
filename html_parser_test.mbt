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
fn test_attr_id(node : @html_parser.Node) -> String {
  match node.attrs().get("id") {
    Some(Some(value)) => value
    _ => ""
  }
}

///|
fn assert_node_origin(
  node : @html_parser.Node,
  offset : Int,
  line : Int,
  col : Int,
) -> Unit raise {
  guard node.origin_offset() is Some(actual_offset) && actual_offset == offset else {
    fail("unexpected origin offset")
  }
  guard node.origin_line() is Some(actual_line) && actual_line == line else {
    fail("unexpected origin line")
  }
  guard node.origin_col() is Some(actual_col) && actual_col == col else {
    fail("unexpected origin column")
  }
  guard node.origin_location() is Some((actual_line, actual_col)) &&
    actual_line == line &&
    actual_col == col else {
    fail("unexpected origin location")
  }
}

///|
fn repeat_for_test(value : String, count : Int) -> String {
  let out = StringBuilder::new(size_hint=value.length() * count)
  for _ in 0..<count {
    out.write_string(value)
  }
  out.to_string()
}

///|
test "to_test_format matches reference line format" {
  let node = @html_parser.element(
    "div",
    attrs={ "b": Some("2"), "a": Some("1"), "data-none": None },
    children=[@html_parser.text("x"), @html_parser.comment("c")],
  )
  assert_eq(
    @html_parser.to_test_format(node),
    "| <div>\n|   a=\"1\"\n|   b=\"2\"\n|   data-none=\"\"\n|   \"x\"\n|   <!-- c -->",
  )
  let nested_fragment = @html_parser.element("div", children=[
    @html_parser.fragment(children=[@html_parser.text("x")]),
  ])
  assert_eq(
    @html_parser.to_test_format(nested_fragment),
    "| <div>\n|   <#document-fragment>\n|     \"x\"",
  )
  let doc = @html_parser.document(children=[
    @html_parser.doctype(),
    @html_parser.element("html", children=[
      @html_parser.element("body", children=[@html_parser.element("p")]),
    ]),
  ])
  assert_eq(
    @html_parser.to_test_format(doc),
    "| <!DOCTYPE html>\n| <html>\n|   <body>\n|     <p>",
  )
  let fragment = @html_parser.fragment(children=[
    @html_parser.element("span", children=[@html_parser.text("x")]),
  ])
  assert_eq(@html_parser.to_test_format(fragment), "| <span>\n|   \"x\"")
  let doctype = @html_parser.doctype(public_id="pub", system_id="sys")
  assert_eq(
    @html_parser.to_test_format(doctype),
    "| <!DOCTYPE html \"pub\" \"sys\">",
  )
  assert_eq(
    @html_parser.to_test_format(@html_parser.doctype(name="")),
    "| <!DOCTYPE >",
  )
  assert_eq(
    @html_parser.to_test_format(@html_parser.doctype(system_id="sys")),
    "| <!DOCTYPE html \"\" \"sys\">",
  )
  assert_eq(
    @html_parser.to_test_format(@html_parser.doctype(public_id="pub")),
    "| <!DOCTYPE html \"pub\" \"\">",
  )
  let svg = @html_parser.element(
    "svg",
    attrs={ "xlink:href": Some("u"), "viewBox": Some("0 0") },
    ns="svg",
  )
  assert_eq(
    @html_parser.to_test_format(svg),
    "| <svg svg>\n|   viewBox=\"0 0\"\n|   xlink href=\"u\"",
  )
  let collision = @html_parser.element(
    "svg",
    attrs={ "xlink href": Some("va"), "xlink:href": Some("v") },
    ns="svg",
  )
  assert_eq(
    @html_parser.to_test_format(collision),
    "| <svg svg>\n|   xlink href=\"v\"\n|   xlink href=\"va\"",
  )
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
test "builder preserves adjusted foreign element names" {
  let gradient = @html_parser.element("linearGradient", ns="svg")
  assert_eq(gradient.name(), "linearGradient")
  assert_true(gradient.namespace_uri() is Some("svg"))
  assert_eq(gradient.to_html(pretty=false), "<linearGradient></linearGradient>")
  let math = @html_parser.element("math", ns="mathml", children=[
    @html_parser.element("mi", ns="mathml", children=[@html_parser.text("x")]),
  ])
  assert_true(math.namespace_uri() is Some("math"))
  assert_eq(math.to_html(pretty=false), "<math><mi>x</mi></math>")
  let rect = @html_parser.element("rect", ns="SVG")
  assert_true(rect.namespace_uri() is Some("svg"))
  let div = @html_parser.element("DIV")
  assert_eq(div.name(), "DIV")
  assert_true(div.namespace_uri() is Some("html"))
}

///|
test "builder exposes DOM helper invariants" {
  let custom = @html_parser.element("Thing", ns="CustomNS")
  assert_eq(custom.name(), "Thing")
  assert_true(custom.namespace_uri() is Some("CustomNS"))
  assert_true(custom.kind() is @html_parser.NodeKind::Element)
  assert_eq(custom.data(), "")
  assert_eq(custom.text(), "")
  assert_eq(custom.has_child_nodes(), false)
  let parent = @html_parser.element("div", attrs={ "id": Some("root") }, children=[
    @html_parser.text("a"),
    @html_parser.element("span", children=[@html_parser.text("b")]),
  ])
  assert_true(parent.has_child_nodes())
  assert_eq(parent.text(), "ab")
  let shallow = parent.clone_node()
  assert_eq(shallow.to_html(pretty=false), "<div id=\"root\"></div>")
  let deep = parent.clone_node(deep=true, override_attrs={ "id": Some("clone") })
  assert_eq(
    deep.to_html(pretty=false),
    "<div id=\"clone\">a<span>b</span></div>",
  )
  assert_eq(
    parent.to_html(pretty=false),
    "<div id=\"root\">a<span>b</span></div>",
  )
  let original_children = parent.children()
  assert_true(original_children[0].kind() is @html_parser.NodeKind::Text)
  assert_eq(original_children[0].data(), "a")
  let attrs_copy = parent.attrs()
  attrs_copy["id"] = Some("mutated")
  assert_eq(
    parent.to_html(pretty=false),
    "<div id=\"root\">a<span>b</span></div>",
  )
  let override_attrs = { "id": Some("override") }
  let override_clone = parent.clone_node(override_attrs~)
  override_attrs["id"] = Some("mutated")
  assert_eq(override_clone.to_html(pretty=false), "<div id=\"override\"></div>")
  let note = @html_parser.comment("note")
  assert_true(note.kind() is @html_parser.NodeKind::Comment)
  assert_eq(note.data(), "note")
  assert_eq(note.text(), "")
  note.append_child(@html_parser.text("ignored"))
  assert_eq(note.has_child_nodes(), false)
}

///|
test "text nodes expose no children" {
  let value = @html_parser.text("hello")
  assert_eq(value.children().length(), 0)
  assert_eq(value.has_child_nodes(), false)
  value.append_child(@html_parser.text("ignored"))
  assert_eq(value.children().length(), 0)
  assert_eq(value.text(), "hello")
}

///|
test "nodes expose empty origin metadata by default" {
  let text = @html_parser.text("hello")
  assert_true(text.origin_offset() is None)
  assert_true(text.origin_line() is None)
  assert_true(text.origin_col() is None)
  assert_true(text.origin_location() is None)
  let parent = @html_parser.element("p", children=[text])
  assert_true(parent.origin_offset() is None)
  assert_true(parent.origin_location() is None)
  let clone = parent.clone_node(deep=true)
  assert_true(clone.origin_offset() is None)
  assert_true(clone.origin_location() is None)
  let doc = @html_parser.parse_fragment("<p>hi</p>")
  guard doc.query_one("p") is Some(parsed_p) else {
    fail("expected parsed paragraph")
  }
  assert_true(parsed_p.origin_offset() is None)
  assert_true(parsed_p.origin_location() is None)
  let parsed_children = parsed_p.children()
  assert_eq(parsed_children.length(), 1)
  assert_true(parsed_children[0].origin_location() is None)
}

///|
test "parser tracks simple element and text origins when requested" {
  let doc = @html_parser.parse_fragment("<p>hi</p>", track_node_locations=true)
  guard doc.query_one("p") is Some(paragraph) else {
    fail("expected parsed paragraph")
  }
  assert_node_origin(paragraph, 0, 1, 1)
  let children = paragraph.children()
  assert_eq(children.length(), 1)
  assert_eq(children[0].data(), "hi")
  assert_node_origin(children[0], 3, 1, 4)
  let multiline = @html_parser.parse_fragment(
    "lead\n<p>x</p>",
    track_node_locations=true,
  )
  guard multiline.query_one("p") is Some(multiline_p) else {
    fail("expected multiline paragraph")
  }
  assert_node_origin(multiline_p, 5, 2, 1)
  let multiline_children = multiline_p.children()
  assert_eq(multiline_children.length(), 1)
  assert_node_origin(multiline_children[0], 8, 2, 4)
}

///|
test "parser tracks comment and doctype origins when requested" {
  let fragment = @html_parser.parse_fragment(
    "<!--x--><p><!--y--></p>",
    track_node_locations=true,
  )
  let root_children = fragment.root.children()
  assert_eq(root_children.length(), 2)
  assert_true(root_children[0].kind() is Comment)
  assert_node_origin(root_children[0], 0, 1, 1)
  guard fragment.query_one("p") is Some(paragraph) else {
    fail("expected parsed paragraph")
  }
  assert_node_origin(paragraph, 8, 1, 9)
  let paragraph_children = paragraph.children()
  assert_eq(paragraph_children.length(), 1)
  assert_true(paragraph_children[0].kind() is Comment)
  assert_node_origin(paragraph_children[0], 11, 1, 12)
  let doc = @html_parser.parse(
    "<!doctype html><p>x</p>",
    track_node_locations=true,
  )
  let doc_children = doc.root.children()
  assert_true(doc_children[0].kind() is Doctype)
  assert_node_origin(doc_children[0], 0, 1, 1)
}

///|
test "parse_bytes forwards node origin tracking" {
  let doc = @html_parser.parse_bytes(b"<p>x</p>", track_node_locations=true)
  guard doc.query_one("p") is Some(paragraph) else {
    fail("expected parsed paragraph")
  }
  assert_node_origin(paragraph, 0, 1, 1)
  let children = paragraph.children()
  assert_eq(children.length(), 1)
  assert_node_origin(children[0], 3, 1, 4)
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
test "sanitize_dom default policy drops unsafe document content" {
  let doc = @html_parser.parse(
    "<!DOCTYPE html><!--x--><p onclick=alert(1)>ok</p><script>alert(1)</script>",
    sanitize=false,
  )
  let sanitized = @html_parser.sanitize_dom(
    doc.root,
    policy=@html_parser.default_sanitization_policy(),
  )
  assert_eq(sanitized.to_html(pretty=false), "<p>ok</p>")
}

///|
test "sanitize_dom default policy keeps table captions" {
  let root = @html_parser.fragment(children=[
    @html_parser.element("table", children=[
      @html_parser.element("caption", children=[@html_parser.text("Summary")]),
    ]),
  ])
  assert_eq(
    @html_parser.sanitize_dom(root).to_html(pretty=false),
    "<table><caption>Summary</caption></table>",
  )
}

///|
test "sanitize_dom document policy preserves shell and doctype" {
  let doc = @html_parser.parse(
    "<!DOCTYPE html><!--x--><html><head><title>T</title><script>bad</script></head><body><p onclick=x>ok</p></body></html>",
    sanitize=false,
  )
  let sanitized = @html_parser.sanitize_dom(doc.root)
  assert_eq(
    sanitized.to_html(pretty=false),
    "<!DOCTYPE html><html><head><title>T</title></head><body><p>ok</p></body></html>",
  )
}

///|
test "sanitize_dom custom policy keeps comments and can drop subtrees" {
  let keep_shell = @html_parser.parse(
    "<!DOCTYPE html><!--x--><p>ok</p><span>kept text</span>",
    sanitize=false,
  )
  let keep_policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    allowed_attributes={ "*": [], "p": [] },
    drop_comments=false,
    drop_doctype=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(keep_shell.root, policy=keep_policy).to_html(
      pretty=false,
    ),
    "<!DOCTYPE html><!--x--><p>ok</p>kept text",
  )
  let fragment = @html_parser.parse_fragment(
    "<div>keep<sarcasm><b>drop</b></sarcasm><p>ok</p></div>",
    sanitize=false,
  )
  let drop_policy = @html_parser.SanitizationPolicy::new(
    ["div", "p"],
    allowed_attributes={ "*": [], "div": [], "p": [] },
    disallowed_tag_handling=Drop,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy=drop_policy).to_html(
      pretty=false,
    ),
    "<div>keep<p>ok</p></div>",
  )
}

///|
test "sanitize_dom handles standalone text comment and doctype roots" {
  assert_eq(@html_parser.sanitize_dom(@html_parser.text("x")).to_html(), "x")
  let keep_policy = @html_parser.SanitizationPolicy::new(
    [],
    allowed_attributes={},
    drop_comments=false,
    drop_doctype=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(@html_parser.comment("x"), policy=keep_policy).to_html(
      pretty=false,
    ),
    "<!--x-->",
  )
  assert_eq(
    @html_parser.sanitize_dom(@html_parser.doctype(), policy=keep_policy).to_html(
      pretty=false,
    ),
    "<!DOCTYPE html>",
  )
  assert_eq(
    @html_parser.sanitize_dom(@html_parser.comment("x")).to_html(pretty=false),
    "",
  )
  assert_eq(
    @html_parser.sanitize_dom(@html_parser.doctype()).to_html(pretty=false),
    "",
  )
}

///|
test "sanitize_dom recurses through nested containers and empty templates" {
  let text_policy = @html_parser.SanitizationPolicy::new([], allowed_attributes={
    "*": [],
  })
  let nested = @html_parser.fragment(children=[
    @html_parser.fragment(children=[@html_parser.text("t")]),
  ])
  assert_eq(
    @html_parser.sanitize_dom(nested, policy=text_policy).to_html(pretty=false),
    "t",
  )
  let template_policy = @html_parser.SanitizationPolicy::new(["template"], allowed_attributes={
    "*": [],
    "template": [],
  })
  let root = @html_parser.fragment(children=[@html_parser.element("template")])
  assert_eq(
    @html_parser.sanitize_dom(root, policy=template_policy).to_html(
      pretty=false,
    ),
    "<template></template>",
  )
}

///|
test "sanitize_dom handles standalone root element edge cases" {
  let unwrap_policy = @html_parser.SanitizationPolicy::new(["div"], allowed_attributes={
    "*": [],
    "div": [],
  })
  assert_eq(
    @html_parser.sanitize_dom(
      @html_parser.element("div", ns="svg"),
      policy=unwrap_policy,
    ).to_html(pretty=false),
    "",
  )
  assert_eq(
    @html_parser.sanitize_dom(
      @html_parser.element("span", children=[@html_parser.text("x")]),
      policy=unwrap_policy,
    ).to_html(pretty=false),
    "x",
  )
  let drop_content_policy = @html_parser.SanitizationPolicy::new(
    ["div", "img"],
    allowed_attributes={ "*": [], "div": [], "img": ["src"] },
    url_policy=@html_parser.UrlPolicy::new(allow_rules=[]),
    drop_content_tags=["SCRIPT"],
    disallowed_tag_handling=Unwrap,
  )
  assert_eq(
    @html_parser.sanitize_dom(
      @html_parser.element("ScRiPt", children=[
        @html_parser.element("img", attrs={
          "src": Some("pixel"),
          "onerror": Some("alert(1)"),
        }),
      ]),
      policy=drop_content_policy,
    ).to_html(pretty=false),
    "",
  )
}

///|
test "sanitize_dom escape handling emits disallowed tags as text" {
  let fragment = @html_parser.parse_fragment(
    "<b>Hello <sarcasm title='tone' onclick=x><i onclick=y>world</i><script>bad</script></sarcasm></b>",
    sanitize=false,
  )
  let policy = @html_parser.SanitizationPolicy::new(
    ["b", "i"],
    allowed_attributes={ "*": [], "b": [], "i": [] },
    disallowed_tag_handling=Escape,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<b>Hello &lt;sarcasm title=\"tone\" onclick=\"x\"&gt;<i>world</i>&lt;/sarcasm&gt;</b>",
  )
}

///|
test "sanitize_dom escape handling can return fragments for standalone roots" {
  let policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    allowed_attributes={ "*": [], "p": [] },
    drop_content_tags=[],
    disallowed_tag_handling=Escape,
  )
  let standalone = @html_parser.element(
    "widget",
    attrs={ "data-x": Some("1") },
    children=[@html_parser.text("ok")],
  )
  let sanitized = @html_parser.sanitize_dom(standalone, policy~)
  assert_true(sanitized.kind() is Fragment)
  assert_eq(
    sanitized.to_html(pretty=false),
    "&lt;widget data-x=\"1\"&gt;ok&lt;/widget&gt;",
  )
  let image = @html_parser.fragment(children=[
    @html_parser.element("img", attrs={ "src": Some("/safe.png") }),
  ])
  assert_eq(
    @html_parser.sanitize_dom(image, policy~).to_html(pretty=false),
    "&lt;img src=\"/safe.png\"&gt;",
  )
}

///|
test "sanitize_dom escape handling preserves disallowed template children" {
  let policy = @html_parser.SanitizationPolicy::new(
    ["b"],
    allowed_attributes={ "*": [], "b": [] },
    drop_content_tags=[],
    disallowed_tag_handling=Escape,
  )
  let fragment = @html_parser.parse_fragment(
    "<template><b>x</b></template>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "&lt;template&gt;<b>x</b>&lt;/template&gt;",
  )
}

///|
test "sanitize_dom filters attributes and dangerous URLs" {
  let fragment = @html_parser.parse_fragment(
    "<div id=x onclick=alert(1) srcdoc='<p>p</p>' x:y=z title=t class=c data-x=y><a href='javascript:alert(1)' title='t'>x</a><a href='//example.com/path'>y</a><img src='https://x' alt=abs><img src='/safe.png' onerror=x alt=ok></div>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root).to_html(pretty=false),
    "<div id=\"x\" title=\"t\" class=\"c\"><a title=\"t\">x</a><a href=\"https://example.com/path\">y</a><img alt=\"abs\"><img src=\"/safe.png\" alt=\"ok\"></div>",
  )
}

///|
test "sanitize_dom preserves allowed valueless non-url attributes" {
  let policy = @html_parser.SanitizationPolicy::new(["div"], allowed_attributes={
    "*": [],
    "div": ["disabled"],
  })
  let fragment = @html_parser.parse_fragment(
    "<div disabled></div>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<div disabled></div>",
  )
}

///|
test "sanitize_dom lowercases manual DOM attribute names" {
  let root = @html_parser.element(
    "a",
    attrs={ "HREF": Some("https://example.com") },
    children=[@html_parser.text("x")],
  )
  assert_eq(
    @html_parser.sanitize_dom(root).to_html(pretty=false),
    "<a href=\"https://example.com\">x</a>",
  )
}

///|
test "sanitize_dom reports valueless url and style attributes" {
  let url_policy = @html_parser.UrlPolicy::new(default_handling=UrlAllow, allow_rules=[
    @html_parser.UrlPolicyRule::new(
      "a",
      "href",
      @html_parser.UrlRule::new(allowed_schemes=["https"]),
    ),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    ["a", "span", "div"],
    allowed_attributes={
      "*": [],
      "a": ["href"],
      "span": ["style"],
      "div": ["disabled"],
    },
    allowed_css_properties=["color"],
    unsafe_handling=Collect,
    url_policy~,
  )
  policy.reset_collected_security_errors()
  let root = @html_parser.fragment(children=[
    @html_parser.element("a", attrs={ "href": None }, children=[
      @html_parser.text("link"),
    ]),
    @html_parser.element("span", attrs={ "style": None }, children=[
      @html_parser.text("style"),
    ]),
    @html_parser.element("div", attrs={ "disabled": None }, children=[
      @html_parser.text("ok"),
    ]),
  ])
  assert_eq(
    @html_parser.sanitize_dom(root, policy~).to_html(pretty=false),
    "<a>link</a><span>style</span><div disabled>ok</div>",
  )
  let errors = policy.collected_security_errors()
  assert_eq(errors.length(), 2)
  assert_eq(errors[0].code, "unsafe-html")
  assert_eq(errors[0].category, "security")
  assert_eq(errors[1].code, "unsafe-html")
  assert_eq(errors[1].category, "security")
}

///|
test "sanitize_dom can collect and raise unsafe findings" {
  let safe_policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    allowed_attributes={ "p": [] },
    unsafe_handling=Collect,
  )
  let safe_fragment = @html_parser.parse_fragment("<p>ok</p>", sanitize=false)
  assert_eq(
    @html_parser.sanitize_dom(safe_fragment.root, policy=safe_policy).to_html(
      pretty=false,
    ),
    "<p>ok</p>",
  )
  assert_eq(safe_policy.collected_security_errors().length(), 0)

  let collect_policy = @html_parser.SanitizationPolicy::new(
    ["p", "a"],
    allowed_attributes={ "p": [], "a": ["href"] },
    unsafe_handling=Collect,
  )
  let fragment = @html_parser.parse_fragment(
    "<p foo=1>safe<script>bad</script><a href='javascript:alert(1)'>bad</a></p><!--x-->",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy=collect_policy).to_html(
      pretty=false,
    ),
    "<p>safe<a>bad</a></p>",
  )
  let errors = collect_policy.collected_security_errors()
  assert_eq(errors.length(), 4)
  assert_eq(errors[0].code, "unsafe-html")
  assert_eq(errors[0].category, "security")
  collect_policy.reset_collected_security_errors()
  assert_eq(collect_policy.collected_security_errors().length(), 0)

  let raise_policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    allowed_attributes={ "p": [] },
    unsafe_handling=Raise,
  )
  let unsafe_fragment = @html_parser.parse_fragment(
    "<p foo=1>safe</p>",
    sanitize=false,
  )
  let result : Result[@html_parser.Node, @html_parser.HtmlError] = try? @html_parser.sanitize_dom(
    unsafe_fragment.root,
    policy=raise_policy,
  )
  match result {
    Err(UnsafeHtml(message)) =>
      assert_eq(
        message, "Unsafe attribute 'foo' on <p> was dropped because it is not allowed",
      )
    _ => fail("expected sanitize_dom to raise UnsafeHtml")
  }
}

///|
test "sanitize_dom raise mode reports dangerous attributes and urls" {
  let attr_policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    allowed_attributes={ "p": ["onclick"] },
    unsafe_handling=Raise,
  )
  let attr_fragment = @html_parser.parse_fragment(
    "<p onclick='alert(1)'>x</p>",
    sanitize=false,
  )
  let attr_result : Result[@html_parser.Node, @html_parser.HtmlError] = try? @html_parser.sanitize_dom(
    attr_fragment.root,
    policy=attr_policy,
  )
  match attr_result {
    Err(UnsafeHtml(message)) =>
      assert_eq(
        message, "Unsafe attribute 'onclick' on <p> was dropped because it is not allowed",
      )
    _ => fail("expected dangerous attribute to raise UnsafeHtml")
  }

  let url_policy = @html_parser.UrlPolicy::new(allow_rules=[
    @html_parser.UrlPolicyRule::new(
      "a",
      "href",
      @html_parser.UrlRule::new(allowed_schemes=["https"]),
    ),
  ])
  let link_policy = @html_parser.SanitizationPolicy::new(
    ["a"],
    allowed_attributes={ "a": ["href"] },
    unsafe_handling=Raise,
    url_policy~,
  )
  let link_fragment = @html_parser.parse_fragment(
    "<a href='javascript:alert(1)'>x</a>",
    sanitize=false,
  )
  let link_result : Result[@html_parser.Node, @html_parser.HtmlError] = try? @html_parser.sanitize_dom(
    link_fragment.root,
    policy=link_policy,
  )
  match link_result {
    Err(UnsafeHtml(message)) =>
      assert_eq(message, "Unsafe attribute 'href' on <a> was dropped")
    _ => fail("expected unsafe URL to raise UnsafeHtml")
  }

  let meta_policy = @html_parser.SanitizationPolicy::new(
    ["meta"],
    allowed_attributes={ "meta": ["http-equiv", "content"] },
    drop_content_tags=[],
    unsafe_handling=Raise,
  )
  let meta_fragment = @html_parser.parse_fragment(
    "<meta http-equiv='refresh' content='0;url=javascript:alert(1)'>",
    sanitize=false,
  )
  let meta_result : Result[@html_parser.Node, @html_parser.HtmlError] = try? @html_parser.sanitize_dom(
    meta_fragment.root,
    policy=meta_policy,
  )
  match meta_result {
    Err(UnsafeHtml(message)) =>
      assert_eq(
        message, "Unsafe URL in attribute 'content' on <meta> refresh was dropped",
      )
    _ => fail("expected meta refresh content to raise UnsafeHtml")
  }
}

///|
test "sanitize_dom raise mode reports URL list and base drops" {
  let srcset_rule = @html_parser.UrlRule::new(
    allowed_schemes=["https"],
    allowed_hosts=["trusted.example"],
    allow_relative=false,
  )
  let srcset_policy = @html_parser.SanitizationPolicy::new(
    ["link"],
    allowed_attributes={ "link": ["rel", "as", "imagesrcset"] },
    unsafe_handling=Raise,
    url_policy=@html_parser.UrlPolicy::new(allow_rules=[
      @html_parser.UrlPolicyRule::new("link", "imagesrcset", srcset_rule),
    ]),
    drop_content_tags=[],
  )
  let srcset_fragment = @html_parser.parse_fragment(
    "<link rel='preload' as='image' imagesrcset='https://evil.example/a 1x'>",
    sanitize=false,
  )
  let srcset_result : Result[@html_parser.Node, @html_parser.HtmlError] = try? @html_parser.sanitize_dom(
    srcset_fragment.root,
    policy=srcset_policy,
  )
  match srcset_result {
    Err(UnsafeHtml(message)) =>
      assert_eq(message, "Unsafe attribute 'imagesrcset' on <link> was dropped")
    _ => fail("expected unsafe imagesrcset to raise UnsafeHtml")
  }

  let base_policy = @html_parser.SanitizationPolicy::new(
    ["base"],
    allowed_attributes={ "base": ["href"] },
    unsafe_handling=Raise,
    url_policy=@html_parser.UrlPolicy::new(allow_rules=[
      @html_parser.UrlPolicyRule::new(
        "base",
        "href",
        @html_parser.UrlRule::new(allowed_schemes=["https"]),
      ),
    ]),
    drop_content_tags=[],
  )
  let base_fragment = @html_parser.parse_fragment(
    "<base href='https://evil.example/assets/'>",
    sanitize=false,
  )
  let base_result : Result[@html_parser.Node, @html_parser.HtmlError] = try? @html_parser.sanitize_dom(
    base_fragment.root,
    policy=base_policy,
  )
  match base_result {
    Err(UnsafeHtml(message)) =>
      assert_eq(message, "Unsafe attribute 'href' on <base> was dropped")
    _ => fail("expected base href to raise UnsafeHtml")
  }

  let attr_rule = @html_parser.UrlRule::new(
    allowed_schemes=["https"],
    allowed_hosts=["trusted.example"],
    allow_relative=false,
  )
  let attr_policy = @html_parser.SanitizationPolicy::new(
    ["img"],
    allowed_attributes={ "img": ["src", "attributionsrc"] },
    unsafe_handling=Raise,
    url_policy=@html_parser.UrlPolicy::new(allow_rules=[
      @html_parser.UrlPolicyRule::new("img", "src", attr_rule),
      @html_parser.UrlPolicyRule::new("img", "attributionsrc", attr_rule),
    ]),
  )
  let attr_fragment = @html_parser.parse_fragment(
    "<img src='https://trusted.example/x.png' attributionsrc='https://evil.example/register'>",
    sanitize=false,
  )
  let attr_result : Result[@html_parser.Node, @html_parser.HtmlError] = try? @html_parser.sanitize_dom(
    attr_fragment.root,
    policy=attr_policy,
  )
  match attr_result {
    Err(UnsafeHtml(message)) =>
      assert_eq(
        message, "Unsafe attribute 'attributionsrc' on <img> was dropped",
      )
    _ => fail("expected unsafe attributionsrc to raise UnsafeHtml")
  }
}

///|
test "sanitize_dom raises for disallowed standalone root" {
  let policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    allowed_attributes={},
    unsafe_handling=Raise,
  )
  let fragment = @html_parser.parse_fragment("<x-foo></x-foo>", sanitize=false)
  guard fragment.root.children().get(0) is Some(root) else {
    fail("expected standalone root")
  }
  let result : Result[@html_parser.Node, @html_parser.HtmlError] = try? @html_parser.sanitize_dom(
    root,
    policy~,
  )
  match result {
    Err(UnsafeHtml(message)) =>
      assert_eq(
        message, "Unsafe tag 'x-foo' was dropped because it is not allowed",
      )
    _ => fail("expected sanitize_dom to raise UnsafeHtml")
  }
}

///|
test "sanitize_dom raise mode reports dropped content and child tags" {
  let root_script_policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    allowed_attributes={},
    unsafe_handling=Raise,
  )
  let root_script_fragment = @html_parser.parse_fragment(
    "<script>alert(1)</script>",
    sanitize=false,
  )
  guard root_script_fragment.root.children().get(0) is Some(root_script) else {
    fail("expected script root")
  }
  let root_script_result : Result[@html_parser.Node, @html_parser.HtmlError] = try? @html_parser.sanitize_dom(
    root_script,
    policy=root_script_policy,
  )
  match root_script_result {
    Err(UnsafeHtml(message)) =>
      assert_eq(message, "Unsafe tag 'script' was dropped with its content")
    _ => fail("expected dropped-content root to raise UnsafeHtml")
  }

  let child_script_policy = @html_parser.SanitizationPolicy::new(
    ["div"],
    allowed_attributes={ "div": [] },
    unsafe_handling=Raise,
  )
  let child_script_fragment = @html_parser.parse_fragment(
    "<div><script>alert(1)</script></div>",
    sanitize=false,
  )
  guard child_script_fragment.root.children().get(0) is Some(child_script_root) else {
    fail("expected div root")
  }
  let child_script_result : Result[@html_parser.Node, @html_parser.HtmlError] = try? @html_parser.sanitize_dom(
    child_script_root,
    policy=child_script_policy,
  )
  match child_script_result {
    Err(UnsafeHtml(message)) =>
      assert_eq(message, "Unsafe tag 'script' was dropped with its content")
    _ => fail("expected dropped-content child to raise UnsafeHtml")
  }

  let child_tag_policy = @html_parser.SanitizationPolicy::new(
    ["div"],
    allowed_attributes={ "div": [] },
    unsafe_handling=Raise,
  )
  let child_tag_fragment = @html_parser.parse_fragment(
    "<div><foo></foo></div>",
    sanitize=false,
  )
  guard child_tag_fragment.root.children().get(0) is Some(child_tag_root) else {
    fail("expected div root")
  }
  let child_tag_result : Result[@html_parser.Node, @html_parser.HtmlError] = try? @html_parser.sanitize_dom(
    child_tag_root,
    policy=child_tag_policy,
  )
  match child_tag_result {
    Err(UnsafeHtml(message)) =>
      assert_eq(
        message, "Unsafe tag 'foo' was dropped because it is not allowed",
      )
    _ => fail("expected disallowed child tag to raise UnsafeHtml")
  }
}

///|
test "sanitize_dom raise mode reports foreign namespace drops" {
  let root_policy = @html_parser.SanitizationPolicy::new(
    ["svg"],
    allowed_attributes={ "svg": [] },
    drop_foreign_namespaces=true,
    unsafe_handling=Raise,
  )
  let root_fragment = @html_parser.parse_fragment(
    "<svg><title>foo</title></svg>",
    sanitize=false,
  )
  guard root_fragment.root.children().get(0) is Some(svg_root) else {
    fail("expected svg root")
  }
  let root_result : Result[@html_parser.Node, @html_parser.HtmlError] = try? @html_parser.sanitize_dom(
    svg_root,
    policy=root_policy,
  )
  match root_result {
    Err(UnsafeHtml(message)) =>
      assert_eq(
        message, "Unsafe tag 'svg' was dropped because it is in a foreign namespace",
      )
    _ => fail("expected foreign namespace root to raise UnsafeHtml")
  }

  let child_policy = @html_parser.SanitizationPolicy::new(
    ["div"],
    allowed_attributes={ "div": [] },
    drop_foreign_namespaces=true,
    unsafe_handling=Raise,
  )
  let child_fragment = @html_parser.parse_fragment(
    "<div><svg></svg></div>",
    sanitize=false,
  )
  guard child_fragment.root.children().get(0) is Some(div_root) else {
    fail("expected div root")
  }
  let child_result : Result[@html_parser.Node, @html_parser.HtmlError] = try? @html_parser.sanitize_dom(
    div_root,
    policy=child_policy,
  )
  match child_result {
    Err(UnsafeHtml(message)) =>
      assert_eq(
        message, "Unsafe tag 'svg' was dropped because it is in a foreign namespace",
      )
    _ => fail("expected foreign namespace child to raise UnsafeHtml")
  }
}

///|
test "sanitize_dom raise mode reports html namespace foreign root drops" {
  let policy = @html_parser.SanitizationPolicy::new(
    ["svg", "rect"],
    allowed_attributes={ "rect": ["width", "height"] },
    drop_foreign_namespaces=true,
    drop_content_tags=[],
    unsafe_handling=Raise,
  )
  let svg = @html_parser.element("svg", ns="html", children=[
    @html_parser.element("rect", ns="html", attrs={
      "width": Some("10"),
      "height": Some("10"),
    }),
  ])
  let result : Result[@html_parser.Node, @html_parser.HtmlError] = try? @html_parser.sanitize_dom(
    svg,
    policy~,
  )
  match result {
    Err(UnsafeHtml(message)) =>
      assert_eq(
        message, "Unsafe tag 'svg' was dropped because it is in a foreign namespace",
      )
    _ => fail("expected html namespace svg root to raise UnsafeHtml")
  }
}

///|
test "sanitize_dom drop mode returns empty fragment for disallowed standalone root" {
  let policy = @html_parser.SanitizationPolicy::new(
    [],
    allowed_attributes={},
    disallowed_tag_handling=Drop,
  )
  let root = @html_parser.element("x-foo", children=[@html_parser.text("bad")])
  let sanitized = @html_parser.sanitize_dom(root, policy~)
  assert_true(sanitized.kind() is Fragment)
  assert_eq(sanitized.children().length(), 0)
  assert_eq(sanitized.to_html(pretty=false), "")
}

///|
test "sanitize_dom collects rawtext and foreign integration findings" {
  let rawtext_policy = @html_parser.SanitizationPolicy::new(
    ["style"],
    allowed_attributes={ "style": [] },
    drop_content_tags=[],
    unsafe_handling=Collect,
  )
  let rawtext = @html_parser.fragment(children=[
    @html_parser.element("style", children=[
      @html_parser.text("</style><b>x</b>"),
    ]),
  ])
  assert_eq(
    @html_parser.sanitize_dom(rawtext, policy=rawtext_policy).to_html(
      pretty=false,
    ),
    "<style>&lt;/style><b>x</b></style>",
  )
  let rawtext_errors = rawtext_policy.collected_security_errors()
  assert_eq(rawtext_errors.length(), 1)
  assert_eq(rawtext_errors[0].code, "unsafe-html")
  assert_eq(rawtext_errors[0].category, "security")
  assert_eq(
    rawtext_errors[0].message,
    "Unsafe raw text inside <style> contains a closing tag sequence",
  )

  let foreign_policy = @html_parser.SanitizationPolicy::new(
    ["svg", "title", "script"],
    allowed_attributes={ "svg": [], "title": [], "script": [] },
    drop_foreign_namespaces=false,
    drop_content_tags=[],
    unsafe_handling=Collect,
  )
  let foreign = @html_parser.parse_fragment(
    "<svg><title>Hello<script>bad</script></title></svg>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(foreign.root, policy=foreign_policy).to_html(
      pretty=false,
    ),
    "<svg><title>Hello</title></svg>",
  )
  let foreign_errors = foreign_policy.collected_security_errors()
  assert_eq(foreign_errors.length(), 1)
  assert_eq(foreign_errors[0].code, "unsafe-html")
  assert_eq(foreign_errors[0].category, "security")
  assert_eq(
    foreign_errors[0].message,
    "Unsafe HTML child inside foreign integration point <title> was dropped",
  )
}

///|
test "sanitize_dom strips invisible unicode from text and attributes" {
  let invisible = "\u{FE00}\u{E0100}\u{200B}\u{202E}\u{E000}"
  let fragment = @html_parser.parse_fragment(
    "<p title=\"a" +
    invisible +
    "b\">a" +
    invisible +
    "b<a href=\"java\u{200B}script:alert(1)\">x</a></p>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root).to_html(pretty=false),
    "<p title=\"ab\">ab<a>x</a></p>",
  )
}

///|
test "sanitize_dom can preserve invisible unicode by policy" {
  let invisible = "\u{FE00}\u{200B}\u{202E}\u{E000}"
  let fragment = @html_parser.parse_fragment(
    "<p title=\"a" + invisible + "b\">a" + invisible + "b</p>",
    sanitize=false,
  )
  let policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    allowed_attributes={ "p": ["title"] },
    strip_invisible_unicode=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<p title=\"a" + invisible + "b\">a" + invisible + "b</p>",
  )
}

///|
test "sanitize_dom force_link_rel permits and merges anchor rel tokens" {
  let default_rel = @html_parser.parse_fragment(
    "<a href='/x' rel='noopener'>x</a>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(default_rel.root).to_html(pretty=false),
    "<a href=\"/x\">x</a>",
  )
  let forced = @html_parser.parse_fragment(
    "<a href='https://example.com'>one</a><a href='/x' rel='External\tNOOPENER\nfriend'>two</a><a rel>three</a><a href='javascript:evil' rel='friend'>bad</a>",
    sanitize=false,
  )
  let policy = @html_parser.SanitizationPolicy::new(
    ["a"],
    allowed_attributes={ "*": [], "a": ["href"] },
    force_link_rel=["NoOpener", "noreferrer", "noopener"],
  )
  assert_eq(
    @html_parser.sanitize_dom(forced.root, policy~).to_html(pretty=false),
    "<a href=\"https://example.com\" rel=\"noopener noreferrer\">one</a><a href=\"/x\" rel=\"external noopener friend noreferrer\">two</a><a rel=\"noopener noreferrer\">three</a><a rel=\"friend noopener noreferrer\">bad</a>",
  )
}

///|
test "sanitize_dom normalizes mixed-case valueless attributes" {
  let policy = @html_parser.SanitizationPolicy::new(["button"], allowed_attributes={
    "*": [],
    "button": ["disabled", "title"],
  })
  let button = @html_parser.element("button", attrs={
    "DISABLED": None,
    "TITLE": Some("ok"),
    "DATA-X": Some("drop"),
  })
  assert_eq(
    @html_parser.sanitize_dom(button, policy~).to_html(pretty=false),
    "<button disabled title=\"ok\"></button>",
  )
}

///|
test "sanitize_dom filters inline style declarations by property allowlist" {
  let no_css = @html_parser.parse_fragment(
    "<p style='color: red'>x</p>",
    sanitize=false,
  )
  let no_css_policy = @html_parser.SanitizationPolicy::new(["p"], allowed_attributes={
    "*": [],
    "p": ["style"],
  })
  assert_eq(
    @html_parser.sanitize_dom(no_css.root, policy=no_css_policy).to_html(
      pretty=false,
    ),
    "<p>x</p>",
  )
  let styled = @html_parser.parse_fragment(
    "<p style='; color; color: ; co_lor: red; margin: 0; COLOR: red; font-weight: 700; background-image: url(/x.png); width: expression(alert(1))'>ok</p><p style>empty</p><p STYLE='color: blue; text-align: center; background-image: u/**/rl(/x.png)'>case</p><p style='color: /*unterminated'>comment</p><p style=': red; color: orange'>empty-prop</p>",
    sanitize=false,
  )
  let style_policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    allowed_attributes={ "*": [], "p": ["style"] },
    allowed_css_properties=[
      "color", "font-weight", "background-image", "width", "text-align",
    ],
  )
  assert_eq(
    @html_parser.sanitize_dom(styled.root, policy=style_policy).to_html(
      pretty=false,
    ),
    "<p style=\"color: red; font-weight: 700\">ok</p><p>empty</p><p style=\"color: blue; text-align: center\">case</p><p>comment</p><p style=\"color: orange\">empty-prop</p>",
  )
}

///|
test "sanitize_dom applies css url function policy rules" {
  let css_url_rule = @html_parser.UrlRule::new(
    allowed_schemes=[],
    allow_relative=true,
    resolve_protocol_relative=None,
  )
  let url_policy = @html_parser.UrlPolicy::new(allow_rules=[
    @html_parser.UrlPolicyRule::new("*", "style:background-image", css_url_rule),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    allowed_attributes={ "*": [], "p": ["style"] },
    allowed_css_properties=["background-image", "color"],
    url_policy~,
  )
  let fragment = @html_parser.parse_fragment(
    "<p style='background-image: url(/safe.png); color: red'>ok</p><p style=\"background-image: url('https://evil.example/x.png'); color: blue\">bad</p><p style=\"background-image: image-set(url('/safe.png') 1x); color: green\">blocked</p><p style='background-image: URL(  \"/safe-2.png\"  )'>case</p>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<p style=\"background-image: url('/safe.png'); color: red\">ok</p><p style=\"color: blue\">bad</p><p style=\"color: green\">blocked</p><p style=\"background-image: url('/safe-2.png')\">case</p>",
  )
}

///|
test "sanitize_dom rejects comments in css url function values" {
  let css_url_rule = @html_parser.UrlRule::new(
    allowed_schemes=[],
    allow_relative=true,
    resolve_protocol_relative=None,
  )
  let url_policy = @html_parser.UrlPolicy::new(allow_rules=[
    @html_parser.UrlPolicyRule::new("*", "style:background-image", css_url_rule),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    allowed_attributes={ "*": [], "p": ["style"] },
    allowed_css_properties=["background-image", "color"],
    url_policy~,
  )
  let fragment = @html_parser.parse_fragment(
    "<p style='background-image: url(/x.png)/*comment*/; color: red'>comment</p><p style='background-image: linear-gradient(red, blue), url(/y.png); color: blue'>gradient</p>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<p style=\"color: red\">comment</p><p style=\"background-image: linear-gradient(red, blue), url('/y.png'); color: blue\">gradient</p>",
  )
}

///|
test "sanitize_dom rejects malformed css url function values" {
  let css_url_rule = @html_parser.UrlRule::new(
    allowed_schemes=[],
    allow_relative=true,
    resolve_protocol_relative=None,
  )
  let url_policy = @html_parser.UrlPolicy::new(allow_rules=[
    @html_parser.UrlPolicyRule::new("*", "style:background-image", css_url_rule),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    allowed_attributes={ "*": [], "p": ["style"] },
    allowed_css_properties=["background-image", "color"],
    url_policy~,
  )
  let fragment = @html_parser.parse_fragment(
    "<p style=\"background-image: url('/x\\y.png'); color: red\">backslash</p><p style='background-image: url(/x y); color: blue'>space</p><p style='background-image: url(/x\u{007F}y); color: green'>del</p><p style='background-image: url(); color: black'>empty</p><p style=\"background-image: url('/x')x; color: purple\">tail</p><p style=\"background-image: url('/unterminated); color: olive\">missing-quote</p><p style=\"background-image: url('/missing-paren'; color: maroon\">missing-paren</p><p style='background-image: u rl(/x.png); color: lime'>obfuscated</p><p style='background-image: u\trl(/x.png); color: aqua'>tab</p><p style=\"background-image: url('/spaced.png'   ); color: navy\">spaced</p><p style=\"background-image: url(/ok.png), url('/next.png'); color: teal\">ok</p>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<p style=\"color: red\">backslash</p><p style=\"color: blue\">space</p><p style=\"color: green\">del</p><p style=\"color: black\">empty</p><p style=\"color: purple\">tail</p><p style=\"color: olive\">missing-quote</p><p style=\"color: maroon\">missing-paren</p><p style=\"color: lime\">obfuscated</p><p style=\"color: aqua\">tab</p><p style=\"background-image: url('/spaced.png'); color: navy\">spaced</p><p style=\"background-image: url('/ok.png'), url('/next.png'); color: teal\">ok</p>",
  )
}

///|
test "sanitize_dom drops unquoted css url with missing close paren" {
  let css_url_rule = @html_parser.UrlRule::new(
    allowed_schemes=[],
    allow_relative=true,
    resolve_protocol_relative=None,
  )
  let url_policy = @html_parser.UrlPolicy::new(allow_rules=[
    @html_parser.UrlPolicyRule::new("*", "style:background-image", css_url_rule),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    allowed_attributes={ "*": [], "p": ["style"] },
    allowed_css_properties=["background-image", "color"],
    url_policy~,
  )
  let fragment = @html_parser.parse_fragment(
    "<p style='background-image: url(/missing; color: silver'>missing-raw-paren</p>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<p style=\"color: silver\">missing-raw-paren</p>",
  )
}

///|
test "sanitize_dom proxies validated URL values" {
  let url_policy = @html_parser.UrlPolicy::new(
    default_handling=UrlProxy,
    proxy=@html_parser.UrlProxy::new("/proxy"),
    allow_rules=[
      @html_parser.UrlPolicyRule::new(
        "a",
        "href",
        @html_parser.UrlRule::new(allowed_schemes=["https"]),
      ),
      @html_parser.UrlPolicyRule::new(
        "img",
        "srcset",
        @html_parser.UrlRule::new(allowed_schemes=["https"]),
      ),
      @html_parser.UrlPolicyRule::new(
        "p",
        "style:background-image",
        @html_parser.UrlRule::new(
          allowed_schemes=["https"],
          proxy=@html_parser.UrlProxy::new("/asset-proxy", param="src"),
        ),
      ),
    ],
  )
  let policy = @html_parser.SanitizationPolicy::new(
    ["a", "img", "p"],
    allowed_attributes={
      "*": [],
      "a": ["href"],
      "img": ["srcset"],
      "p": ["style"],
    },
    allowed_css_properties=["background-image"],
    url_policy~,
  )
  let fragment = @html_parser.parse_fragment(
    "<a href='https://example.com/x?y=1#z'>x</a><a href='http://example.com/x'>bad</a><a href='//example.com/rel'>rel</a><a href='#frag'>frag</a><img srcset='https://example.com/a 1x, /b 2x'><p style=\"background-image: url('https://example.com/c.png')\">p</p>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<a href=\"/proxy?url=https%3A%2F%2Fexample.com%2Fx%3Fy%3D1%23z\">x</a><a>bad</a><a href=\"/proxy?url=https%3A%2F%2Fexample.com%2Frel\">rel</a><a href=\"/proxy?url=%23frag\">frag</a><img srcset=\"/proxy?url=https%3A%2F%2Fexample.com%2Fa 1x, /proxy?url=%2Fb 2x\"><p style=\"background-image: url('/asset-proxy?src=https%3A%2F%2Fexample.com%2Fc.png')\">p</p>",
  )
}

///|
test "sanitize_dom proxy mode fails closed without usable proxy config" {
  let missing_proxy_policy = @html_parser.UrlPolicy::new(
    default_handling=UrlProxy,
    allow_rules=[
      @html_parser.UrlPolicyRule::new(
        "a",
        "href",
        @html_parser.UrlRule::new(allowed_schemes=["https"]),
      ),
    ],
  )
  let missing_policy = @html_parser.SanitizationPolicy::new(
    ["a"],
    allowed_attributes={ "a": ["href"] },
    url_policy=missing_proxy_policy,
  )
  let missing = @html_parser.parse_fragment(
    "<a href='https://example.com/x'>missing</a>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(missing.root, policy=missing_policy).to_html(
      pretty=false,
    ),
    "<a>missing</a>",
  )
  let empty_proxy_policy = @html_parser.UrlPolicy::new(
    default_handling=UrlProxy,
    proxy=@html_parser.UrlProxy::new(""),
    allow_rules=[
      @html_parser.UrlPolicyRule::new(
        "a",
        "href",
        @html_parser.UrlRule::new(allowed_schemes=["https"]),
      ),
    ],
  )
  let empty_policy = @html_parser.SanitizationPolicy::new(
    ["a"],
    allowed_attributes={ "a": ["href"] },
    url_policy=empty_proxy_policy,
  )
  let empty = @html_parser.parse_fragment(
    "<a href='https://example.com/x'>empty</a>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(empty.root, policy=empty_policy).to_html(
      pretty=false,
    ),
    "<a>empty</a>",
  )
}

///|
test "sanitize_dom proxy rejects invalid scheme-like URL prefixes" {
  let url_policy = @html_parser.UrlPolicy::new(
    default_handling=UrlProxy,
    proxy=@html_parser.UrlProxy::new("/proxy"),
    allow_rules=[
      @html_parser.UrlPolicyRule::new(
        "a",
        "href",
        @html_parser.UrlRule::new(allowed_schemes=["https"]),
      ),
      @html_parser.UrlPolicyRule::new(
        "img",
        "srcset",
        @html_parser.UrlRule::new(allowed_schemes=["https"]),
      ),
      @html_parser.UrlPolicyRule::new(
        "p",
        "style:background-image",
        @html_parser.UrlRule::new(allowed_schemes=["https"]),
      ),
    ],
  )
  let policy = @html_parser.SanitizationPolicy::new(
    ["a", "img", "p"],
    allowed_attributes={
      "*": [],
      "a": ["href"],
      "img": ["srcset"],
      "p": ["style"],
    },
    allowed_css_properties=["background-image"],
    url_policy~,
  )
  let fragment = @html_parser.parse_fragment(
    "<a href='1https:foo'>bad</a><a href='ht^tps:foo'>punct</a><a href=':rel'>colon</a><a href='h ttps:foo'>space</a><a href='/ok'>ok</a><img srcset='1https:foo 1x'><p style=\"background-image: url('1https:foo')\">p</p>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<a>bad</a><a>punct</a><a href=\"/proxy?url=%3Arel\">colon</a><a href=\"/proxy?url=h%20ttps%3Afoo\">space</a><a href=\"/proxy?url=%2Fok\">ok</a><img><p>p</p>",
  )
}

///|
test "sanitize_dom rejects malformed URL schemes when relatives are disabled" {
  let url_policy = @html_parser.UrlPolicy::new(default_allow_relative=false, allow_rules=[
    @html_parser.UrlPolicyRule::new(
      "a",
      "href",
      @html_parser.UrlRule::new(allowed_schemes=["https"], allow_relative=false),
    ),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    ["a"],
    allowed_attributes={ "*": [], "a": ["href"] },
    url_policy~,
  )
  let fragment = @html_parser.parse_fragment(
    "<a href='1https:foo'>leading</a><a href='ht^tps:foo'>punct</a><a href='https://example.com/x'>ok</a><a href='/rel'>rel</a>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<a>leading</a><a>punct</a><a href=\"https://example.com/x\">ok</a><a>rel</a>",
  )
}

///|
test "sanitize_dom applies URL filter before validation" {
  let url_filter = @html_parser.UrlFilter::new(fn(_tag, attr, value) {
    match attr {
      "href" =>
        if value == "drop" {
          None
        } else {
          Some("https://trusted.example" + value)
        }
      "srcset" =>
        Some("https://trusted.example/a 1x, https://trusted.example/b 2x")
      "ping" => Some("https://trusted.example/p https://trusted.example/q")
      "style:background-image" => Some("https://trusted.example/bg.png")
      _ => Some(value)
    }
  })
  let url_policy = @html_parser.UrlPolicy::new(url_filter~, allow_rules=[
    @html_parser.UrlPolicyRule::new(
      "a",
      "href",
      @html_parser.UrlRule::new(allowed_schemes=["https"], allowed_hosts=[
        "trusted.example",
      ]),
    ),
    @html_parser.UrlPolicyRule::new(
      "a",
      "ping",
      @html_parser.UrlRule::new(allowed_schemes=["https"], allowed_hosts=[
        "trusted.example",
      ]),
    ),
    @html_parser.UrlPolicyRule::new(
      "img",
      "srcset",
      @html_parser.UrlRule::new(allowed_schemes=["https"], allowed_hosts=[
        "trusted.example",
      ]),
    ),
    @html_parser.UrlPolicyRule::new(
      "p",
      "style:background-image",
      @html_parser.UrlRule::new(allowed_schemes=["https"], allowed_hosts=[
        "trusted.example",
      ]),
    ),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    ["a", "img", "p"],
    allowed_attributes={
      "*": [],
      "a": ["href", "ping"],
      "img": ["srcset"],
      "p": ["style"],
    },
    allowed_css_properties=["background-image"],
    url_policy~,
  )
  let fragment = @html_parser.parse_fragment(
    "<a href='/ok'>ok</a><a href='drop'>drop</a><img srcset='ignored'><a ping='ignored'>ping</a><p style=\"background-image: url('/ignored.png')\">p</p>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<a href=\"https://trusted.example/ok\">ok</a><a>drop</a><img srcset=\"https://trusted.example/a 1x, https://trusted.example/b 2x\"><a ping=\"https://trusted.example/p https://trusted.example/q\">ping</a><p style=\"background-image: url('https://trusted.example/bg.png')\">p</p>",
  )
}

///|
test "sanitize_dom validates css url filter rewrites" {
  let url_filter = @html_parser.UrlFilter::new(fn(_tag, attr, value) {
    match attr {
      "style:background-image" =>
        match value {
          "/drop.png" => None
          "/empty.png" => Some("")
          "/space.png" => Some("/x y")
          "/ok.png" => Some("/proxied.png")
          _ => Some(value)
        }
      _ => Some(value)
    }
  })
  let css_rule = @html_parser.UrlRule::new(
    allowed_schemes=[],
    allow_relative=true,
    resolve_protocol_relative=None,
  )
  let url_policy = @html_parser.UrlPolicy::new(url_filter~, allow_rules=[
    @html_parser.UrlPolicyRule::new("*", "style:background-image", css_rule),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    allowed_attributes={ "p": ["style"] },
    allowed_css_properties=["background-image", "color"],
    url_policy~,
  )
  let fragment = @html_parser.parse_fragment(
    "<p style=\"background-image: url('/drop.png'); color: red\">drop</p><p style=\"background-image: url('/empty.png'); color: blue\">empty</p><p style=\"background-image: url('/space.png'); color: green\">space</p><p style=\"background-image: url('/ok.png'); color: purple\">ok</p>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<p style=\"color: red\">drop</p><p style=\"color: blue\">empty</p><p style=\"color: green\">space</p><p style=\"background-image: url('/proxied.png'); color: purple\">ok</p>",
  )
}

///|
test "sanitize_dom drops URL list attributes when URL filter drops or empties them" {
  let url_filter = @html_parser.UrlFilter::new(fn(_tag, attr, value) {
    match attr {
      "srcset" =>
        if value == "drop-srcset" {
          None
        } else if value == "empty-srcset" {
          Some(" \t\n ")
        } else {
          Some(value)
        }
      "ping" => if value == "drop-ping" { None } else { Some(value) }
      "attributionsrc" =>
        if value == "empty-list" {
          Some(" \t\n ")
        } else {
          Some(value)
        }
      _ => Some(value)
    }
  })
  let trusted_rule = @html_parser.UrlRule::new(allowed_schemes=["https"], allowed_hosts=[
    "trusted.example",
  ])
  let url_policy = @html_parser.UrlPolicy::new(url_filter~, allow_rules=[
    @html_parser.UrlPolicyRule::new("a", "href", trusted_rule),
    @html_parser.UrlPolicyRule::new("a", "ping", trusted_rule),
    @html_parser.UrlPolicyRule::new("img", "src", trusted_rule),
    @html_parser.UrlPolicyRule::new("img", "srcset", trusted_rule),
    @html_parser.UrlPolicyRule::new("img", "attributionsrc", trusted_rule),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    ["a", "img"],
    allowed_attributes={
      "a": ["href", "ping"],
      "img": ["src", "srcset", "attributionsrc"],
    },
    url_policy~,
  )
  let fragment = @html_parser.parse_fragment(
    "<img srcset='drop-srcset'><img srcset='empty-srcset'><a href='https://trusted.example/x' ping='drop-ping'>ping</a><img src='https://trusted.example/i.png' attributionsrc='empty-list'>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<img><img><a href=\"https://trusted.example/x\">ping</a><img src=\"https://trusted.example/i.png\">",
  )
}

///|
test "sanitize_dom normalizes srcset candidates atomically" {
  let trusted_rule = @html_parser.UrlRule::new(
    allowed_schemes=["https"],
    allowed_hosts=["trusted.example"],
    allow_relative=false,
  )
  let url_policy = @html_parser.UrlPolicy::new(default_allow_relative=false, allow_rules=[
    @html_parser.UrlPolicyRule::new("img", "srcset", trusted_rule),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    ["img"],
    allowed_attributes={ "*": [], "img": ["srcset"] },
    url_policy~,
  )
  let fragment = @html_parser.parse_fragment(
    "<img srcset=', https://trusted.example/a.png, , https://trusted.example/b.png 2x, '><img srcset=', , '><img srcset='https://trusted.example/a.png, https://evil.example/b.png 2x'><img srcset='https://evil.example/b.png 2x, https://trusted.example/a.png'><img srcset='https://trusted.example/c.png 1x'>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<img srcset=\"https://trusted.example/a.png, https://trusted.example/b.png 2x\"><img><img><img><img srcset=\"https://trusted.example/c.png 1x\">",
  )
}

///|
test "sanitize_dom normalizes whitespace URL lists atomically" {
  let trusted_rule = @html_parser.UrlRule::new(
    allowed_schemes=["https"],
    allowed_hosts=["trusted.example"],
    allow_relative=false,
  )
  let url_policy = @html_parser.UrlPolicy::new(default_allow_relative=false, allow_rules=[
    @html_parser.UrlPolicyRule::new("a", "ping", trusted_rule),
    @html_parser.UrlPolicyRule::new("img", "attributionsrc", trusted_rule),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    ["a", "img"],
    allowed_attributes={ "*": [], "a": ["ping"], "img": ["attributionsrc"] },
    url_policy~,
  )
  let fragment = @html_parser.parse_fragment(
    "<a ping=' https://trusted.example/a  https://trusted.example/b '>ok</a><a ping='   '>empty</a><a ping='https://trusted.example/a https://evil.example/b'>bad-final</a><a ping='https://evil.example/b https://trusted.example/a'>bad-first</a><img attributionsrc=' https://trusted.example/i  https://trusted.example/j '>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<a ping=\"https://trusted.example/a https://trusted.example/b\">ok</a><a>empty</a><a>bad-final</a><a>bad-first</a><img attributionsrc=\"https://trusted.example/i https://trusted.example/j\">",
  )
}

///|
test "sanitize_dom enforces URL host allowlists on parsed authorities" {
  let host_rule = @html_parser.UrlRule::new(
    allowed_schemes=["https", "mailto"],
    allowed_hosts=["trusted.example", "::1"],
    allow_relative=false,
  )
  let url_policy = @html_parser.UrlPolicy::new(default_allow_relative=false, allow_rules=[
    @html_parser.UrlPolicyRule::new("a", "href", host_rule),
    @html_parser.UrlPolicyRule::new("img", "src", host_rule),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    ["a", "img"],
    allowed_attributes={ "*": [], "a": ["href"], "img": ["src"] },
    url_policy~,
  )
  let fragment = @html_parser.parse_fragment(
    "<a href='//evil.example/x'>proto-bad</a><a href='//trusted.example/x'>proto-ok</a><a href='https://user:pw@trusted.example:8443/x'>userinfo</a><a href='https://[::1]/x'>ipv6</a><a href='https://[]/x'>empty-ipv6</a><a href='https://[::1]x/y'>bad-bracket</a><a href='https://:443/x'>empty-host-port</a><a href='https://'>empty-absolute</a><a href='https://trusted.example?x=1'>query</a><a href='mailto:user@example.com'>mailto</a><img src='https://trusted.example/i.png'><img src='https://evil.example/i.png'>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<a>proto-bad</a><a href=\"https://trusted.example/x\">proto-ok</a><a href=\"https://user:pw@trusted.example:8443/x\">userinfo</a><a href=\"https://[::1]/x\">ipv6</a><a>empty-ipv6</a><a>bad-bracket</a><a>empty-host-port</a><a>empty-absolute</a><a href=\"https://trusted.example?x=1\">query</a><a>mailto</a><img src=\"https://trusted.example/i.png\"><img>",
  )
}

///|
test "css_preset_text allows conservative inline text styling" {
  let policy = @html_parser.SanitizationPolicy::new(
    ["div"],
    allowed_attributes={ "*": [], "div": ["style"] },
    allowed_css_properties=@html_parser.css_preset_text(),
  )
  let styled = @html_parser.parse_fragment(
    "<div style='color: red; position: fixed; top: 0'>x</div><div style='position: fixed'>y</div>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(styled.root, policy~).to_html(pretty=false),
    "<div style=\"color: red\">x</div><div>y</div>",
  )

  let mutated = @html_parser.css_preset_text()
  mutated.clear()
  let fresh = @html_parser.SanitizationPolicy::new(
    ["span"],
    allowed_attributes={ "span": ["style"] },
    allowed_css_properties=@html_parser.css_preset_text(),
  )
  let span = @html_parser.parse_fragment(
    "<span style='font-weight: 700'>ok</span>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(span.root, policy=fresh).to_html(pretty=false),
    "<span style=\"font-weight: 700\">ok</span>",
  )
}

///|
test "sanitize_dom hardens allowed rawtext element contents" {
  let policy = @html_parser.SanitizationPolicy::new(
    ["style", "script", "img", "span"],
    allowed_attributes={ "img": ["src", "alt"], "span": [] },
    drop_content_tags=[],
  )
  let style = @html_parser.element("style", children=[
    @html_parser.text("</sty"),
    @html_parser.text("le><img src=x onerror=1>"),
  ])
  let script = @html_parser.element("script", children=[
    @html_parser.text("a"),
    @html_parser.element("span", children=[@html_parser.text("ignored")]),
    @html_parser.text("</script><img src=x onerror=1>"),
  ])
  let fragment = @html_parser.fragment(children=[style, script])
  let clean = @html_parser.sanitize_dom(fragment, policy~)
  let out = clean.to_html(pretty=false)
  assert_eq(
    out, "<style>&lt;/style><img src=x onerror=1></style><script>a&lt;/script><img src=x onerror=1></script>",
  )
  let reparsed = @html_parser.parse_fragment(out, sanitize=false)
  assert_eq(reparsed.query("img").length(), 0)
}

///|
test "sanitize_dom preserves empty rawtext and disabled invisible stripping" {
  let policy = @html_parser.SanitizationPolicy::new(
    ["div", "style", "script"],
    allowed_attributes={ "div": [], "style": [], "script": [] },
    drop_content_tags=[],
    strip_invisible_unicode=false,
  )
  let fragment = @html_parser.fragment(children=[
    @html_parser.element("div", children=[
      @html_parser.element("style"),
      @html_parser.element("script"),
      @html_parser.element("style", children=[@html_parser.text("a\u{200B}b")]),
    ]),
  ])
  assert_eq(
    @html_parser.sanitize_dom(fragment, policy~).to_html(pretty=false),
    "<div><style></style><script></script><style>a\u{200B}b</style></div>",
  )
}

///|
test "sanitize_dom neutralizes rawtext end tag boundaries only" {
  let policy = @html_parser.SanitizationPolicy::new(["style"], drop_content_tags=[])
  let fragment = @html_parser.fragment(children=[
    @html_parser.element("style", children=[
      @html_parser.text("</stylex> ok </style"),
    ]),
  ])
  let out = @html_parser.sanitize_dom(fragment, policy~).to_html(pretty=false)
  assert_eq(out, "<style></stylex> ok &lt;/style</style>")
  let reparsed = @html_parser.parse_fragment(out, sanitize=false)
  assert_eq(reparsed.query("style").length(), 1)
}

///|
test "sanitize_dom hardens rawtext inside template children" {
  let policy = @html_parser.SanitizationPolicy::new(
    ["template", "style", "img"],
    allowed_attributes={ "template": [], "img": ["src"] },
    drop_content_tags=[],
  )
  let fragment = @html_parser.fragment(children=[
    @html_parser.element("template", children=[
      @html_parser.element("style", children=[
        @html_parser.text("</style><img src=x>"),
      ]),
    ]),
  ])
  let out = @html_parser.sanitize_dom(fragment, policy~).to_html(pretty=false)
  assert_eq(out, "<template><style>&lt;/style><img src=x></style></template>")
  let reparsed = @html_parser.parse_fragment(out, sanitize=false)
  assert_eq(reparsed.query("img").length(), 0)
}

///|
test "sanitize_dom filters allowed style rawtext resource loads" {
  let policy = @html_parser.SanitizationPolicy::new(["style"], drop_content_tags=[])
  let fragment = @html_parser.parse_fragment(
    "<style>body{background:u\u{200B}rl(/x.png)}</style><style>body{color:red}</style>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<style></style><style>body{color:red}</style>",
  )
}

///|
test "sanitize_dom filters mixed-case style rawtext resource loads" {
  let policy = @html_parser.SanitizationPolicy::new(["style"], drop_content_tags=[])
  let style = @html_parser.element("StYlE", children=[
    @html_parser.text("@import 'https://evil.example/x.css';"),
  ])
  assert_eq(
    @html_parser.sanitize_dom(style, policy~).to_html(pretty=false),
    "<StYlE></StYlE>",
  )
}

///|
test "sanitize_dom strips html descendants inside foreign text integration points" {
  let policy = @html_parser.SanitizationPolicy::new(
    ["svg", "title", "desc", "script", "img", "b", "math", "mtext"],
    allowed_attributes={ "img": ["src"] },
    drop_foreign_namespaces=false,
    drop_content_tags=[],
  )
  let fragment = @html_parser.parse_fragment(
    "<svg><title>He\u{200B}llo<script>bad</script><img src='/x'></title><desc>World<b>drop</b></desc></svg><math><mtext>Hi<script>bad</script><img src='/x'></mtext></math>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<svg><title>Hello</title><desc>World</desc></svg><math><mtext>Hi</mtext></math>",
  )
}

///|
test "sanitize_dom preserves math marker exceptions in text integration points" {
  let policy = @html_parser.SanitizationPolicy::new(
    ["math", "mtext", "mglyph", "malignmark", "mi"],
    drop_foreign_namespaces=false,
    drop_content_tags=[],
  )
  let fragment = @html_parser.parse_fragment(
    "<math><mtext>Hello<mglyph></mglyph><malignmark></malignmark><mi>drop</mi></mtext></math>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<math><mtext>Hello<mglyph></mglyph><malignmark></malignmark></mtext></math>",
  )
  let programmatic = @html_parser.element("math", ns="math", children=[
    @html_parser.element("mtext", ns="math", children=[
      @html_parser.text("Hello"),
      @html_parser.element("mglyph", ns="math"),
      @html_parser.element("mglyph", ns="html"),
      @html_parser.element("malignmark", ns="math"),
      @html_parser.element("malignmark", ns="html"),
      @html_parser.element("mi", ns="math", children=[@html_parser.text("drop")]),
    ]),
  ])
  assert_eq(
    @html_parser.sanitize_dom(programmatic, policy~).to_html(pretty=false),
    "<math><mtext>Hello<mglyph></mglyph><malignmark></malignmark></mtext></math>",
  )
}

///|
test "sanitize_dom drops active foreign mutation tags when allowlisted" {
  let url_policy = @html_parser.UrlPolicy::new(allow_rules=[
    @html_parser.UrlPolicyRule::new(
      "image",
      "href",
      @html_parser.UrlRule::new(
        allowed_schemes=[],
        allow_fragment=true,
        allow_relative=false,
      ),
    ),
    @html_parser.UrlPolicyRule::new(
      "set",
      "href",
      @html_parser.UrlRule::new(
        allowed_schemes=[],
        allow_fragment=true,
        allow_relative=false,
      ),
    ),
    @html_parser.UrlPolicyRule::new(
      "animate",
      "href",
      @html_parser.UrlRule::new(
        allowed_schemes=[],
        allow_fragment=true,
        allow_relative=false,
      ),
    ),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    [
      "svg", "image", "set", "animate", "foreignobject", "script", "math", "annotation-xml",
    ],
    allowed_attributes={
      "image": ["id", "href", "width", "height"],
      "set": ["href", "attributeName", "to", "begin"],
      "animate": ["href", "attributeName", "values", "dur"],
      "annotation-xml": ["encoding"],
    },
    url_policy~,
    drop_foreign_namespaces=false,
    drop_content_tags=[],
  )
  let fragment = @html_parser.parse_fragment(
    "<svg><image id='img' href='#ok' width='10' height='10'></image><set href='#img' attributeName='href' to='https://evil.example/pwn' begin='0s'></set><animate href='#img' attributeName='href' values='https://evil.example/pwn;#ok' dur='1s'></animate><foreignObject><script>bad</script></foreignObject></svg><math><annotation-xml encoding='text/html'><script>bad</script></annotation-xml></math>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<svg><image id=\"img\" href=\"#ok\" width=\"10\" height=\"10\"></image></svg><math></math>",
  )
}

///|
test "sanitize_dom raise mode reports active foreign mutation tags" {
  let fragment_rule = @html_parser.UrlRule::new(
    allowed_schemes=[],
    allow_relative=false,
    allow_fragment=true,
  )
  let policy = @html_parser.SanitizationPolicy::new(
    ["svg", "image", "set"],
    allowed_attributes={
      "image": ["id", "href", "width", "height"],
      "set": ["href", "attributeName", "to", "begin"],
    },
    url_policy=@html_parser.UrlPolicy::new(allow_rules=[
      @html_parser.UrlPolicyRule::new("image", "href", fragment_rule),
      @html_parser.UrlPolicyRule::new("set", "href", fragment_rule),
    ]),
    drop_foreign_namespaces=false,
    drop_content_tags=[],
    unsafe_handling=Raise,
  )
  let svg = @html_parser.element("svg", ns="svg", children=[
    @html_parser.element("image", ns="svg", attrs={
      "id": Some("img"),
      "href": Some("#ok"),
      "width": Some("10"),
      "height": Some("10"),
    }),
    @html_parser.element("set", ns="svg", attrs={
      "href": Some("#img"),
      "attributeName": Some("href"),
      "to": Some("https://evil.example/pwn"),
      "begin": Some("0s"),
    }),
  ])
  let result : Result[@html_parser.Node, @html_parser.HtmlError] = try? @html_parser.sanitize_dom(
    svg,
    policy~,
  )
  match result {
    Err(UnsafeHtml(message)) =>
      assert_eq(
        message, "Unsafe tag 'set' was dropped because it can mutate foreign content",
      )
    _ => fail("expected active foreign content to raise UnsafeHtml")
  }
}

///|
test "sanitize_dom treats html namespace svg roots as foreign for active tags" {
  let policy = @html_parser.SanitizationPolicy::new(
    ["svg", "rect", "set"],
    allowed_attributes={ "rect": ["width"], "set": ["begin"] },
    drop_foreign_namespaces=false,
    drop_content_tags=[],
  )
  let svg = @html_parser.element("svg", ns="html", children=[
    @html_parser.element("set", ns="html", attrs={ "begin": Some("0s") }),
    @html_parser.element("rect", ns="html", attrs={ "width": Some("10") }),
  ])
  assert_eq(
    @html_parser.sanitize_dom(svg, policy~).to_html(pretty=false),
    "<svg><rect width=\"10\"></rect></svg>",
  )
}

///|
test "sanitize_dom drops html namespace foreign roots when namespace dropping is enabled" {
  let policy = @html_parser.SanitizationPolicy::new(
    ["svg", "rect", "math", "mtext", "p"],
    allowed_attributes={ "rect": ["width"], "p": ["id"] },
    drop_foreign_namespaces=true,
    drop_content_tags=[],
  )
  let fragment = @html_parser.fragment(children=[
    @html_parser.element("svg", ns="html", children=[
      @html_parser.element("rect", ns="html", attrs={ "width": Some("10") }),
    ]),
    @html_parser.element("math", ns="html", children=[
      @html_parser.element("mtext", ns="html", children=[@html_parser.text("x")]),
    ]),
    @html_parser.element("p", ns="html", attrs={ "id": Some("kept") }),
  ])
  assert_eq(
    @html_parser.sanitize_dom(fragment, policy~).to_html(pretty=false),
    "<p id=\"kept\"></p>",
  )
}

///|
test "sanitize_dom stabilizes foreign namespace mXSS after reparse" {
  let url_policy = @html_parser.UrlPolicy::new(allow_rules=[
    @html_parser.UrlPolicyRule::new(
      "img",
      "src",
      @html_parser.UrlRule::new(
        allowed_schemes=[],
        allow_relative=true,
        resolve_protocol_relative=None,
      ),
    ),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    ["form", "math", "mtext", "mglyph", "style", "img"],
    allowed_attributes={ "img": ["src"] },
    url_policy~,
    drop_foreign_namespaces=false,
    drop_content_tags=[],
  )
  let parsed = @html_parser.parse_fragment(
    "<form><math><mtext></form><form><mglyph><style></math><img src onerror=alert(1)>",
    sanitize=false,
  )
  let sanitized = @html_parser.sanitize_dom(parsed.root, policy~)
  assert_eq(
    sanitized.to_html(pretty=false),
    "<form><math><mtext></mtext></math></form>",
  )
  let reparsed = @html_parser.parse_fragment(
    sanitized.to_html(pretty=false),
    sanitize=false,
  )
  assert_eq(
    reparsed.to_html(pretty=false),
    "<form><math><mtext></mtext></math></form>",
  )
}

///|
test "sanitize_dom stabilizes cloned foreign namespace mXSS after reparse" {
  let url_policy = @html_parser.UrlPolicy::new(allow_rules=[
    @html_parser.UrlPolicyRule::new(
      "img",
      "src",
      @html_parser.UrlRule::new(
        allowed_schemes=[],
        allow_relative=true,
        resolve_protocol_relative=None,
      ),
    ),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    ["form", "math", "mtext", "mglyph", "style", "img"],
    allowed_attributes={ "img": ["src"] },
    url_policy~,
    drop_foreign_namespaces=false,
    drop_content_tags=[],
  )
  let parsed = @html_parser.parse_fragment(
    "<form><math><mtext></form><form><mglyph><style></math><img src onerror=alert(1)>",
    sanitize=false,
  )
  let original = parsed.to_html(pretty=false)
  let clone = parsed.root.clone_node(deep=true)
  let sanitized = @html_parser.sanitize_dom(clone, policy~)
  assert_eq(
    sanitized.to_html(pretty=false),
    "<form><math><mtext></mtext></math></form>",
  )
  assert_eq(parsed.to_html(pretty=false), original)
  let reparsed = @html_parser.parse_fragment(
    sanitized.to_html(pretty=false),
    sanitize=false,
  )
  assert_eq(
    reparsed.to_html(pretty=false),
    "<form><math><mtext></mtext></math></form>",
  )
}

///|
test "sanitize_dom stabilizes foreign namespace mXSS for document roots" {
  let url_policy = @html_parser.UrlPolicy::new(allow_rules=[
    @html_parser.UrlPolicyRule::new(
      "img",
      "src",
      @html_parser.UrlRule::new(
        allowed_schemes=[],
        allow_relative=true,
        resolve_protocol_relative=None,
      ),
    ),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    ["html", "head", "body", "form", "math", "mtext", "mglyph", "style", "img"],
    allowed_attributes={ "img": ["src"] },
    url_policy~,
    drop_foreign_namespaces=false,
    drop_content_tags=[],
    drop_doctype=false,
  )
  let parsed = @html_parser.parse(
    "<!DOCTYPE html><html><head></head><body><form><math><mtext></form><form><mglyph><style></math><img src onerror=1></body></html>",
    sanitize=false,
  )
  let sanitized = @html_parser.sanitize_dom(parsed.root, policy~)
  assert_eq(
    sanitized.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body><form><math><mtext></mtext></math></form></body></html>",
  )
}

///|
test "sanitize_dom drops active foreign integration points during stabilization" {
  let url_policy = @html_parser.UrlPolicy::new(allow_rules=[
    @html_parser.UrlPolicyRule::new(
      "img",
      "src",
      @html_parser.UrlRule::new(
        allowed_schemes=[],
        allow_relative=true,
        resolve_protocol_relative=None,
      ),
    ),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    ["svg", "style", "img"],
    allowed_attributes={ "img": ["src"] },
    url_policy~,
    drop_foreign_namespaces=false,
    drop_content_tags=[],
  )
  let parsed = @html_parser.parse_fragment(
    "<svg><foreignObject><style></svg><img src onerror=1>",
    sanitize=false,
  )
  guard parsed.root.children().get(0) is Some(svg) else {
    fail("expected svg root child")
  }
  let sanitized = @html_parser.sanitize_dom(svg, policy~)
  assert_eq(sanitized.to_html(pretty=false), "<svg></svg>")
  let reparsed = @html_parser.parse_fragment(
    sanitized.to_html(pretty=false),
    sanitize=false,
  )
  assert_eq(reparsed.to_html(pretty=false), "<svg></svg>")
}

///|
test "sanitize_dom can return fragment after foreign stabilization" {
  let url_policy = @html_parser.UrlPolicy::new(allow_rules=[
    @html_parser.UrlPolicyRule::new(
      "img",
      "src",
      @html_parser.UrlRule::new(
        allowed_schemes=[],
        allow_relative=true,
        resolve_protocol_relative=None,
      ),
    ),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    ["svg", "img"],
    allowed_attributes={ "img": ["src"] },
    url_policy~,
    drop_foreign_namespaces=false,
    drop_content_tags=[],
  )
  let parsed = @html_parser.parse_fragment(
    "<foo><svg></svg><img src onerror=1></foo>",
    sanitize=false,
  )
  guard parsed.root.children().get(0) is Some(foo) else {
    fail("expected foo root child")
  }
  let sanitized = @html_parser.sanitize_dom(foo, policy~)
  assert_true(sanitized.kind() is Fragment)
  assert_eq(sanitized.to_html(pretty=false), "<svg></svg><img>")
}

///|
test "sanitize_dom preserves allowed template content" {
  let policy = @html_parser.SanitizationPolicy::new(
    ["template", "p"],
    allowed_attributes={ "template": [], "p": [] },
    drop_foreign_namespaces=false,
    drop_content_tags=[],
  )
  let template = @html_parser.element("template", children=[
    @html_parser.element("p", children=[@html_parser.text("x")]),
  ])
  assert_eq(
    @html_parser.sanitize_dom(template, policy~).to_html(pretty=false),
    "<template><p>x</p></template>",
  )
}

///|
test "sanitize_dom unwraps disallowed template content" {
  let policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    allowed_attributes={ "*": [], "p": [] },
    drop_foreign_namespaces=false,
    drop_content_tags=[],
  )
  let fragment = @html_parser.parse_fragment(
    "<template><p>ok</p></template>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<p>ok</p>",
  )
}

///|
test "sanitize_dom drops foreign url function attributes without url policy" {
  let policy = @html_parser.SanitizationPolicy::new(
    ["svg", "rect"],
    allowed_attributes={
      "rect": ["fill", "filter", "marker-start", "stroke", "width", "height"],
    },
    drop_foreign_namespaces=false,
    drop_content_tags=[],
  )
  let parsed = @html_parser.parse_fragment(
    "<svg><rect width='10' height='10' fill='url(https://evil.example/fill.svg#x) red' filter='URL ( #shadow )' marker-start='image-set(/x.png 1x)' stroke='u/**/rl(#paint)'></rect><rect fill='red' marker-start='none'></rect></svg>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(parsed.root, policy~).to_html(pretty=false),
    "<svg><rect width=\"10\" height=\"10\"></rect><rect fill=\"red\" marker-start=\"none\"></rect></svg>",
  )
  let svg = @html_parser.element("svg", ns="html", children=[
    @html_parser.element("rect", ns="html", attrs={
      "fill": Some("url(https://evil.example/fill.svg#x)"),
      "width": Some("10"),
    }),
  ])
  assert_eq(
    @html_parser.sanitize_dom(svg, policy~).to_html(pretty=false),
    "<svg><rect width=\"10\"></rect></svg>",
  )
}

///|
test "sanitize_dom filters foreign url function attributes with exact rules" {
  let url_filter = @html_parser.UrlFilter::new(fn(tag, attr, value) {
    if tag == "rect" && attr == "fill" && value == "#grad" {
      Some("#rewritten")
    } else {
      None
    }
  })
  let policy = @html_parser.SanitizationPolicy::new(
    ["svg", "rect"],
    allowed_attributes={ "rect": ["fill", "width", "height", "filter"] },
    url_policy=@html_parser.UrlPolicy::new(url_filter~, allow_rules=[
      @html_parser.UrlPolicyRule::new(
        "rect",
        "fill",
        @html_parser.UrlRule::new(
          allowed_schemes=[],
          allow_relative=false,
          allow_fragment=true,
          resolve_protocol_relative=None,
        ),
      ),
    ]),
    drop_foreign_namespaces=false,
    drop_content_tags=[],
  )
  let parsed = @html_parser.parse_fragment(
    "<svg><rect width='10' height='10' fill='url(#grad) red'></rect><rect width='10' height='10' filter='url(#grad)'></rect></svg>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(parsed.root, policy~).to_html(pretty=false),
    "<svg><rect width=\"10\" height=\"10\" fill=\"url('#rewritten') red\"></rect><rect width=\"10\" height=\"10\"></rect></svg>",
  )
}

///|
test "sanitize_dom drops meta refresh content attributes" {
  let policy = @html_parser.SanitizationPolicy::new(
    ["meta", "p"],
    allowed_attributes={ "meta": ["http-equiv", "content"] },
    drop_content_tags=[],
  )
  let fragment = @html_parser.parse_fragment(
    "<meta http-equiv='refresh' content='0;url=javascript:alert(1)'><meta http-equiv='Content-Type' content='text/html; charset=utf-8'><p>ok</p>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<meta http-equiv=\"refresh\"><meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\"><p>ok</p>",
  )
}

///|
test "sanitize_dom drops base href even when allowlisted" {
  let policy = @html_parser.SanitizationPolicy::new(
    ["base", "img"],
    allowed_attributes={ "base": ["href"], "img": ["src"] },
    drop_content_tags=[],
  )
  let fragment = @html_parser.parse_fragment(
    "<base Href='https://evil.example/assets/'><img src='pixel'>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<base><img src=\"pixel\">",
  )
}

///|
test "sanitize_dom drops url-like attributes without exact url rules" {
  let policy = @html_parser.SanitizationPolicy::new(
    ["a", "img", "blockquote", "object", "p", "form", "button", "video"],
    allowed_attributes={
      "a": ["href", "ping"],
      "img": ["src", "srcset", "attributionsrc", "poster"],
      "video": ["poster"],
      "form": ["action"],
      "button": ["formaction"],
      "blockquote": ["cite"],
      "object": ["data"],
      "p": ["background", "data-x"],
    },
    url_policy=@html_parser.UrlPolicy::new(allow_rules=[]),
    drop_content_tags=[],
  )
  let fragment = @html_parser.parse_fragment(
    "<a href='https://example.com' ping='https://trusted.example/p https://evil.example/p'>x</a><img src='/ok.png' srcset='/one.png 1x' attributionsrc='https://evil.example/register' poster='/poster.png'><video poster='/poster.png'></video><form action='/submit'></form><button formaction='/submit'>go</button><blockquote cite='https://evil.example/q'></blockquote><object data='/payload'></object><p background='/bg.png' data-x='ok'>t</p>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<a>x</a><img><video></video><form></form><button>go</button><blockquote></blockquote><object></object><p data-x=\"ok\">t</p>",
  )
}

///|
test "sanitize_dom applies single url-like attribute rules" {
  let remote_rule = @html_parser.UrlRule::new(
    allowed_schemes=["https"],
    allowed_hosts=["trusted.example"],
    allow_relative=false,
  )
  let url_policy = @html_parser.UrlPolicy::new(allow_rules=[
    @html_parser.UrlPolicyRule::new("video", "poster", remote_rule),
    @html_parser.UrlPolicyRule::new("form", "action", remote_rule),
    @html_parser.UrlPolicyRule::new("button", "formaction", remote_rule),
    @html_parser.UrlPolicyRule::new("blockquote", "cite", remote_rule),
    @html_parser.UrlPolicyRule::new("object", "data", remote_rule),
    @html_parser.UrlPolicyRule::new("p", "background", remote_rule),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    ["video", "form", "button", "blockquote", "object", "p"],
    allowed_attributes={
      "video": ["poster"],
      "form": ["action"],
      "button": ["formaction"],
      "blockquote": ["cite"],
      "object": ["data"],
      "p": ["background"],
    },
    url_policy~,
    drop_content_tags=[],
  )
  let fragment = @html_parser.parse_fragment(
    "<video poster='https://trusted.example/poster.png'></video><video poster='https://evil.example/poster.png'></video><form action='//trusted.example/submit'></form><button formaction='https://trusted.example/send'>go</button><blockquote cite='https://trusted.example/q'></blockquote><object data='https://trusted.example/payload'></object><p background='https://trusted.example/bg.png'>ok</p><p background='/relative.png'>rel</p>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<video poster=\"https://trusted.example/poster.png\"></video><video></video><form action=\"https://trusted.example/submit\"></form><button formaction=\"https://trusted.example/send\">go</button><blockquote cite=\"https://trusted.example/q\"></blockquote><object data=\"https://trusted.example/payload\"></object><p background=\"https://trusted.example/bg.png\">ok</p><p>rel</p>",
  )
}

///|
test "sanitize_dom applies custom url policy rules" {
  let url_policy = @html_parser.UrlPolicy::new(
    default_handling=UrlStrip,
    default_allow_relative=false,
    allow_rules=[
      @html_parser.UrlPolicyRule::new(
        "a",
        "href",
        @html_parser.UrlRule::new(
          allowed_schemes=["https"],
          allow_fragment=false,
          allow_relative=false,
          handling=UrlAllow,
        ),
      ),
      @html_parser.UrlPolicyRule::new(
        "img",
        "src",
        @html_parser.UrlRule::new(
          allowed_schemes=["https"],
          allow_relative=false,
          resolve_protocol_relative=None,
        ),
      ),
    ],
  )
  let policy = @html_parser.SanitizationPolicy::new(
    ["a", "img"],
    allowed_attributes={ "a": ["href"], "img": ["src"] },
    url_policy~,
  )
  let fragment = @html_parser.parse_fragment(
    "<a href='http://drop.test/'>http</a><a href='https://ok.test/'>https</a><a href='/rel'>rel</a><a href='#frag'>frag</a><a href='//ok.test/path'>proto</a><img src='https://ok.test/i.png'><img src='/rel.png'>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<a>http</a><a href=\"https://ok.test/\">https</a><a>rel</a><a>frag</a><a href=\"https://ok.test/path\">proto</a><img><img>",
  )
}

///|
test "sanitize_dom drops empty url values" {
  let url_policy = @html_parser.UrlPolicy::new(allow_rules=[
    @html_parser.UrlPolicyRule::new(
      "a",
      "href",
      @html_parser.UrlRule::new(allowed_schemes=["https"], allow_relative=false),
    ),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    ["a"],
    allowed_attributes={ "a": ["href"] },
    url_policy~,
  )
  let fragment = @html_parser.parse_fragment(
    "<a href=' \t\n'></a>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<a></a>",
  )
}

///|
test "sanitize_dom drops decoded control characters in url values" {
  let url_policy = @html_parser.UrlPolicy::new(allow_rules=[
    @html_parser.UrlPolicyRule::new(
      "a",
      "href",
      @html_parser.UrlRule::new(
        allowed_schemes=["https"],
        allowed_hosts=["example.com"],
        allow_relative=false,
      ),
    ),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    ["a"],
    allowed_attributes={ "a": ["href"] },
    url_policy~,
  )
  let fragment = @html_parser.parse_fragment(
    "<a href='https://example.com/a&#10;b'>lf</a><a href='https://example.com/a&#x7F;b'>del</a><a href='https://example.com/a\\b'>slash</a><a href='https://example.com/ok'>ok</a>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<a>lf</a><a>del</a><a>slash</a><a href=\"https://example.com/ok\">ok</a>",
  )
}

///|
test "sanitize_dom applies url policy host allowlists" {
  let url_policy = @html_parser.UrlPolicy::new(allow_rules=[
    @html_parser.UrlPolicyRule::new(
      "a",
      "href",
      @html_parser.UrlRule::new(
        allowed_schemes=["https"],
        allowed_hosts=["trusted.example", "::1"],
        allow_relative=false,
      ),
    ),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    ["a"],
    allowed_attributes={ "a": ["href"] },
    url_policy~,
  )
  let fragment = @html_parser.parse_fragment(
    "<a href='https://trusted.example/path'>ok</a><a href='https://TRUSTED.example/case'>case</a><a href='https://trusted.example:443/port'>port</a><a href='https://user@trusted.example/userinfo'>userinfo</a><a href='https://[::1]/ip'>ipv6</a><a href='//trusted.example/proto'>proto</a><a href='https://evil.example/path'>evil</a><a href='https://ex[ample].com/path'>bad-bracket</a><a href='https://[::1'>missing-bracket</a><a href='https://evil.example\\@trusted.example/path'>backslash</a><a href='/relative'>relative</a>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<a href=\"https://trusted.example/path\">ok</a><a href=\"https://TRUSTED.example/case\">case</a><a href=\"https://trusted.example:443/port\">port</a><a href=\"https://user@trusted.example/userinfo\">userinfo</a><a href=\"https://[::1]/ip\">ipv6</a><a href=\"https://trusted.example/proto\">proto</a><a>evil</a><a>bad-bracket</a><a>missing-bracket</a><a>backslash</a><a>relative</a>",
  )
}

///|
test "sanitize_dom applies srcset url policy rules" {
  let srcset_rule = @html_parser.UrlRule::new(
    allowed_schemes=["https"],
    allowed_hosts=["trusted.example"],
    allow_relative=false,
  )
  let url_policy = @html_parser.UrlPolicy::new(allow_rules=[
    @html_parser.UrlPolicyRule::new("img", "srcset", srcset_rule),
    @html_parser.UrlPolicyRule::new("link", "imagesrcset", srcset_rule),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    ["img", "link"],
    allowed_attributes={
      "img": ["srcset"],
      "link": ["rel", "as", "imagesrcset"],
    },
    url_policy~,
    drop_content_tags=[],
  )
  let fragment = @html_parser.parse_fragment(
    "<img srcset=' https://trusted.example/a 1x, , //trusted.example/b 2x '><img srcset='https://trusted.example/a 1x, https://evil.example/b 2x'><img srcset='  \t\n  '><link rel='preload' as='image' imagesrcset='https://trusted.example/a 1x, https://trusted.example/b 2x'><link rel='preload' as='image' imagesrcset='https://evil.example/a 1x'>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<img srcset=\"https://trusted.example/a 1x, https://trusted.example/b 2x\"><img><img><link rel=\"preload\" as=\"image\" imagesrcset=\"https://trusted.example/a 1x, https://trusted.example/b 2x\"><link rel=\"preload\" as=\"image\">",
  )
}

///|
test "sanitize_dom applies space separated url list rules" {
  let url_list_rule = @html_parser.UrlRule::new(
    allowed_schemes=["https"],
    allowed_hosts=["trusted.example"],
    allow_relative=false,
  )
  let url_policy = @html_parser.UrlPolicy::new(allow_rules=[
    @html_parser.UrlPolicyRule::new("a", "href", url_list_rule),
    @html_parser.UrlPolicyRule::new("a", "ping", url_list_rule),
    @html_parser.UrlPolicyRule::new("img", "src", url_list_rule),
    @html_parser.UrlPolicyRule::new("img", "attributionsrc", url_list_rule),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    ["a", "img"],
    allowed_attributes={
      "a": ["href", "ping"],
      "img": ["src", "attributionsrc"],
    },
    url_policy~,
  )
  let fragment = @html_parser.parse_fragment(
    "<a href='https://trusted.example/x' ping=' https://trusted.example/p   //trusted.example/q '>ok</a><a href='https://trusted.example/x' ping='https://trusted.example/p https://evil.example/p'>bad</a><a href='https://trusted.example/x' ping='  \t\n  '>empty</a><img src='https://trusted.example/x.png' attributionsrc='https://trusted.example/register https://trusted.example/measure'><img src='https://trusted.example/x.png' attributionsrc='https://trusted.example/register https://evil.example/register'>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<a href=\"https://trusted.example/x\" ping=\"https://trusted.example/p https://trusted.example/q\">ok</a><a href=\"https://trusted.example/x\">bad</a><a href=\"https://trusted.example/x\">empty</a><img src=\"https://trusted.example/x.png\" attributionsrc=\"https://trusted.example/register https://trusted.example/measure\"><img src=\"https://trusted.example/x.png\">",
  )
}

///|
test "sanitize_dom handles standalone nodes and url edge cases" {
  let allowed = @html_parser.element(
    "p",
    attrs={ "onclick": Some("x"), "title": Some("t") },
    children=[@html_parser.text("ok")],
  )
  assert_eq(
    @html_parser.sanitize_dom(allowed).to_html(pretty=false),
    "<p title=\"t\">ok</p>",
  )
  let unwrapped = @html_parser.element("sarcasm", children=[
    @html_parser.text("a"),
    @html_parser.element("b", children=[@html_parser.text("b")]),
  ])
  assert_eq(
    @html_parser.sanitize_dom(unwrapped).to_html(pretty=false),
    "a<b>b</b>",
  )
  let strict_attrs = @html_parser.fragment(children=[
    @html_parser.element("div", attrs={ "id": Some("x") }),
  ])
  let strict_policy = @html_parser.SanitizationPolicy::new(["div"])
  assert_eq(
    @html_parser.sanitize_dom(strict_attrs, policy=strict_policy).to_html(
      pretty=false,
    ),
    "<div></div>",
  )
  let foreign = @html_parser.fragment(children=[
    @html_parser.element("svg", ns="svg", children=[
      @html_parser.element("title", ns="svg", children=[@html_parser.text("x")]),
    ]),
    @html_parser.element("p", children=[@html_parser.text("ok")]),
  ])
  assert_eq(
    @html_parser.sanitize_dom(foreign).to_html(pretty=false),
    "<p>ok</p>",
  )
  let urls = @html_parser.parse_fragment(
    "<a href='#frag'>f</a><a href='HTTP://ok'>h</a><a href='/rel'>r</a><a href='java\t\nscript:evil'>bad</a><a href='/bad\npath'>control</a><img src='//x'><img src>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(urls.root).to_html(pretty=false),
    "<a href=\"#frag\">f</a><a href=\"HTTP://ok\">h</a><a href=\"/rel\">r</a><a>bad</a><a>control</a><img><img>",
  )
}

///|
test "parse sanitize flag applies default sanitizer policies" {
  let fragment = @html_parser.parse_fragment(
    "<p onclick=x>ok</p><script>bad</script>",
    sanitize=true,
  )
  assert_eq(fragment.to_html(pretty=false), "<p>ok</p>")
  let doc = @html_parser.parse(
    "<!DOCTYPE html><!--x--><html><head><title>T</title><script>bad</script></head><body><p onclick=x>ok</p></body></html>",
    sanitize=true,
  )
  assert_eq(
    doc.to_html(pretty=false),
    "<!DOCTYPE html><html><head><title>T</title></head><body><p>ok</p></body></html>",
  )
  let bytes = @html_parser.parse_bytes(
    b"<p onclick=x>bytes</p><script>bad</script>",
    sanitize=true,
  )
  assert_eq(
    bytes.to_html(pretty=false),
    "<html><head></head><body><p>bytes</p></body></html>",
  )
  guard bytes.encoding is Some("windows-1252") else {
    fail("expected sanitized bytes parse to preserve encoding")
  }
}

///|
test "builder insert and replace helpers preserve graph invariants" {
  let parent = @html_parser.element("div", attrs={ "id": Some("parent") })
  let first = @html_parser.element("span", attrs={ "id": Some("1") })
  let second = @html_parser.element("span", attrs={ "id": Some("2") })
  let third = @html_parser.element("span", attrs={ "id": Some("3") })
  parent.append_child(first)
  parent.insert_before(second, Some(first))
  parent.insert_before(third, None)
  let children = parent.children()
  assert_eq(children.length(), 3)
  assert_eq(test_attr_id(children[0]), "2")
  assert_eq(test_attr_id(children[1]), "1")
  assert_eq(test_attr_id(children[2]), "3")
  guard second.parent() is Some(second_parent) else {
    fail("expected inserted child parent")
  }
  assert_eq(test_attr_id(second_parent), "parent")
  parent.insert_before(second, Some(second))
  assert_eq(test_attr_id(parent.children()[0]), "2")
  let fallback = @html_parser.element("span", attrs={ "id": Some("4") })
  parent.insert_before(fallback, Some(@html_parser.element("missing")))
  assert_eq(test_attr_id(parent.children()[3]), "4")
  let replacement = @html_parser.element("p", attrs={ "id": Some("new") })
  guard parent.replace_child(replacement, first) is Some(replaced) else {
    fail("expected replaced child")
  }
  assert_eq(test_attr_id(replaced), "1")
  assert_true(first.parent() is None)
  guard replacement.parent() is Some(replacement_parent) else {
    fail("expected replacement parent")
  }
  assert_eq(test_attr_id(replacement_parent), "parent")
  let after_replace = parent.children()
  assert_eq(test_attr_id(after_replace[0]), "2")
  assert_eq(test_attr_id(after_replace[1]), "new")
  assert_eq(test_attr_id(after_replace[2]), "3")
  assert_eq(test_attr_id(after_replace[3]), "4")
  guard parent.replace_child(replacement, replacement) is Some(same_child) else {
    fail("expected same-child replacement")
  }
  assert_eq(test_attr_id(same_child), "new")
  assert_eq(test_attr_id(parent.children()[1]), "new")
  guard parent.replace_child(second, third) is Some(moved_out) else {
    fail("expected moved old child")
  }
  assert_eq(test_attr_id(moved_out), "3")
  assert_true(third.parent() is None)
  let after_move = parent.children()
  assert_eq(after_move.length(), 3)
  assert_eq(test_attr_id(after_move[0]), "new")
  assert_eq(test_attr_id(after_move[1]), "2")
  assert_eq(test_attr_id(after_move[2]), "4")
  assert_true(parent.replace_child(@html_parser.element("x"), first) is None)
  let nested = @html_parser.element("i", attrs={ "id": Some("nested") })
  replacement.append_child(nested)
  assert_true(replacement.replace_child(parent, nested) is None)
  assert_eq(test_attr_id(replacement.children()[0]), "nested")
}

///|
test "clone_node deep handles deep trees iteratively" {
  let root = @html_parser.document()
  let mut parent = root
  for _ in 0..<1200 {
    let child = @html_parser.element("div")
    parent.append_child(child)
    parent = child
  }
  parent.append_child(@html_parser.text("x"))
  let cloned = root.clone_node(deep=true)
  assert_eq(cloned.to_text(separator="", strip=false), "x")
  let mut current = cloned
  let mut depth = 0
  while current.children().length() > 0 {
    let children = current.children()
    current = children[0]
    depth += 1
    if current.kind() is Text {
      break
    }
  }
  assert_eq(depth, 1201)
}

///|
test "tree builder finishes deeply nested parsed HTML without recursion" {
  let html = repeat_for_test("<div>", 1200) +
    "x" +
    repeat_for_test("</div>", 1200)
  let doc = @html_parser.parse(html)
  assert_eq(doc.to_text(separator="", strip=false), "x")
  guard doc.query_one("div") is Some(first_div) else {
    fail("expected parsed deep div")
  }
  assert_eq(first_div.to_text(separator="", strip=false), "x")
}

///|
test "clone_node copies template descendants through child traversal" {
  let template = @html_parser.element("template", children=[
    @html_parser.element("div", attrs={ "id": Some("content") }),
    @html_parser.element("span"),
  ])
  assert_eq(
    template.clone_node().to_html(pretty=false),
    "<template></template>",
  )
  let cloned = template.clone_node(deep=true)
  assert_eq(
    cloned.to_html(pretty=false),
    "<template><div id=\"content\"></div><span></span></template>",
  )
  guard cloned.query_one("div") is Some(cloned_div) else {
    fail("expected cloned template content")
  }
  cloned_div.append_child(@html_parser.text("clone"))
  guard cloned_div.parent() is Some(cloned_parent) else {
    fail("expected cloned template child parent")
  }
  assert_eq(cloned_parent.name(), "template")
  assert_eq(
    template.to_html(pretty=false),
    "<template><div id=\"content\"></div><span></span></template>",
  )
  assert_eq(
    cloned.to_html(pretty=false),
    "<template><div id=\"content\">clone</div><span></span></template>",
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
  let controls = @html_parser.text(
    "\u{0001}\u{0004}\u{0006}\u{000B}\u{000D}\u{000F}\u{007F}",
  )
  assert_eq(
    controls.to_html(pretty=false, context=Url),
    "%01%04%06%0B%0D%0F%7F",
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
  let digit_prefixes = @html_parser.parse_fragment(
    "<p>a<br>3x plain<br>4.no space<br>5)no space<br>6. ordered<br>7) ordered</p>",
  )
  assert_eq(
    digit_prefixes.to_markdown(),
    "a\n3x plain\n4.no space\n5)no space\n6\\. ordered\n7\\) ordered",
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
  let text_in_head = @html_parser.parse(
    "<head>x</head><p>y",
    collect_errors=true,
  )
  assert_eq(
    text_in_head.to_html(pretty=false),
    "<html><head></head><body>x<p>y</p></body></html>",
  )
  assert_eq(text_in_head.errors.length(), 2)
  assert_eq(text_in_head.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(text_in_head.errors[1].code, "unexpected-end-tag")
  let duplicate_head = @html_parser.parse(
    "<head><head><title>T</title>",
    collect_errors=true,
  )
  assert_eq(
    duplicate_head.to_html(pretty=false),
    "<html><head></head><body><title>T</title></body></html>",
  )
  assert_eq(duplicate_head.errors.length(), 2)
  assert_eq(duplicate_head.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(duplicate_head.errors[1].code, "unexpected-start-tag")
  let duplicate_head_body_start = @html_parser.parse(
    "<head><head><p>x",
    collect_errors=true,
  )
  assert_eq(
    duplicate_head_body_start.to_html(pretty=false),
    "<html><head></head><body><p>x</p></body></html>",
  )
  assert_eq(duplicate_head_body_start.errors.length(), 2)
  assert_eq(
    duplicate_head_body_start.errors[0].code,
    "expected-doctype-but-got-start-tag",
  )
  assert_eq(duplicate_head_body_start.errors[1].code, "unexpected-start-tag")
  let closed_duplicate_head = @html_parser.parse(
    "<head><head></head><title>T</title>",
    collect_errors=true,
  )
  assert_eq(
    closed_duplicate_head.to_html(pretty=false),
    "<html><head></head><body><title>T</title></body></html>",
  )
  assert_eq(closed_duplicate_head.errors.length(), 3)
  assert_eq(
    closed_duplicate_head.errors[0].code,
    "expected-doctype-but-got-start-tag",
  )
  assert_eq(closed_duplicate_head.errors[1].code, "unexpected-start-tag")
  assert_eq(closed_duplicate_head.errors[2].code, "unexpected-end-tag")
  let root_duplicate_head = @html_parser.parse(
    "<head></head><head><title>T</title>",
    collect_errors=true,
  )
  assert_eq(
    root_duplicate_head.to_html(pretty=false),
    "<html><head></head><body><title>T</title></body></html>",
  )
  assert_eq(root_duplicate_head.errors.length(), 2)
  assert_eq(
    root_duplicate_head.errors[0].code,
    "expected-doctype-but-got-start-tag",
  )
  assert_eq(root_duplicate_head.errors[1].code, "unexpected-start-tag")
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
test "document parser ignores early body end after explicit html" {
  let doc = @html_parser.parse(
    "<!doctype html><html></body><p>x",
    collect_errors=true,
  )
  assert_eq(
    doc.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body><p>x</p></body></html>",
  )
  assert_eq(doc.errors.length(), 0)
  let after_head = @html_parser.parse(
    "<!doctype html><html><head></head></body><p>x",
    collect_errors=true,
  )
  assert_eq(
    after_head.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body><p>x</p></body></html>",
  )
  assert_eq(after_head.errors.length(), 0)
}

///|
test "tree builder matches Python reference body hidden input fixture" {
  let doc = @html_parser.parse(
    "<body><input type=\"hidden\">",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(doc.root),
    "| <html>\n|   <head>\n|   <body>\n|     <input>\n|       type=\"hidden\"",
  )
  assert_eq(doc.errors.length(), 1)
  assert_eq(doc.errors[0].code, "expected-doctype-but-got-start-tag")
  guard doc.errors[0].column is Some(6) else {
    fail("expected body doctype error at body start close")
  }
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
  let body_repeated = @html_parser.parse(
    "<html><body><html attr=\"test\">",
    collect_errors=true,
  )
  assert_eq(
    body_repeated.to_html(pretty=false),
    "<html attr=\"test\"><head></head><body></body></html>",
  )
  assert_eq(body_repeated.errors.length(), 2)
  assert_eq(body_repeated.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(body_repeated.errors[1].code, "unexpected-start-tag")
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
test "document parser preserves shell scaffolding edge ordering" {
  let leading_text = @html_parser.parse(
    "<html> \n\tBody</html>",
    collect_errors=true,
  )
  assert_eq(
    leading_text.to_html(pretty=false),
    "<html><head></head><body>Body</body></html>",
  )
  assert_eq(leading_text.errors.length(), 1)
  assert_eq(leading_text.errors[0].code, "expected-doctype-but-got-start-tag")
  let leading_space_only = @html_parser.parse(
    "<!doctype html><html>   </html>",
    collect_errors=true,
  )
  assert_eq(
    leading_space_only.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body></body></html>",
  )
  assert_eq(leading_space_only.errors.length(), 0)
  let late_head = @html_parser.parse(
    "<html><body>x</body><head><title>T</title></head></html>",
    collect_errors=true,
  )
  assert_eq(
    late_head.to_html(pretty=false),
    "<html><head></head><body>x<title>T</title></body></html>",
  )
  assert_eq(late_head.errors.length(), 3)
  assert_eq(late_head.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(late_head.errors[1].code, "unexpected-start-tag")
  assert_eq(late_head.errors[2].code, "unexpected-end-tag")
  let frameset_tail = @html_parser.parse(
    "<html><frameset></frameset>   <!--tail--></html>",
    collect_errors=true,
  )
  assert_eq(
    frameset_tail.to_html(pretty=false),
    "<html><head></head><frameset></frameset>   <!--tail--></html>",
  )
  assert_eq(frameset_tail.errors.length(), 1)
  assert_eq(frameset_tail.errors[0].code, "expected-doctype-but-got-start-tag")
  let recursive_html = @html_parser.parse(
    "<html lang=en></html><html dir=ltr><html data-x=1><body>x</body></html></html>",
    collect_errors=true,
  )
  assert_eq(
    recursive_html.to_html(pretty=false),
    "<html lang=\"en\" dir=\"ltr\" data-x=\"1\"><head></head><body>x</body></html>",
  )
  assert_eq(recursive_html.errors.length(), 5)
  assert_eq(recursive_html.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(recursive_html.errors[1].code, "unexpected-start-tag")
  assert_eq(recursive_html.errors[2].code, "unexpected-start-tag")
  assert_eq(recursive_html.errors[3].code, "unexpected-start-tag")
  assert_eq(recursive_html.errors[4].code, "unexpected-token-after-body")
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
test "document parser preserves head-side whitespace like reference" {
  let implicit = @html_parser.parse("<!doctype html><title>T</title>  text")
  assert_eq(
    implicit.to_html(pretty=false),
    "<!DOCTYPE html><html><head><title>T</title>  </head><body>text</body></html>",
  )
  let implicit_trailing_space = @html_parser.parse(
    "<!doctype html><title>T</title>  ",
    collect_errors=true,
  )
  assert_eq(
    implicit_trailing_space.to_html(pretty=false),
    "<!DOCTYPE html><html><head><title>T</title>  </head><body></body></html>",
  )
  assert_eq(implicit_trailing_space.errors.length(), 0)
  let open_head = @html_parser.parse(
    "<!doctype html><head><title>T</title>  text",
  )
  assert_eq(
    open_head.to_html(pretty=false),
    "<!DOCTYPE html><html><head><title>T</title>  </head><body>text</body></html>",
  )
  let coerced_head_space = @html_parser.parse(
    "<!doctype html><head><title>T</title>\u{000C} x",
    xml_coercion=true,
  )
  assert_eq(
    coerced_head_space.to_html(pretty=false),
    "<!DOCTYPE html><html><head><title>T</title>  </head><body>x</body></html>",
  )
  let explicit = @html_parser.parse(
    "<!doctype html><head></head><!--c-->  <meta name=x><p>y",
  )
  assert_eq(
    explicit.to_html(pretty=false),
    "<!DOCTYPE html><html><head><meta name=\"x\"></head><!--c-->  <body><p>y</p></body></html>",
  )
  let explicit_html_implicit_head = @html_parser.parse(
    "<html><title>T</title>  text</html>",
  )
  assert_eq(
    explicit_html_implicit_head.to_html(pretty=false),
    "<html><head><title>T</title>  </head><body>text</body></html>",
  )
  let explicit_html_closed_head = @html_parser.parse(
    "<html><head></head>  <p>x</p></html>",
  )
  assert_eq(
    explicit_html_closed_head.to_html(pretty=false),
    "<html><head></head>  <body><p>x</p></body></html>",
  )
}

///|
test "document parser accepts doctype after leading comments and whitespace" {
  let comment = @html_parser.parse(
    "<!--c-->\n<!DOCTYPE html><p>x",
    collect_errors=true,
  )
  assert_eq(
    comment.to_html(pretty=false),
    "<!--c--><!DOCTYPE html><html><head></head><body><p>x</p></body></html>",
  )
  assert_eq(comment.errors.length(), 0)
  let whitespace = @html_parser.parse(
    " \n<!doctype html><p>x",
    collect_errors=true,
  )
  assert_eq(
    whitespace.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body><p>x</p></body></html>",
  )
  assert_eq(whitespace.errors.length(), 0)
  let mixed = @html_parser.parse(
    "\t<!--a--><!doctype html><p>x",
    collect_errors=true,
  )
  assert_eq(
    mixed.to_html(pretty=false),
    "<!--a--><!DOCTYPE html><html><head></head><body><p>x</p></body></html>",
  )
  assert_eq(mixed.errors.length(), 0)
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
  let newline_ids = @html_parser.tokenize(
    "<!DOCTYPE html PUBLIC \"a\rb\" \"s\r\nt\">",
  )
  guard newline_ids.tokens[0]
    is @html_parser.HtmlToken::DoctypeToken(newline_info) else {
    fail("expected newline-normalized doctype")
  }
  guard newline_info.public_id is Some("a\nb") else {
    fail("expected CR-normalized public id")
  }
  guard newline_info.system_id is Some("s\nt") else {
    fail("expected CRLF-normalized system id")
  }
  let newline_doc = @html_parser.parse(
    "<!DOCTYPE html PUBLIC \"a\rb\" \"s\r\nt\">",
    collect_errors=true,
  )
  assert_eq(
    newline_doc.to_html(pretty=false),
    "<!DOCTYPE html PUBLIC \"a\nb\" \"s\nt\"><html><head></head><body></body></html>",
  )
  assert_eq(newline_doc.errors.length(), 1)
  assert_eq(newline_doc.errors[0].code, "unknown-doctype")
  guard newline_doc.errors[0].line is Some(3) else {
    fail("expected unknown doctype after CRLF-normalized system id on line 3")
  }
  guard newline_doc.errors[0].column is Some(3) else {
    fail("expected unknown doctype at closing bracket column")
  }
  let public_trailing_cr = @html_parser.tokenize(
    "<!DOCTYPE html PUBLIC \"p\"\r>",
    collect_errors=true,
  )
  assert_eq(public_trailing_cr.errors.length(), 0)
  guard public_trailing_cr.tokens[0]
    is @html_parser.HtmlToken::DoctypeToken(public_trailing_info) else {
    fail("expected public doctype with trailing CR whitespace")
  }
  guard public_trailing_info.public_id is Some("p") else {
    fail("expected public id before trailing CR")
  }
  guard public_trailing_info.system_id is None else {
    fail("expected no system id after trailing CR before bracket")
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
  let eof_token = @html_parser.tokenize("<!doctype", collect_errors=true)
  guard eof_token.tokens[0] is @html_parser.HtmlToken::DoctypeToken(eof_info) else {
    fail("expected EOF doctype token")
  }
  assert_eq(eof_info.name, "")
  assert_eq(eof_info.force_quirks, true)
  assert_eq(eof_token.errors.length(), 1)
  assert_eq(eof_token.errors[0].code, "eof-in-doctype")
  let name_eof_token = @html_parser.tokenize(
    "<!doctype html",
    collect_errors=true,
  )
  guard name_eof_token.tokens[0]
    is @html_parser.HtmlToken::DoctypeToken(name_eof_info) else {
    fail("expected named EOF doctype token")
  }
  assert_eq(name_eof_info.name, "html")
  assert_eq(name_eof_info.force_quirks, true)
  assert_eq(name_eof_token.errors.length(), 1)
  assert_eq(name_eof_token.errors[0].code, "eof-in-doctype")
  let name_eof = @html_parser.parse("<!doctype html", collect_errors=true)
  assert_eq(
    name_eof.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body></body></html>",
  )
  assert_eq(name_eof.errors.length(), 1)
  assert_eq(name_eof.errors[0].code, "eof-in-doctype")
  guard name_eof.errors[0].column is Some(14) else {
    fail("expected named doctype EOF at final character")
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
  let parsed_name_null = @html_parser.parse(
    "<!doctype h\u{0000}tml><p>x",
    collect_errors=true,
  )
  assert_eq(parsed_name_null.errors.length(), 2)
  assert_eq(parsed_name_null.errors[0].code, "unexpected-null-character")
  guard parsed_name_null.errors[0].column is Some(12) else {
    fail("expected parser null error inside doctype name")
  }
  assert_eq(parsed_name_null.errors[1].code, "unknown-doctype")
  let children = parsed_name_null.root.children()
  assert_eq(@html_parser.to_test_format(children[0]), "| <!DOCTYPE h�tml>")
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
  let public_whitespace_eof = @html_parser.parse(
    "<!doctype html PUBLIC ",
    collect_errors=true,
  )
  assert_eq(
    public_whitespace_eof.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body></body></html>",
  )
  assert_eq(public_whitespace_eof.errors.length(), 1)
  assert_eq(
    public_whitespace_eof.errors[0].code,
    "missing-doctype-public-identifier",
  )
  guard public_whitespace_eof.errors[0].column is Some(22) else {
    fail("expected whitespace EOF missing public id at final whitespace")
  }
  let public_newline_eof = @html_parser.tokenize(
    "<!doctype html PUBLIC \n",
    collect_errors=true,
  )
  assert_eq(public_newline_eof.errors.length(), 1)
  assert_eq(
    public_newline_eof.errors[0].code,
    "missing-doctype-public-identifier",
  )
  guard public_newline_eof.errors[0].line is Some(2) else {
    fail("expected public identifier EOF after newline on line 2")
  }
  guard public_newline_eof.errors[0].column is Some(0) else {
    fail("expected public identifier EOF after newline at column 0")
  }
  guard public_newline_eof.tokens[0] is DoctypeToken(public_newline_info) else {
    fail("expected doctype token for newline EOF public id")
  }
  assert_eq(public_newline_info.name, "html")
  assert_eq(public_newline_info.force_quirks, true)
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
  let system_whitespace_eof = @html_parser.parse(
    "<!doctype html SYSTEM ",
    collect_errors=true,
  )
  assert_eq(
    system_whitespace_eof.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body></body></html>",
  )
  assert_eq(system_whitespace_eof.errors.length(), 1)
  assert_eq(
    system_whitespace_eof.errors[0].code,
    "missing-doctype-system-identifier",
  )
  guard system_whitespace_eof.errors[0].column is Some(22) else {
    fail("expected whitespace EOF missing system id at final whitespace")
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
test "parser reports doctype quoted identifier edge recovery" {
  let public_abrupt = @html_parser.parse(
    "<!doctype html PUBLIC \"x>",
    collect_errors=true,
  )
  assert_eq(
    public_abrupt.to_html(pretty=false),
    "<!DOCTYPE html PUBLIC \"x\"><html><head></head><body></body></html>",
  )
  assert_eq(public_abrupt.errors.length(), 2)
  assert_eq(public_abrupt.errors[0].code, "abrupt-doctype-public-identifier")
  guard public_abrupt.errors[0].column is Some(25) else {
    fail("expected abrupt public id at close bracket")
  }
  assert_eq(public_abrupt.errors[1].code, "unknown-doctype")
  let public_identifier_eof = @html_parser.parse(
    "<!doctype html PUBLIC \"x",
    collect_errors=true,
  )
  assert_eq(
    public_identifier_eof.to_html(pretty=false),
    "<!DOCTYPE html PUBLIC \"x\"><html><head></head><body></body></html>",
  )
  assert_eq(public_identifier_eof.errors.length(), 2)
  assert_eq(
    public_identifier_eof.errors[0].code,
    "eof-in-doctype-public-identifier",
  )
  guard public_identifier_eof.errors[0].column is Some(24) else {
    fail("expected public id EOF at final character")
  }
  assert_eq(public_identifier_eof.errors[1].code, "unknown-doctype")
  let public_identifier_newline_eof = @html_parser.parse(
    "<!doctype html PUBLIC \"x\n",
    collect_errors=true,
  )
  assert_eq(
    public_identifier_newline_eof.to_html(pretty=false),
    "<!DOCTYPE html PUBLIC \"x\n\"><html><head></head><body></body></html>",
  )
  assert_eq(public_identifier_newline_eof.errors.length(), 2)
  assert_eq(
    public_identifier_newline_eof.errors[0].code,
    "eof-in-doctype-public-identifier",
  )
  guard public_identifier_newline_eof.errors[0].line is Some(2) else {
    fail("expected public identifier newline EOF on line 2")
  }
  guard public_identifier_newline_eof.errors[0].column is Some(0) else {
    fail("expected public identifier newline EOF at column 0")
  }
  assert_eq(public_identifier_newline_eof.errors[1].code, "unknown-doctype")
  let system_abrupt = @html_parser.parse(
    "<!doctype html SYSTEM \"x>",
    collect_errors=true,
  )
  assert_eq(
    system_abrupt.to_html(pretty=false),
    "<!DOCTYPE html SYSTEM \"x\"><html><head></head><body></body></html>",
  )
  assert_eq(system_abrupt.errors.length(), 2)
  assert_eq(system_abrupt.errors[0].code, "abrupt-doctype-system-identifier")
  guard system_abrupt.errors[0].column is Some(25) else {
    fail("expected abrupt system id at close bracket")
  }
  assert_eq(system_abrupt.errors[1].code, "unknown-doctype")
  let system_identifier_eof = @html_parser.parse(
    "<!doctype html SYSTEM \"x",
    collect_errors=true,
  )
  assert_eq(
    system_identifier_eof.to_html(pretty=false),
    "<!DOCTYPE html SYSTEM \"x\"><html><head></head><body></body></html>",
  )
  assert_eq(system_identifier_eof.errors.length(), 2)
  assert_eq(
    system_identifier_eof.errors[0].code,
    "eof-in-doctype-system-identifier",
  )
  guard system_identifier_eof.errors[0].column is Some(24) else {
    fail("expected system id EOF at final character")
  }
  assert_eq(system_identifier_eof.errors[1].code, "unknown-doctype")
  let system_identifier_newline_eof = @html_parser.parse(
    "<!doctype html SYSTEM \"x\n",
    collect_errors=true,
  )
  assert_eq(
    system_identifier_newline_eof.to_html(pretty=false),
    "<!DOCTYPE html SYSTEM \"x\n\"><html><head></head><body></body></html>",
  )
  assert_eq(system_identifier_newline_eof.errors.length(), 2)
  assert_eq(
    system_identifier_newline_eof.errors[0].code,
    "eof-in-doctype-system-identifier",
  )
  guard system_identifier_newline_eof.errors[0].line is Some(2) else {
    fail("expected system identifier newline EOF on line 2")
  }
  guard system_identifier_newline_eof.errors[0].column is Some(0) else {
    fail("expected system identifier newline EOF at column 0")
  }
  assert_eq(system_identifier_newline_eof.errors[1].code, "unknown-doctype")
}

///|
test "parser reports doctype keyword spacing edge recovery" {
  let public_direct_quote = @html_parser.parse(
    "<!doctype html PUBLIC\"x\">",
    collect_errors=true,
  )
  assert_eq(
    public_direct_quote.to_html(pretty=false),
    "<!DOCTYPE html PUBLIC \"x\"><html><head></head><body></body></html>",
  )
  assert_eq(public_direct_quote.errors.length(), 2)
  assert_eq(
    public_direct_quote.errors[0].code,
    "missing-whitespace-before-doctype-public-identifier",
  )
  guard public_direct_quote.errors[0].column is Some(22) else {
    fail("expected missing whitespace before public id")
  }
  assert_eq(public_direct_quote.errors[1].code, "unknown-doctype")
  let system_direct_quote = @html_parser.parse(
    "<!doctype html SYSTEM\"x\">",
    collect_errors=true,
  )
  assert_eq(
    system_direct_quote.to_html(pretty=false),
    "<!DOCTYPE html SYSTEM \"x\"><html><head></head><body></body></html>",
  )
  assert_eq(system_direct_quote.errors.length(), 2)
  assert_eq(
    system_direct_quote.errors[0].code,
    "missing-whitespace-after-doctype-public-identifier",
  )
  guard system_direct_quote.errors[0].column is Some(22) else {
    fail("expected missing whitespace after system keyword")
  }
  assert_eq(system_direct_quote.errors[1].code, "unknown-doctype")
  let public_direct_junk = @html_parser.parse(
    "<!doctype html PUBLICx>",
    collect_errors=true,
  )
  assert_eq(
    public_direct_junk.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body></body></html>",
  )
  assert_eq(public_direct_junk.errors.length(), 1)
  assert_eq(
    public_direct_junk.errors[0].code,
    "unexpected-character-after-doctype-public-keyword",
  )
  let system_direct_junk = @html_parser.parse(
    "<!doctype html SYSTEMx>",
    collect_errors=true,
  )
  assert_eq(
    system_direct_junk.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body></body></html>",
  )
  assert_eq(system_direct_junk.errors.length(), 1)
  assert_eq(
    system_direct_junk.errors[0].code,
    "unexpected-character-after-doctype-system-keyword",
  )
  let immediate_system_quote = @html_parser.parse(
    "<!doctype html PUBLIC \"x\"\"y\">",
    collect_errors=true,
  )
  assert_eq(
    immediate_system_quote.to_html(pretty=false),
    "<!DOCTYPE html PUBLIC \"x\" \"y\"><html><head></head><body></body></html>",
  )
  assert_eq(immediate_system_quote.errors.length(), 2)
  assert_eq(
    immediate_system_quote.errors[0].code,
    "missing-whitespace-between-doctype-public-and-system-identifiers",
  )
  guard immediate_system_quote.errors[0].column is Some(26) else {
    fail("expected missing whitespace before system id")
  }
  assert_eq(immediate_system_quote.errors[1].code, "unknown-doctype")
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
  let missing_system_after_space = @html_parser.parse(
    "<!doctype html PUBLIC \"x\" ",
    collect_errors=true,
  )
  assert_eq(
    missing_system_after_space.to_html(pretty=false),
    "<!DOCTYPE html PUBLIC \"x\"><html><head></head><body></body></html>",
  )
  assert_eq(missing_system_after_space.errors.length(), 2)
  assert_eq(
    missing_system_after_space.errors[0].code,
    "missing-quote-before-doctype-system-identifier",
  )
  assert_eq(missing_system_after_space.errors[1].code, "unknown-doctype")
  guard missing_system_after_space.errors[0].column is Some(26) else {
    fail("expected missing system quote at trailing whitespace EOF")
  }
  let missing_system_after_newline = @html_parser.parse(
    "<!doctype html PUBLIC \"x\" \n",
    collect_errors=true,
  )
  assert_eq(missing_system_after_newline.errors.length(), 2)
  assert_eq(
    missing_system_after_newline.errors[0].code,
    "missing-quote-before-doctype-system-identifier",
  )
  guard missing_system_after_newline.errors[0].line is Some(2) else {
    fail("expected missing system quote newline EOF on line 2")
  }
  guard missing_system_after_newline.errors[0].column is Some(0) else {
    fail("expected missing system quote newline EOF at column 0")
  }
  assert_eq(missing_system_after_newline.errors[1].code, "unknown-doctype")
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
  let missing_quote = @html_parser.tokenize(
    "<!doctype html PUBLIC \"x\" foo>",
    collect_errors=true,
  )
  assert_eq(missing_quote.errors.length(), 1)
  assert_eq(
    missing_quote.errors[0].code,
    "missing-quote-before-doctype-system-identifier",
  )
  guard missing_quote.errors[0].column is Some(27) else {
    fail("expected missing system quote after public-id whitespace")
  }
  guard missing_quote.tokens[0]
    is @html_parser.HtmlToken::DoctypeToken(missing_quote_info) else {
    fail("expected doctype token after missing system quote")
  }
  guard missing_quote_info.public_id is Some("x") else {
    fail("expected public id before missing system quote")
  }
  guard missing_quote_info.system_id is None else {
    fail("expected no system id after missing quote")
  }
  assert_eq(missing_quote_info.force_quirks, true)
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
  let system_newline_eof = @html_parser.tokenize(
    "<!doctype html SYSTEM \"x\" \n",
    collect_errors=true,
  )
  assert_eq(system_newline_eof.errors.length(), 1)
  assert_eq(system_newline_eof.errors[0].code, "eof-in-doctype")
  guard system_newline_eof.errors[0].line is Some(2) else {
    fail("expected system doctype newline EOF on line 2")
  }
  guard system_newline_eof.errors[0].column is Some(0) else {
    fail("expected system doctype newline EOF at column 0")
  }
  guard system_newline_eof.tokens[0] is DoctypeToken(system_newline_info) else {
    fail("expected system doctype token at newline EOF")
  }
  guard system_newline_info.system_id is Some("x") else {
    fail("expected system id before newline EOF")
  }
  assert_eq(system_newline_info.force_quirks, true)
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
  let stray_template = @html_parser.parse("</template>", collect_errors=true)
  assert_eq(
    stray_template.to_html(pretty=false),
    "<html><head></head><body></body></html>",
  )
  assert_eq(stray_template.errors.length(), 2)
  assert_eq(stray_template.errors[0].code, "expected-doctype-but-got-end-tag")
  assert_eq(stray_template.errors[1].code, "unexpected-end-tag-before-html")
  guard stray_template.errors[1].column is Some(11) else {
    fail("expected before-html end tag error at tag close")
  }
  let stray_html = @html_parser.parse("</html>", collect_errors=true)
  assert_eq(stray_html.errors.length(), 1)
  assert_eq(stray_html.errors[0].code, "expected-doctype-but-got-end-tag")
  let stray_br = @html_parser.parse("</br>", collect_errors=true)
  assert_eq(
    stray_br.to_html(pretty=false),
    "<html><head></head><body><br></body></html>",
  )
  assert_eq(stray_br.errors.length(), 2)
  assert_eq(stray_br.errors[0].code, "expected-doctype-but-got-end-tag")
  assert_eq(stray_br.errors[1].code, "unexpected-end-tag")
  guard stray_br.errors[1].column is Some(5) else {
    fail("expected before-html br error at tag close")
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
  let invalid_open = @html_parser.parse("<*foo>", collect_errors=true)
  assert_eq(
    invalid_open.to_html(pretty=false),
    "<html><head></head><body>&lt;*foo&gt;</body></html>",
  )
  assert_eq(invalid_open.errors.length(), 2)
  assert_eq(invalid_open.errors[0].code, "invalid-first-character-of-tag-name")
  assert_eq(invalid_open.errors[1].code, "expected-doctype-but-got-chars")
}

///|
test "document parser defers initial doctype errors after bogus markup" {
  let start = @html_parser.parse("<!foo><div>x", collect_errors=true)
  assert_eq(
    start.to_html(pretty=false),
    "<!--foo--><html><head></head><body><div>x</div></body></html>",
  )
  assert_eq(start.errors.length(), 3)
  assert_eq(start.errors[0].code, "incorrectly-opened-comment")
  assert_eq(start.errors[1].code, "expected-doctype-but-got-start-tag")
  assert_eq(start.errors[2].code, "expected-closing-tag-but-got-eof")
  guard start.errors[1].column is Some(11) else {
    fail("expected deferred start-tag doctype error at div close")
  }
  let end_tag = @html_parser.parse("<!foo></div>", collect_errors=true)
  assert_eq(
    end_tag.to_html(pretty=false),
    "<!--foo--><html><head></head><body></body></html>",
  )
  assert_eq(end_tag.errors.length(), 3)
  assert_eq(end_tag.errors[0].code, "incorrectly-opened-comment")
  assert_eq(end_tag.errors[1].code, "expected-doctype-but-got-end-tag")
  assert_eq(end_tag.errors[2].code, "unexpected-end-tag-before-html")
  guard end_tag.errors[1].column is Some(12) else {
    fail("expected deferred end-tag doctype error at end tag close")
  }
  let bare_lt = @html_parser.parse("<!foo><", collect_errors=true)
  assert_eq(
    bare_lt.to_html(pretty=false),
    "<!--foo--><html><head></head><body>&lt;</body></html>",
  )
  assert_eq(bare_lt.errors.length(), 3)
  assert_eq(bare_lt.errors[0].code, "incorrectly-opened-comment")
  assert_eq(bare_lt.errors[1].code, "eof-before-tag-name")
  assert_eq(bare_lt.errors[2].code, "expected-doctype-but-got-chars")
  guard bare_lt.errors[2].column is Some(7) else {
    fail("expected deferred character doctype error at literal <")
  }
  let unfinished_declaration = @html_parser.parse(
    "<!foo<!",
    collect_errors=true,
  )
  assert_eq(
    unfinished_declaration.to_html(pretty=false),
    "<!--foo<!--><html><head></head><body></body></html>",
  )
  assert_eq(unfinished_declaration.errors.length(), 2)
  assert_eq(unfinished_declaration.errors[0].code, "incorrectly-opened-comment")
  assert_eq(
    unfinished_declaration.errors[1].code,
    "expected-doctype-but-got-eof",
  )
  guard unfinished_declaration.errors[1].column is Some(7) else {
    fail("expected deferred doctype EOF after unfinished declaration")
  }
  let invalid_open = @html_parser.parse("<!foo><*x>", collect_errors=true)
  assert_eq(
    invalid_open.to_html(pretty=false),
    "<!--foo--><html><head></head><body>&lt;*x&gt;</body></html>",
  )
  assert_eq(invalid_open.errors.length(), 3)
  assert_eq(invalid_open.errors[0].code, "incorrectly-opened-comment")
  assert_eq(invalid_open.errors[1].code, "invalid-first-character-of-tag-name")
  assert_eq(invalid_open.errors[2].code, "expected-doctype-but-got-chars")
  guard invalid_open.errors[2].column is Some(7) else {
    fail("expected deferred character doctype error at invalid tag open")
  }
}

///|
test "tree builder matches reference empty-stack foreign select edge" {
  let doc = @html_parser.parse(
    "<!><svg><th><title><n><select><td>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(doc.root),
    "| <!--  -->\n| <html>\n|   <head>\n|   <body>\n|     <svg svg>\n|       <svg th>\n|         <svg title>\n|           <n>\n|             <select>\n|   <td>",
  )
  assert_eq(doc.errors.length(), 3)
  assert_eq(doc.errors[0].code, "incorrectly-opened-comment")
  assert_eq(doc.errors[1].code, "expected-doctype-but-got-start-tag")
  assert_eq(doc.errors[2].code, "unexpected-start-tag-in-select")
  guard doc.errors[0].column is Some(2) else {
    fail("expected malformed declaration at bang")
  }
  let td_siblings = @html_parser.parse(
    "<!><svg><th><title><n><select><td>x<td>y",
    collect_errors=true,
  )
  assert_eq(
    td_siblings.to_html(pretty=false),
    "<!----><html><head></head><body><svg><th><title><n><select></select></n></title></th></svg></body><td>x</td><td>y</td></html>",
  )
  assert_eq(td_siblings.errors.length(), 3)
  assert_eq(td_siblings.errors[0].code, "incorrectly-opened-comment")
  assert_eq(td_siblings.errors[1].code, "expected-doctype-but-got-start-tag")
  assert_eq(td_siblings.errors[2].code, "unexpected-start-tag-in-select")
  let th_then_td = @html_parser.parse(
    "<!><svg><th><title><n><select><th>x<td>y",
    collect_errors=true,
  )
  assert_eq(
    th_then_td.to_html(pretty=false),
    "<!----><html><head></head><body><svg><th><title><n><select></select></n></title></th></svg></body><th>x</th><td>y</td></html>",
  )
  assert_eq(th_then_td.errors.length(), 3)
  assert_eq(th_then_td.errors[0].code, "incorrectly-opened-comment")
  assert_eq(th_then_td.errors[1].code, "expected-doctype-but-got-start-tag")
  assert_eq(th_then_td.errors[2].code, "unexpected-start-tag-in-select")
}

///|
test "tree builder matches reference empty-stack nested select edge" {
  let doc = @html_parser.parse(
    "<svg><slot><select/e><title/a><select><select></slot></select>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(doc.root),
    "| <html>\n|   <head>\n|   <body>\n|     <svg svg>\n|       <svg slot>\n|         <svg select>\n|           e=\"\"\n|           <svg title>\n|             a=\"\"\n|             <select>",
  )
  assert_eq(doc.errors.length(), 6)
  assert_eq(doc.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(doc.errors[1].code, "unexpected-character-after-solidus-in-tag")
  assert_eq(doc.errors[2].code, "unexpected-character-after-solidus-in-tag")
  assert_eq(doc.errors[3].code, "unexpected-select-in-select")
  assert_eq(doc.errors[4].code, "unexpected-end-tag")
  assert_eq(doc.errors[5].code, "unexpected-end-tag")
}

///|
test "tree builder matches reference empty-stack foreign table row edge" {
  let doc = @html_parser.parse(
    "<svg><tr><title><section\n><math><p><tr>>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(doc.root),
    "| <html>\n|   <head>\n|   <body>\n|     <svg svg>\n|       <svg tr>\n|         <svg title>\n|           <section>\n|             <math math>\n|             <p>\n|   <tr>\n|     \">\"",
  )
  assert_eq(doc.errors.length(), 3)
  assert_eq(doc.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(doc.errors[1].code, "unexpected-html-element-in-foreign-content")
  assert_eq(doc.errors[2].code, "unexpected-character-implies-table-voodoo")
}

///|
test "parser tracks origins for foreign table recovery helpers" {
  let cell = @html_parser.parse(
    "<!><svg><th><title><n><select><td>",
    track_node_locations=true,
  )
  guard cell.root.query("td").get(0) is Some(td) else {
    fail("expected recovered td")
  }
  assert_node_origin(td, 30, 1, 31)
  let row = @html_parser.parse(
    "<svg><tr><title><section\n><math><p><tr>>",
    track_node_locations=true,
  )
  let trs = row.root.query("tr")
  guard trs.length() == 2 else { fail("expected foreign and recovered tr") }
  assert_node_origin(trs[1], 35, 2, 11)
}

///|
test "tree builder matches reference iframe srcdoc doctype edge" {
  let doc = @html_parser.parse(
    "<!DOCTYPE foo><p><table></table>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(doc.root),
    "| <!DOCTYPE foo>\n| <html>\n|   <head>\n|   <body>\n|     <p>\n|     <table>",
  )
  assert_eq(doc.errors.length(), 1)
  assert_eq(doc.errors[0].code, "unknown-doctype")
}

///|
test "tree builder matches reference legacy loose doctype fixture" {
  let doc = @html_parser.parse(
    "<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//\" \"http://www.w3.org/TR/html4/loose.dtd\">",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(doc.root),
    "| <!DOCTYPE html \"-//W3C//DTD HTML 4.01 Transitional//\" \"http://www.w3.org/TR/html4/loose.dtd\">\n| <html>\n|   <head>\n|   <body>",
  )
  assert_eq(doc.errors.length(), 1)
  assert_eq(doc.errors[0].code, "unknown-doctype")
  guard doc.errors[0].column is Some(100) else {
    fail("expected unknown loose doctype at close bracket")
  }
}

///|
test "tree builder matches reference MathML text form-feed fixture" {
  let doc = @html_parser.parse(
    "<math><mi>\u{000C}text</mi></math>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(doc.root),
    "| <html>\n|   <head>\n|   <body>\n|     <math math>\n|       <math mi>\n|         \" text\"",
  )
  assert_eq(doc.errors.length(), 1)
  assert_eq(doc.errors[0].code, "expected-doctype-but-got-start-tag")
}

///|
test "tree builder matches Python reference MathML null text fixtures" {
  let null_only = @html_parser.parse(
    "<math><mi>\u{0000}</mi></math>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(null_only.root),
    "| <html>\n|   <head>\n|   <body>\n|     <math math>\n|       <math mi>",
  )
  assert_eq(null_only.errors.length(), 2)
  assert_eq(null_only.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(null_only.errors[1].code, "unexpected-null-character")
  guard null_only.errors[0].column is Some(6) else {
    fail("expected MathML doctype error at math start close")
  }
  guard null_only.errors[1].column is Some(11) else {
    fail("expected MathML null error at null character")
  }
  let null_form_feed = @html_parser.parse(
    "<math><mi>\u{0000}\u{000C}</mi></math>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(null_form_feed.root),
    "| <html>\n|   <head>\n|   <body>\n|     <math math>\n|       <math mi>\n|         \" \"",
  )
  assert_eq(null_form_feed.errors.length(), 2)
  assert_eq(null_form_feed.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(null_form_feed.errors[1].code, "unexpected-null-character")
  guard null_form_feed.errors[1].column is Some(11) else {
    fail("expected MathML mixed null error at null character")
  }
  let whitespace = @html_parser.parse(
    "<math><mi>   </mi></math>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(whitespace.root),
    "| <html>\n|   <head>\n|   <body>\n|     <math math>\n|       <math mi>\n|         \"   \"",
  )
  assert_eq(whitespace.errors.length(), 1)
  assert_eq(whitespace.errors[0].code, "expected-doctype-but-got-start-tag")
  guard whitespace.errors[0].column is Some(6) else {
    fail("expected MathML whitespace doctype error at math start close")
  }
}

///|
test "tree builder matches reference after-head stray template end fixture" {
  let doc = @html_parser.parse(
    "<head></head></template>text",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(doc.root),
    "| <html>\n|   <head>\n|   <body>\n|     \"text\"",
  )
  assert_eq(doc.errors.length(), 2)
  assert_eq(doc.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(doc.errors[1].code, "unexpected-end-tag")
  guard doc.errors[1].column is Some(24) else {
    fail("expected stray template end at close bracket")
  }
}

///|
test "tree builder matches reference definition list fixture" {
  let doc = @html_parser.parse("<dl><dd>x</dd></dl>", collect_errors=true)
  assert_eq(
    @html_parser.to_test_format(doc.root),
    "| <html>\n|   <head>\n|   <body>\n|     <dl>\n|       <dd>\n|         \"x\"",
  )
  assert_eq(doc.errors.length(), 1)
  assert_eq(doc.errors[0].code, "expected-doctype-but-got-start-tag")
}

///|
test "tree builder matches reference table caption comment fixture" {
  let doc = @html_parser.parse(
    "<table><caption><!--comment--></caption></table>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(doc.root),
    "| <html>\n|   <head>\n|   <body>\n|     <table>\n|       <caption>\n|         <!-- comment -->",
  )
  assert_eq(doc.errors.length(), 1)
  assert_eq(doc.errors[0].code, "expected-doctype-but-got-start-tag")
}

///|
test "tree builder matches reference select form-feed text fixture" {
  let doc = @html_parser.parse(
    "<select>\u{000C}text</select>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(doc.root),
    "| <html>\n|   <head>\n|   <body>\n|     <select>\n|       \" text\"",
  )
  assert_eq(doc.errors.length(), 1)
  assert_eq(doc.errors[0].code, "expected-doctype-but-got-start-tag")
}

///|
test "tree builder matches reference frameset trailing end fixture" {
  let doc = @html_parser.parse(
    "<frameset></frameset></frameset>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(doc.root),
    "| <html>\n|   <head>\n|   <frameset>",
  )
  assert_eq(doc.errors.length(), 2)
  assert_eq(doc.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(doc.errors[1].code, "unexpected-token-after-frameset")
  guard doc.errors[1].column is Some(32) else {
    fail("expected trailing frameset end tag at close bracket")
  }
}

///|
test "tree builder matches reference nested table in caption fixture" {
  let doc = @html_parser.parse(
    "<table><caption><table></table></caption></table>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(doc.root),
    "| <html>\n|   <head>\n|   <body>\n|     <table>\n|       <caption>\n|     <table>",
  )
  assert_eq(doc.errors.length(), 5)
  assert_eq(doc.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(doc.errors[1].code, "unexpected-start-tag-implies-end-tag")
  assert_eq(doc.errors[2].code, "unexpected-start-tag-implies-end-tag")
  assert_eq(doc.errors[3].code, "unexpected-end-tag")
  assert_eq(doc.errors[4].code, "unexpected-end-tag")
  guard doc.errors[1].column is Some(23) else {
    fail("expected nested table first implied close at table start close")
  }
  guard doc.errors[2].column is Some(23) else {
    fail("expected nested table second implied close at table start close")
  }
  guard doc.errors[3].column is Some(41) else {
    fail("expected stray caption end at close bracket")
  }
  guard doc.errors[4].column is Some(49) else {
    fail("expected stray outer table end at close bracket")
  }
}

///|
test "tree builder matches reference table null text fixture" {
  let doc = @html_parser.parse("<table>\u{0000}</table>", collect_errors=true)
  assert_eq(
    @html_parser.to_test_format(doc.root),
    "| <html>\n|   <head>\n|   <body>\n|     <table>",
  )
  assert_eq(doc.errors.length(), 2)
  assert_eq(doc.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(doc.errors[1].code, "unexpected-null-character")
  guard doc.errors[0].column is Some(7) else {
    fail("expected table doctype error at table start close")
  }
  guard doc.errors[1].column is Some(8) else {
    fail("expected null text error at null character")
  }
}

///|
test "tree builder matches Python reference table fostered text behavior" {
  let doc = @html_parser.parse("<table>text</table>", collect_errors=true)
  assert_eq(
    @html_parser.to_test_format(doc.root),
    "| <html>\n|   <head>\n|   <body>\n|     \"text\"\n|     <table>",
  )
  assert_eq(doc.errors.length(), 5)
  assert_eq(doc.errors[0].code, "expected-doctype-but-got-start-tag")
  for index in 1..<doc.errors.length() {
    assert_eq(doc.errors[index].code, "foster-parenting-character")
  }
  guard doc.errors[0].column is Some(7) else {
    fail("expected table doctype error at table start close")
  }
}

///|
test "tree builder matches reference table direct cell comment fixture" {
  let doc = @html_parser.parse(
    "<table><td><!-- comment in cell --></td></table>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(doc.root),
    "| <html>\n|   <head>\n|   <body>\n|     <table>\n|       <tbody>\n|         <tr>\n|           <td>\n|             <!--  comment in cell  -->",
  )
  assert_eq(doc.errors.length(), 2)
  assert_eq(doc.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(doc.errors[1].code, "unexpected-cell-in-table-body")
  guard doc.errors[1].column is Some(11) else {
    fail("expected direct table cell error at td start close")
  }
}

///|
test "tree builder matches reference after-head null fixture" {
  let doc = @html_parser.parse("<head></head>\u{0000}", collect_errors=true)
  assert_eq(
    @html_parser.to_test_format(doc.root),
    "| <html>\n|   <head>\n|   <body>",
  )
  assert_eq(doc.errors.length(), 2)
  assert_eq(doc.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(doc.errors[1].code, "unexpected-null-character")
  guard doc.errors[0].column is Some(6) else {
    fail("expected head doctype error at head start close")
  }
  guard doc.errors[1].column is Some(14) else {
    fail("expected after-head null error at null character")
  }
}

///|
test "tree builder matches Python reference table form-feed behavior" {
  let doc = @html_parser.parse("<table>\u{000C}</table>", collect_errors=true)
  assert_eq(
    @html_parser.to_test_format(doc.root),
    "| <html>\n|   <head>\n|   <body>\n|     <table>\n|       \" \"",
  )
  assert_eq(doc.errors.length(), 1)
  assert_eq(doc.errors[0].code, "expected-doctype-but-got-start-tag")
  guard doc.errors[0].column is Some(7) else {
    fail("expected table form-feed doctype error at table start close")
  }
}

///|
test "tree builder matches reference select stray end EOF fixture" {
  let doc = @html_parser.parse("<select></regularitem>", collect_errors=true)
  assert_eq(
    @html_parser.to_test_format(doc.root),
    "| <html>\n|   <head>\n|   <body>\n|     <select>",
  )
  assert_eq(doc.errors.length(), 3)
  assert_eq(doc.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(doc.errors[1].code, "unexpected-end-tag")
  assert_eq(doc.errors[2].code, "expected-closing-tag-but-got-eof")
  guard doc.errors[1].column is Some(22) else {
    fail("expected stray select end tag at close bracket")
  }
  guard doc.errors[2].column is Some(22) else {
    fail("expected open select EOF at final column")
  }
}

///|
test "tree builder matches reference select parent end text fixture" {
  let doc = @html_parser.parse("<div><select></div>text", collect_errors=true)
  assert_eq(
    @html_parser.to_test_format(doc.root),
    "| <html>\n|   <head>\n|   <body>\n|     <div>\n|       <select>\n|         \"text\"",
  )
  assert_eq(doc.errors.length(), 3)
  assert_eq(doc.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(doc.errors[1].code, "unexpected-end-tag-in-select")
  assert_eq(doc.errors[2].code, "expected-closing-tag-but-got-eof")
  guard doc.errors[1].column is Some(19) else {
    fail("expected parent end tag in select at close bracket")
  }
  guard doc.errors[2].column is Some(23) else {
    fail("expected open select EOF after trailing text")
  }
}

///|
test "tree builder matches Python reference mixed frameset recovery behavior" {
  let doc = @html_parser.parse(
    "<figure><frameset><h1><aside><figcaption><html><frameset>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(doc.root),
    "| <html>\n|   <head>\n|   <frameset>",
  )
  assert_eq(doc.errors.length(), 7)
  assert_eq(doc.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(doc.errors[1].code, "unexpected-token-in-frameset")
  assert_eq(doc.errors[2].code, "unexpected-token-in-frameset")
  assert_eq(doc.errors[3].code, "unexpected-token-in-frameset")
  assert_eq(doc.errors[4].code, "unexpected-start-tag")
  assert_eq(doc.errors[5].code, "unexpected-start-tag-ignored")
  assert_eq(doc.errors[6].code, "expected-closing-tag-but-got-eof")
  guard doc.errors[0].column is Some(8) else {
    fail("expected figure doctype error at start tag close")
  }
  guard doc.errors[1].column is Some(22) else {
    fail("expected h1 frameset error at close bracket")
  }
  guard doc.errors[2].column is Some(29) else {
    fail("expected aside frameset error at close bracket")
  }
  guard doc.errors[3].column is Some(41) else {
    fail("expected figcaption frameset error at close bracket")
  }
  guard doc.errors[4].column is Some(47) else {
    fail("expected html frameset recovery error at close bracket")
  }
  guard doc.errors[5].column is Some(57) else {
    fail("expected ignored nested frameset error at close bracket")
  }
  guard doc.errors[6].column is Some(57) else {
    fail("expected open frameset EOF at final column")
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
  let html40_public = @html_parser.parse(
    "<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.0//EN\">",
    collect_errors=true,
  )
  assert_eq(
    html40_public.to_html(pretty=false),
    "<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.0//EN\"><html><head></head><body></body></html>",
  )
  assert_eq(html40_public.errors.length(), 0)
  let html40_strict = @html_parser.parse(
    "<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.0//EN\" \"http://www.w3.org/TR/REC-html40/strict.dtd\">",
    collect_errors=true,
  )
  assert_eq(
    html40_strict.to_html(pretty=false),
    "<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.0//EN\" \"http://www.w3.org/TR/REC-html40/strict.dtd\"><html><head></head><body></body></html>",
  )
  assert_eq(html40_strict.errors.length(), 0)
  let xhtml10 = @html_parser.parse(
    "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">",
    collect_errors=true,
  )
  assert_eq(
    xhtml10.to_html(pretty=false),
    "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\"><html><head></head><body></body></html>",
  )
  assert_eq(xhtml10.errors.length(), 0)
  let xhtml11 = @html_parser.parse(
    "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.1//EN\" \"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd\">",
    collect_errors=true,
  )
  assert_eq(
    xhtml11.to_html(pretty=false),
    "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.1//EN\" \"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd\"><html><head></head><body></body></html>",
  )
  assert_eq(xhtml11.errors.length(), 0)
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

///|
test "fragment context seeds foreign namespaces" {
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
  let cdata = @html_parser.parse_fragment(
    "text<![CDATA[x<y]]>",
    context=@html_parser.FragmentContext::new("svg", ns="svg"),
    collect_errors=true,
  )
  assert_eq(cdata.to_html(pretty=false), "textx&lt;y")
  assert_eq(cdata.errors.length(), 1)
  assert_eq(cdata.errors[0].code, "expected-closing-tag-but-got-eof")
  let math = @html_parser.parse_fragment(
    "<mi>x</mi><mo>=</mo><mn>5</mn>",
    context=@html_parser.FragmentContext::new("math", ns="mathml"),
    collect_errors=true,
  )
  assert_eq(math.to_html(pretty=false), "<mi>x</mi><mo>=</mo><mn>5</mn>")
  assert_eq(math.errors.length(), 1)
  assert_eq(math.errors[0].code, "expected-closing-tag-but-got-eof")
  guard math.query_one("mi") is Some(mi) else { fail("expected MathML mi") }
  assert_true(mi.namespace_uri() is Some("math"))
  let breakout = @html_parser.parse_fragment(
    "</svg><p>x</p>",
    context=@html_parser.FragmentContext::new("svg", ns="svg"),
    collect_errors=true,
  )
  assert_eq(breakout.to_html(pretty=false), "<p>x</p>")
  assert_eq(breakout.errors.length(), 3)
  assert_eq(breakout.errors[0].code, "unexpected-end-tag-in-fragment-context")
  assert_eq(
    breakout.errors[1].code,
    "unexpected-html-element-in-foreign-content",
  )
  assert_eq(breakout.errors[2].code, "expected-closing-tag-but-got-eof")
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
test "template table context defers structural end recovery to template end" {
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
  let section = @html_parser.parse_fragment(
    "<template><tbody><tr><td>x</td></tr></tbody></template>",
    collect_errors=true,
  )
  assert_eq(
    section.to_html(pretty=false),
    "<template><tbody><tr><td>x</td></tr></tbody></template>",
  )
  assert_eq(section.errors.length(), 2)
  assert_eq(section.errors[0].code, "unexpected-end-tag")
  assert_eq(section.errors[1].code, "unexpected-end-tag-implies-table-voodoo")
  let direct_cell = @html_parser.parse_fragment(
    "<template><tbody><td>x</td></tbody></template>",
    collect_errors=true,
  )
  assert_eq(
    direct_cell.to_html(pretty=false),
    "<template><tbody><tr><td>x</td></tr></tbody></template>",
  )
  assert_eq(direct_cell.errors.length(), 3)
  assert_eq(direct_cell.errors[0].code, "unexpected-cell-in-table-body")
  assert_eq(direct_cell.errors[1].code, "unexpected-end-tag")
  assert_eq(
    direct_cell.errors[2].code,
    "unexpected-end-tag-implies-table-voodoo",
  )
  let colgroup = @html_parser.parse_fragment(
    "<template><colgroup> x</colgroup></template>",
    collect_errors=true,
  )
  assert_eq(
    colgroup.to_html(pretty=false),
    "<template><colgroup> </colgroup>x</template>",
  )
  assert_eq(colgroup.errors.length(), 4)
  assert_eq(colgroup.errors[0].code, "unexpected-characters-in-column-group")
  assert_eq(colgroup.errors[1].code, "foster-parenting-character")
  assert_eq(colgroup.errors[2].code, "unexpected-end-tag")
  assert_eq(colgroup.errors[3].code, "unexpected-end-tag-implies-table-voodoo")
}

///|
test "template table row contexts foster non-whitespace text" {
  let row = @html_parser.parse_fragment(
    "<template><tr>x<td>y</td></tr></template>",
    collect_errors=true,
  )
  assert_eq(
    row.to_html(pretty=false),
    "<template><tr><td>y</td></tr>x</template>",
  )
  assert_eq(row.errors.length(), 2)
  assert_eq(row.errors[0].code, "foster-parenting-character")
  assert_eq(row.errors[1].code, "unexpected-end-tag-implies-table-voodoo")
  let section = @html_parser.parse_fragment(
    "<template><tbody>x<tr><td>y</td></tr></tbody></template>",
    collect_errors=true,
  )
  assert_eq(
    section.to_html(pretty=false),
    "<template><tbody><tr><td>y</td></tr></tbody>x</template>",
  )
  assert_eq(section.errors.length(), 3)
  assert_eq(section.errors[0].code, "foster-parenting-character")
  assert_eq(section.errors[1].code, "unexpected-end-tag")
  assert_eq(section.errors[2].code, "unexpected-end-tag-implies-table-voodoo")
}

///|
test "parser tracks origins for template table helper starts" {
  let caption = @html_parser.parse_fragment(
    "<template><caption>x</caption></template>",
    track_node_locations=true,
  )
  guard caption.query_one("caption") is Some(caption_node) else {
    fail("expected caption")
  }
  assert_node_origin(caption_node, 10, 1, 11)
  let caption_children = caption_node.children()
  assert_eq(caption_children.length(), 1)
  assert_node_origin(caption_children[0], 19, 1, 20)
  let row = @html_parser.parse_fragment(
    "<template><tr><td>x</td></tr></template>",
    track_node_locations=true,
  )
  guard row.query_one("tr") is Some(row_node) else { fail("expected row") }
  assert_node_origin(row_node, 10, 1, 11)
  guard row.query_one("td") is Some(row_cell) else { fail("expected cell") }
  assert_node_origin(row_cell, 14, 1, 15)
  let direct_cell = @html_parser.parse_fragment(
    "<template><td>x</td></template>",
    track_node_locations=true,
  )
  guard direct_cell.query_one("td") is Some(cell) else { fail("expected td") }
  assert_node_origin(cell, 10, 1, 11)
  let section = @html_parser.parse_fragment(
    "<template><tbody><tr><td>x</td></tr></tbody></template>",
    track_node_locations=true,
  )
  guard section.query_one("tbody") is Some(section_node) else {
    fail("expected section")
  }
  assert_node_origin(section_node, 10, 1, 11)
}

///|
test "template caption structural starts close caption and reprocess" {
  let row = @html_parser.parse_fragment(
    "<template><caption>x<tr><td>y</td></tr></caption></template>",
    collect_errors=true,
  )
  assert_eq(
    row.to_html(pretty=false),
    "<template><caption>x</caption><tbody><tr><td>y</td></tr></tbody></template>",
  )
  assert_eq(row.errors.length(), 3)
  assert_eq(row.errors[0].code, "unexpected-start-tag-implies-end-tag")
  assert_eq(row.errors[1].code, "unexpected-end-tag")
  assert_eq(row.errors[2].code, "unexpected-end-tag-implies-table-voodoo")
  let nested_table = @html_parser.parse_fragment(
    "<template><caption>x<table><tr><td>y</td></tr></table></caption></template>",
    collect_errors=true,
  )
  assert_eq(
    nested_table.to_html(pretty=false),
    "<template><caption>x</caption><tbody><tr><td>y</td></tr></tbody></template>",
  )
  assert_eq(nested_table.errors.length(), 6)
  assert_eq(nested_table.errors[0].code, "unexpected-start-tag-implies-end-tag")
  assert_eq(nested_table.errors[1].code, "unexpected-start-tag-implies-end-tag")
  assert_eq(nested_table.errors[2].code, "unexpected-end-tag")
  assert_eq(nested_table.errors[3].code, "unexpected-end-tag")
  assert_eq(nested_table.errors[4].code, "unexpected-end-tag")
  assert_eq(
    nested_table.errors[5].code,
    "unexpected-end-tag-implies-table-voodoo",
  )
  let colgroup = @html_parser.parse_fragment(
    "<template><caption>x<colgroup><col></colgroup></caption></template>",
    collect_errors=true,
  )
  assert_eq(
    colgroup.to_html(pretty=false),
    "<template><caption>x</caption><colgroup><col></colgroup></template>",
  )
  assert_eq(colgroup.errors.length(), 3)
  assert_eq(colgroup.errors[0].code, "unexpected-start-tag-implies-end-tag")
  assert_eq(colgroup.errors[1].code, "unexpected-end-tag")
  assert_eq(colgroup.errors[2].code, "unexpected-end-tag-implies-table-voodoo")
}

///|
test "template caption end defers recovery to template end" {
  let caption = @html_parser.parse_fragment(
    "<template><caption>x</caption></template>",
    collect_errors=true,
  )
  assert_eq(
    caption.to_html(pretty=false),
    "<template><caption>x</caption></template>",
  )
  assert_eq(caption.errors.length(), 1)
  assert_eq(caption.errors[0].code, "unexpected-end-tag-implies-table-voodoo")
  let nested_caption = @html_parser.parse_fragment(
    "<template><caption>x<caption>y</caption></caption></template>",
    collect_errors=true,
  )
  assert_eq(
    nested_caption.to_html(pretty=false),
    "<template><caption>x</caption><caption>y</caption></template>",
  )
  assert_eq(nested_caption.errors.length(), 3)
  assert_eq(
    nested_caption.errors[0].code,
    "unexpected-start-tag-implies-end-tag",
  )
  assert_eq(nested_caption.errors[1].code, "unexpected-end-tag")
  assert_eq(
    nested_caption.errors[2].code,
    "unexpected-end-tag-implies-table-voodoo",
  )
}

///|
test "template table recovery fosters ordinary body starts" {
  let after_caption = @html_parser.parse_fragment(
    "<template><caption>x</caption><p>z</p></template>",
    collect_errors=true,
  )
  assert_eq(
    after_caption.to_html(pretty=false),
    "<template><caption>x</caption><p>z</p></template>",
  )
  assert_eq(after_caption.errors.length(), 4)
  assert_eq(after_caption.errors[0].code, "foster-parenting-start-tag")
  assert_eq(after_caption.errors[1].code, "foster-parenting-character")
  assert_eq(
    after_caption.errors[2].code,
    "unexpected-end-tag-implies-table-voodoo",
  )
  assert_eq(
    after_caption.errors[3].code,
    "unexpected-end-tag-implies-table-voodoo",
  )
  let after_row = @html_parser.parse_fragment(
    "<template><tr><td>x</td></tr><p>z</p></template>",
    collect_errors=true,
  )
  assert_eq(
    after_row.to_html(pretty=false),
    "<template><tr><td>x</td></tr><p>z</p></template>",
  )
  assert_eq(after_row.errors.length(), 4)
  assert_eq(after_row.errors[0].code, "foster-parenting-start-tag")
  assert_eq(after_row.errors[1].code, "foster-parenting-character")
  assert_eq(after_row.errors[2].code, "unexpected-end-tag-implies-table-voodoo")
  assert_eq(after_row.errors[3].code, "unexpected-end-tag-implies-table-voodoo")
}

///|
test "template table recovery accepts structural starts after caption" {
  let section = @html_parser.parse_fragment(
    "<template><caption>x</caption><tbody><tr><td>y</td></tr></tbody></template>",
    collect_errors=true,
  )
  assert_eq(
    section.to_html(pretty=false),
    "<template><caption>x</caption><tbody><tr><td>y</td></tr></tbody></template>",
  )
  assert_eq(section.errors.length(), 2)
  assert_eq(section.errors[0].code, "unexpected-end-tag")
  assert_eq(section.errors[1].code, "unexpected-end-tag-implies-table-voodoo")
  let direct_cell = @html_parser.parse_fragment(
    "<template><caption>x</caption><td>y</td></template>",
    collect_errors=true,
  )
  assert_eq(
    direct_cell.to_html(pretty=false),
    "<template><caption>x</caption><tbody><tr><td>y</td></tr></tbody></template>",
  )
  assert_eq(direct_cell.errors.length(), 1)
  assert_eq(direct_cell.errors[0].code, "unexpected-cell-in-table-body")
  let script = @html_parser.parse_fragment(
    "<template><caption>x</caption><script>y</script></template>",
    collect_errors=true,
  )
  assert_eq(
    script.to_html(pretty=false),
    "<template><caption>x</caption><script>y</script></template>",
  )
  assert_eq(script.errors.length(), 1)
  assert_eq(script.errors[0].code, "unexpected-end-tag-implies-table-voodoo")
}

///|
test "template caption end tags keep caption open for recovery" {
  let table_body = @html_parser.parse_fragment(
    "<template><caption>x</tbody></caption></template>",
    collect_errors=true,
  )
  assert_eq(
    table_body.to_html(pretty=false),
    "<template><caption>x</caption></template>",
  )
  assert_eq(table_body.errors.length(), 2)
  assert_eq(table_body.errors[0].code, "unexpected-end-tag")
  assert_eq(
    table_body.errors[1].code,
    "unexpected-end-tag-implies-table-voodoo",
  )
  let generic = @html_parser.parse_fragment(
    "<template><caption>x</div></caption></template>",
    collect_errors=true,
  )
  assert_eq(
    generic.to_html(pretty=false),
    "<template><caption>x</caption></template>",
  )
  assert_eq(generic.errors.length(), 2)
  assert_eq(generic.errors[0].code, "unexpected-end-tag")
  assert_eq(generic.errors[1].code, "unexpected-end-tag-implies-table-voodoo")
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
test "nested templates suspend hidden template table modes" {
  let nested_column_group = @html_parser.parse_fragment(
    "<template><col><template><p>x</p></template><col></template>",
    collect_errors=true,
  )
  assert_eq(
    nested_column_group.to_html(pretty=false),
    "<template><col><template><p>x</p></template><col></template>",
  )
  assert_eq(nested_column_group.errors.length(), 0)
  let nested_own_column_group = @html_parser.parse_fragment(
    "<template><col><template><col>x</template><col></template>",
    collect_errors=true,
  )
  assert_eq(
    nested_own_column_group.to_html(pretty=false),
    "<template><col><template><col></template><col></template>",
  )
  assert_eq(nested_own_column_group.errors.length(), 1)
  assert_eq(
    nested_own_column_group.errors[0].code,
    "unexpected-characters-in-template-column-group",
  )
  let nested_table_context = @html_parser.parse_fragment(
    "<template><tr></tr><template>x</template></template>",
    collect_errors=true,
  )
  assert_eq(
    nested_table_context.to_html(pretty=false),
    "<template><tr></tr><template>x</template></template>",
  )
  assert_eq(nested_table_context.errors.length(), 1)
  assert_eq(
    nested_table_context.errors[0].code,
    "unexpected-end-tag-implies-table-voodoo",
  )
  let whitespace_colgroup = @html_parser.parse_fragment(
    "<template><colgroup> </colgroup><template>x</template></template>",
    collect_errors=true,
  )
  assert_eq(
    whitespace_colgroup.to_html(pretty=false),
    "<template><colgroup> </colgroup><template>x</template></template>",
  )
  assert_eq(whitespace_colgroup.errors.length(), 3)
  assert_eq(
    whitespace_colgroup.errors[0].code,
    "unexpected-characters-in-column-group",
  )
  assert_eq(whitespace_colgroup.errors[1].code, "unexpected-end-tag")
  assert_eq(
    whitespace_colgroup.errors[2].code,
    "unexpected-end-tag-implies-table-voodoo",
  )
  let detached_then_nested = @html_parser.parse_fragment(
    "<template><col></p><template>x</template></template>",
    collect_errors=true,
  )
  assert_eq(
    detached_then_nested.to_html(pretty=false),
    "<template><col></template><p></p><template>x</template>",
  )
  assert_eq(detached_then_nested.errors.length(), 3)
  assert_eq(
    detached_then_nested.errors[0].code,
    "unexpected-end-tag-implies-table-voodoo",
  )
  assert_eq(detached_then_nested.errors[1].code, "unexpected-end-tag")
  assert_eq(detached_then_nested.errors[2].code, "unexpected-end-tag")
}

///|
test "parser tracks origins for template column group starts" {
  let parsed = @html_parser.parse_fragment(
    "<template><col>x<col></template>",
    track_node_locations=true,
  )
  guard parsed.query_one("template") is Some(template) else {
    fail("expected template")
  }
  let children = template.children()
  assert_eq(children.length(), 2)
  assert_node_origin(children[0], 10, 1, 11)
  assert_node_origin(children[1], 16, 1, 17)
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
  let detached_colgroup_end = @html_parser.parse_fragment(
    "<template><col><div>x</div><col></colgroup></template>",
    collect_errors=true,
  )
  assert_eq(
    detached_colgroup_end.to_html(pretty=false),
    "<template><col></template><colgroup><col></colgroup>",
  )
  assert_eq(detached_colgroup_end.errors.length(), 6)
  assert_eq(
    detached_colgroup_end.errors[0].code,
    "unexpected-start-tag-in-template-column-group",
  )
  assert_eq(
    detached_colgroup_end.errors[1].code,
    "unexpected-characters-in-template-column-group",
  )
  assert_eq(
    detached_colgroup_end.errors[2].code,
    "unexpected-end-tag-implies-table-voodoo",
  )
  assert_eq(detached_colgroup_end.errors[3].code, "unexpected-end-tag")
  assert_eq(
    detached_colgroup_end.errors[4].code,
    "unexpected-end-tag-implies-table-voodoo",
  )
  assert_eq(detached_colgroup_end.errors[5].code, "unexpected-end-tag")
  let detached_col_end = @html_parser.parse_fragment(
    "<template><col><div>x</div><col></col></template>",
    collect_errors=true,
  )
  assert_eq(
    detached_col_end.to_html(pretty=false),
    "<template><col></template><colgroup><col></colgroup>",
  )
  assert_eq(detached_col_end.errors.length(), 5)
  assert_eq(
    detached_col_end.errors[0].code,
    "unexpected-start-tag-in-template-column-group",
  )
  assert_eq(
    detached_col_end.errors[1].code,
    "unexpected-characters-in-template-column-group",
  )
  assert_eq(
    detached_col_end.errors[2].code,
    "unexpected-end-tag-implies-table-voodoo",
  )
  assert_eq(detached_col_end.errors[3].code, "unexpected-end-tag")
  assert_eq(detached_col_end.errors[4].code, "unexpected-end-tag")
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
  let explicit_html_ns_cell = @html_parser.parse_fragment(
    "<td>x</td>",
    context=@html_parser.FragmentContext::new("table", ns="html"),
    collect_errors=true,
  )
  assert_eq(
    explicit_html_ns_cell.to_html(pretty=false),
    "<tbody><tr><td>x</td></tr></tbody>",
  )
  assert_eq(explicit_html_ns_cell.errors.length(), 1)
  assert_eq(
    explicit_html_ns_cell.errors[0].code,
    "unexpected-cell-in-table-body",
  )
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
  let br_end = @html_parser.parse_fragment(
    "</br>x",
    context=@html_parser.FragmentContext::new("table"),
    collect_errors=true,
  )
  assert_eq(br_end.to_html(pretty=false), "<br>x")
  assert_eq(br_end.errors.length(), 3)
  assert_eq(br_end.errors[0].code, "unexpected-end-tag")
  assert_eq(br_end.errors[1].code, "unexpected-end-tag-implies-table-voodoo")
  assert_eq(br_end.errors[2].code, "foster-parenting-character")
  guard br_end.errors[0].column is Some(1) else {
    fail("expected table fragment br end tag error at opener")
  }
  guard br_end.errors[1].column is Some(5) else {
    fail("expected table fragment br voodoo error at tag close")
  }
  guard br_end.errors[2].column is Some(6) else {
    fail("expected table fragment fostered text after br")
  }
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
  let ignored_section_end = @html_parser.parse_fragment(
    "</tbody>x",
    context=@html_parser.FragmentContext::new("tbody"),
    collect_errors=true,
  )
  assert_eq(ignored_section_end.to_html(pretty=false), "x")
  assert_eq(ignored_section_end.errors.length(), 2)
  assert_eq(ignored_section_end.errors[0].code, "unexpected-end-tag")
  assert_eq(ignored_section_end.errors[1].code, "foster-parenting-character")
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
test "parser tracks origins for fragment colgroup starts" {
  let cols = @html_parser.parse_fragment(
    "<col><col>",
    context=@html_parser.FragmentContext::new("colgroup"),
    track_node_locations=true,
  )
  let children = cols.root.children()
  assert_eq(children.length(), 2)
  assert_node_origin(children[0], 0, 1, 1)
  assert_node_origin(children[1], 5, 1, 6)
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
  assert_eq(doc.query("*foo").length(), 0)
  let first = doc.query_one("p.lead")
  guard first is Some(node) else { fail("expected p.lead") }
  assert_eq(node.to_text(separator="", strip=false), "One")
  assert_true(@html_parser.matches(node, "*"))
  assert_eq(@html_parser.matches(node, "*foo"), false)
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
  let leading_space = @html_parser.fragment(children=[
    @html_parser.element("p", attrs={ "class": Some(" alpha") }),
  ])
  assert_eq(leading_space.query(".alpha").length(), 1)
  let compound = @html_parser.parse_fragment(
    "<div id='main' class='container featured'><p>Text</p></div>",
  )
  assert_eq(compound.query("div#main").length(), 1)
  assert_eq(compound.query("span#main").length(), 0)
  assert_eq(compound.query("*.container").length(), 1)
  assert_eq(compound.query("div.container#main").length(), 1)
  assert_eq(compound.query("#main.container.featured").length(), 1)
  assert_eq(compound.query("div#main.missing").length(), 0)
  assert_eq(@html_parser.query(compound.root, "p").length(), 1)
  let identifiers = @html_parser.fragment(children=[
    @html_parser.element("1box", attrs={
      "id": Some("1id"),
      "class": Some("1lead ok _under -dash 日本語"),
    }),
    @html_parser.element("-box", attrs={ "id": Some("_id") }),
    @html_parser.element("日本語"),
  ])
  assert_eq(identifiers.query("1box").length(), 0)
  assert_eq(identifiers.query("#1id").length(), 0)
  assert_eq(identifiers.query(".1lead").length(), 0)
  assert_eq(identifiers.query(".ok").length(), 1)
  assert_eq(identifiers.query("._under").length(), 1)
  assert_eq(identifiers.query(".-dash").length(), 1)
  assert_eq(identifiers.query(".日本語").length(), 1)
  assert_eq(identifiers.query("-box").length(), 1)
  assert_eq(identifiers.query("#_id").length(), 1)
  assert_eq(identifiers.query("日本語").length(), 1)
  let css_identifiers = @html_parser.parse_fragment(
    "<my-element id='my-id' class='my-class class1 über'>Test</my-element>",
  )
  assert_eq(css_identifiers.query("my-element").length(), 1)
  assert_eq(css_identifiers.query("#my-id").length(), 1)
  assert_eq(css_identifiers.query(".my-class").length(), 1)
  assert_eq(css_identifiers.query(".class1").length(), 1)
  assert_eq(css_identifiers.query(".über").length(), 1)
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
  assert_eq(doc.query("[]").length(), 0)
  assert_eq(doc.query("[=main]").length(), 0)
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
    "<div class='container secondary' lang='en-US' data-tags='alpha\tbeta' data-name='example item' data-quote='hello&quot;world' data-slash='a\\b' data-escape='x'><a href='http://example.com'>Link</a><p data-empty=''></p></div>",
  )
  assert_eq(doc.query("[class~='container']").length(), 1)
  assert_eq(doc.query("[class~='contain']").length(), 0)
  assert_eq(doc.query("[class~='']").length(), 0)
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
  assert_eq(doc.query("[data-name='example item']").length(), 1)
  assert_eq(doc.query("[data-name=example item]").length(), 0)
  assert_eq(doc.query("[href^='']").length(), 0)
  assert_eq(doc.query("[href$='']").length(), 0)
  assert_eq(doc.query("[href*='']").length(), 0)
  assert_eq(doc.query("[data-quote=\"hello\\\"world\"]").length(), 1)
  assert_eq(doc.query("[data-slash=\"a\\\\b\"]").length(), 1)
  assert_eq(doc.query("[data-escape=\"\\x\"]").length(), 1)
  assert_eq(doc.query("[data-quote=\"hello\\\"world\"], p").length(), 2)
  assert_eq(doc.query("div > [data-quote=\"hello\\\"world\"]").length(), 0)
  assert_eq(doc.query("[~=container]").length(), 0)
  assert_eq(doc.query("[href!=http://example.com]").length(), 0)
  assert_eq(doc.query("[lang|=e]").length(), 0)
  let exact_lang = @html_parser.parse_fragment(
    "<p lang='en'></p><p lang='en-US'></p><p lang='eng'></p>",
  )
  assert_eq(exact_lang.query("[lang|=en]").length(), 2)
  let empty = @html_parser.parse_fragment(
    "<p data-empty=''></p><p data-empty='x'></p>",
  )
  assert_eq(empty.query("[data-empty=]").length(), 1)
  let punctuation = @html_parser.fragment(children=[
    @html_parser.element("p", attrs={
      "data-id": Some("x"),
      "data-id!": Some("x"),
      "1data": Some("x"),
      "xlink:href": Some("url"),
      "日本語": Some("yes"),
    }),
  ])
  assert_eq(punctuation.query("[data-id=x]").length(), 1)
  assert_eq(punctuation.query("[data-id!=x]").length(), 0)
  assert_eq(punctuation.query("[1data=x]").length(), 0)
  assert_eq(punctuation.query("[xlink:href]").length(), 0)
  assert_eq(punctuation.query("[日本語=yes]").length(), 1)
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
  assert_eq(doc.query("p,").length(), 2)
  assert_eq(doc.query("p,, a").length(), 3)
  assert_eq(doc.query(", p").length(), 0)
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
test "query treats malformed selector pieces as no match" {
  let doc = @html_parser.parse_fragment(
    "<section><h1>Title</h1><p id='intro' class='lead'>One</p><a href='x'>Link</a></section>",
  )
  assert_eq(doc.query("").length(), 0)
  assert_eq(doc.query("   ").length(), 0)
  assert_eq(doc.query("div@foo").length(), 0)
  assert_eq(doc.query("p[").length(), 0)
  assert_eq(doc.query("p.").length(), 0)
  assert_eq(doc.query("p#").length(), 0)
  assert_eq(doc.query("p[id]]").length(), 0)
  assert_eq(doc.query("[attr=\"unclosed]").length(), 0)
  assert_eq(doc.query(":contains(foo").length(), 0)
  assert_eq(doc.query("p >").length(), 0)
  assert_eq(doc.query("> p").length(), 0)
  assert_eq(doc.query("section > > p").length(), 0)
  assert_eq(doc.query("section,, p").length(), 2)
  assert_eq(doc.query("p, p[").length(), 0)
  assert_eq(doc.query("p, :hover").length(), 0)
  assert_eq(doc.query("p, > a").length(), 0)
  assert_eq(doc.query("p, .").length(), 0)
  guard doc.query_one("p") is Some(paragraph) else {
    fail("expected paragraph")
  }
  assert_eq(@html_parser.matches(paragraph, "p["), false)
  assert_eq(@html_parser.matches(paragraph, "p."), false)
  assert_eq(@html_parser.matches(paragraph, "> p"), false)
  assert_eq(@html_parser.matches(paragraph, "p, p["), false)
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
  assert_eq(doc.query("p + h1").length(), 0)
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
  assert_eq(doc.query("p ~ h1").length(), 0)
  assert_eq(doc.query("h1 ~ p span").length(), 1)
  assert_eq(doc.query("h1 ~ p ~ span").length(), 1)
  assert_eq(doc.query("div > h1 ~ p").length(), 3)
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
  assert_eq(doc.query("li:nth-child(ODD)").length(), 3)
  assert_eq(doc.query("li:nth-child(+n)").length(), 5)
  assert_eq(doc.query("li:nth-child(-2n+5)").length(), 3)
  assert_eq(doc.query("li:nth-child(-2n+4)").length(), 2)
  assert_eq(doc.query("li:nth-child( 2n + 1 )").length(), 3)
  assert_eq(doc.query("li:nth-child(0)").length(), 0)
  assert_eq(doc.query("li:nth-child(-1)").length(), 0)
  assert_eq(doc.query("li:nth-child(100)").length(), 0)
  assert_eq(doc.query("li:nth-child(abc)").length(), 0)
  assert_eq(doc.query("li:nth-child(+)").length(), 0)
  assert_eq(doc.query("li:nth-child(xn+1)").length(), 0)
  assert_eq(doc.query("li:nth-child(2n+)").length(), 0)
  assert_eq(doc.query("li:nth-child(2n+n)").length(), 0)
  assert_eq(doc.query("li:nth-child(2n+x)").length(), 0)
  assert_eq(doc.query("li:nth-child()").length(), 0)
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
test "matches handles detached nodes for structural pseudo selectors" {
  let item = @html_parser.element("li")
  assert_eq(@html_parser.matches(item, ":first-child"), false)
  assert_eq(@html_parser.matches(item, ":last-child"), false)
  assert_eq(@html_parser.matches(item, ":first-of-type"), false)
  assert_eq(@html_parser.matches(item, ":last-of-type"), false)
  assert_eq(@html_parser.matches(item, ":nth-child(1)"), false)
  assert_eq(@html_parser.matches(item, ":nth-of-type(1)"), false)
  assert_eq(@html_parser.matches(item, "p + li"), false)
  assert_eq(@html_parser.matches(item, "p ~ li"), false)
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
  assert_eq(doc.query(":comment:empty").length(), 3)
  assert_eq(doc.query(":comment:not(.missing)").length(), 3)
  assert_eq(doc.query(":comment(x)").length(), 3)
  guard doc.query_one(":comment") is Some(comment) else {
    fail("expected comment")
  }
  assert_eq(comment.name(), "#comment")
  assert_true(@html_parser.matches(comment, ":comment"))
  assert_true(@html_parser.matches(comment, ":empty"))
  assert_true(@html_parser.matches(comment, ":not(span)"))
  assert_eq(@html_parser.matches(comment, ":not(:comment)"), false)
  assert_true(@html_parser.matches(comment, "div > :empty"))
  assert_eq(@html_parser.matches(comment, "*"), false)
  let mixed = @html_parser.parse_fragment(
    "<div>A<!-- note --><p>text</p></div>",
  )
  assert_eq(mixed.query(":empty").length(), 0)
  assert_eq(mixed.query("div > :empty").length(), 0)
  assert_eq(mixed.query("div > :comment:empty").length(), 1)
  assert_eq(mixed.query(":comment, :empty").length(), 3)
  assert_eq(mixed.query("[data-note=':comment'], :empty").length(), 0)
  assert_eq(mixed.query(":contains(':comment'), :empty").length(), 0)
  assert_eq(mixed.query(":1comment, :empty").length(), 0)
}

///|
test "query treats pseudo selector names case insensitively" {
  let doc = @html_parser.parse_fragment(
    "<ul><li>One</li><li class='special'>Two</li><li>Three</li></ul><button>Click</button><button>click</button><!-- note -->",
  )
  assert_eq(doc.query("li:FIRST-CHILD").length(), 1)
  assert_eq(doc.query("li:LAST-CHILD").length(), 1)
  assert_eq(doc.query("li:Nth-Child(2)").length(), 1)
  assert_eq(doc.query("li:nth-OF-type(2)").length(), 1)
  assert_eq(doc.query("li:NOT(.special)").length(), 2)
  assert_eq(doc.query("li:HOVER(2)").length(), 0)
  assert_eq(doc.query("button:CONTAINS(\"Click\")").length(), 1)
  assert_eq(doc.query("button:CONTAINS(\"CLICK\")").length(), 0)
  assert_eq(doc.query(":COMMENT").length(), 1)
  guard doc.query_one(":COMMENT") is Some(comment) else {
    fail("expected uppercase comment pseudo selector")
  }
  assert_true(@html_parser.matches(comment, ":COMMENT"))
}

///|
test "query supports contains pseudo selector" {
  let doc = @html_parser.parse_fragment(
    "<div id='a'><button>click me</button></div><div id='b'><button>do not click</button></div><div id='c'><span>click</span> me</div><div id='joined'><span>a</span><span>b</span></div><div id='spaced'><span>a</span> <span>b</span></div><p> padded </p><span>a)b</span><span>a(b</span>",
  )
  assert_eq(doc.query("button:contains(\"click me\")").length(), 1)
  assert_eq(doc.query("button:contains(click)").length(), 2)
  assert_eq(doc.query("div:contains(\"click me\")").length(), 2)
  assert_eq(doc.query("button:contains(\"Click\")").length(), 0)
  assert_eq(doc.query("button:contains(\"\")").length(), 2)
  assert_eq(doc.query("button:contains()").length(), 0)
  assert_eq(doc.query("div:contains(\"a b\")").length(), 2)
  assert_eq(doc.query("div:contains(\"ab\")").length(), 0)
  assert_eq(doc.query("#joined:contains(\"a b\")").length(), 1)
  assert_eq(doc.query("#joined:contains(\"ab\")").length(), 0)
  assert_eq(doc.query("p:contains(\"padded\")").length(), 1)
  assert_eq(doc.query("p:contains(\" padded \")").length(), 0)
  assert_eq(doc.query("span:contains('a)b')").length(), 0)
  assert_eq(doc.query("span:contains('a(b')").length(), 0)
  guard doc.query_one("#a") is Some(first) else { fail("expected first div") }
  assert_true(@html_parser.matches(first, "div:contains(\"click me\")"))
}

///|
test "query supports contains pseudo selector quoted escapes" {
  let doc = @html_parser.parse_fragment(
    "<div><span>don't</span><span>a\\b</span><span>don\\x</span><span>tail\\</span></div>",
  )
  assert_eq(doc.query("span:contains('don\\'t')").length(), 1)
  assert_eq(doc.query("span:contains(\"a\\\\b\")").length(), 1)
  assert_eq(doc.query("span:contains(\"don\\x\")").length(), 1)
  assert_eq(doc.query("span:contains(\"tail\\\")").length(), 1)
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
test "remove_child ignores missing children" {
  let parent = @html_parser.element("div")
  let kept = @html_parser.element("span")
  let missing = @html_parser.element("em")
  parent.append_child(kept)
  parent.remove_child(missing)
  assert_eq(parent.to_html(pretty=false), "<div><span></span></div>")
  assert_true(missing.parent() is None)
  guard kept.parent() is Some(kept_parent) else {
    fail("expected retained child parent")
  }
  assert_eq(kept_parent.name(), "div")
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
test "parser adoption agency preserves formatting origins" {
  let inline = @html_parser.parse_fragment(
    "<b><i>1</b>2</i>",
    collect_errors=true,
    track_node_locations=true,
  )
  assert_eq(inline.to_html(pretty=false), "<b><i>1</i></b><i>2</i>")
  assert_eq(inline.errors.length(), 1)
  assert_eq(inline.errors[0].code, "adoption-agency-1.3")
  let inline_bold = inline.root.query("b")
  guard inline_bold.length() == 1 else { fail("expected one inline bold") }
  assert_node_origin(inline_bold[0], 0, 1, 1)
  let inline_italic = inline.root.query("i")
  guard inline_italic.length() == 2 else { fail("expected replacement italic") }
  assert_node_origin(inline_italic[0], 3, 1, 4)
  assert_node_origin(inline_italic[1], 3, 1, 4)
  let block = @html_parser.parse_fragment(
    "<b><p>1</b>2",
    collect_errors=true,
    track_node_locations=true,
  )
  assert_eq(block.to_html(pretty=false), "<b></b><p><b>1</b>2</p>")
  assert_eq(block.errors.length(), 1)
  assert_eq(block.errors[0].code, "adoption-agency-1.3")
  let block_bold = block.root.query("b")
  guard block_bold.length() == 2 else {
    fail("expected block replacement bold")
  }
  assert_node_origin(block_bold[0], 0, 1, 1)
  assert_node_origin(block_bold[1], 0, 1, 1)
  let nested = @html_parser.parse_fragment(
    "<b><i><p>1</b>2</i>",
    collect_errors=true,
    track_node_locations=true,
  )
  assert_eq(
    nested.to_html(pretty=false),
    "<b><i></i></b><i></i><p><i><b>1</b>2</i></p>",
  )
  assert_eq(nested.errors.length(), 2)
  assert_eq(nested.errors[0].code, "adoption-agency-1.3")
  assert_eq(nested.errors[1].code, "adoption-agency-1.3")
  let nested_bold = nested.root.query("b")
  guard nested_bold.length() == 2 else {
    fail("expected nested replacement bold")
  }
  assert_node_origin(nested_bold[0], 0, 1, 1)
  assert_node_origin(nested_bold[1], 0, 1, 1)
  let nested_italic = nested.root.query("i")
  guard nested_italic.length() == 3 else {
    fail("expected nested replacement italic")
  }
  assert_node_origin(nested_italic[0], 3, 1, 4)
  assert_node_origin(nested_italic[1], 3, 1, 4)
  assert_node_origin(nested_italic[2], 3, 1, 4)
}

///|
test "parser handles active formatting duplicate starts" {
  let anchors = @html_parser.parse_fragment(
    "<a><a>x</a>y</a>",
    collect_errors=true,
    track_node_locations=true,
  )
  assert_eq(anchors.to_html(pretty=false), "<a></a><a>x</a>y")
  assert_eq(anchors.errors.length(), 2)
  assert_eq(anchors.errors[0].code, "unexpected-start-tag-implies-end-tag")
  assert_eq(anchors.errors[1].code, "adoption-agency-1.3")
  let anchor_nodes = anchors.root.query("a")
  guard anchor_nodes.length() == 2 else { fail("expected repeated anchors") }
  assert_node_origin(anchor_nodes[0], 0, 1, 1)
  assert_node_origin(anchor_nodes[1], 3, 1, 4)
  let nobr = @html_parser.parse_fragment(
    "<nobr><nobr>x</nobr>y</nobr>",
    collect_errors=true,
    track_node_locations=true,
  )
  assert_eq(nobr.to_html(pretty=false), "<nobr></nobr><nobr>x</nobr>y")
  assert_eq(nobr.errors.length(), 1)
  assert_eq(nobr.errors[0].code, "adoption-agency-1.3")
  let nobr_nodes = nobr.root.query("nobr")
  guard nobr_nodes.length() == 2 else { fail("expected repeated nobr") }
  assert_node_origin(nobr_nodes[0], 0, 1, 1)
  assert_node_origin(nobr_nodes[1], 6, 1, 7)
  let repeated = @html_parser.parse_fragment(
    "<p><b><b><b><b>x</p>y",
    collect_errors=true,
    track_node_locations=true,
  )
  assert_eq(
    repeated.to_html(pretty=false),
    "<p><b><b><b><b>x</b></b></b></b></p><b><b><b>y</b></b></b>",
  )
  let repeated_bold = repeated.root.query("b")
  guard repeated_bold.length() == 7 else {
    fail("expected capped reconstructed bold entries")
  }
  assert_node_origin(repeated_bold[0], 3, 1, 4)
  assert_node_origin(repeated_bold[1], 6, 1, 7)
  assert_node_origin(repeated_bold[2], 9, 1, 10)
  assert_node_origin(repeated_bold[3], 12, 1, 13)
  assert_node_origin(repeated_bold[4], 6, 1, 7)
  assert_node_origin(repeated_bold[5], 9, 1, 10)
  assert_node_origin(repeated_bold[6], 12, 1, 13)
  let repeated_attrs = @html_parser.parse_fragment(
    "<p><b class=x><b class=x><b class=x><b class=x>z</p>tail",
  )
  assert_eq(
    repeated_attrs.to_html(pretty=false),
    "<p><b class=\"x\"><b class=\"x\"><b class=\"x\"><b class=\"x\">z</b></b></b></b></p><b class=\"x\"><b class=\"x\"><b class=\"x\">tail</b></b></b>",
  )
  let mixed_attrs = @html_parser.parse_fragment(
    "<p><b class=x><b class=x id=y><b class=x id=y><b class=x id=y><b class=x id=y>z</p>tail",
  )
  assert_eq(
    mixed_attrs.to_html(pretty=false),
    "<p><b class=\"x\"><b class=\"x\" id=\"y\"><b class=\"x\" id=\"y\"><b class=\"x\" id=\"y\"><b class=\"x\" id=\"y\">z</b></b></b></b></b></p><b class=\"x\"><b class=\"x\" id=\"y\"><b class=\"x\" id=\"y\"><b class=\"x\" id=\"y\">tail</b></b></b></b>",
  )
  let mismatched_attrs = @html_parser.parse_fragment(
    "<p><b class=x><b class=y><b class=x><b class=y><b class=x>z</p>tail",
  )
  assert_eq(
    mismatched_attrs.to_html(pretty=false),
    "<p><b class=\"x\"><b class=\"y\"><b class=\"x\"><b class=\"y\"><b class=\"x\">z</b></b></b></b></b></p><b class=\"x\"><b class=\"y\"><b class=\"x\"><b class=\"y\"><b class=\"x\">tail</b></b></b></b></b>",
  )
}

///|
test "parser clears active formatting at applet-like markers" {
  let stray = @html_parser.parse_fragment("</applet>", collect_errors=true)
  assert_eq(stray.to_html(pretty=false), "")
  assert_eq(stray.errors.length(), 1)
  assert_eq(stray.errors[0].code, "unexpected-end-tag")
  guard stray.errors[0].column is Some(9) else {
    fail("expected stray applet end tag error at tag close")
  }
  let nested_stray = @html_parser.parse_fragment(
    "<p>x</object>y",
    collect_errors=true,
  )
  assert_eq(nested_stray.to_html(pretty=false), "<p>xy</p>")
  assert_eq(nested_stray.errors.length(), 1)
  assert_eq(nested_stray.errors[0].code, "unexpected-end-tag")
  guard nested_stray.errors[0].column is Some(13) else {
    fail("expected stray object end tag error at tag close")
  }
  let object = @html_parser.parse_fragment(
    "<p><object><b>x</object>y",
    track_node_locations=true,
  )
  assert_eq(object.to_html(pretty=false), "<p><object><b>x</b></object>y</p>")
  let object_bold = object.root.query("b")
  guard object_bold.length() == 1 else {
    fail("expected object-local bold only")
  }
  assert_node_origin(object_bold[0], 11, 1, 12)
  let marquee = @html_parser.parse_fragment(
    "<p><marquee><b>x</marquee>y",
    track_node_locations=true,
  )
  assert_eq(
    marquee.to_html(pretty=false),
    "<p><marquee><b>x</b></marquee>y</p>",
  )
  let marquee_bold = marquee.root.query("b")
  guard marquee_bold.length() == 1 else {
    fail("expected marquee-local bold only")
  }
  assert_node_origin(marquee_bold[0], 12, 1, 13)
  let mixed = @html_parser.parse_fragment(
    "<p><b>before<object><i>in</object>after</p>tail",
    track_node_locations=true,
  )
  assert_eq(
    mixed.to_html(pretty=false),
    "<p><b>before<object><i>in</i></object>after</b></p><b>tail</b>",
  )
  let mixed_bold = mixed.root.query("b")
  guard mixed_bold.length() == 2 else {
    fail("expected outer bold reconstruction")
  }
  assert_node_origin(mixed_bold[0], 3, 1, 4)
  assert_node_origin(mixed_bold[1], 3, 1, 4)
  let mixed_italic = mixed.root.query("i")
  guard mixed_italic.length() == 1 else {
    fail("expected object-local italic only")
  }
  assert_node_origin(mixed_italic[0], 20, 1, 21)
}

///|
test "parser clears active formatting at caption and template markers" {
  let template = @html_parser.parse_fragment(
    "<template><b>x</template>y",
    collect_errors=true,
    track_node_locations=true,
  )
  assert_eq(template.to_html(pretty=false), "<template><b>x</b></template>y")
  assert_eq(template.errors.length(), 0)
  let template_bold = template.root.query("b")
  guard template_bold.length() == 1 else {
    fail("expected template-local bold only")
  }
  assert_node_origin(template_bold[0], 10, 1, 11)
  let template_outer = @html_parser.parse_fragment(
    "<b>before<template><i>in</template>after",
    collect_errors=true,
    track_node_locations=true,
  )
  assert_eq(
    template_outer.to_html(pretty=false),
    "<b>before<template><i>in</i></template>after</b>",
  )
  assert_eq(template_outer.errors.length(), 1)
  assert_eq(template_outer.errors[0].code, "expected-closing-tag-but-got-eof")
  let template_outer_bold = template_outer.root.query("b")
  guard template_outer_bold.length() == 1 else {
    fail("expected outer template bold only")
  }
  assert_node_origin(template_outer_bold[0], 0, 1, 1)
  let template_italic = template_outer.root.query("i")
  guard template_italic.length() == 1 else {
    fail("expected template-local italic only")
  }
  assert_node_origin(template_italic[0], 19, 1, 20)
  let caption = @html_parser.parse_fragment(
    "<table><caption><b>x</caption></table>y",
    collect_errors=true,
    track_node_locations=true,
  )
  assert_eq(
    caption.to_html(pretty=false),
    "<table><caption><b>x</b></caption></table>y",
  )
  assert_eq(caption.errors.length(), 0)
  let caption_bold = caption.root.query("b")
  guard caption_bold.length() == 1 else {
    fail("expected caption-local bold only")
  }
  assert_node_origin(caption_bold[0], 16, 1, 17)
  let caption_outer = @html_parser.parse_fragment(
    "<b>before<table><caption><i>cap</caption></table>after",
    collect_errors=true,
    track_node_locations=true,
  )
  assert_eq(
    caption_outer.to_html(pretty=false),
    "<b>before<table><caption><i>cap</i></caption></table>after</b>",
  )
  assert_eq(caption_outer.errors.length(), 1)
  assert_eq(caption_outer.errors[0].code, "expected-closing-tag-but-got-eof")
  let caption_outer_bold = caption_outer.root.query("b")
  guard caption_outer_bold.length() == 1 else {
    fail("expected outer caption bold only")
  }
  assert_node_origin(caption_outer_bold[0], 0, 1, 1)
  let caption_italic = caption_outer.root.query("i")
  guard caption_italic.length() == 1 else {
    fail("expected caption-local italic only")
  }
  assert_node_origin(caption_italic[0], 25, 1, 26)
}

///|
test "parser reports implied active formatting end in table view" {
  let row = @html_parser.parse_fragment(
    "<table><a><tr>x</table></a>",
    collect_errors=true,
    track_node_locations=true,
  )
  assert_eq(
    row.to_html(pretty=false),
    "<a></a><a>x</a><table><tbody><tr></tr></tbody></table>",
  )
  assert_eq(row.errors.length(), 3)
  assert_eq(row.errors[0].code, "foster-parenting-start-tag")
  assert_eq(row.errors[1].code, "unexpected-implied-end-tag-in-table-view")
  assert_eq(row.errors[2].code, "adoption-agency-1.3")
  let links = row.root.query("a")
  guard links.length() == 2 else {
    fail("expected original and reconstructed links")
  }
  assert_node_origin(links[0], 7, 1, 8)
  assert_node_origin(links[1], 7, 1, 8)
  guard row.root.query_one("tr") is Some(tr) else {
    fail("expected implied row")
  }
  assert_node_origin(tr, 10, 1, 11)
}

///|
test "fragment table contexts foster active formatting text" {
  let row = @html_parser.parse_fragment(
    "<a><tr>x</tr></a>",
    context=@html_parser.FragmentContext::new("table"),
    collect_errors=true,
    track_node_locations=true,
  )
  assert_eq(
    row.to_html(pretty=false),
    "<a></a><tbody><tr><a>x</a></tr></tbody>",
  )
  assert_eq(row.errors.length(), 3)
  assert_eq(row.errors[0].code, "foster-parenting-start-tag")
  assert_eq(row.errors[1].code, "unexpected-end-tag-implies-table-voodoo")
  assert_eq(row.errors[2].code, "adoption-agency-1.3")
  let row_links = row.root.query("a")
  guard row_links.length() == 2 else {
    fail("expected fostered and reconstructed links")
  }
  assert_node_origin(row_links[0], 0, 1, 1)
  assert_node_origin(row_links[1], 0, 1, 1)
  let text_row = @html_parser.parse_fragment(
    "<a>x<tr></tr></a>",
    context=@html_parser.FragmentContext::new("table"),
    collect_errors=true,
  )
  assert_eq(text_row.to_html(pretty=false), "<a>x</a><tbody><tr></tr></tbody>")
  assert_eq(text_row.errors.length(), 4)
  assert_eq(text_row.errors[0].code, "foster-parenting-start-tag")
  assert_eq(text_row.errors[1].code, "foster-parenting-character")
  assert_eq(text_row.errors[2].code, "unexpected-end-tag-implies-table-voodoo")
  assert_eq(text_row.errors[3].code, "adoption-agency-1.3")
  let text_only = @html_parser.parse_fragment(
    "<a>x</a>",
    context=@html_parser.FragmentContext::new("table"),
    collect_errors=true,
  )
  assert_eq(text_only.to_html(pretty=false), "<a>x</a>")
  assert_eq(text_only.errors.length(), 3)
  assert_eq(text_only.errors[0].code, "foster-parenting-start-tag")
  assert_eq(text_only.errors[1].code, "foster-parenting-character")
  assert_eq(text_only.errors[2].code, "unexpected-end-tag-implies-table-voodoo")
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
  let through_table_header = @html_parser.parse_fragment(
    "<button>outer<table><tr><th><button>inner</button></th></tr></table></button>",
    collect_errors=true,
  )
  assert_eq(
    through_table_header.to_html(pretty=false),
    "<button>outer<table><tbody><tr><th><button>inner</button></th></tr></tbody></table></button>",
  )
  assert_eq(through_table_header.errors.length(), 0)
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
test "parser assigns namespaces and adjusted names for foreign content" {
  let svg = @html_parser.parse_fragment(
    "<svg><lineargradient><stop/></lineargradient><feimage attributename='href'></feimage></svg>",
    collect_errors=true,
  )
  assert_eq(
    svg.to_html(pretty=false),
    "<svg><linearGradient><stop></stop></linearGradient><feImage attributeName=\"href\"></feImage></svg>",
  )
  assert_eq(svg.errors.length(), 0)
  guard svg.query_one("svg") is Some(svg_node) else { fail("expected svg") }
  assert_true(svg_node.namespace_uri() is Some("svg"))
  let svg_children = svg_node.children()
  assert_eq(svg_children.length(), 2)
  assert_eq(svg_children[0].name(), "linearGradient")
  assert_true(svg_children[0].namespace_uri() is Some("svg"))
  let gradient_children = svg_children[0].children()
  assert_eq(gradient_children.length(), 1)
  assert_eq(gradient_children[0].name(), "stop")
  assert_true(gradient_children[0].namespace_uri() is Some("svg"))
  assert_eq(svg_children[1].name(), "feImage")
  assert_true(svg_children[1].namespace_uri() is Some("svg"))
  let image_attrs = svg_children[1].attrs()
  guard image_attrs["attributeName"] is Some("href") else {
    fail("expected adjusted SVG attribute")
  }
  let math = @html_parser.parse_fragment(
    "<math><mi definitionurl='x'>y</mi></math>",
    collect_errors=true,
  )
  assert_eq(
    math.to_html(pretty=false),
    "<math><mi definitionURL=\"x\">y</mi></math>",
  )
  assert_eq(math.errors.length(), 0)
  guard math.query_one("math") is Some(math_node) else { fail("expected math") }
  assert_true(math_node.namespace_uri() is Some("math"))
  let math_children = math_node.children()
  assert_eq(math_children.length(), 1)
  assert_true(math_children[0].namespace_uri() is Some("math"))
  let mi_attrs = math_children[0].attrs()
  guard mi_attrs["definitionURL"] is Some("x") else {
    fail("expected adjusted MathML attribute")
  }
  let breakout = @html_parser.parse_fragment(
    "<svg><font color='red'>text</font></svg>",
    collect_errors=true,
  )
  assert_eq(
    breakout.to_html(pretty=false),
    "<svg></svg><font color=\"red\">text</font>",
  )
  assert_eq(breakout.errors.length(), 2)
  assert_eq(
    breakout.errors[0].code,
    "unexpected-html-element-in-foreign-content",
  )
  assert_eq(breakout.errors[1].code, "unexpected-end-tag")
  guard breakout.query_one("font") is Some(font_node) else {
    fail("expected breakout font")
  }
  assert_true(font_node.namespace_uri() is Some("html"))
  let integrated = @html_parser.parse_fragment(
    "<math><annotation-xml encoding='text/html'><div>x</div></annotation-xml></math>",
    collect_errors=true,
  )
  assert_eq(
    integrated.to_html(pretty=false),
    "<math><annotation-xml encoding=\"text/html\"><div>x</div></annotation-xml></math>",
  )
  assert_eq(integrated.errors.length(), 0)
  guard integrated.query_one("div") is Some(integrated_div) else {
    fail("expected integrated div")
  }
  assert_true(integrated_div.namespace_uri() is Some("html"))
  let plain_encoding = @html_parser.parse_fragment(
    "<math><annotation-xml encoding='text/plain'><div></div></annotation-xml></math>",
    collect_errors=true,
  )
  assert_eq(
    plain_encoding.to_html(pretty=false),
    "<math><annotation-xml encoding=\"text/plain\"></annotation-xml></math><div></div>",
  )
  assert_eq(plain_encoding.errors.length(), 3)
  assert_eq(
    plain_encoding.errors[0].code,
    "unexpected-html-element-in-foreign-content",
  )
  assert_eq(plain_encoding.errors[1].code, "unexpected-end-tag")
  assert_eq(plain_encoding.errors[2].code, "unexpected-end-tag")
  let missing_encoding = @html_parser.parse_fragment(
    "<math><annotation-xml><div>test</div></annotation-xml></math>",
    collect_errors=true,
  )
  assert_eq(
    missing_encoding.to_html(pretty=false),
    "<math><annotation-xml></annotation-xml></math><div>test</div>",
  )
  assert_eq(missing_encoding.errors.length(), 3)
  assert_eq(
    missing_encoding.errors[0].code,
    "unexpected-html-element-in-foreign-content",
  )
  assert_eq(missing_encoding.errors[1].code, "unexpected-end-tag")
  assert_eq(missing_encoding.errors[2].code, "unexpected-end-tag")
  let empty_encoding = @html_parser.parse_fragment(
    "<math><annotation-xml encoding><div>x</div></annotation-xml></math>",
    collect_errors=true,
  )
  assert_eq(
    empty_encoding.to_html(pretty=false),
    "<math><annotation-xml encoding></annotation-xml></math><div>x</div>",
  )
  assert_eq(empty_encoding.errors.length(), 3)
  assert_eq(
    empty_encoding.errors[0].code,
    "unexpected-html-element-in-foreign-content",
  )
  assert_eq(empty_encoding.errors[1].code, "unexpected-end-tag")
  assert_eq(empty_encoding.errors[2].code, "unexpected-end-tag")
}

///|
test "tree builder matches Python reference annotation-xml breakout branch fixtures" {
  let plain_encoding = @html_parser.parse(
    "<math><annotation-xml encoding=\"text/plain\"><div></div></annotation-xml></math>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(plain_encoding.root),
    "| <html>\n|   <head>\n|   <body>\n|     <math math>\n|       <math annotation-xml>\n|         encoding=\"text/plain\"\n|     <div>",
  )
  assert_eq(plain_encoding.errors.length(), 4)
  assert_eq(plain_encoding.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(
    plain_encoding.errors[1].code,
    "unexpected-html-element-in-foreign-content",
  )
  assert_eq(plain_encoding.errors[2].code, "unexpected-end-tag")
  assert_eq(plain_encoding.errors[3].code, "unexpected-end-tag")
  guard plain_encoding.errors[1].column is Some(49) else {
    fail("expected text/plain annotation-xml breakout at div start close")
  }
  let missing_encoding = @html_parser.parse(
    "<math><annotation-xml><div></div></annotation-xml></math>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(missing_encoding.root),
    "| <html>\n|   <head>\n|   <body>\n|     <math math>\n|       <math annotation-xml>\n|     <div>",
  )
  assert_eq(missing_encoding.errors.length(), 4)
  assert_eq(
    missing_encoding.errors[0].code,
    "expected-doctype-but-got-start-tag",
  )
  assert_eq(
    missing_encoding.errors[1].code,
    "unexpected-html-element-in-foreign-content",
  )
  assert_eq(missing_encoding.errors[2].code, "unexpected-end-tag")
  assert_eq(missing_encoding.errors[3].code, "unexpected-end-tag")
  guard missing_encoding.errors[1].column is Some(27) else {
    fail("expected missing-encoding annotation-xml breakout at div start close")
  }
}

///|
test "tree builder matches Python reference SVG font breakout branch fixture" {
  let doc = @html_parser.parse(
    "<svg><font color=\"red\">text</font></svg>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(doc.root),
    "| <html>\n|   <head>\n|   <body>\n|     <svg svg>\n|     <font>\n|       color=\"red\"\n|       \"text\"",
  )
  assert_eq(doc.errors.length(), 3)
  assert_eq(doc.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(doc.errors[1].code, "unexpected-html-element-in-foreign-content")
  assert_eq(doc.errors[2].code, "unexpected-end-tag")
  guard doc.errors[1].column is Some(23) else {
    fail("expected SVG font breakout error at font start close")
  }
  guard doc.errors[2].column is Some(40) else {
    fail("expected SVG end-tag recovery at svg end close")
  }
}

///|
test "tree builder matches Python reference foreign integration branch fixtures" {
  let svg = @html_parser.parse(
    "<svg><g><rect></rect><circle></circle><path></path></g></svg><div></div>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(svg.root),
    "| <html>\n|   <head>\n|   <body>\n|     <svg svg>\n|       <svg g>\n|         <svg rect>\n|         <svg circle>\n|         <svg path>\n|     <div>",
  )
  assert_eq(svg.errors.length(), 1)
  assert_eq(svg.errors[0].code, "expected-doctype-but-got-start-tag")
  guard svg.errors[0].column is Some(5) else {
    fail("expected SVG doctype error at svg start close")
  }
  let math = @html_parser.parse(
    "<math><annotation-xml encoding=\"text/html\"><div><table><tr></tr></table></div></annotation-xml></math>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(math.root),
    "| <html>\n|   <head>\n|   <body>\n|     <math math>\n|       <math annotation-xml>\n|         encoding=\"text/html\"\n|         <div>\n|           <table>\n|             <tbody>\n|               <tr>",
  )
  assert_eq(math.errors.length(), 1)
  assert_eq(math.errors[0].code, "expected-doctype-but-got-start-tag")
  guard math.errors[0].column is Some(6) else {
    fail("expected MathML doctype error at math start close")
  }
}

///|
test "tree builder matches Python reference nested foreign breakout branch fixtures" {
  let math = @html_parser.parse(
    "<math><annotation-xml foo=\"bar\"><div>test</div></annotation-xml></math>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(math.root),
    "| <html>\n|   <head>\n|   <body>\n|     <math math>\n|       <math annotation-xml>\n|         foo=\"bar\"\n|     <div>\n|       \"test\"",
  )
  assert_eq(math.errors.length(), 4)
  assert_eq(math.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(math.errors[1].code, "unexpected-html-element-in-foreign-content")
  assert_eq(math.errors[2].code, "unexpected-end-tag")
  assert_eq(math.errors[3].code, "unexpected-end-tag")
  guard math.errors[1].column is Some(37) else {
    fail("expected MathML annotation breakout at div start close")
  }
  guard math.errors[2].column is Some(64) else {
    fail("expected annotation-xml end recovery at close bracket")
  }
  guard math.errors[3].column is Some(71) else {
    fail("expected math end recovery at close bracket")
  }
  let svg = @html_parser.parse(
    "<svg><g><rect><circle><path><div>text</div></path></circle></rect></g></svg>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(svg.root),
    "| <html>\n|   <head>\n|   <body>\n|     <svg svg>\n|       <svg g>\n|         <svg rect>\n|           <svg circle>\n|             <svg path>\n|     <div>\n|       \"text\"",
  )
  assert_eq(svg.errors.length(), 7)
  assert_eq(svg.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(svg.errors[1].code, "unexpected-html-element-in-foreign-content")
  for index in 2..<svg.errors.length() {
    assert_eq(svg.errors[index].code, "unexpected-end-tag")
  }
  guard svg.errors[1].column is Some(33) else {
    fail("expected nested SVG breakout at div start close")
  }
  guard svg.errors[6].column is Some(76) else {
    fail("expected final SVG end recovery at close bracket")
  }
}

///|
test "parser adjusts SVG edge names and foreign attributes" {
  let svg = @html_parser.parse_fragment(
    "<svg><altglyph attributetype='xml' xlink:actuate='onLoad'></altglyph><femerge><femergenode></femergenode></femerge><radialgradient gradienttransform='r'></radialgradient></svg>",
    collect_errors=true,
  )
  assert_eq(
    svg.to_html(pretty=false),
    "<svg><altGlyph attributeType=\"xml\" xlink:actuate=\"onLoad\"></altGlyph><feMerge><feMergeNode></feMergeNode></feMerge><radialGradient gradientTransform=\"r\"></radialGradient></svg>",
  )
  assert_eq(svg.errors.length(), 0)
  guard svg.query_one("svg") is Some(svg_node) else { fail("expected svg") }
  let svg_children = svg_node.children()
  assert_eq(svg_children.length(), 3)
  assert_eq(svg_children[0].name(), "altGlyph")
  let alt_attrs = svg_children[0].attrs()
  guard alt_attrs["attributeType"] is Some("xml") else {
    fail("expected adjusted attributeType")
  }
  guard alt_attrs["xlink:actuate"] is Some("onLoad") else {
    fail("expected preserved xlink:actuate")
  }
  assert_eq(svg_children[1].name(), "feMerge")
  let merge_children = svg_children[1].children()
  assert_eq(merge_children.length(), 1)
  assert_eq(merge_children[0].name(), "feMergeNode")
  assert_eq(svg_children[2].name(), "radialGradient")
  let radial_attrs = svg_children[2].attrs()
  guard radial_attrs["gradientTransform"] is Some("r") else {
    fail("expected adjusted gradientTransform")
  }
}

///|
test "parser adjusts long tail SVG names attributes and font breakouts" {
  let svg = @html_parser.parse_fragment(
    "<svg><altglyphdef><altglyphitem><femorphology basefrequency='x' gradientunits='u' xlink:arcrole='r'></femorphology><glyphref></glyphref><textpath></textpath></altglyphitem></altglyphdef></svg>",
    collect_errors=true,
  )
  assert_eq(
    svg.to_html(pretty=false),
    "<svg><altGlyphDef><altGlyphItem><feMorphology baseFrequency=\"x\" gradientUnits=\"u\" xlink:arcrole=\"r\"></feMorphology><glyphRef></glyphRef><textPath></textPath></altGlyphItem></altGlyphDef></svg>",
  )
  assert_eq(svg.errors.length(), 0)
  let remaining = @html_parser.parse_fragment(
    "<svg><animatecolor baseprofile='tiny'></animatecolor><feoffset kernelmatrix='k' xlink:href='#f'></feoffset></svg>",
    collect_errors=true,
  )
  assert_eq(
    remaining.to_html(pretty=false),
    "<svg><animateColor baseProfile=\"tiny\"></animateColor><feOffset kernelMatrix=\"k\" xlink:href=\"#f\"></feOffset></svg>",
  )
  assert_eq(remaining.errors.length(), 0)
  let motion = @html_parser.parse_fragment(
    "<svg><animatemotion calcmode='paced'></animatemotion><fepointlight kernelunitlength='1 1' xlink:role='r'></fepointlight></svg>",
    collect_errors=true,
  )
  assert_eq(
    motion.to_html(pretty=false),
    "<svg><animateMotion calcMode=\"paced\"></animateMotion><fePointLight kernelUnitLength=\"1 1\" xlink:role=\"r\"></fePointLight></svg>",
  )
  assert_eq(motion.errors.length(), 0)
  let transform = @html_parser.parse_fragment(
    "<svg><animatetransform clippathunits='userSpaceOnUse' keypoints='0;1' xlink:show='new'></animatetransform><fespecularlighting></fespecularlighting></svg>",
    collect_errors=true,
  )
  assert_eq(
    transform.to_html(pretty=false),
    "<svg><animateTransform clipPathUnits=\"userSpaceOnUse\" keyPoints=\"0;1\" xlink:show=\"new\"></animateTransform><feSpecularLighting></feSpecularLighting></svg>",
  )
  assert_eq(transform.errors.length(), 0)
  let face = @html_parser.parse_fragment(
    "<svg><font face='serif'>text</font></svg>",
    collect_errors=true,
  )
  assert_eq(
    face.to_html(pretty=false),
    "<svg></svg><font face=\"serif\">text</font>",
  )
  assert_eq(face.errors.length(), 2)
  assert_eq(face.errors[0].code, "unexpected-html-element-in-foreign-content")
  assert_eq(face.errors[1].code, "unexpected-end-tag")
  let size = @html_parser.parse_fragment(
    "<svg><font size='3'>text</font></svg>",
    collect_errors=true,
  )
  assert_eq(
    size.to_html(pretty=false),
    "<svg></svg><font size=\"3\">text</font>",
  )
  assert_eq(size.errors.length(), 2)
  assert_eq(size.errors[0].code, "unexpected-html-element-in-foreign-content")
  assert_eq(size.errors[1].code, "unexpected-end-tag")
}

///|
test "parser tracks origins for nested foreign content starts" {
  let svg = @html_parser.parse_fragment(
    "<svg><lineargradient>\n  <stop/></lineargradient><feimage></feimage></svg>",
    track_node_locations=true,
  )
  guard svg.query_one("svg") is Some(svg_node) else { fail("expected svg") }
  assert_node_origin(svg_node, 0, 1, 1)
  let svg_children = svg_node.children()
  assert_eq(svg_children.length(), 2)
  assert_node_origin(svg_children[0], 5, 1, 6)
  let gradient_children = svg_children[0].children()
  assert_eq(gradient_children.length(), 2)
  assert_eq(gradient_children[1].name(), "stop")
  assert_node_origin(gradient_children[1], 24, 2, 3)
  assert_node_origin(svg_children[1], 48, 2, 27)
  let math = @html_parser.parse_fragment(
    "<math><mi definitionurl='x'>y</mi><annotation-xml encoding='text/html'><section>x</section></annotation-xml></math>",
    track_node_locations=true,
  )
  guard math.query_one("mi") is Some(mi) else { fail("expected mi") }
  assert_node_origin(mi, 6, 1, 7)
  guard math.query_one("annotation-xml") is Some(annotation) else {
    fail("expected annotation-xml")
  }
  assert_node_origin(annotation, 34, 1, 35)
}

///|
test "parser treats foreign integration points as HTML islands" {
  let svg = @html_parser.parse_fragment(
    "<svg><foreignobject><div><span>x</span></div></foreignobject></svg>",
    collect_errors=true,
  )
  assert_eq(
    svg.to_html(pretty=false),
    "<svg><foreignObject><div><span>x</span></div></foreignObject></svg>",
  )
  assert_eq(svg.errors.length(), 0)
  guard svg.query_one("div") is Some(div) else { fail("expected div") }
  assert_true(div.namespace_uri() is Some("html"))
  guard svg.query_one("span") is Some(span) else { fail("expected span") }
  assert_true(span.namespace_uri() is Some("html"))
  let math = @html_parser.parse_fragment(
    "<math><annotation-xml encoding='application/xhtml+xml'><section>x</section></annotation-xml></math>",
    collect_errors=true,
  )
  assert_eq(
    math.to_html(pretty=false),
    "<math><annotation-xml encoding=\"application/xhtml+xml\"><section>x</section></annotation-xml></math>",
  )
  assert_eq(math.errors.length(), 0)
  guard math.query_one("section") is Some(section) else {
    fail("expected integrated section")
  }
  assert_true(section.namespace_uri() is Some("html"))
}

///|
test "parser handles foreign content end tag recovery" {
  let ancestor_end = @html_parser.parse_fragment(
    "<svg><lineargradient></svg>",
    collect_errors=true,
  )
  assert_eq(
    ancestor_end.to_html(pretty=false),
    "<svg><linearGradient></linearGradient></svg>",
  )
  assert_eq(ancestor_end.errors.length(), 1)
  assert_eq(ancestor_end.errors[0].code, "unexpected-end-tag")
  let missing_foreign = @html_parser.parse_fragment(
    "<svg><g></path></svg>",
    collect_errors=true,
  )
  assert_eq(missing_foreign.to_html(pretty=false), "<svg><g></g></svg>")
  assert_eq(missing_foreign.errors.length(), 3)
  assert_eq(missing_foreign.errors[0].code, "unexpected-end-tag")
  assert_eq(missing_foreign.errors[1].code, "unexpected-end-tag")
  assert_eq(missing_foreign.errors[2].code, "unexpected-end-tag")
  let paragraph_breakout = @html_parser.parse_fragment(
    "<svg></p>",
    collect_errors=true,
  )
  assert_eq(paragraph_breakout.to_html(pretty=false), "<svg></svg><p></p>")
  assert_eq(paragraph_breakout.errors.length(), 2)
  assert_eq(
    paragraph_breakout.errors[0].code,
    "unexpected-html-element-in-foreign-content",
  )
  assert_eq(paragraph_breakout.errors[1].code, "unexpected-end-tag")
  let nested_svg_breakout = @html_parser.parse_fragment(
    "<div><svg><g><p>x</p></g></svg>after</div>",
    collect_errors=true,
  )
  assert_eq(
    nested_svg_breakout.to_html(pretty=false),
    "<div><svg><g></g></svg><p>x</p>after</div>",
  )
  assert_eq(nested_svg_breakout.errors.length(), 3)
  assert_eq(
    nested_svg_breakout.errors[0].code,
    "unexpected-html-element-in-foreign-content",
  )
  assert_eq(nested_svg_breakout.errors[1].code, "unexpected-end-tag")
  assert_eq(nested_svg_breakout.errors[2].code, "unexpected-end-tag")
  let math_text_integration = @html_parser.parse_fragment(
    "<math><mi><b>x</b></mi></math>",
    collect_errors=true,
  )
  assert_eq(
    math_text_integration.to_html(pretty=false),
    "<math><mi><b>x</b></mi></math>",
  )
  assert_eq(math_text_integration.errors.length(), 0)
  guard math_text_integration.query_one("b") is Some(bold) else {
    fail("expected html b")
  }
  assert_true(bold.namespace_uri() is Some("html"))
  let math_exception_children = @html_parser.parse_fragment(
    "<math><mi><mglyph></mglyph><malignmark></malignmark><b>x</b></mi></math>",
    collect_errors=true,
  )
  assert_eq(
    math_exception_children.to_html(pretty=false),
    "<math><mi><mglyph></mglyph><malignmark></malignmark><b>x</b></mi></math>",
  )
  assert_eq(math_exception_children.errors.length(), 0)
  guard math_exception_children.query_one("mglyph") is Some(mglyph) else {
    fail("expected mglyph")
  }
  assert_true(mglyph.namespace_uri() is Some("math"))
  guard math_exception_children.query_one("malignmark") is Some(malignmark) else {
    fail("expected malignmark")
  }
  assert_true(malignmark.namespace_uri() is Some("math"))
  guard math_exception_children.query_one("b") is Some(exception_bold) else {
    fail("expected html b after MathML exceptions")
  }
  assert_true(exception_bold.namespace_uri() is Some("html"))
  let integration_breakout = @html_parser.parse_fragment(
    "<svg><foreignObject><svg><p>x</p></svg></foreignObject></svg>",
    collect_errors=true,
  )
  assert_eq(
    integration_breakout.to_html(pretty=false),
    "<svg><foreignObject><svg></svg><p>x</p></foreignObject></svg>",
  )
  assert_eq(integration_breakout.errors.length(), 4)
  assert_eq(
    integration_breakout.errors[0].code,
    "unexpected-html-element-in-foreign-content",
  )
  assert_eq(integration_breakout.errors[1].code, "unexpected-end-tag")
  assert_eq(integration_breakout.errors[2].code, "unexpected-end-tag")
  assert_eq(integration_breakout.errors[3].code, "unexpected-end-tag")
  let ancestor_html_end = @html_parser.parse_fragment(
    "<div><svg></div><p>after</p>",
    collect_errors=true,
  )
  assert_eq(
    ancestor_html_end.to_html(pretty=false),
    "<div><svg></svg></div><p>after</p>",
  )
  assert_eq(ancestor_html_end.errors.length(), 2)
  assert_eq(ancestor_html_end.errors[0].code, "unexpected-end-tag")
  assert_eq(ancestor_html_end.errors[1].code, "end-tag-too-early")
}

///|
test "parser reports invalid codepoints in foreign text" {
  let svg = @html_parser.parse_fragment(
    "<svg>a\u{0000}\u{000C}</svg>",
    collect_errors=true,
  )
  assert_eq(svg.to_html(pretty=false), "<svg>a� </svg>")
  assert_eq(svg.errors.length(), 2)
  assert_eq(svg.errors[0].code, "unexpected-null-character")
  assert_eq(svg.errors[1].code, "invalid-codepoint-in-foreign-content")
  let math_text_integration = @html_parser.parse_fragment(
    "<math><mi>\u{0000}\u{000C}text</mi></math>",
    collect_errors=true,
  )
  assert_eq(
    math_text_integration.to_html(pretty=false),
    "<math><mi> text</mi></math>",
  )
  assert_eq(math_text_integration.errors.length(), 1)
  assert_eq(math_text_integration.errors[0].code, "unexpected-null-character")
}

///|
test "parser treats cdata sections as foreign text" {
  let svg = @html_parser.parse_fragment(
    "<svg><![CDATA[x<y]]><![CDATA[a&lt;b]]></svg>",
    collect_errors=true,
  )
  assert_eq(svg.to_html(pretty=false), "<svg>x&lt;ya&amp;lt;b</svg>")
  assert_eq(svg.errors.length(), 0)
  let nul_svg = @html_parser.parse_fragment(
    "<svg><![CDATA[a\u{0000}b]]></svg>",
    collect_errors=true,
  )
  assert_eq(nul_svg.to_html(pretty=false), "<svg>a�b</svg>")
  assert_eq(nul_svg.errors.length(), 2)
  assert_eq(nul_svg.errors[0].code, "unexpected-null-character")
  assert_eq(nul_svg.errors[1].code, "invalid-codepoint-in-foreign-content")
  let math_text_integration = @html_parser.parse_fragment(
    "<math><mi><![CDATA[a\u{0000}b]]></mi></math>",
    collect_errors=true,
  )
  assert_eq(
    math_text_integration.to_html(pretty=false),
    "<math><mi>ab</mi></math>",
  )
  assert_eq(math_text_integration.errors.length(), 1)
  assert_eq(math_text_integration.errors[0].code, "unexpected-null-character")
  let html = @html_parser.parse_fragment("<![CDATA[x]]>", collect_errors=true)
  assert_eq(html.to_html(pretty=false), "<!--[CDATA[x]]-->")
  assert_eq(html.errors.length(), 1)
  assert_eq(html.errors[0].code, "cdata-in-html-content")
}

///|
test "parser and tokenizer optionally coerce XML-invalid text" {
  let tokens = @html_parser.tokenize(
    "\u{000C}\u{FDD0}<script>\u{FDD0}</script><!--a--b-->",
    xml_coercion=true,
  )
  guard tokens.tokens[0] is @html_parser.HtmlToken::Characters(" �") else {
    fail("expected form-feed and noncharacter coercion in text")
  }
  guard tokens.tokens[2] is @html_parser.HtmlToken::Characters("�") else {
    fail("expected XML coercion in script text")
  }
  guard tokens.tokens[4] is @html_parser.HtmlToken::CommentToken("a- -b") else {
    fail("expected XML comment double-hyphen coercion")
  }
  let default_tokens = @html_parser.tokenize("\u{000C}\u{FDD0}")
  guard default_tokens.tokens[0]
    is @html_parser.HtmlToken::Characters("\u{000C}\u{FDD0}") else {
    fail("expected XML coercion to be opt-in")
  }
  let parsed = @html_parser.parse_fragment(
    "<div>a\u{000C}\u{FDD0}</div><textarea>\u{000C}\u{FDD0}</textarea>",
    xml_coercion=true,
  )
  assert_eq(
    parsed.to_html(pretty=false),
    "<div>a �</div><textarea> �</textarea>",
  )
  let raw_text = @html_parser.parse(
    "<script>\u{000C}\u{FDD0}</script><style>\u{000C}\u{FDD0}</style>",
    xml_coercion=true,
  )
  assert_eq(
    raw_text.to_html(pretty=false),
    "<html><head><script> �</script><style> �</style></head><body></body></html>",
  )
  let comments = @html_parser.parse_fragment(
    "<!--a--b--><?c--d>",
    collect_errors=true,
    xml_coercion=true,
  )
  assert_eq(comments.to_html(pretty=false), "<!--a- -b--><!--?c- -d-->")
  assert_eq(comments.errors.length(), 2)
  assert_eq(comments.errors[0].code, "incorrectly-closed-comment")
  assert_eq(
    comments.errors[1].code,
    "unexpected-question-mark-instead-of-tag-name",
  )
  let foreign_cdata = @html_parser.parse_fragment(
    "<svg><![CDATA[\u{000C}\u{FDD0}]]></svg>",
    xml_coercion=true,
  )
  assert_eq(foreign_cdata.to_html(pretty=false), "<svg> �</svg>")
}

///|
test "tokenize matches upstream XML violation coverage fixtures" {
  let form_feed = @html_parser.tokenize("\u{000C}", xml_coercion=true)
  guard form_feed.tokens[0] is Characters(" ") else {
    fail("expected XML coercion to replace form feed with space")
  }
  let noncharacter = @html_parser.tokenize("\u{FDD0}", xml_coercion=true)
  guard noncharacter.tokens[0] is Characters("\u{FFFD}") else {
    fail("expected XML coercion to replace noncharacter")
  }
}

///|
test "tree builder matches upstream XML coercion document fixtures" {
  let comment = @html_parser.parse(
    "<!-- normal comment -->",
    collect_errors=true,
    xml_coercion=true,
  )
  assert_eq(
    @html_parser.to_test_format(comment.root),
    "| <!--  normal comment  -->\n| <html>\n|   <head>\n|   <body>",
  )
  assert_eq(comment.errors.length(), 1)
  assert_eq(comment.errors[0].code, "expected-doctype-but-got-eof")
  guard comment.errors[0].column is Some(23) else {
    fail("expected XML comment doctype EOF at final column")
  }
  let normal = @html_parser.parse(
    "<div>normal text</div>",
    collect_errors=true,
    xml_coercion=true,
  )
  assert_eq(
    @html_parser.to_test_format(normal.root),
    "| <html>\n|   <head>\n|   <body>\n|     <div>\n|       \"normal text\"",
  )
  assert_eq(normal.errors.length(), 1)
  assert_eq(normal.errors[0].code, "expected-doctype-but-got-start-tag")
  let non_ascii = @html_parser.parse(
    "<div>über</div>",
    collect_errors=true,
    xml_coercion=true,
  )
  assert_eq(
    @html_parser.to_test_format(non_ascii.root),
    "| <html>\n|   <head>\n|   <body>\n|     <div>\n|       \"über\"",
  )
  assert_eq(non_ascii.errors.length(), 1)
  assert_eq(non_ascii.errors[0].code, "expected-doctype-but-got-start-tag")
  let form_feed = @html_parser.parse(
    "<div>über\u{000C}</div>",
    collect_errors=true,
    xml_coercion=true,
  )
  assert_eq(
    @html_parser.to_test_format(form_feed.root),
    "| <html>\n|   <head>\n|   <body>\n|     <div>\n|       \"über \"",
  )
  assert_eq(form_feed.errors.length(), 1)
  assert_eq(form_feed.errors[0].code, "expected-doctype-but-got-start-tag")
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
  let stray = @html_parser.parse_fragment("x</ruby>y", collect_errors=true)
  assert_eq(stray.to_html(pretty=false), "xy")
  assert_eq(stray.errors.length(), 1)
  assert_eq(stray.errors[0].code, "unexpected-end-tag")
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
  let inner_tag = @html_parser.parse(
    "<!doctype html><frameset><p>x</p><frame src=y></frameset>",
    collect_errors=true,
  )
  assert_eq(
    inner_tag.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><frameset><frame src=\"y\"></frame></frameset></html>",
  )
  assert_eq(inner_tag.errors.length(), 2)
  assert_eq(inner_tag.errors[0].code, "unexpected-token-in-frameset")
  assert_eq(inner_tag.errors[1].code, "unexpected-token-in-frameset")
  let html_inside = @html_parser.parse(
    "<!doctype html><frameset><html id=x><frame src=y></frameset>",
    collect_errors=true,
  )
  assert_eq(
    html_inside.to_html(pretty=false),
    "<!DOCTYPE html><html id=\"x\"><head></head><frameset></frameset></html>",
  )
  assert_eq(html_inside.errors.length(), 2)
  assert_eq(html_inside.errors[0].code, "unexpected-start-tag")
  assert_eq(html_inside.errors[1].code, "unexpected-start-tag-ignored")
  guard html_inside.errors[0].column is Some(36) else {
    fail("expected html-in-frameset error at close bracket")
  }
  guard html_inside.errors[1].column is Some(49) else {
    fail("expected ignored frame after html-in-frameset at close bracket")
  }
  let html_inside_stray_p_end = @html_parser.parse(
    "<!doctype html><frameset><html id=x></p></frameset>",
    collect_errors=true,
  )
  assert_eq(
    html_inside_stray_p_end.to_html(pretty=false),
    "<!DOCTYPE html><html id=\"x\"><head></head><frameset><p></p></frameset></html>",
  )
  assert_eq(html_inside_stray_p_end.errors.length(), 2)
  assert_eq(html_inside_stray_p_end.errors[0].code, "unexpected-start-tag")
  assert_eq(html_inside_stray_p_end.errors[1].code, "unexpected-end-tag")
  guard html_inside_stray_p_end.errors[0].column is Some(36) else {
    fail("expected html-in-frameset reprocess error at close bracket")
  }
  guard html_inside_stray_p_end.errors[1].column is Some(40) else {
    fail("expected reprocessed paragraph end error at close bracket")
  }
  let explicit_html_inside = @html_parser.parse(
    "<!doctype html><html><frameset><html id=x><frame src=y></frameset>",
    collect_errors=true,
  )
  assert_eq(
    explicit_html_inside.to_html(pretty=false),
    "<!DOCTYPE html><html id=\"x\"><head></head><frameset></frameset></html>",
  )
  assert_eq(explicit_html_inside.errors.length(), 2)
  assert_eq(explicit_html_inside.errors[0].code, "unexpected-start-tag")
  assert_eq(explicit_html_inside.errors[1].code, "unexpected-start-tag-ignored")
  guard explicit_html_inside.errors[0].column is Some(42) else {
    fail("expected explicit html-in-frameset error at close bracket")
  }
  guard explicit_html_inside.errors[1].column is Some(55) else {
    fail("expected explicit ignored frame after html-in-frameset")
  }
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
test "document parser replaces implicit body before frameset" {
  let discarded_body = @html_parser.parse(
    "<!doctype html><meta name=x>  <p><b></b></p><!--drop--><frameset></frameset>",
    collect_errors=true,
  )
  assert_eq(
    discarded_body.to_html(pretty=false),
    "<!DOCTYPE html><html><head><meta name=\"x\">  </head><frameset></frameset></html>",
  )
  assert_eq(discarded_body.errors.length(), 0)
  let preserved_head_comment = @html_parser.parse(
    "<!doctype html><meta name=x>  <!--keep--><figure></figure><!--drop--><frameset></frameset>",
    collect_errors=true,
  )
  assert_eq(
    preserved_head_comment.to_html(pretty=false),
    "<!DOCTYPE html><html><head><meta name=\"x\">  <!--keep--></head><frameset></frameset></html>",
  )
  assert_eq(preserved_head_comment.errors.length(), 0)
  let text_blocks_frameset = @html_parser.parse(
    "<!doctype html><meta name=x>  <p>x</p><!--keep--><frameset></frameset>",
    collect_errors=true,
  )
  assert_eq(
    text_blocks_frameset.to_html(pretty=false),
    "<!DOCTYPE html><html><head><meta name=\"x\">  </head><body><p>x</p><!--keep--></body></html>",
  )
  assert_eq(text_blocks_frameset.errors.length(), 2)
  assert_eq(text_blocks_frameset.errors[0].code, "unexpected-start-tag-ignored")
  assert_eq(text_blocks_frameset.errors[1].code, "unexpected-end-tag")
}

///|
test "parser tracks origins for frameset helper insertions" {
  let doc = @html_parser.parse(
    "<!doctype html><frameset><frame src=x><frameset></frameset></frameset>",
    track_node_locations=true,
  )
  let framesets = doc.root.query("frameset")
  guard framesets.length() == 2 else { fail("expected nested framesets") }
  assert_node_origin(framesets[0], 15, 1, 16)
  assert_node_origin(framesets[1], 38, 1, 39)
  guard doc.query_one("frame") is Some(frame) else { fail("expected frame") }
  assert_node_origin(frame, 25, 1, 26)
}

///|
test "document parser ignores tokens after frameset" {
  let text = @html_parser.parse(
    "<!DOCTYPE html><html><head></head><frameset></frameset>abc",
    collect_errors=true,
  )
  assert_eq(
    text.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><frameset></frameset></html>",
  )
  assert_eq(text.errors.length(), 1)
  assert_eq(text.errors[0].code, "unexpected-token-after-frameset")
  guard text.errors[0].column is Some(58) else {
    fail("expected post-frameset text error at final text column")
  }
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
  let extra_end = @html_parser.parse(
    "<!doctype html><frameset></frameset></frameset>",
    collect_errors=true,
  )
  assert_eq(
    extra_end.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><frameset></frameset></html>",
  )
  assert_eq(extra_end.errors.length(), 1)
  assert_eq(extra_end.errors[0].code, "unexpected-token-after-frameset")
  let stray_end = @html_parser.parse(
    "<!doctype html><frameset></p></frameset>",
    collect_errors=true,
  )
  assert_eq(
    stray_end.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><frameset></frameset></html>",
  )
  assert_eq(stray_end.errors.length(), 1)
  assert_eq(stray_end.errors[0].code, "unexpected-token-in-frameset")
  let after_stray_end = @html_parser.parse(
    "<!doctype html><frameset></frameset></p>",
    collect_errors=true,
  )
  assert_eq(
    after_stray_end.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><frameset></frameset></html>",
  )
  assert_eq(after_stray_end.errors.length(), 2)
  assert_eq(after_stray_end.errors[0].code, "unexpected-token-after-frameset")
  assert_eq(after_stray_end.errors[1].code, "unexpected-token-in-frameset")
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
test "document parser reprocesses starts after frameset" {
  let sibling_frameset = @html_parser.parse(
    "<!doctype html><frameset></frameset><frameset><frame></frameset>",
    collect_errors=true,
  )
  assert_eq(
    sibling_frameset.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><frameset></frameset><frameset><frame></frame></frameset></html>",
  )
  assert_eq(sibling_frameset.errors.length(), 1)
  assert_eq(sibling_frameset.errors[0].code, "unexpected-token-after-frameset")
  guard sibling_frameset.errors[0].column is Some(46) else {
    fail("expected post-frameset sibling frameset error at close bracket")
  }
  let sibling_frame = @html_parser.parse(
    "<!doctype html><frameset></frameset><frame>x",
    collect_errors=true,
  )
  assert_eq(
    sibling_frame.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><frameset></frameset><frame></frame></html>",
  )
  assert_eq(sibling_frame.errors.length(), 1)
  assert_eq(sibling_frame.errors[0].code, "unexpected-token-after-frameset")
  guard sibling_frame.errors[0].column is Some(43) else {
    fail("expected post-frameset frame error at close bracket")
  }
  let nested_reprocessed = @html_parser.parse(
    "<!doctype html><frameset></frameset><div><frameset></frameset></div>",
    collect_errors=true,
  )
  assert_eq(
    nested_reprocessed.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><frameset></frameset><frameset></frameset></html>",
  )
  assert_eq(nested_reprocessed.errors.length(), 4)
  assert_eq(
    nested_reprocessed.errors[0].code,
    "unexpected-token-after-frameset",
  )
  assert_eq(nested_reprocessed.errors[1].code, "unexpected-token-in-frameset")
  assert_eq(
    nested_reprocessed.errors[2].code,
    "unexpected-token-after-frameset",
  )
  assert_eq(nested_reprocessed.errors[3].code, "unexpected-token-in-frameset")
  let detached_end = @html_parser.parse(
    "<!doctype html><frameset></frameset><div></frameset>",
    collect_errors=true,
  )
  assert_eq(
    detached_end.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><frameset></frameset></html>",
  )
  assert_eq(detached_end.errors.length(), 3)
  assert_eq(detached_end.errors[0].code, "unexpected-token-after-frameset")
  assert_eq(detached_end.errors[1].code, "unexpected-token-in-frameset")
  assert_eq(detached_end.errors[2].code, "unexpected-end-tag")
  guard detached_end.errors[2].column is Some(52) else {
    fail("expected detached frameset end error at close bracket")
  }
  let detached_html = @html_parser.parse(
    "<!doctype html><frameset></frameset><div><html id=x><frameset></frameset>",
    collect_errors=true,
  )
  assert_eq(
    detached_html.to_html(pretty=false),
    "<!DOCTYPE html><html id=\"x\"><head></head><frameset></frameset></html>",
  )
  assert_eq(detached_html.errors.length(), 5)
  assert_eq(detached_html.errors[0].code, "unexpected-token-after-frameset")
  assert_eq(detached_html.errors[1].code, "unexpected-token-in-frameset")
  assert_eq(detached_html.errors[2].code, "unexpected-start-tag")
  assert_eq(detached_html.errors[3].code, "unexpected-start-tag-ignored")
  assert_eq(detached_html.errors[4].code, "unexpected-end-tag")
  let repeated_html = @html_parser.parse(
    "<!doctype html><frameset></frameset><html id=x><frameset></frameset>",
    collect_errors=true,
  )
  assert_eq(
    repeated_html.to_html(pretty=false),
    "<!DOCTYPE html><html id=\"x\"><head></head><frameset></frameset></html>",
  )
  assert_eq(repeated_html.errors.length(), 3)
  assert_eq(repeated_html.errors[0].code, "unexpected-start-tag")
  assert_eq(repeated_html.errors[1].code, "unexpected-start-tag-ignored")
  assert_eq(repeated_html.errors[2].code, "unexpected-end-tag")
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
  let shell = @html_parser.parse_fragment(
    "<select><body>x</body><head>y</head></select>",
    collect_errors=true,
  )
  assert_eq(shell.to_html(pretty=false), "<select>xy</select>")
  assert_eq(shell.errors.length(), 4)
  assert_eq(shell.errors[0].code, "unexpected-start-tag-in-select")
  assert_eq(shell.errors[1].code, "unexpected-end-tag")
  assert_eq(shell.errors[2].code, "unexpected-start-tag-in-select")
  assert_eq(shell.errors[3].code, "unexpected-end-tag")
}

///|
test "parser ignores sectioning starts in select mode" {
  let aside = @html_parser.parse(
    "<select><aside>text</aside></select>",
    collect_errors=true,
  )
  assert_eq(
    aside.to_html(pretty=false),
    "<html><head></head><body><select>text</select></body></html>",
  )
  assert_eq(aside.errors.length(), 3)
  assert_eq(aside.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(aside.errors[1].code, "unexpected-start-tag-in-select")
  assert_eq(aside.errors[2].code, "unexpected-end-tag")
}

///|
test "parser tracks origins for select helper start tags" {
  let div = @html_parser.parse_fragment(
    "<select><div>x</div>y</select>",
    track_node_locations=true,
  )
  guard div.query_one("div") is Some(div_node) else {
    fail("expected select div")
  }
  assert_node_origin(div_node, 8, 1, 9)
  let div_children = div_node.children()
  assert_eq(div_children.length(), 1)
  assert_node_origin(div_children[0], 13, 1, 14)
  let br = @html_parser.parse_fragment(
    "<select><br>x</select>",
    track_node_locations=true,
  )
  guard br.query_one("br") is Some(br_node) else { fail("expected select br") }
  assert_node_origin(br_node, 8, 1, 9)
  let plain = @html_parser.parse_fragment(
    "<select><plaintext>x</select>y",
    track_node_locations=true,
  )
  guard plain.query_one("plaintext") is Some(plaintext) else {
    fail("expected select plaintext")
  }
  assert_node_origin(plaintext, 8, 1, 9)
  let plain_children = plaintext.children()
  assert_eq(plain_children.length(), 1)
  assert_node_origin(plain_children[0], 19, 1, 20)
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
  let nested_inline = @html_parser.parse_fragment(
    "<ul><li><span>one<li>two</ul>",
    collect_errors=true,
  )
  assert_eq(
    nested_inline.to_html(pretty=false),
    "<ul><li><span>one</span></li><li>two</li></ul>",
  )
  assert_eq(nested_inline.errors.length(), 0)
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
  let outside_select = @html_parser.parse_fragment(
    "</optgroup></option></menuitem>",
    collect_errors=true,
  )
  assert_eq(outside_select.to_html(pretty=false), "")
  assert_eq(outside_select.errors.length(), 3)
  for error in outside_select.errors {
    assert_eq(error.code, "unexpected-end-tag")
  }
}

///|
test "tree builder matches Python reference select optgroup branch fixtures" {
  let nested_group = @html_parser.parse(
    "<select><optgroup><option>1</option></optgroup></select>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(nested_group.root),
    "| <html>\n|   <head>\n|   <body>\n|     <select>\n|       <optgroup>\n|         <option>\n|           \"1\"",
  )
  assert_eq(nested_group.errors.length(), 1)
  assert_eq(nested_group.errors[0].code, "expected-doctype-but-got-start-tag")
  guard nested_group.errors[0].column is Some(8) else {
    fail("expected select doctype error at select start close")
  }
  let stray_group = @html_parser.parse(
    "<select><option>1</option></optgroup></select>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(stray_group.root),
    "| <html>\n|   <head>\n|   <body>\n|     <select>\n|       <option>\n|         \"1\"",
  )
  assert_eq(stray_group.errors.length(), 2)
  assert_eq(stray_group.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(stray_group.errors[1].code, "unexpected-end-tag-in-select")
  guard stray_group.errors[1].column is Some(37) else {
    fail("expected stray optgroup end at close bracket")
  }
}

///|
test "tree builder matches Python reference selectedcontent branch fixtures" {
  let selected = @html_parser.parse(
    "<select><selectedcontent></selectedcontent><option>A</option><option selected>B</option></select>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(selected.root),
    "| <html>\n|   <head>\n|   <body>\n|     <select>\n|       <selectedcontent>\n|         \"B\"\n|       <option>\n|         \"A\"\n|       <option>\n|         selected=\"\"\n|         \"B\"",
  )
  assert_eq(selected.errors.length(), 3)
  assert_eq(selected.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(selected.errors[1].code, "unexpected-start-tag-in-select")
  assert_eq(selected.errors[2].code, "unexpected-end-tag-in-select")
  guard selected.errors[1].column is Some(25) else {
    fail("expected selectedcontent start error at start tag close")
  }
  guard selected.errors[2].column is Some(43) else {
    fail("expected selectedcontent end error at end tag close")
  }
  let default_first = @html_parser.parse(
    "<select><selectedcontent></selectedcontent><option>A</option><option>B</option></select>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(default_first.root),
    "| <html>\n|   <head>\n|   <body>\n|     <select>\n|       <selectedcontent>\n|         \"A\"\n|       <option>\n|         \"A\"\n|       <option>\n|         \"B\"",
  )
  assert_eq(default_first.errors.length(), 3)
  assert_eq(default_first.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(default_first.errors[1].code, "unexpected-start-tag-in-select")
  assert_eq(default_first.errors[2].code, "unexpected-end-tag-in-select")
  guard default_first.errors[1].column is Some(25) else {
    fail("expected default selectedcontent start error at start tag close")
  }
  guard default_first.errors[2].column is Some(43) else {
    fail("expected default selectedcontent end error at end tag close")
  }
}

///|
test "tree builder matches Python reference select aside and selectedcontent attribute branch fixtures" {
  let aside = @html_parser.parse(
    "<select><aside>text</aside></select>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(aside.root),
    "| <html>\n|   <head>\n|   <body>\n|     <select>\n|       \"text\"",
  )
  assert_eq(aside.errors.length(), 3)
  assert_eq(aside.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(aside.errors[1].code, "unexpected-start-tag-in-select")
  assert_eq(aside.errors[2].code, "unexpected-end-tag")
  guard aside.errors[1].column is Some(15) else {
    fail("expected aside start error at start tag close")
  }
  guard aside.errors[2].column is Some(27) else {
    fail("expected aside end error at end tag close")
  }
  let disabled = @html_parser.parse(
    "<select><selectedcontent></selectedcontent><option disabled>A</option></select>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(disabled.root),
    "| <html>\n|   <head>\n|   <body>\n|     <select>\n|       <selectedcontent>\n|         \"A\"\n|       <option>\n|         disabled=\"\"\n|         \"A\"",
  )
  assert_eq(disabled.errors.length(), 3)
  assert_eq(disabled.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(disabled.errors[1].code, "unexpected-start-tag-in-select")
  assert_eq(disabled.errors[2].code, "unexpected-end-tag-in-select")
  let classed = @html_parser.parse(
    "<select><selectedcontent></selectedcontent><option class=\"x\">A</option><option selected>B</option></select>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(classed.root),
    "| <html>\n|   <head>\n|   <body>\n|     <select>\n|       <selectedcontent>\n|         \"B\"\n|       <option>\n|         class=\"x\"\n|         \"A\"\n|       <option>\n|         selected=\"\"\n|         \"B\"",
  )
  assert_eq(classed.errors.length(), 3)
  assert_eq(classed.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(classed.errors[1].code, "unexpected-start-tag-in-select")
  assert_eq(classed.errors[2].code, "unexpected-end-tag-in-select")
}

///|
test "tree builder matches Python reference select formatting end branch fixtures" {
  let bold = @html_parser.parse("<b><select></b></select>", collect_errors=true)
  assert_eq(
    @html_parser.to_test_format(bold.root),
    "| <html>\n|   <head>\n|   <body>\n|     <b>\n|       <select>",
  )
  assert_eq(bold.errors.length(), 3)
  assert_eq(bold.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(bold.errors[1].code, "unexpected-end-tag-in-select")
  assert_eq(bold.errors[2].code, "expected-closing-tag-but-got-eof")
  guard bold.errors[1].column is Some(15) else {
    fail("expected bold end tag in select at close bracket")
  }
  guard bold.errors[2].column is Some(24) else {
    fail("expected bold EOF recovery at EOF column")
  }
  let link = @html_parser.parse(
    "<a href=\"x\"><select></a></select>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(link.root),
    "| <html>\n|   <head>\n|   <body>\n|     <a>\n|       href=\"x\"\n|       <select>",
  )
  assert_eq(link.errors.length(), 3)
  assert_eq(link.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(link.errors[1].code, "unexpected-end-tag-in-select")
  assert_eq(link.errors[2].code, "expected-closing-tag-but-got-eof")
  guard link.errors[1].column is Some(24) else {
    fail("expected link end tag in select at close bracket")
  }
  guard link.errors[2].column is Some(33) else {
    fail("expected link EOF recovery at EOF column")
  }
}

///|
test "tree builder matches Python reference select formatting stray branch fixtures" {
  let link_end = @html_parser.parse(
    "<select></a></select>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(link_end.root),
    "| <html>\n|   <head>\n|   <body>\n|     <select>",
  )
  assert_eq(link_end.errors.length(), 2)
  assert_eq(link_end.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(link_end.errors[1].code, "unexpected-end-tag-in-select")
  guard link_end.errors[1].column is Some(12) else {
    fail("expected stray link end in select at close bracket")
  }
  let bold_end = @html_parser.parse(
    "<select></b></select>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(bold_end.root),
    "| <html>\n|   <head>\n|   <body>\n|     <select>",
  )
  assert_eq(bold_end.errors.length(), 2)
  assert_eq(bold_end.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(bold_end.errors[1].code, "unexpected-end-tag-in-select")
  guard bold_end.errors[1].column is Some(12) else {
    fail("expected stray bold end in select at close bracket")
  }
}

///|
test "tree builder matches Python reference select plaintext branch fixture" {
  let doc = @html_parser.parse(
    "<select><plaintext></select>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(doc.root),
    "| <html>\n|   <head>\n|   <body>\n|     <select>\n|       <plaintext>\n|         \"</select>\"",
  )
  assert_eq(doc.errors.length(), 3)
  assert_eq(doc.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(doc.errors[1].code, "unexpected-start-tag-in-select")
  assert_eq(doc.errors[2].code, "expected-closing-tag-but-got-eof")
  guard doc.errors[1].column is Some(19) else {
    fail("expected plaintext start error at start tag close")
  }
  guard doc.errors[2].column is Some(28) else {
    fail("expected plaintext EOF recovery at EOF column")
  }
}

///|
test "parser populates selectedcontent from selected option" {
  let no_options = @html_parser.parse_fragment(
    "<select><selectedcontent></selectedcontent></select>",
    collect_errors=true,
  )
  assert_eq(
    no_options.to_html(pretty=false),
    "<select><selectedcontent></selectedcontent></select>",
  )
  assert_eq(no_options.errors.length(), 2)
  assert_eq(no_options.errors[0].code, "unexpected-start-tag-in-select")
  assert_eq(no_options.errors[1].code, "unexpected-end-tag-in-select")
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
test "selectedcontent population handles deeply nested selected option" {
  let html = "<select><option selected>" +
    repeat_for_test("<div>", 1200) +
    "x" +
    repeat_for_test("</div>", 1200) +
    "</option><selectedcontent></selectedcontent></select>"
  let doc = @html_parser.parse_fragment(html, collect_errors=true)
  guard doc.query_one("selectedcontent") is Some(selectedcontent) else {
    fail("expected selectedcontent element")
  }
  assert_eq(selectedcontent.children().length(), 1)
  let cloned = selectedcontent.children()[0]
  assert_eq(cloned.name(), "div")
  assert_eq(cloned.to_text(separator="", strip=false), "x")
  assert_eq(doc.errors.length(), 2402)
  assert_eq(doc.errors[0].code, "unexpected-start-tag-in-select")
  assert_eq(
    doc.errors[doc.errors.length() - 1].code,
    "unexpected-end-tag-in-select",
  )
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
  let generic_end = @html_parser.parse_fragment(
    "<table><caption>x</div>y</caption></table>",
    collect_errors=true,
  )
  assert_eq(
    generic_end.to_html(pretty=false),
    "<table><caption>xy</caption></table>",
  )
  assert_eq(generic_end.errors.length(), 1)
  assert_eq(generic_end.errors[0].code, "unexpected-end-tag")
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
test "parser tracks origins for foster-parented table text" {
  let direct = @html_parser.parse_fragment(
    "<table>text</table>",
    track_node_locations=true,
  )
  let direct_children = direct.root.children()
  assert_eq(direct_children.length(), 2)
  assert_eq(direct_children[0].data(), "text")
  assert_node_origin(direct_children[0], 7, 1, 8)
  let section = @html_parser.parse_fragment(
    "<table><tbody>text</tbody></table>",
    track_node_locations=true,
  )
  let section_children = section.root.children()
  assert_eq(section_children.length(), 2)
  assert_eq(section_children[0].data(), "text")
  assert_node_origin(section_children[0], 14, 1, 15)
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
test "tree builder matches Python reference hidden input in table branch fixture" {
  let document_hidden = @html_parser.parse(
    "<table><input id=\"x\" class=\"y\" type=\"hidden\"></table>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(document_hidden.root),
    "| <html>\n|   <head>\n|   <body>\n|     <table>\n|       <input>\n|         class=\"y\"\n|         id=\"x\"\n|         type=\"hidden\"",
  )
  assert_eq(document_hidden.errors.length(), 2)
  assert_eq(
    document_hidden.errors[0].code,
    "expected-doctype-but-got-start-tag",
  )
  assert_eq(document_hidden.errors[1].code, "unexpected-hidden-input-in-table")
  guard document_hidden.errors[1].column is Some(45) else {
    fail("expected hidden input table error at input start close")
  }
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
  guard hidden.errors[0].column is Some(41) else {
    fail("expected hidden input table error at fragment input start close")
  }
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
  guard form.errors[0].column is Some(18) else {
    fail("expected form table error at start tag close")
  }
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
test "parser tracks origins for hidden input and form table helpers" {
  let hidden = @html_parser.parse_fragment(
    "<table><input type=hidden name=x value=y></table>",
    track_node_locations=true,
  )
  guard hidden.query_one("input") is Some(input) else {
    fail("expected hidden input")
  }
  assert_node_origin(input, 7, 1, 8)
  let form = @html_parser.parse_fragment(
    "<table><form id=f></form></table>",
    track_node_locations=true,
  )
  guard form.query_one("form") is Some(form_node) else { fail("expected form") }
  assert_node_origin(form_node, 7, 1, 8)
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
test "parser tracks origins for end-tag recovery elements" {
  let before_html = @html_parser.parse("</br>", track_node_locations=true)
  guard before_html.query_one("br") is Some(before_br) else {
    fail("expected before-html br")
  }
  assert_node_origin(before_br, 0, 1, 1)
  let paragraph = @html_parser.parse_fragment(
    "<p>one</br>two",
    track_node_locations=true,
  )
  guard paragraph.query_one("br") is Some(br) else { fail("expected br") }
  assert_node_origin(br, 6, 1, 7)
  let stray_p = @html_parser.parse_fragment(
    "<div></p>after</div>",
    track_node_locations=true,
  )
  guard stray_p.query_one("p") is Some(p) else { fail("expected recovered p") }
  assert_node_origin(p, 5, 1, 6)
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
  let c1_letters = @html_parser.parse_bytes(b"<p>\x83\x9f</p>")
  assert_eq(c1_letters.to_text(separator="", strip=false), "\u{0192}\u{0178}")
  guard c1_letters.encoding is Some("windows-1252") else {
    fail("expected C1 default bytes to use windows-1252")
  }
  let c1_punctuation = @html_parser.parse_bytes(b"<p>\x84\x8c</p>")
  assert_eq(
    c1_punctuation.to_text(separator="", strip=false),
    "\u{201E}\u{0152}",
  )
  guard c1_punctuation.encoding is Some("windows-1252") else {
    fail("expected sparse C1 bytes to use windows-1252")
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
  let mixed = b"<p>\xa0\xa2\xb2\xc7\xe7</p>"
  let mixed_doc = @html_parser.parse_bytes(mixed, encoding="latin-2")
  assert_eq(
    mixed_doc.to_text(separator="", strip=false),
    "\u{00A0}\u{02D8}\u{02DB}\u{00C7}\u{00E7}",
  )
  guard mixed_doc.encoding is Some("iso-8859-2") else {
    fail("expected latin-2 label to normalize to iso-8859-2")
  }
  let polish_czech = b"<p>\xa3\xb3\xc8\xe8</p>"
  let polish_czech_doc = @html_parser.parse_bytes(
    polish_czech,
    encoding="iso-8859-2",
  )
  assert_eq(
    polish_czech_doc.to_text(separator="", strip=false),
    "\u{0141}\u{0142}\u{010C}\u{010D}",
  )
  guard polish_czech_doc.encoding is Some("iso-8859-2") else {
    fail("expected explicit iso-8859-2 encoding for Central European bytes")
  }
  let latin2_marks = b"<p>\xa5\xb5\xca\xea\xff</p>"
  let latin2_marks_doc = @html_parser.parse_bytes(
    latin2_marks,
    encoding="iso-8859-2",
  )
  assert_eq(
    latin2_marks_doc.to_text(separator="", strip=false),
    "\u{013D}\u{013E}\u{0118}\u{0119}\u{02D9}",
  )
  guard latin2_marks_doc.encoding is Some("iso-8859-2") else {
    fail("expected explicit iso-8859-2 encoding for remapped high bytes")
  }
  let identity_high_bytes = b"<p>\xa4\xb4\xc9\xe9</p>"
  let identity_high_doc = @html_parser.parse_bytes(
    identity_high_bytes,
    encoding="iso-8859-2",
  )
  assert_eq(
    identity_high_doc.to_text(separator="", strip=false),
    "\u{00A4}\u{00B4}\u{00C9}\u{00E9}",
  )
  guard identity_high_doc.encoding is Some("iso-8859-2") else {
    fail("expected explicit iso-8859-2 encoding for identity high bytes")
  }
  let identity_e_diaeresis = @html_parser.parse_bytes(
    b"<p>\xcb\xeb</p>",
    encoding="iso-8859-2",
  )
  assert_eq(
    identity_e_diaeresis.to_text(separator="", strip=false),
    "\u{00CB}\u{00EB}",
  )
  guard identity_e_diaeresis.encoding is Some("iso-8859-2") else {
    fail("expected explicit iso-8859-2 encoding for sparse identity bytes")
  }
  let latin2_mid = @html_parser.parse_bytes(
    b"<p>\xa6\xa7\xa8\xa9\xaa\xab\xac\xad\xae\xaf\xb0\xb1\xb2\xb3\xb4\xb5\xb6\xb7\xb8\xb9\xba\xbb\xbc\xbd\xbe\xbf</p>",
    encoding="iso-8859-2",
  )
  assert_eq(
    latin2_mid.to_text(separator="", strip=false),
    "\u{015A}\u{00A7}\u{00A8}\u{0160}\u{015E}\u{0164}\u{0179}\u{00AD}\u{017D}\u{017B}\u{00B0}\u{0105}\u{02DB}\u{0142}\u{00B4}\u{013E}\u{015B}\u{02C7}\u{00B8}\u{0161}\u{015F}\u{0165}\u{017A}\u{02DD}\u{017E}\u{017C}",
  )
  let latin2_upper = @html_parser.parse_bytes(
    b"<p>\xc0\xc1\xc2\xc3\xc4\xc5\xc6\xc7\xc8\xc9\xca\xcb\xcc\xcd\xce\xcf\xd0\xd1\xd2\xd3\xd4\xd5\xd6\xd7\xd8\xd9\xda\xdb\xdc\xdd\xde\xdf</p>",
    encoding="iso-8859-2",
  )
  assert_eq(
    latin2_upper.to_text(separator="", strip=false),
    "\u{0154}\u{00C1}\u{00C2}\u{0102}\u{00C4}\u{0139}\u{0106}\u{00C7}\u{010C}\u{00C9}\u{0118}\u{00CB}\u{011A}\u{00CD}\u{00CE}\u{010E}\u{0110}\u{0143}\u{0147}\u{00D3}\u{00D4}\u{0150}\u{00D6}\u{00D7}\u{0158}\u{016E}\u{00DA}\u{0170}\u{00DC}\u{00DD}\u{0162}\u{00DF}",
  )
  let latin2_lower = @html_parser.parse_bytes(
    b"<p>\xe0\xe1\xe2\xe3\xe4\xe5\xe6\xe7\xe8\xe9\xea\xeb\xec\xed\xee\xef\xf0\xf1\xf2\xf3\xf4\xf5\xf6\xf7\xf8\xf9\xfa\xfb\xfc\xfd\xfe\xff</p>",
    encoding="iso-8859-2",
  )
  assert_eq(
    latin2_lower.to_text(separator="", strip=false),
    "\u{0155}\u{00E1}\u{00E2}\u{0103}\u{00E4}\u{013A}\u{0107}\u{00E7}\u{010D}\u{00E9}\u{0119}\u{00EB}\u{011B}\u{00ED}\u{00EE}\u{010F}\u{0111}\u{0144}\u{0148}\u{00F3}\u{00F4}\u{0151}\u{00F6}\u{00F7}\u{0159}\u{016F}\u{00FA}\u{0171}\u{00FC}\u{00FD}\u{0163}\u{02D9}",
  )
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
  let spaced = b"<meta\tcharset\r\n=\tutf-8><p>\xe2\x82\xac</p>"
  let spaced_doc = @html_parser.parse_bytes(spaced)
  assert_eq(spaced_doc.to_text(separator="", strip=false), "\u{20AC}")
  guard spaced_doc.encoding is Some("utf-8") else {
    fail("expected whitespace around meta charset equals to sniff utf-8")
  }
  let quoted = b"\x3c\x6d\x65\x74\x61\x20\x63\x68\x61\x72\x73\x65\x74\x3d\x22\x6c\x61\x74\x69\x6e\x31\x22\x3e\x3c\x70\x3e\x80\x3c\x2f\x70\x3e"
  let quoted_doc = @html_parser.parse_bytes(quoted)
  assert_eq(quoted_doc.to_text(separator="", strip=false), "\u{20AC}")
  guard quoted_doc.encoding is Some("windows-1252") else {
    fail("expected meta latin1 to normalize to windows-1252")
  }
  let trimmed = b"<meta charset=' utf-8 '><p>\xe2\x82\xac</p>"
  let trimmed_doc = @html_parser.parse_bytes(trimmed)
  assert_eq(trimmed_doc.to_text(separator="", strip=false), "\u{20AC}")
  guard trimmed_doc.encoding is Some("utf-8") else {
    fail("expected trimmed quoted meta charset to sniff utf-8")
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
  let bogus_declaration = b"<!meta charset=utf-8><p>\x80</p>"
  let bogus_declaration_doc = @html_parser.parse_bytes(bogus_declaration)
  assert_eq(
    bogus_declaration_doc.to_text(separator="", strip=false),
    "\u{20AC}",
  )
  guard bogus_declaration_doc.encoding is Some("windows-1252") else {
    fail("expected bogus meta declaration to be ignored")
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
  let broken_value = b"<meta charset=   <p>\x80</p>"
  let broken_value_doc = @html_parser.parse_bytes(broken_value)
  assert_eq(broken_value_doc.to_text(separator="", strip=false), "\u{20AC}")
  guard broken_value_doc.encoding is Some("windows-1252") else {
    fail("expected meta charset interrupted by markup to fall back")
  }
  let eof_after_equals = @html_parser.parse_bytes(b"<meta charset=   ")
  guard eof_after_equals.encoding is Some("windows-1252") else {
    fail("expected eof after meta charset equals to fall back")
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
  let blank_content_charset = b"<meta http-equiv=\"Content-Type\" content=\"charset=   \"><p>\x80</p>"
  let blank_content_charset_doc = @html_parser.parse_bytes(
    blank_content_charset,
  )
  assert_eq(
    blank_content_charset_doc.to_text(separator="", strip=false),
    "\u{20AC}",
  )
  guard blank_content_charset_doc.encoding is Some("windows-1252") else {
    fail("expected blank content charset value to fall back")
  }
  let quoted_empty_charset = b"<meta http-equiv=\"Content-Type\" content=\"charset=''\"><p>\x80</p>"
  let quoted_empty_charset_doc = @html_parser.parse_bytes(quoted_empty_charset)
  assert_eq(
    quoted_empty_charset_doc.to_text(separator="", strip=false),
    "\u{20AC}",
  )
  guard quoted_empty_charset_doc.encoding is Some("windows-1252") else {
    fail("expected quoted empty content charset to fall back")
  }
  let valueless_http = b"<meta http-equiv content=\"text/html; charset=utf-8\"><p>\x80</p>"
  let valueless_http_doc = @html_parser.parse_bytes(valueless_http)
  assert_eq(valueless_http_doc.to_text(separator="", strip=false), "\u{20AC}")
  guard valueless_http_doc.encoding is Some("windows-1252") else {
    fail("expected valueless http-equiv to fall back")
  }
  let valueless_content = b"<meta http-equiv=\"Content-Type\" content><p>\x80</p>"
  let valueless_content_doc = @html_parser.parse_bytes(valueless_content)
  assert_eq(
    valueless_content_doc.to_text(separator="", strip=false),
    "\u{20AC}",
  )
  guard valueless_content_doc.encoding is Some("windows-1252") else {
    fail("expected valueless content to fall back")
  }
  let unterminated = b"<meta http-equiv=\"Content-Type\" content=\"text/html; charset='utf-8\"><p>\x80</p>"
  let unterminated_doc = @html_parser.parse_bytes(unterminated)
  assert_eq(unterminated_doc.to_text(separator="", strip=false), "\u{20AC}")
  guard unterminated_doc.encoding is Some("windows-1252") else {
    fail("expected unterminated content charset quote to fall back")
  }
  let quoted_charset = b"<meta http-equiv='Content-Type' content='text/html; charset=\"utf-8\"'><p>\xe2\x82\xac</p>"
  let quoted_charset_doc = @html_parser.parse_bytes(quoted_charset)
  assert_eq(quoted_charset_doc.to_text(separator="", strip=false), "\u{20AC}")
  guard quoted_charset_doc.encoding is Some("utf-8") else {
    fail("expected raw quoted content charset to sniff utf-8")
  }
  let semicolon = b"<meta http-equiv='Content-Type' content='text/html; charset=utf-8; x=y'><p>\xe2\x82\xac</p>"
  let semicolon_doc = @html_parser.parse_bytes(semicolon)
  assert_eq(semicolon_doc.to_text(separator="", strip=false), "\u{20AC}")
  guard semicolon_doc.encoding is Some("utf-8") else {
    fail("expected semicolon-terminated content charset to sniff utf-8")
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
  let explicit_generic_big = @html_parser.parse_bytes(big, encoding="utf-16")
  assert_eq(
    explicit_generic_big.to_html(pretty=false),
    "<html><head></head><body><p>hi</p></body></html>",
  )
  guard explicit_generic_big.encoding is Some("utf-16") else {
    fail("expected generic utf-16 encoding to preserve label")
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
test "parse_bytes handles empty labels aliases and malformed utf16 tails" {
  let empty_label = @html_parser.parse_bytes(b"<p>\x80</p>", encoding="  ")
  assert_eq(empty_label.to_text(separator="", strip=false), "\u{20AC}")
  guard empty_label.encoding is Some("windows-1252") else {
    fail("expected empty transport label to fall back")
  }
  let explicit_little = b"\x3c\x00\x70\x00\x3e\x00\x68\x00\x69\x00\x3c\x00\x2f\x00\x70\x00\x3e\x00"
  let explicit_little_doc = @html_parser.parse_bytes(
    explicit_little,
    encoding="UTF16LE",
  )
  assert_eq(
    explicit_little_doc.to_html(pretty=false),
    "<html><head></head><body><p>hi</p></body></html>",
  )
  guard explicit_little_doc.encoding is Some("utf-16le") else {
    fail("expected utf16le alias to normalize")
  }
  let odd_little = b"\xff\xfe\x3c\x00\x70\x00\x3e\x00\x41"
  let odd_little_doc = @html_parser.parse_bytes(odd_little)
  assert_eq(
    odd_little_doc.to_html(pretty=false),
    "<html><head></head><body><p>\u{FFFD}</p></body></html>",
  )
  guard odd_little_doc.encoding is Some("utf-16le") else {
    fail("expected malformed utf16le bom encoding")
  }
  let odd_big = b"\xfe\xff\x00\x3c\x00\x70\x00\x3e\x00\x42\x00"
  let odd_big_doc = @html_parser.parse_bytes(odd_big)
  assert_eq(
    odd_big_doc.to_html(pretty=false),
    "<html><head></head><body><p>B\u{FFFD}</p></body></html>",
  )
  guard odd_big_doc.encoding is Some("utf-16be") else {
    fail("expected malformed utf16be bom encoding")
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
test "tokenize matches upstream coverage gap fixtures" {
  let null_attr_name = @html_parser.tokenize(
    "<div a\u{0000}b='c'>",
    collect_errors=true,
  )
  guard null_attr_name.tokens[0] is Tag(null_attr_name_tag) else {
    fail("expected null attribute name start tag")
  }
  guard null_attr_name_tag.attrs["a\u{FFFD}b"] is Some("c") else {
    fail("expected replacement character in attribute name")
  }
  assert_eq(null_attr_name.errors.length(), 1)
  assert_eq(null_attr_name.errors[0].code, "unexpected-null-character")
  guard null_attr_name.errors[0].column is Some(7) else {
    fail("expected null attribute name error at column 7")
  }
  let null_double = @html_parser.tokenize(
    "<div a=\"b\u{0000}c\">",
    collect_errors=true,
  )
  guard null_double.tokens[0] is Tag(null_double_tag) else {
    fail("expected null double-quoted attribute start tag")
  }
  guard null_double_tag.attrs["a"] is Some("b\u{FFFD}c") else {
    fail("expected replacement character in double-quoted attribute value")
  }
  assert_eq(null_double.errors.length(), 1)
  assert_eq(null_double.errors[0].code, "unexpected-null-character")
  guard null_double.errors[0].column is Some(10) else {
    fail("expected double-quoted attribute null at column 10")
  }
  let null_single = @html_parser.tokenize(
    "<div a='b\u{0000}c'>",
    collect_errors=true,
  )
  guard null_single.tokens[0] is Tag(null_single_tag) else {
    fail("expected null single-quoted attribute start tag")
  }
  guard null_single_tag.attrs["a"] is Some("b\u{FFFD}c") else {
    fail("expected replacement character in single-quoted attribute value")
  }
  assert_eq(null_single.errors.length(), 1)
  assert_eq(null_single.errors[0].code, "unexpected-null-character")
  guard null_single.errors[0].column is Some(10) else {
    fail("expected single-quoted attribute null at column 10")
  }
  let missing_value = @html_parser.tokenize("<div a=>", collect_errors=true)
  guard missing_value.tokens[0] is Tag(missing_tag) else {
    fail("expected missing attribute value start tag")
  }
  guard missing_tag.attrs["a"] is Some("") else {
    fail("expected empty missing attribute value")
  }
  assert_eq(missing_value.errors.length(), 1)
  assert_eq(missing_value.errors[0].code, "missing-attribute-value")
  guard missing_value.errors[0].column is Some(8) else {
    fail("expected missing value at tag close")
  }
  let title_space = @html_parser.tokenize("<title >")
  guard title_space.tokens[0] is Tag(title_space_tag) else {
    fail("expected title start tag after attribute-name whitespace")
  }
  assert_eq(title_space_tag.name, "title")
  assert_eq(title_space_tag.attrs.length(), 0)
  let title_attr = @html_parser.tokenize("<title id>")
  guard title_attr.tokens[0] is Tag(title_attr_tag) else {
    fail("expected title start tag with empty id")
  }
  guard title_attr_tag.attrs["id"] is Some("") else {
    fail("expected empty id attribute")
  }
  let title_slow_attr = @html_parser.tokenize("<title id\\\">")
  guard title_slow_attr.tokens[0] is Tag(title_slow_attr_tag) else {
    fail("expected title start tag with quote in attribute name")
  }
  guard title_slow_attr_tag.attrs["id\\\""] is Some("") else {
    fail("expected backslash and quote in title attribute name")
  }
  let title_after_attr = @html_parser.tokenize("<title id >")
  guard title_after_attr.tokens[0] is Tag(title_after_attr_tag) else {
    fail("expected title start tag after attribute name")
  }
  guard title_after_attr_tag.attrs["id"] is Some("") else {
    fail("expected empty id after whitespace")
  }
  let title_before_value = @html_parser.tokenize("<title id=>")
  guard title_before_value.tokens[0] is Tag(title_before_value_tag) else {
    fail("expected title start tag before missing value")
  }
  guard title_before_value_tag.attrs["id"] is Some("") else {
    fail("expected empty id after equals")
  }
}

///|
test "entity decoding covers upstream fixture cases" {
  let numeric = @html_parser.parse_fragment("&#65")
  assert_eq(numeric.to_text(separator="", strip=false), "A")
  let control = @html_parser.parse_fragment("&#x80")
  assert_eq(control.to_text(separator="", strip=false), "\u{20AC}")
  let legacy = @html_parser.parse_fragment("&notit; &not &amp")
  assert_eq(legacy.to_text(separator="", strip=false), "¬it; ¬ &")
  let named = @html_parser.parse_fragment(
    "&copy; &eacute; &frac12; &AMP; &apos; &nbsp;",
  )
  assert_eq(
    named.to_text(separator="", strip=false),
    "\u{00A9} \u{00E9} \u{00BD} & ' \u{00A0}",
  )
  let legacy_named_entities : Array[(String, String)] = [
    ("gt", ">"),
    ("lt", "<"),
    ("amp", "&"),
    ("quot", "\""),
    ("nbsp", "\u{00A0}"),
    ("AMP", "&"),
    ("QUOT", "\""),
    ("GT", ">"),
    ("LT", "<"),
    ("COPY", "\u{00A9}"),
    ("REG", "\u{00AE}"),
    ("AElig", "\u{00C6}"),
    ("Aacute", "\u{00C1}"),
    ("Acirc", "\u{00C2}"),
    ("Agrave", "\u{00C0}"),
    ("Aring", "\u{00C5}"),
    ("Atilde", "\u{00C3}"),
    ("Auml", "\u{00C4}"),
    ("Ccedil", "\u{00C7}"),
    ("ETH", "\u{00D0}"),
    ("Eacute", "\u{00C9}"),
    ("Ecirc", "\u{00CA}"),
    ("Egrave", "\u{00C8}"),
    ("Euml", "\u{00CB}"),
    ("Iacute", "\u{00CD}"),
    ("Icirc", "\u{00CE}"),
    ("Igrave", "\u{00CC}"),
    ("Iuml", "\u{00CF}"),
    ("Ntilde", "\u{00D1}"),
    ("Oacute", "\u{00D3}"),
    ("Ocirc", "\u{00D4}"),
    ("Ograve", "\u{00D2}"),
    ("Oslash", "\u{00D8}"),
    ("Otilde", "\u{00D5}"),
    ("Ouml", "\u{00D6}"),
    ("THORN", "\u{00DE}"),
    ("Uacute", "\u{00DA}"),
    ("Ucirc", "\u{00DB}"),
    ("Ugrave", "\u{00D9}"),
    ("Uuml", "\u{00DC}"),
    ("Yacute", "\u{00DD}"),
    ("aacute", "\u{00E1}"),
    ("acirc", "\u{00E2}"),
    ("acute", "\u{00B4}"),
    ("aelig", "\u{00E6}"),
    ("agrave", "\u{00E0}"),
    ("aring", "\u{00E5}"),
    ("atilde", "\u{00E3}"),
    ("auml", "\u{00E4}"),
    ("brvbar", "\u{00A6}"),
    ("ccedil", "\u{00E7}"),
    ("cedil", "\u{00B8}"),
    ("cent", "\u{00A2}"),
    ("copy", "\u{00A9}"),
    ("curren", "\u{00A4}"),
    ("deg", "\u{00B0}"),
    ("divide", "\u{00F7}"),
    ("eacute", "\u{00E9}"),
    ("ecirc", "\u{00EA}"),
    ("egrave", "\u{00E8}"),
    ("eth", "\u{00F0}"),
    ("euml", "\u{00EB}"),
    ("frac12", "\u{00BD}"),
    ("frac14", "\u{00BC}"),
    ("frac34", "\u{00BE}"),
    ("iacute", "\u{00ED}"),
    ("icirc", "\u{00EE}"),
    ("iexcl", "\u{00A1}"),
    ("igrave", "\u{00EC}"),
    ("iquest", "\u{00BF}"),
    ("iuml", "\u{00EF}"),
    ("laquo", "\u{00AB}"),
    ("macr", "\u{00AF}"),
    ("micro", "\u{00B5}"),
    ("middot", "\u{00B7}"),
    ("not", "\u{00AC}"),
    ("ntilde", "\u{00F1}"),
    ("oacute", "\u{00F3}"),
    ("ocirc", "\u{00F4}"),
    ("ograve", "\u{00F2}"),
    ("ordf", "\u{00AA}"),
    ("ordm", "\u{00BA}"),
    ("oslash", "\u{00F8}"),
    ("otilde", "\u{00F5}"),
    ("ouml", "\u{00F6}"),
    ("para", "\u{00B6}"),
    ("plusmn", "\u{00B1}"),
    ("pound", "\u{00A3}"),
    ("raquo", "\u{00BB}"),
    ("reg", "\u{00AE}"),
    ("sect", "\u{00A7}"),
    ("shy", "\u{00AD}"),
    ("sup1", "\u{00B9}"),
    ("sup2", "\u{00B2}"),
    ("sup3", "\u{00B3}"),
    ("szlig", "\u{00DF}"),
    ("thorn", "\u{00FE}"),
    ("times", "\u{00D7}"),
    ("uacute", "\u{00FA}"),
    ("ucirc", "\u{00FB}"),
    ("ugrave", "\u{00F9}"),
    ("uml", "\u{00A8}"),
    ("uuml", "\u{00FC}"),
    ("yacute", "\u{00FD}"),
    ("yen", "\u{00A5}"),
    ("yuml", "\u{00FF}"),
  ]
  for item in legacy_named_entities {
    let (name, value) = item
    let parsed = @html_parser.parse_fragment("&" + name + ";")
    assert_eq(parsed.to_text(separator="", strip=false), value)
  }
  let exact = @html_parser.parse_fragment(
    "&notin; &hellip; &mdash; &ndash; &trade; &euro;",
  )
  assert_eq(
    exact.to_text(separator="", strip=false),
    "\u{2209} \u{2026} \u{2014} \u{2013} \u{2122} \u{20AC}",
  )
  let quotes = @html_parser.parse_fragment(
    "&ldquo;quote&rdquo; &lsquo;x&rsquo; &rarr; &larr; &le; &ge; &ne;",
  )
  assert_eq(
    quotes.to_text(separator="", strip=false),
    "\u{201C}quote\u{201D} \u{2018}x\u{2019} \u{2192} \u{2190} \u{2264} \u{2265} \u{2260}",
  )
}

///|
test "entity decoding reports upstream fixture errors" {
  let numeric = @html_parser.tokenize("&#65", collect_errors=true)
  guard numeric.tokens[0] is @html_parser.HtmlToken::Characters("A") else {
    fail("expected numeric reference token")
  }
  assert_eq(numeric.errors.length(), 1)
  assert_eq(
    numeric.errors[0].code,
    "missing-semicolon-after-character-reference",
  )
  guard numeric.errors[0].column is Some(4) else {
    fail("expected numeric missing semicolon at column 4")
  }
  let control = @html_parser.tokenize("&#x80", collect_errors=true)
  guard control.tokens[0] is @html_parser.HtmlToken::Characters("\u{20AC}") else {
    fail("expected Windows-1252 numeric replacement")
  }
  assert_eq(control.errors.length(), 2)
  assert_eq(
    control.errors[0].code,
    "missing-semicolon-after-character-reference",
  )
  assert_eq(control.errors[1].code, "control-character-reference")
  guard control.errors[1].column is Some(5) else {
    fail("expected control reference at column 5")
  }
  let noncharacter = @html_parser.tokenize("&#xFDD0;", collect_errors=true)
  guard noncharacter.tokens[0] is @html_parser.HtmlToken::Characters("\u{FDD0}") else {
    fail("expected noncharacter numeric reference")
  }
  assert_eq(noncharacter.errors.length(), 1)
  assert_eq(noncharacter.errors[0].code, "noncharacter-character-reference")
  guard noncharacter.errors[0].column is Some(8) else {
    fail("expected noncharacter reference at column 8")
  }
  let named_semicolon = @html_parser.tokenize("&notit;", collect_errors=true)
  guard named_semicolon.tokens[0] is @html_parser.HtmlToken::Characters("¬it;") else {
    fail("expected legacy prefix match with semicolon")
  }
  assert_eq(named_semicolon.errors.length(), 1)
  assert_eq(
    named_semicolon.errors[0].code,
    "missing-semicolon-after-character-reference",
  )
  guard named_semicolon.errors[0].column is Some(7) else {
    fail("expected legacy semicolon error at column 7")
  }
  let named_eof = @html_parser.tokenize("&notit", collect_errors=true)
  guard named_eof.tokens[0] is @html_parser.HtmlToken::Characters("¬it") else {
    fail("expected legacy prefix match without semicolon")
  }
  assert_eq(named_eof.errors.length(), 1)
  assert_eq(
    named_eof.errors[0].code,
    "missing-semicolon-after-character-reference",
  )
  guard named_eof.errors[0].column is Some(6) else {
    fail("expected legacy EOF error at column 6")
  }
  let fragment = @html_parser.parse_fragment(
    "&#x80 &#xFDD0; &not",
    collect_errors=true,
  )
  assert_eq(fragment.to_text(separator="", strip=false), "€ \u{FDD0} ¬")
  assert_eq(fragment.errors.length(), 4)
  assert_eq(
    fragment.errors[0].code,
    "missing-semicolon-after-character-reference",
  )
  assert_eq(fragment.errors[1].code, "control-character-reference")
  assert_eq(fragment.errors[2].code, "noncharacter-character-reference")
  assert_eq(
    fragment.errors[3].code,
    "missing-semicolon-after-character-reference",
  )
  let named_legacy = @html_parser.tokenize(
    "&copy &eacute &frac12 &COPY",
    collect_errors=true,
  )
  guard named_legacy.tokens[0]
    is @html_parser.HtmlToken::Characters("\u{00A9} \u{00E9} \u{00BD} \u{00A9}") else {
    fail("expected legacy named entity decoding")
  }
  assert_eq(named_legacy.errors.length(), 4)
  for error in named_legacy.errors {
    assert_eq(error.code, "missing-semicolon-after-character-reference")
  }
  let named_prefix = @html_parser.tokenize(
    "&copycat; &regression &frac12x &notit;",
    collect_errors=true,
  )
  guard named_prefix.tokens[0]
    is @html_parser.HtmlToken::Characters(
      "\u{00A9}cat; \u{00AE}ression \u{00BD}x \u{00AC}it;"
    ) else {
    fail("expected longest legacy prefix decoding")
  }
  assert_eq(named_prefix.errors.length(), 4)
  for error in named_prefix.errors {
    assert_eq(error.code, "missing-semicolon-after-character-reference")
  }
}

///|
test "numeric entity decoding covers replacement and no digit edges" {
  let zero = @html_parser.tokenize("&#0;", collect_errors=true)
  guard zero.tokens[0] is @html_parser.HtmlToken::Characters("\u{FFFD}") else {
    fail("expected null numeric reference replacement")
  }
  assert_eq(zero.errors.length(), 1)
  assert_eq(zero.errors[0].code, "control-character-reference")
  guard zero.errors[0].column is Some(4) else {
    fail("expected null control reference at column 4")
  }
  let c1 = @html_parser.tokenize("&#x82;", collect_errors=true)
  guard c1.tokens[0] is @html_parser.HtmlToken::Characters("\u{201A}") else {
    fail("expected C1 numeric replacement")
  }
  assert_eq(c1.errors.length(), 1)
  assert_eq(c1.errors[0].code, "control-character-reference")
  guard c1.errors[0].column is Some(6) else {
    fail("expected C1 control reference at column 6")
  }
  let c1_printable = @html_parser.tokenize("&#x83; &#131;", collect_errors=true)
  guard c1_printable.tokens[0] is Characters("\u{0192} \u{0192}") else {
    fail("expected C1 printable numeric replacements")
  }
  assert_eq(c1_printable.errors.length(), 2)
  for error in c1_printable.errors {
    assert_eq(error.code, "control-character-reference")
  }
  guard c1_printable.errors[0].column is Some(6) else {
    fail("expected hex C1 printable error at column 6")
  }
  guard c1_printable.errors[1].column is Some(13) else {
    fail("expected decimal C1 printable error at column 13")
  }
  let c1_replacements : Array[(String, String)] = [
    ("&#x84;", "\u{201E}"),
    ("&#x85;", "\u{2026}"),
    ("&#x86;", "\u{2020}"),
    ("&#x87;", "\u{2021}"),
    ("&#x88;", "\u{02C6}"),
    ("&#x89;", "\u{2030}"),
    ("&#x8A;", "\u{0160}"),
    ("&#x8B;", "\u{2039}"),
    ("&#x8C;", "\u{0152}"),
    ("&#x8E;", "\u{017D}"),
    ("&#x91;", "\u{2018}"),
    ("&#x92;", "\u{2019}"),
    ("&#x93;", "\u{201C}"),
    ("&#x94;", "\u{201D}"),
    ("&#x95;", "\u{2022}"),
    ("&#x96;", "\u{2013}"),
    ("&#x97;", "\u{2014}"),
    ("&#x98;", "\u{02DC}"),
    ("&#x99;", "\u{2122}"),
    ("&#x9A;", "\u{0161}"),
    ("&#x9B;", "\u{203A}"),
    ("&#x9C;", "\u{0153}"),
    ("&#x9E;", "\u{017E}"),
    ("&#x9F;", "\u{0178}"),
  ]
  for item in c1_replacements {
    let (source, expected) = item
    let result = @html_parser.tokenize(source, collect_errors=true)
    guard result.tokens[0] is Characters(actual) else {
      fail("expected C1 replacement token")
    }
    assert_eq(actual, expected)
    assert_eq(result.errors.length(), 1)
    assert_eq(result.errors[0].code, "control-character-reference")
  }
  let lowercase_hex = @html_parser.tokenize("&#xa;", collect_errors=true)
  guard lowercase_hex.tokens[0] is @html_parser.HtmlToken::Characters("\n") else {
    fail("expected lowercase hex numeric reference")
  }
  assert_eq(lowercase_hex.errors.length(), 1)
  assert_eq(lowercase_hex.errors[0].code, "control-character-reference")
  guard lowercase_hex.errors[0].column is Some(5) else {
    fail("expected lowercase hex control reference at column 5")
  }
  let upper_x = @html_parser.tokenize("&#X66;", collect_errors=true)
  guard upper_x.tokens[0] is @html_parser.HtmlToken::Characters("f") else {
    fail("expected uppercase X hex marker")
  }
  assert_eq(upper_x.errors.length(), 0)
  let invalid_scalars = @html_parser.tokenize(
    "&#x110000; &#xD800;",
    collect_errors=true,
  )
  guard invalid_scalars.tokens[0]
    is @html_parser.HtmlToken::Characters("\u{FFFD} \u{FFFD}") else {
    fail("expected invalid numeric scalars to replace")
  }
  assert_eq(invalid_scalars.errors.length(), 0)
  let no_digits = @html_parser.tokenize("&#x; &#; &#xg;", collect_errors=true)
  guard no_digits.tokens[0]
    is @html_parser.HtmlToken::Characters("&#x; &#; &#xg;") else {
    fail("expected digitless numeric references to remain literal")
  }
  assert_eq(no_digits.errors.length(), 0)
}

///|
test "attribute entity decoding reports upstream fixture errors" {
  let quoted = @html_parser.tokenize(
    "<div a='&#x80 &notit;'>",
    collect_errors=true,
  )
  guard quoted.tokens[0] is @html_parser.HtmlToken::Tag(quoted_tag) else {
    fail("expected quoted attr tag")
  }
  guard quoted_tag.attrs["a"] is Some("\u{20AC} &notit;") else {
    fail("expected stricter attribute entity decoding")
  }
  assert_eq(quoted.errors.length(), 2)
  assert_eq(
    quoted.errors[0].code,
    "missing-semicolon-after-character-reference",
  )
  assert_eq(quoted.errors[1].code, "control-character-reference")
  guard quoted.errors[0].column is Some(23) else {
    fail("expected quoted attr errors at current tag cursor")
  }
  guard quoted.errors[1].column is Some(23) else {
    fail("expected quoted attr control error at current tag cursor")
  }
  let unquoted_numeric = @html_parser.tokenize(
    "<div a=&#65>",
    collect_errors=true,
  )
  guard unquoted_numeric.tokens[0]
    is @html_parser.HtmlToken::Tag(unquoted_numeric_tag) else {
    fail("expected unquoted numeric attr tag")
  }
  guard unquoted_numeric_tag.attrs["a"] is Some("A") else {
    fail("expected unquoted numeric attr")
  }
  assert_eq(unquoted_numeric.errors.length(), 1)
  assert_eq(
    unquoted_numeric.errors[0].code,
    "missing-semicolon-after-character-reference",
  )
  guard unquoted_numeric.errors[0].column is Some(12) else {
    fail("expected unquoted numeric attr error at tag close")
  }
  let unquoted_named = @html_parser.tokenize(
    "<div a=&notit>",
    collect_errors=true,
  )
  guard unquoted_named.tokens[0]
    is @html_parser.HtmlToken::Tag(unquoted_named_tag) else {
    fail("expected unquoted named attr tag")
  }
  guard unquoted_named_tag.attrs["a"] is Some("&notit") else {
    fail("expected blocked legacy prefix in attribute")
  }
  assert_eq(unquoted_named.errors.length(), 0)
  let parsed = @html_parser.parse_fragment(
    "<div a='&#x80 &notit;'></div>",
    collect_errors=true,
  )
  guard parsed.query_one("div") is Some(div) else {
    fail("expected parsed div")
  }
  guard div.attrs()["a"] is Some("\u{20AC} &notit;") else {
    fail("expected parsed attr value")
  }
  assert_eq(parsed.errors.length(), 2)
  assert_eq(
    parsed.errors[0].code,
    "missing-semicolon-after-character-reference",
  )
  assert_eq(parsed.errors[1].code, "control-character-reference")
  let legacy_named = @html_parser.tokenize(
    "<div a='&copycat; &copy= &copy &copy; &apos &apos;'>",
    collect_errors=true,
  )
  guard legacy_named.tokens[0] is @html_parser.HtmlToken::Tag(legacy_tag) else {
    fail("expected legacy named attr tag")
  }
  guard legacy_tag.attrs["a"]
    is Some("&copycat; &copy= \u{00A9} \u{00A9} &apos '") else {
    fail("expected legacy named attr blocking")
  }
  assert_eq(legacy_named.errors.length(), 1)
  assert_eq(
    legacy_named.errors[0].code,
    "missing-semicolon-after-character-reference",
  )
  let exact_named = @html_parser.tokenize(
    "<div a='&notin; &trade; &notin &trade'>x</div>",
    collect_errors=true,
  )
  guard exact_named.tokens[0] is @html_parser.HtmlToken::Tag(exact_tag) else {
    fail("expected exact named attr tag")
  }
  guard exact_tag.attrs["a"] is Some("\u{2209} \u{2122} &notin &trade") else {
    fail("expected exact named attr decoding")
  }
  assert_eq(exact_named.errors.length(), 0)
}

///|
test "attribute legacy entities block alphanumeric continuations" {
  let attr = @html_parser.parse_fragment(
    "<div a='&copycat &copy0 &copy= &copy.'>x</div>",
    collect_errors=true,
  )
  assert_eq(
    attr.to_html(pretty=false),
    "<div a=\"&amp;copycat &amp;copy0 &amp;copy= \u{00A9}.\">x</div>",
  )
  assert_eq(attr.errors.length(), 1)
  assert_eq(attr.errors[0].code, "missing-semicolon-after-character-reference")
  guard attr.errors[0].column is Some(39) else {
    fail("expected decoded attribute legacy entity error at tag close")
  }
  let text = @html_parser.parse_fragment(
    "&copycat &copy0 &copy= &copy.",
    collect_errors=true,
  )
  assert_eq(
    text.to_html(pretty=false),
    "\u{00A9}cat \u{00A9}0 \u{00A9}= \u{00A9}.",
  )
  assert_eq(text.errors.length(), 4)
  for error in text.errors {
    assert_eq(error.code, "missing-semicolon-after-character-reference")
  }
}

///|
test "special text entity decoding reports upstream fixture errors" {
  let title = @html_parser.tokenize(
    "<title>&#x80 &notit;</title>",
    collect_errors=true,
  )
  guard title.tokens[1] is @html_parser.HtmlToken::Characters("\u{20AC} ¬it;") else {
    fail("expected title RCDATA entities")
  }
  assert_eq(title.errors.length(), 3)
  assert_eq(title.errors[0].code, "missing-semicolon-after-character-reference")
  assert_eq(title.errors[1].code, "control-character-reference")
  assert_eq(title.errors[2].code, "missing-semicolon-after-character-reference")
  guard title.errors[0].column is Some(28) else {
    fail("expected title entity errors at closing tag")
  }
  guard title.errors[2].column is Some(28) else {
    fail("expected title legacy entity error at closing tag")
  }
  let textarea = @html_parser.tokenize(
    "<textarea>&#65</textarea>",
    collect_errors=true,
  )
  guard textarea.tokens[1] is @html_parser.HtmlToken::Characters("A") else {
    fail("expected textarea RCDATA entity")
  }
  assert_eq(textarea.errors.length(), 1)
  assert_eq(
    textarea.errors[0].code,
    "missing-semicolon-after-character-reference",
  )
  guard textarea.errors[0].column is Some(25) else {
    fail("expected textarea entity error at closing tag")
  }
  let script = @html_parser.tokenize(
    "<script>&#x80</script>",
    collect_errors=true,
  )
  guard script.tokens[1] is @html_parser.HtmlToken::Characters("&#x80") else {
    fail("expected script raw text to skip entity decoding")
  }
  assert_eq(script.errors.length(), 0)
  let parsed = @html_parser.parse_fragment(
    "<title>&#x80 &notit;</title>",
    collect_errors=true,
  )
  assert_eq(parsed.to_text(separator="", strip=false), "\u{20AC} ¬it;")
  assert_eq(parsed.errors.length(), 3)
  assert_eq(
    parsed.errors[0].code,
    "missing-semicolon-after-character-reference",
  )
  assert_eq(parsed.errors[1].code, "control-character-reference")
  assert_eq(
    parsed.errors[2].code,
    "missing-semicolon-after-character-reference",
  )
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
  let null_name = @html_parser.tokenize("</d\u{0000}iv>", collect_errors=true)
  guard null_name.tokens[0] is @html_parser.HtmlToken::Tag(null_tag) else {
    fail("expected null-containing end tag")
  }
  assert_true(null_tag.kind is @html_parser.TagKind::EndTag)
  assert_eq(null_tag.name, "d\u{FFFD}iv")
  assert_eq(null_name.errors.length(), 1)
  assert_eq(null_name.errors[0].code, "unexpected-null-character")
  let bad_solidus = @html_parser.tokenize("</div/ x>", collect_errors=true)
  guard bad_solidus.tokens[0] is @html_parser.HtmlToken::Tag(bad_tag) else {
    fail("expected recovered end tag after bad solidus")
  }
  assert_true(bad_tag.kind is @html_parser.TagKind::EndTag)
  assert_eq(bad_tag.name, "div")
  assert_eq(bad_tag.self_closing, false)
  guard bad_tag.attrs["x"] is Some("") else {
    fail("expected recovered attr after bad end-tag solidus")
  }
  assert_eq(bad_solidus.errors.length(), 1)
  assert_eq(
    bad_solidus.errors[0].code,
    "unexpected-character-after-solidus-in-tag",
  )
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
test "tokenize matches rawtext and rcdata end tags before bad solidus" {
  let title = @html_parser.tokenize(
    "<title>a</title/foo><p>b",
    collect_errors=true,
  )
  guard title.tokens[1] is @html_parser.HtmlToken::Characters("a") else {
    fail("expected title text before slash end tag")
  }
  guard title.tokens[2] is @html_parser.HtmlToken::Tag(end_title) else {
    fail("expected title end tag before slash attribute")
  }
  assert_true(end_title.kind is @html_parser.TagKind::EndTag)
  assert_eq(end_title.name, "title")
  guard end_title.attrs["foo"] is Some("") else {
    fail("expected recovered foo attribute on title end tag")
  }
  assert_eq(title.errors.length(), 1)
  assert_eq(title.errors[0].code, "unexpected-character-after-solidus-in-tag")
  guard title.errors[0].column is Some(17) else {
    fail("expected title solidus recovery at column 17")
  }
  let script = @html_parser.tokenize(
    "<script>a</script/foo><p>b",
    collect_errors=true,
  )
  guard script.tokens[1] is @html_parser.HtmlToken::Characters("a") else {
    fail("expected script text before slash end tag")
  }
  guard script.tokens[2] is @html_parser.HtmlToken::Tag(end_script) else {
    fail("expected script end tag before slash attribute")
  }
  assert_true(end_script.kind is @html_parser.TagKind::EndTag)
  assert_eq(end_script.name, "script")
  guard end_script.attrs["foo"] is Some("") else {
    fail("expected recovered foo attribute on script end tag")
  }
  assert_eq(script.errors.length(), 1)
  assert_eq(script.errors[0].code, "unexpected-character-after-solidus-in-tag")
  guard script.errors[0].column is Some(19) else {
    fail("expected script solidus recovery at column 19")
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
  let question_crlf = @html_parser.tokenize("<?a\r\nb>", collect_errors=true)
  guard question_crlf.tokens[0] is CommentToken("?a\nb") else {
    fail("expected CRLF-normalized question-mark bogus comment")
  }
  assert_eq(question_crlf.errors.length(), 1)
  assert_eq(
    question_crlf.errors[0].code,
    "unexpected-question-mark-instead-of-tag-name",
  )
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
  let invalid_entity = @html_parser.tokenize("<&notit", collect_errors=true)
  guard invalid_entity.tokens[0] is @html_parser.HtmlToken::Characters("<¬it") else {
    fail("expected invalid tag-open entity recovery")
  }
  assert_eq(invalid_entity.errors.length(), 2)
  assert_eq(
    invalid_entity.errors[0].code,
    "invalid-first-character-of-tag-name",
  )
  assert_eq(
    invalid_entity.errors[1].code,
    "missing-semicolon-after-character-reference",
  )
  let xml_question = @html_parser.tokenize(
    "<?a--b>",
    collect_errors=true,
    xml_coercion=true,
  )
  guard xml_question.tokens[0] is @html_parser.HtmlToken::CommentToken("?a- -b") else {
    fail("expected XML-coerced bogus comment")
  }
  assert_eq(xml_question.errors.length(), 1)
  assert_eq(
    xml_question.errors[0].code,
    "unexpected-question-mark-instead-of-tag-name",
  )
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
  let unfinished_single = @html_parser.tokenize(
    "<div foo='",
    collect_errors=true,
  )
  assert_eq(unfinished_single.tokens.length(), 1)
  guard unfinished_single.tokens[0] is Eof else {
    fail("expected only EOF token for incomplete single-quoted tag")
  }
  assert_eq(unfinished_single.errors.length(), 1)
  assert_eq(unfinished_single.errors[0].code, "eof-in-tag")
  guard unfinished_single.errors[0].column is Some(10) else {
    fail("expected incomplete single-quoted tag EOF at final quote")
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
  let nul_single_attr = @html_parser.tokenize(
    "<div foo='a\u{0000}b'>",
    collect_errors=true,
  )
  guard nul_single_attr.tokens[0] is Tag(single_tag) else {
    fail("expected div tag with single-quoted null attr")
  }
  guard single_tag.attrs["foo"] is Some("a\u{FFFD}b") else {
    fail("expected replacement char in single-quoted attr")
  }
  assert_eq(nul_single_attr.errors.length(), 1)
  assert_eq(nul_single_attr.errors[0].code, "unexpected-null-character")
  guard nul_single_attr.errors[0].column is Some(12) else {
    fail("expected single-quoted null attr at column 12")
  }
  let nul_unquoted_attr = @html_parser.tokenize(
    "<div foo=a\u{0000}b>",
    collect_errors=true,
  )
  guard nul_unquoted_attr.tokens[0] is @html_parser.HtmlToken::Tag(unquoted_tag) else {
    fail("expected div tag with unquoted null attr")
  }
  guard unquoted_tag.attrs["foo"] is Some("a\u{FFFD}b") else {
    fail("expected replacement char in unquoted attr")
  }
  assert_eq(nul_unquoted_attr.errors.length(), 1)
  assert_eq(nul_unquoted_attr.errors[0].code, "unexpected-null-character")
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
test "tokenize matches upstream script escaped null EOF fixture" {
  let result = @html_parser.tokenize(
    "<script><!---\u{0000}",
    collect_errors=true,
  )
  guard result.tokens[0] is Tag(start) else {
    fail("expected script start tag")
  }
  assert_eq(start.name, "script")
  guard result.tokens[1] is Characters("<!---\u{FFFD}") else {
    fail("expected escaped script text with replacement character")
  }
  guard result.tokens[2] is Eof else {
    fail("expected EOF after unclosed script text")
  }
  assert_eq(result.errors.length(), 1)
  assert_eq(result.errors[0].code, "unexpected-null-character")
  guard result.errors[0].column is Some(14) else {
    fail("expected script escaped null at column 14")
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
  let numeric = @html_parser.parse_fragment(
    "<p title=&#x80>x</p>",
    collect_errors=true,
  )
  assert_eq(numeric.to_html(pretty=false), "<p title=\"\u{20AC}\">x</p>")
  assert_eq(numeric.errors.length(), 2)
  assert_eq(
    numeric.errors[0].code,
    "missing-semicolon-after-character-reference",
  )
  assert_eq(numeric.errors[1].code, "control-character-reference")
  assert_eq(numeric.errors[0].category, "tokenizer")
  assert_eq(numeric.errors[1].category, "tokenizer")
  guard numeric.errors[0].column is Some(15) else {
    fail("expected unquoted attr entity error at tag close")
  }
  guard numeric.errors[1].column is Some(15) else {
    fail("expected unquoted attr control error at tag close")
  }
  guard numeric.query_one("p") is Some(paragraph) else {
    fail("expected parsed paragraph")
  }
  guard paragraph.attrs()["title"] is Some("\u{20AC}") else {
    fail("expected decoded unquoted attribute value")
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
test "tokenize matches upstream CR and LF normalization fixtures" {
  let bom = @html_parser.tokenize("\u{FEFF}<div>", collect_errors=true)
  guard bom.tokens[0] is Tag(bom_tag) else {
    fail("expected BOM-stripped div start tag")
  }
  assert_eq(bom_tag.name, "div")
  assert_eq(bom.errors.length(), 0)
  let cr_text = @html_parser.tokenize("abc\rdef", collect_errors=true)
  guard cr_text.tokens[0] is Characters("abc\ndef") else {
    fail("expected CR in text to normalize to LF")
  }
  assert_eq(cr_text.errors.length(), 0)
  let crlf_text = @html_parser.tokenize("\r\n", collect_errors=true)
  guard crlf_text.tokens[0] is Characters("\n") else {
    fail("expected CRLF in text to collapse to one LF")
  }
  assert_eq(crlf_text.errors.length(), 0)
  let cr_after_name = @html_parser.tokenize("<div\r>", collect_errors=true)
  guard cr_after_name.tokens[0] is Tag(cr_after_name_tag) else {
    fail("expected CR after tag name to close div")
  }
  assert_eq(cr_after_name_tag.name, "div")
  assert_eq(cr_after_name_tag.attrs.length(), 0)
  assert_eq(cr_after_name.errors.length(), 0)
  let crlf_before_attr = @html_parser.tokenize(
    "<div\r\nattr>",
    collect_errors=true,
  )
  guard crlf_before_attr.tokens[0] is Tag(crlf_before_attr_tag) else {
    fail("expected CRLF before attribute name")
  }
  guard crlf_before_attr_tag.attrs["attr"] is Some("") else {
    fail("expected empty attr after CRLF")
  }
  assert_eq(crlf_before_attr.errors.length(), 0)
  let cr_after_attr = @html_parser.tokenize("<div attr\r>", collect_errors=true)
  guard cr_after_attr.tokens[0] is Tag(cr_after_attr_tag) else {
    fail("expected CR after attribute name")
  }
  guard cr_after_attr_tag.attrs["attr"] is Some("") else {
    fail("expected empty attr after CR")
  }
  assert_eq(cr_after_attr.errors.length(), 0)
  let cr_space_after_attr = @html_parser.tokenize(
    "<div attr\r >",
    collect_errors=true,
  )
  guard cr_space_after_attr.tokens[0] is Tag(cr_space_after_attr_tag) else {
    fail("expected CR space after attribute name")
  }
  guard cr_space_after_attr_tag.attrs["attr"] is Some("") else {
    fail("expected empty attr after CR space")
  }
  assert_eq(cr_space_after_attr.errors.length(), 0)
  let crlf_after_attr = @html_parser.tokenize(
    "<div attr\r\n>",
    collect_errors=true,
  )
  guard crlf_after_attr.tokens[0] is Tag(crlf_after_attr_tag) else {
    fail("expected CRLF after attribute name")
  }
  guard crlf_after_attr_tag.attrs["attr"] is Some("") else {
    fail("expected empty attr after CRLF")
  }
  assert_eq(crlf_after_attr.errors.length(), 0)
  let cr_tab_after_attr = @html_parser.tokenize(
    "<div attr\r\t>",
    collect_errors=true,
  )
  guard cr_tab_after_attr.tokens[0] is Tag(cr_tab_after_attr_tag) else {
    fail("expected CR tab after attribute name")
  }
  guard cr_tab_after_attr_tag.attrs["attr"] is Some("") else {
    fail("expected empty attr after CR tab")
  }
  assert_eq(cr_tab_after_attr.errors.length(), 0)
  let double_attr = @html_parser.tokenize(
    "<div attr=\"a\rb\">",
    collect_errors=true,
  )
  guard double_attr.tokens[0] is Tag(double_attr_tag) else {
    fail("expected double-quoted attr with CR")
  }
  guard double_attr_tag.attrs["attr"] is Some("a\nb") else {
    fail("expected normalized CR in double-quoted attr")
  }
  assert_eq(double_attr.errors.length(), 0)
  let single_attr = @html_parser.tokenize(
    "<div attr='a\rb'>",
    collect_errors=true,
  )
  guard single_attr.tokens[0] is Tag(single_attr_tag) else {
    fail("expected single-quoted attr with CR")
  }
  guard single_attr_tag.attrs["attr"] is Some("a\nb") else {
    fail("expected normalized CR in single-quoted attr")
  }
  assert_eq(single_attr.errors.length(), 0)
  let unquoted = @html_parser.tokenize("<div attr=abc>", collect_errors=true)
  guard unquoted.tokens[0] is Tag(unquoted_tag) else {
    fail("expected unquoted attr")
  }
  guard unquoted_tag.attrs["attr"] is Some("abc") else {
    fail("expected unquoted attr value")
  }
  assert_eq(unquoted.errors.length(), 0)
  let lf_after_name = @html_parser.tokenize("<div\n>", collect_errors=true)
  guard lf_after_name.tokens[0] is Tag(lf_after_name_tag) else {
    fail("expected LF after tag name")
  }
  assert_eq(lf_after_name_tag.name, "div")
  assert_eq(lf_after_name_tag.attrs.length(), 0)
  assert_eq(lf_after_name.errors.length(), 0)
  let lf_after_attr = @html_parser.tokenize("<div attr\n>", collect_errors=true)
  guard lf_after_attr.tokens[0] is Tag(lf_after_attr_tag) else {
    fail("expected LF after attribute name")
  }
  guard lf_after_attr_tag.attrs["attr"] is Some("") else {
    fail("expected empty attr after LF")
  }
  assert_eq(lf_after_attr.errors.length(), 0)
  let double_lf_attr = @html_parser.tokenize(
    "<div attr=\"a\nb\">",
    collect_errors=true,
  )
  guard double_lf_attr.tokens[0] is Tag(double_lf_attr_tag) else {
    fail("expected double-quoted attr with LF")
  }
  guard double_lf_attr_tag.attrs["attr"] is Some("a\nb") else {
    fail("expected LF in double-quoted attr")
  }
  assert_eq(double_lf_attr.errors.length(), 0)
  let single_lf_attr = @html_parser.tokenize(
    "<div attr='a\nb'>",
    collect_errors=true,
  )
  guard single_lf_attr.tokens[0] is Tag(single_lf_attr_tag) else {
    fail("expected single-quoted attr with LF")
  }
  guard single_lf_attr_tag.attrs["attr"] is Some("a\nb") else {
    fail("expected LF in single-quoted attr")
  }
  assert_eq(single_lf_attr.errors.length(), 0)
  let crlf_space_attr = @html_parser.tokenize(
    "<div \r\n attr>",
    collect_errors=true,
  )
  guard crlf_space_attr.tokens[0] is Tag(crlf_space_attr_tag) else {
    fail("expected CRLF space before attr")
  }
  guard crlf_space_attr_tag.attrs["attr"] is Some("") else {
    fail("expected empty attr after CRLF space")
  }
  assert_eq(crlf_space_attr.errors.length(), 0)
  let comment = @html_parser.tokenize(
    "<!-- test\rcomment -->",
    collect_errors=true,
  )
  guard comment.tokens[0] is CommentToken(" test\ncomment ") else {
    fail("expected CR in comment to normalize to LF")
  }
  assert_eq(comment.errors.length(), 0)
}

///|
test "tokenize handles comment dash EOF and null edge cases" {
  let crlf_eof = @html_parser.tokenize("<!----!\r\n", collect_errors=true)
  guard crlf_eof.tokens[0] is @html_parser.HtmlToken::CommentToken("--!\n") else {
    fail("expected CRLF EOF comment data")
  }
  assert_eq(crlf_eof.errors.length(), 1)
  assert_eq(crlf_eof.errors[0].code, "eof-in-comment")
  guard crlf_eof.errors[0].line is Some(2) else {
    fail("expected EOF comment error on line 2")
  }
  guard crlf_eof.errors[0].column is Some(0) else {
    fail("expected EOF comment error at column 0")
  }
  let parsed_crlf_eof = @html_parser.parse("<!----!\r\n", collect_errors=true)
  assert_eq(parsed_crlf_eof.errors.length(), 2)
  assert_eq(parsed_crlf_eof.errors[0].code, "eof-in-comment")
  assert_eq(parsed_crlf_eof.errors[1].code, "expected-doctype-but-got-eof")
  guard parsed_crlf_eof.errors[0].column is Some(0) else {
    fail("expected parser comment EOF error at column 0")
  }
  guard parsed_crlf_eof.errors[1].column is Some(0) else {
    fail("expected parser doctype EOF error at column 0")
  }
  let bang_null = @html_parser.tokenize(
    "<!--x--!\u{0000}-->",
    collect_errors=true,
  )
  guard bang_null.tokens[0] is @html_parser.HtmlToken::CommentToken("x--!�") else {
    fail("expected replacement after --! null")
  }
  assert_eq(bang_null.errors.length(), 1)
  assert_eq(bang_null.errors[0].code, "unexpected-null-character")
  guard bang_null.errors[0].column is Some(9) else {
    fail("expected --! null error at column 9")
  }
  let incorrectly_closed = @html_parser.tokenize(
    "<!--x---a-->",
    collect_errors=true,
  )
  guard incorrectly_closed.tokens[0]
    is @html_parser.HtmlToken::CommentToken("x---a") else {
    fail("expected incorrectly closed dash run data")
  }
  assert_eq(incorrectly_closed.errors.length(), 1)
  assert_eq(incorrectly_closed.errors[0].code, "incorrectly-closed-comment")
  guard incorrectly_closed.errors[0].column is Some(9) else {
    fail("expected incorrect close error at column 9")
  }
  let dash_null = @html_parser.tokenize("<!--x--\u{0000}>", collect_errors=true)
  guard dash_null.tokens[0] is @html_parser.HtmlToken::CommentToken("x--�>") else {
    fail("expected replacement after -- null")
  }
  assert_eq(dash_null.errors.length(), 2)
  assert_eq(dash_null.errors[0].code, "unexpected-null-character")
  assert_eq(dash_null.errors[1].code, "eof-in-comment")
}

///|
test "tokenize handles comment EOF branch variants" {
  let empty = @html_parser.tokenize("<!--", collect_errors=true)
  guard empty.tokens[0] is @html_parser.HtmlToken::CommentToken("") else {
    fail("expected empty EOF comment")
  }
  assert_eq(empty.errors.length(), 1)
  assert_eq(empty.errors[0].code, "eof-in-comment")
  guard empty.errors[0].column is Some(4) else {
    fail("expected empty comment EOF at column 4")
  }
  let bang_eof = @html_parser.tokenize("<!--x--!", collect_errors=true)
  guard bang_eof.tokens[0] is @html_parser.HtmlToken::CommentToken("x") else {
    fail("expected --! EOF comment data")
  }
  assert_eq(bang_eof.errors.length(), 1)
  assert_eq(bang_eof.errors[0].code, "eof-in-comment")
  guard bang_eof.errors[0].column is Some(8) else {
    fail("expected --! EOF at column 8")
  }
  let dash_eof = @html_parser.tokenize("<!--x--", collect_errors=true)
  guard dash_eof.tokens[0] is @html_parser.HtmlToken::CommentToken("x") else {
    fail("expected -- EOF comment data")
  }
  assert_eq(dash_eof.errors.length(), 1)
  assert_eq(dash_eof.errors[0].code, "eof-in-comment")
  guard dash_eof.errors[0].column is Some(7) else {
    fail("expected -- EOF at column 7")
  }
  let null_eof = @html_parser.tokenize("<!--x\u{0000}", collect_errors=true)
  guard null_eof.tokens[0] is @html_parser.HtmlToken::CommentToken("x�") else {
    fail("expected null EOF comment data")
  }
  assert_eq(null_eof.errors.length(), 2)
  assert_eq(null_eof.errors[0].code, "unexpected-null-character")
  assert_eq(null_eof.errors[1].code, "eof-in-comment")
  guard null_eof.errors[0].column is Some(6) else {
    fail("expected comment null at column 6")
  }
  guard null_eof.errors[1].column is Some(6) else {
    fail("expected null EOF at column 6")
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
  let unquoted_attr = @html_parser.parse_fragment(
    "<div title=a\u{0000}b>x</div>",
    collect_errors=true,
  )
  assert_eq(unquoted_attr.to_html(pretty=false), "<div title=\"a�b\">x</div>")
  assert_eq(unquoted_attr.errors.length(), 1)
  assert_eq(unquoted_attr.errors[0].code, "unexpected-null-character")
  let attr_name = @html_parser.parse_fragment(
    "<div a\u{0000}b='c'>x</div>",
    collect_errors=true,
  )
  let attr_name_children = attr_name.root.children()
  assert_eq(attr_name_children.length(), 1)
  assert_eq(attr_name_children[0].name(), "div")
  guard attr_name_children[0].attrs()["a\u{FFFD}b"] is Some("c") else {
    fail("expected parser replacement char in attr name")
  }
  assert_eq(attr_name.to_text(separator="", strip=false), "x")
  assert_eq(attr_name.errors.length(), 1)
  assert_eq(attr_name.errors[0].code, "unexpected-null-character")
  let tag_name = @html_parser.parse_fragment(
    "<a\u{0000}b id=x>y</a\u{0000}b>",
    collect_errors=true,
  )
  let tag_name_children = tag_name.root.children()
  assert_eq(tag_name_children.length(), 1)
  assert_eq(tag_name_children[0].name(), "a\u{FFFD}b")
  guard tag_name_children[0].attrs()["id"] is Some("x") else {
    fail("expected attr on null-mutated start tag")
  }
  assert_eq(tag_name_children[0].text(), "y")
  assert_eq(tag_name.to_text(separator="", strip=false), "y")
  assert_eq(tag_name.errors.length(), 2)
  assert_eq(tag_name.errors[0].code, "unexpected-null-character")
  assert_eq(tag_name.errors[1].code, "unexpected-null-character")
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
test "parser and tokenizer report noncharacters in input stream" {
  let tokens = @html_parser.tokenize("ab\u{FDD0}cd", collect_errors=true)
  guard tokens.tokens[0] is @html_parser.HtmlToken::Characters("ab\u{FDD0}cd") else {
    fail("expected noncharacter to stay in character token")
  }
  assert_eq(tokens.errors.length(), 1)
  assert_eq(tokens.errors[0].code, "noncharacter-in-input-stream")
  guard tokens.errors[0].column is Some(3) else {
    fail("expected data-state noncharacter at column 3")
  }
  let multiline = @html_parser.tokenize("a\nb\u{FDD0}c", collect_errors=true)
  assert_eq(multiline.errors.length(), 1)
  assert_eq(multiline.errors[0].code, "noncharacter-in-input-stream")
  guard multiline.errors[0].line is Some(2) else {
    fail("expected multiline noncharacter on line 2")
  }
  guard multiline.errors[0].column is Some(2) else {
    fail("expected multiline noncharacter at column 2")
  }
  let invalid_open = @html_parser.tokenize("<\u{FDD0}", collect_errors=true)
  guard invalid_open.tokens[0]
    is @html_parser.HtmlToken::Characters("<\u{FDD0}") else {
    fail("expected invalid tag open as text")
  }
  assert_eq(invalid_open.errors.length(), 3)
  assert_eq(invalid_open.errors[0].code, "noncharacter-in-input-stream")
  assert_eq(invalid_open.errors[1].code, "invalid-first-character-of-tag-name")
  assert_eq(invalid_open.errors[2].code, "noncharacter-in-input-stream")
  let invalid_xml = @html_parser.tokenize(
    "<\u{000C}\u{FDD0}&lt;",
    collect_errors=true,
    xml_coercion=true,
  )
  guard invalid_xml.tokens[0] is @html_parser.HtmlToken::Characters("< �<") else {
    fail("expected invalid tag-open text to decode and XML-coerce")
  }
  assert_eq(invalid_xml.errors.length(), 2)
  assert_eq(invalid_xml.errors[0].code, "invalid-first-character-of-tag-name")
  assert_eq(invalid_xml.errors[1].code, "noncharacter-in-input-stream")
  let invalid_null = @html_parser.tokenize("<\u{0000}", collect_errors=true)
  guard invalid_null.tokens[0]
    is @html_parser.HtmlToken::Characters("<\u{0000}") else {
    fail("expected invalid tag-open null text")
  }
  assert_eq(invalid_null.errors.length(), 2)
  assert_eq(invalid_null.errors[0].code, "invalid-first-character-of-tag-name")
  assert_eq(invalid_null.errors[1].code, "unexpected-null-character")
  let fragment = @html_parser.parse_fragment(
    "ab\u{FDD0}cd",
    collect_errors=true,
  )
  assert_eq(fragment.to_html(pretty=false), "ab\u{FDD0}cd")
  assert_eq(fragment.errors.length(), 1)
  assert_eq(fragment.errors[0].code, "noncharacter-in-input-stream")
  let invalid_fragment = @html_parser.parse_fragment(
    "<\u{FDD0}",
    collect_errors=true,
  )
  assert_eq(invalid_fragment.to_html(pretty=false), "&lt;\u{FDD0}")
  assert_eq(invalid_fragment.errors.length(), 3)
  assert_eq(invalid_fragment.errors[0].code, "noncharacter-in-input-stream")
  assert_eq(
    invalid_fragment.errors[1].code,
    "invalid-first-character-of-tag-name",
  )
  assert_eq(invalid_fragment.errors[2].code, "noncharacter-in-input-stream")
  let invalid_entity = @html_parser.parse_fragment(
    "<&notit",
    collect_errors=true,
  )
  assert_eq(invalid_entity.to_html(pretty=false), "&lt;¬it")
  assert_eq(invalid_entity.errors.length(), 2)
  assert_eq(
    invalid_entity.errors[0].code,
    "invalid-first-character-of-tag-name",
  )
  assert_eq(
    invalid_entity.errors[1].code,
    "missing-semicolon-after-character-reference",
  )
  let invalid_xml = @html_parser.parse_fragment(
    "<\u{000C}\u{FDD0}&lt;",
    collect_errors=true,
    xml_coercion=true,
  )
  assert_eq(invalid_xml.to_html(pretty=false), "&lt; �&lt;")
  assert_eq(invalid_xml.errors.length(), 2)
  assert_eq(invalid_xml.errors[0].code, "invalid-first-character-of-tag-name")
  assert_eq(invalid_xml.errors[1].code, "noncharacter-in-input-stream")
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
  let dash_dash_less_than = @html_parser.parse_fragment(
    "<script><!----<x</script>",
  )
  assert_eq(
    dash_dash_less_than.to_html(pretty=false),
    "<script><!----<<x</script>",
  )
  let double_escaped_dash = @html_parser.parse_fragment(
    "<script><!--<script>---x</script>tail</script>",
  )
  assert_eq(
    double_escaped_dash.to_html(pretty=false),
    "<script><!--<script>---x&lt;/script>tail</script>",
  )
  let non_script_double_escape_end = @html_parser.parse_fragment(
    "<script><!--<script></style x</script>tail</script>",
  )
  assert_eq(
    non_script_double_escape_end.to_html(pretty=false),
    "<script><!--<script></style x&lt;/script>tail</script>",
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
fn assert_script_fragment_eof(
  source : StringView,
  expected_html : String,
  expected_column : Int,
) -> Unit raise {
  let doc = @html_parser.parse_fragment(source, collect_errors=true)
  assert_eq(doc.to_html(pretty=false), expected_html)
  assert_eq(doc.errors.length(), 1)
  assert_eq(doc.errors[0].code, "expected-named-closing-tag-but-got-eof")
  guard doc.errors[0].line is Some(line) else {
    fail("expected script EOF line")
  }
  assert_eq(line, 1)
  guard doc.errors[0].column is Some(column) else {
    fail("expected script EOF column")
  }
  assert_eq(column, expected_column)
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
  assert_script_fragment_eof("<script><!--", "<script><!--</script>", 12)
  assert_script_fragment_eof("<script><!---", "<script><!---</script>", 13)
  assert_script_fragment_eof("<script><!--a--", "<script><!--a--</script>", 15)
  assert_script_fragment_eof(
    "<script><!--<script>x", "<script><!--<script>x</script>", 21,
  )
  assert_script_fragment_eof(
    "<script><!--<script>--", "<script><!--<script>--</script>", 22,
  )
  assert_script_fragment_eof(
    "<script><!--<script>--<", "<script><!--<script>--<</script>", 23,
  )
}

///|
test "parser matches malformed special text end tags after solidus" {
  let title = @html_parser.parse(
    "<title>a</title/foo><p>b",
    collect_errors=true,
  )
  assert_eq(
    title.to_html(pretty=false),
    "<html><head><title>a</title></head><body><p>b</p></body></html>",
  )
  assert_eq(title.errors.length(), 2)
  assert_eq(title.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(title.errors[1].code, "unexpected-character-after-solidus-in-tag")
  guard title.errors[1].column is Some(17) else {
    fail("expected title solidus recovery at column 17")
  }
  let title_attr = @html_parser.parse(
    "<title>a</title foo><p>b",
    collect_errors=true,
  )
  assert_eq(
    title_attr.to_html(pretty=false),
    "<html><head><title>a</title></head><body><p>b</p></body></html>",
  )
  assert_eq(title_attr.errors.length(), 1)
  assert_eq(title_attr.errors[0].code, "expected-doctype-but-got-start-tag")
  let title_self_closing = @html_parser.parse(
    "<title>a</title/><p>b",
    collect_errors=true,
  )
  assert_eq(
    title_self_closing.to_html(pretty=false),
    "<html><head><title>a</title></head><body><p>b</p></body></html>",
  )
  assert_eq(title_self_closing.errors.length(), 1)
  assert_eq(
    title_self_closing.errors[0].code,
    "expected-doctype-but-got-start-tag",
  )
  let title_eof = @html_parser.parse("<title>a</title/foo", collect_errors=true)
  assert_eq(
    title_eof.to_html(pretty=false),
    "<html><head><title>a</title></head><body></body></html>",
  )
  assert_eq(title_eof.errors.length(), 4)
  assert_eq(title_eof.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(
    title_eof.errors[1].code,
    "unexpected-character-after-solidus-in-tag",
  )
  assert_eq(title_eof.errors[2].code, "eof-in-tag")
  assert_eq(title_eof.errors[3].code, "expected-named-closing-tag-but-got-eof")
  guard title_eof.errors[2].column is Some(19) else {
    fail("expected title EOF-in-tag at column 19")
  }
  guard title_eof.errors[3].column is Some(19) else {
    fail("expected title tree-builder EOF at column 19")
  }
  let textarea = @html_parser.parse(
    "<textarea>a</textarea/foo><p>b",
    collect_errors=true,
  )
  assert_eq(
    textarea.to_html(pretty=false),
    "<html><head></head><body><textarea>a</textarea><p>b</p></body></html>",
  )
  assert_eq(textarea.errors.length(), 2)
  assert_eq(textarea.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(
    textarea.errors[1].code,
    "unexpected-character-after-solidus-in-tag",
  )
  guard textarea.errors[1].column is Some(23) else {
    fail("expected textarea solidus recovery at column 23")
  }
  let style = @html_parser.parse(
    "<style>a</style/foo><p>b",
    collect_errors=true,
  )
  assert_eq(
    style.to_html(pretty=false),
    "<html><head><style>a</style></head><body><p>b</p></body></html>",
  )
  assert_eq(style.errors.length(), 2)
  assert_eq(style.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(style.errors[1].code, "unexpected-character-after-solidus-in-tag")
  guard style.errors[1].column is Some(17) else {
    fail("expected style solidus recovery at column 17")
  }
  let xmp = @html_parser.parse("<xmp>a</xmp/foo><p>b", collect_errors=true)
  assert_eq(
    xmp.to_html(pretty=false),
    "<html><head></head><body><xmp>a</xmp><p>b</p></body></html>",
  )
  assert_eq(xmp.errors.length(), 2)
  assert_eq(xmp.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(xmp.errors[1].code, "unexpected-character-after-solidus-in-tag")
  guard xmp.errors[1].column is Some(13) else {
    fail("expected xmp solidus recovery at column 13")
  }
  let script = @html_parser.parse(
    "<script>a</script/foo><p>b",
    collect_errors=true,
  )
  assert_eq(
    script.to_html(pretty=false),
    "<html><head><script>a</script></head><body><p>b</p></body></html>",
  )
  assert_eq(script.errors.length(), 2)
  assert_eq(script.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(script.errors[1].code, "unexpected-character-after-solidus-in-tag")
  guard script.errors[1].column is Some(19) else {
    fail("expected script solidus recovery at column 19")
  }
  let script_eof = @html_parser.parse(
    "<script>a</script/foo",
    collect_errors=true,
  )
  assert_eq(
    script_eof.to_html(pretty=false),
    "<html><head><script>a</script></head><body></body></html>",
  )
  assert_eq(script_eof.errors.length(), 4)
  assert_eq(script_eof.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(
    script_eof.errors[1].code,
    "unexpected-character-after-solidus-in-tag",
  )
  assert_eq(script_eof.errors[2].code, "eof-in-tag")
  assert_eq(script_eof.errors[3].code, "expected-named-closing-tag-but-got-eof")
  guard script_eof.errors[2].column is Some(21) else {
    fail("expected script EOF-in-tag at column 21")
  }
  guard script_eof.errors[3].column is Some(21) else {
    fail("expected script tree-builder EOF at column 21")
  }
}

///|
test "parser treats similarly named special end tags as text" {
  let title = @html_parser.parse(
    "<title>a</titlex></title><p>b",
    collect_errors=true,
  )
  assert_eq(
    title.to_html(pretty=false),
    "<html><head><title>a&lt;/titlex&gt;</title></head><body><p>b</p></body></html>",
  )
  assert_eq(title.errors.length(), 1)
  assert_eq(title.errors[0].code, "expected-doctype-but-got-start-tag")
  let textarea = @html_parser.parse(
    "<textarea>a</textareax></textarea><p>b",
    collect_errors=true,
  )
  assert_eq(
    textarea.to_html(pretty=false),
    "<html><head></head><body><textarea>a&lt;/textareax&gt;</textarea><p>b</p></body></html>",
  )
  assert_eq(textarea.errors.length(), 1)
  assert_eq(textarea.errors[0].code, "expected-doctype-but-got-start-tag")
  let xmp = @html_parser.parse("<xmp>a</xmpx></xmp><p>b", collect_errors=true)
  assert_eq(
    xmp.to_html(pretty=false),
    "<html><head></head><body><xmp>a&lt;/xmpx&gt;</xmp><p>b</p></body></html>",
  )
  assert_eq(xmp.errors.length(), 1)
  assert_eq(xmp.errors[0].code, "expected-doctype-but-got-start-tag")
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
test "parser handles disabled scripting noscript in head" {
  let doctype = @html_parser.parse(
    "<head><noscript><!DOCTYPE html></noscript>",
    collect_errors=true,
    scripting_enabled=false,
  )
  assert_eq(
    doctype.to_html(pretty=false),
    "<html><head><noscript></noscript></head><body></body></html>",
  )
  assert_eq(doctype.errors.length(), 2)
  assert_eq(doctype.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(doctype.errors[1].code, "unexpected-doctype")
  let stray_end = @html_parser.parse(
    "<head><noscript></p></noscript>",
    collect_errors=true,
    scripting_enabled=false,
  )
  assert_eq(
    stray_end.to_html(pretty=false),
    "<html><head><noscript></noscript></head><body></body></html>",
  )
  assert_eq(stray_end.errors.length(), 2)
  assert_eq(stray_end.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(stray_end.errors[1].code, "unexpected-end-tag")
  let stray_head = @html_parser.parse(
    "<head><noscript><head></noscript>",
    collect_errors=true,
    scripting_enabled=false,
  )
  assert_eq(
    stray_head.to_html(pretty=false),
    "<html><head><noscript></noscript></head><body></body></html>",
  )
  assert_eq(stray_head.errors.length(), 2)
  assert_eq(stray_head.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(stray_head.errors[1].code, "unexpected-start-tag")
  let stray_br = @html_parser.parse(
    "<head><noscript></br>x",
    collect_errors=true,
    scripting_enabled=false,
  )
  assert_eq(
    stray_br.to_html(pretty=false),
    "<html><head><noscript></noscript></head><body><br>x</body></html>",
  )
  assert_eq(stray_br.errors.length(), 3)
  assert_eq(stray_br.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(stray_br.errors[1].code, "unexpected-end-tag")
  assert_eq(stray_br.errors[2].code, "unexpected-end-tag")
  let paragraph = @html_parser.parse(
    "<head><noscript><p>x</noscript>",
    collect_errors=true,
    scripting_enabled=false,
  )
  assert_eq(
    paragraph.to_html(pretty=false),
    "<html><head><noscript></noscript></head><body><p>x</p></body></html>",
  )
  assert_eq(paragraph.errors.length(), 3)
  assert_eq(paragraph.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(paragraph.errors[1].code, "unexpected-start-tag")
  assert_eq(paragraph.errors[2].code, "unexpected-end-tag")
  let text = @html_parser.parse(
    "<head><noscript>x</noscript>",
    collect_errors=true,
    scripting_enabled=false,
  )
  assert_eq(
    text.to_html(pretty=false),
    "<html><head><noscript></noscript></head><body>x</body></html>",
  )
  assert_eq(text.errors.length(), 3)
  assert_eq(text.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(text.errors[1].code, "unexpected-start-tag")
  assert_eq(text.errors[2].code, "unexpected-end-tag")
  let leading_space = @html_parser.parse(
    "<head><noscript> x</noscript>",
    collect_errors=true,
    scripting_enabled=false,
  )
  assert_eq(
    leading_space.to_html(pretty=false),
    "<html><head><noscript></noscript> </head><body>x</body></html>",
  )
  assert_eq(leading_space.errors.length(), 3)
  assert_eq(leading_space.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(leading_space.errors[1].code, "unexpected-start-tag")
  assert_eq(leading_space.errors[2].code, "unexpected-end-tag")
  let coerced_leading_space = @html_parser.parse(
    "<head><noscript>\u{000C} x</noscript>",
    collect_errors=true,
    scripting_enabled=false,
    xml_coercion=true,
  )
  assert_eq(
    coerced_leading_space.to_html(pretty=false),
    "<html><head><noscript></noscript>  </head><body>x</body></html>",
  )
  assert_eq(coerced_leading_space.errors.length(), 3)
  assert_eq(
    coerced_leading_space.errors[0].code,
    "expected-doctype-but-got-start-tag",
  )
  assert_eq(coerced_leading_space.errors[1].code, "unexpected-start-tag")
  assert_eq(coerced_leading_space.errors[2].code, "unexpected-end-tag")
  let allowed = @html_parser.parse(
    "<head><noscript><link rel=x></noscript><p>y",
    collect_errors=true,
    scripting_enabled=false,
  )
  assert_eq(
    allowed.to_html(pretty=false),
    "<html><head><noscript><link rel=\"x\"></noscript></head><body><p>y</p></body></html>",
  )
  assert_eq(allowed.errors.length(), 1)
  assert_eq(allowed.errors[0].code, "expected-doctype-but-got-start-tag")
}

///|
test "parser ignores one initial newline in pre listing and textarea" {
  let pre = @html_parser.parse_fragment(
    "<pre>\r\nline</pre><listing>\nitem</listing>",
  )
  assert_eq(pre.to_html(pretty=false), "<pre>line</pre><listing>item</listing>")
  let pre_cr = @html_parser.parse_fragment("<pre>\rline</pre>")
  assert_eq(pre_cr.to_html(pretty=false), "<pre>line</pre>")
  let listing_cr = @html_parser.parse_fragment("<listing>\rline</listing>")
  assert_eq(listing_cr.to_html(pretty=false), "<listing>line</listing>")
  let textarea = @html_parser.parse_fragment("<textarea>\nline</textarea>")
  assert_eq(textarea.to_html(pretty=false), "<textarea>line</textarea>")
  let textarea_cr = @html_parser.parse_fragment("<textarea>\rline</textarea>")
  assert_eq(textarea_cr.to_html(pretty=false), "<textarea>line</textarea>")
  let textarea_crlf = @html_parser.parse_fragment(
    "<textarea>\r\nline</textarea>",
  )
  assert_eq(textarea_crlf.to_html(pretty=false), "<textarea>line</textarea>")
  let title = @html_parser.parse_fragment("<title>\nline</title>")
  assert_eq(title.to_html(pretty=false), "<title>\nline</title>")
  let title_cr = @html_parser.parse_fragment("<title>\rline</title>")
  assert_eq(title_cr.to_html(pretty=false), "<title>\nline</title>")
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
  let empty_title = @html_parser.tokenize("<title></title>")
  guard empty_title.tokens[1] is @html_parser.HtmlToken::Tag(empty_title_end) else {
    fail("expected immediate title end tag")
  }
  assert_true(empty_title_end.kind is @html_parser.TagKind::EndTag)
  let eof_title = @html_parser.tokenize("<title>")
  guard eof_title.tokens[1] is @html_parser.HtmlToken::Eof else {
    fail("expected EOF after empty unclosed title")
  }
  let empty_plaintext = @html_parser.tokenize("<plaintext>")
  guard empty_plaintext.tokens[1] is @html_parser.HtmlToken::Eof else {
    fail("expected EOF after empty plaintext")
  }
  let xml_title = @html_parser.tokenize(
    "<title>\u{000C}\u{FDD0}</title>",
    xml_coercion=true,
  )
  guard xml_title.tokens[1] is @html_parser.HtmlToken::Characters(" �") else {
    fail("expected XML coercion in RCDATA text")
  }
}

///|
test "tokenize keeps similarly named special end tags in text" {
  let title = @html_parser.tokenize("<title>a</titlex></title>")
  guard title.tokens[1] is @html_parser.HtmlToken::Characters("a</titlex>") else {
    fail("expected title suffix end tag to stay in text")
  }
  guard title.tokens[2] is @html_parser.HtmlToken::Tag(end_title) else {
    fail("expected final title end tag")
  }
  assert_true(end_title.kind is @html_parser.TagKind::EndTag)
  assert_eq(end_title.name, "title")
  let style = @html_parser.tokenize("<style>a</stylex></style>")
  guard style.tokens[1] is @html_parser.HtmlToken::Characters("a</stylex>") else {
    fail("expected style suffix end tag to stay in text")
  }
  guard style.tokens[2] is @html_parser.HtmlToken::Tag(end_style) else {
    fail("expected final style end tag")
  }
  assert_true(end_style.kind is @html_parser.TagKind::EndTag)
  assert_eq(end_style.name, "style")
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
