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
