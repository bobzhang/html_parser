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
test "parser cursor advances by unicode character length" {
  let doc = @html_parser.parse_fragment("<p>😀 &lt; ok</p>")
  assert_eq(doc.to_html(pretty=false), "<p>😀 &lt; ok</p>")
  assert_eq(doc.to_text(separator="", strip=false), "😀 < ok")
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

///|
test "public parser source locations and scripting mode stay stable" {
  let located = @html_parser.parse_fragment(
    "lead\n<p id=x>Hi</p>",
    track_node_locations=true,
  )
  guard located.query_one("p") is Some(paragraph) else {
    fail("expected parsed paragraph")
  }
  guard paragraph.origin_offset() is Some(5) else {
    fail("expected paragraph origin offset")
  }
  guard paragraph.origin_line() is Some(2) else {
    fail("expected paragraph origin line")
  }
  guard paragraph.origin_col() is Some(1) else {
    fail("expected paragraph origin column")
  }
  let children = paragraph.children()
  assert_eq(children.length(), 1)
  guard children[0].origin_location() is Some((2, 9)) else {
    fail("expected text child origin location")
  }

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
test "parser reports noncharacters in input stream" {
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
