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
