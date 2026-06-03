///|
test "linkify_dom wraps fuzzy domains and emails in text nodes" {
  let doc = @html_parser.parse_fragment(
    "<p>See example.com and test@example.com</p>",
  )
  ignore(@html_parser.linkify_dom(doc.root))
  assert_eq(
    doc.root.to_html(pretty=false),
    "<p>See <a href=\"http://example.com\">example.com</a> and <a href=\"mailto:test@example.com\">test@example.com</a></p>",
  )
}

///|
test "linkify_dom skips anchors and preformatted tags by default" {
  let doc = @html_parser.parse_fragment(
    "<p><a href='/x'>example.com</a></p><pre>example.com</pre><p>example.com</p>",
  )
  ignore(@html_parser.linkify_dom(doc.root))
  assert_eq(
    doc.root.to_html(pretty=false),
    "<p><a href=\"/x\">example.com</a></p><pre>example.com</pre><p><a href=\"http://example.com\">example.com</a></p>",
  )
}

///|
test "linkify_dom handles ampersands and preserves trailing text" {
  let doc = @html_parser.parse_fragment(
    "<p>See http://a.co?b=1&amp;c=2 now</p>",
  )
  ignore(@html_parser.linkify_dom(doc.root))
  assert_eq(
    doc.root.to_html(pretty=false),
    "<p>See <a href=\"http://a.co?b=1&amp;c=2\">http://a.co?b=1&amp;c=2</a> now</p>",
  )
}

///|
test "linkify_dom runs inside template content" {
  let doc = @html_parser.parse_fragment("<template>example.com</template>")
  ignore(@html_parser.linkify_dom(doc.root))
  assert_eq(
    doc.root.to_html(pretty=false),
    "<template><a href=\"http://example.com\">example.com</a></template>",
  )
}

///|
test "linkify_dom supports config and custom skip tags" {
  let doc = @html_parser.parse_fragment(
    "<p>site.internal 192.168.0.1</p><span>example.com</span>",
  )
  ignore(
    @html_parser.linkify_dom(
      doc.root,
      config=LinkifyConfig(fuzzy_ip=true, extra_tlds=["internal"]),
      skip_tags=["span"],
    ),
  )
  assert_eq(
    doc.root.to_html(pretty=false),
    "<p><a href=\"http://site.internal\">site.internal</a> <a href=\"http://192.168.0.1\">192.168.0.1</a></p><span>example.com</span>",
  )
}

///|
test "linkify_dom supports config without custom skip tags" {
  let doc = @html_parser.parse_fragment("<p>site.internal</p>")
  ignore(
    @html_parser.linkify_dom(
      doc.root,
      config=@html_parser.LinkifyConfig::with_extra_tlds(["internal"]),
    ),
  )
  assert_eq(
    doc.root.to_html(pretty=false),
    "<p><a href=\"http://site.internal\">site.internal</a></p>",
  )
}

///|
test "linkify_dom supports custom skip tags without config" {
  let doc = @html_parser.parse_fragment(
    "<p>example.com</p><span>example.com</span>",
  )
  ignore(@html_parser.linkify_dom(doc.root, skip_tags=["span"]))
  assert_eq(
    doc.root.to_html(pretty=false),
    "<p><a href=\"http://example.com\">example.com</a></p><span>example.com</span>",
  )
}

///|
test "linkify_dom handles standalone text nodes and empty text nodes" {
  let linked = @html_parser.linkify_dom(@html_parser.text("Go example.com now"))
  assert_eq(
    linked.to_html(pretty=false),
    "Go <a href=\"http://example.com\">example.com</a> now",
  )
  let plain = @html_parser.linkify_dom(@html_parser.text("plain text"))
  assert_eq(plain.to_html(pretty=false), "plain text")
  let div = @html_parser.element("div", children=[@html_parser.text("")])
  ignore(@html_parser.linkify_dom(div))
  assert_eq(div.to_html(pretty=false), "<div></div>")
}

///|
test "linkify_dom keeps no-link text and exact text matches stable" {
  let no_link = @html_parser.element("p", children=[
    @html_parser.text("plain text"),
  ])
  ignore(@html_parser.linkify_dom(no_link))
  assert_eq(no_link.to_html(pretty=false), "<p>plain text</p>")
  let exact = @html_parser.element("p", children=[
    @html_parser.text("example.com"),
  ])
  ignore(@html_parser.linkify_dom(exact))
  assert_eq(
    exact.to_html(pretty=false),
    "<p><a href=\"http://example.com\">example.com</a></p>",
  )
}

///|
test "linkify_dom recurses through fragment children and leaves leaf nodes alone" {
  let nested = @html_parser.fragment(children=[
    @html_parser.fragment(children=[@html_parser.text("example.com")]),
  ])
  ignore(@html_parser.linkify_dom(nested))
  assert_eq(
    nested.to_html(pretty=false),
    "<a href=\"http://example.com\">example.com</a>",
  )
  let comment = @html_parser.linkify_dom(@html_parser.comment("example.com"))
  assert_eq(comment.to_html(pretty=false), "<!--example.com-->")
  let doctype = @html_parser.linkify_dom(@html_parser.doctype())
  assert_eq(doctype.to_html(pretty=false), "<!DOCTYPE html>")
}
