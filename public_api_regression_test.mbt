///|
test "public parse query render workflow stays stable" {
  let doc = @html_parser.parse(
    "<!doctype html><title>T</title><main><article id=a><h1>Hi</h1><p>One <a href=/x>link</a></p></article></main>",
    track_node_locations=true,
  )
  assert_eq(doc.query("main article#a > p a[href]").length(), 1)
  assert_eq(
    @html_parser.query(doc.root, "main article#a > p a[href]").length(),
    1,
  )
  guard doc.query_one("article#a") is Some(article) else {
    fail("expected article")
  }
  guard @html_parser.query_one(doc.root, "article#a") is Some(function_article) else {
    fail("expected article from function query")
  }
  assert_eq(article.name(), "article")
  assert_eq(function_article.name(), "article")
  assert_eq(
    doc.to_html(pretty=false),
    "<!DOCTYPE html><html><head><title>T</title></head><body><main><article id=\"a\"><h1>Hi</h1><p>One <a href=\"/x\">link</a></p></article></main></body></html>",
  )
  assert_eq(
    doc.to_html(pretty=true, indent_size=2),
    "<!DOCTYPE html>\n<html>\n  <head>\n    <title>T</title>\n  </head>\n  <body>\n    <main>\n      <article id=\"a\">\n        <h1>Hi</h1>\n        <p>One <a href=\"/x\">link</a></p>\n      </article>\n    </main>\n  </body>\n</html>",
  )
  assert_eq(doc.to_text(separator="|", strip=true), "T|Hi|One|link")
  assert_eq(
    @html_parser.to_text(doc.root, separator="|", strip=true),
    "T|Hi|One|link",
  )
  assert_eq(doc.to_markdown(), "# Hi\n\nOne [link](/x)")
  assert_eq(@html_parser.to_markdown(doc.root), "# Hi\n\nOne [link](/x)")
}

///|
test "public sanitize and linkify transform workflow stays stable" {
  let doc = @html_parser.parse_fragment(
    "<p onclick=bad>Visit example.com</p><script>x</script>",
    sanitize=false,
  )
  let root = @html_parser.apply_transforms(doc.root, [
    @html_parser.TransformSpec::sanitize(),
    @html_parser.TransformSpec::linkify(),
  ])
  assert_eq(
    root.to_html(pretty=false),
    "<p>Visit <a href=\"http://example.com\">example.com</a></p>",
  )
  assert_eq(root.query("script").length(), 0)
  assert_eq(root.query("a[href]").length(), 1)
  assert_eq(root.to_text(separator=" ", strip=true), "Visit example.com")
}

///|
test "public bytes parse stream workflow stays stable" {
  let source = b"<meta charset=utf-8><p>\xe2\x82\xac &amp; tea</p>"
  let doc = @html_parser.parse_bytes(source)
  guard doc.encoding is Some("utf-8") else { fail("expected utf-8 encoding") }
  assert_eq(
    doc.to_html(pretty=false),
    "<html><head><meta charset=\"utf-8\"></head><body><p>€ &amp; tea</p></body></html>",
  )
  assert_eq(doc.to_text(separator="", strip=false), "€ & tea")
  assert_true(
    @html_parser.stream_bytes(source) ==
    [
      StreamStart({ name: "meta", attrs: { "charset": Some("utf-8") } }),
      StreamStart({ name: "p", attrs: {} }),
      StreamText("€ & tea"),
      StreamEnd("p"),
    ],
  )
}
