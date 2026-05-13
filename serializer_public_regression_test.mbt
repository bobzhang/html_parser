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
