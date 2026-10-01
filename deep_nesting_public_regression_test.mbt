///|
/// Nesting depth for these regressions. Tree walks used to recurse once per
/// level and overflowed the stack at around 2,000 levels on js and wasm-gc
/// (about 20,000 on native), so hostile input could crash even
/// `parse(..., sanitize=true)`.
let deep_levels : Int = 50000

///|
fn deep_markup(open : String, inner : String, close : String) -> String {
  open.repeat(deep_levels) + inner + close.repeat(deep_levels)
}

///|
test "deep nesting: parse and serialize compactly" {
  let doc = @html_parser.parse("<div>".repeat(deep_levels) + "hi").root
  let expected = "<html><head></head><body>" +
    deep_markup("<div>", "hi", "</div>") +
    "</body></html>"
  assert_eq(@html_parser.to_html(doc, pretty=false), expected)
  assert_eq(
    doc.clone_node(deep=true) |> @html_parser.to_html(pretty=false),
    expected,
  )
  let fragment = @html_parser.parse_fragment("<span>".repeat(deep_levels) + "x").root
  assert_eq(
    @html_parser.to_html(fragment, pretty=false),
    deep_markup("<span>", "x", "</span>"),
  )
}

///|
test "deep nesting: pretty print" {
  let doc = @html_parser.parse("<div>".repeat(deep_levels)).root
  // With no indentation the output stays linear in depth; each level is one
  // opening and one closing line around the innermost empty element.
  assert_eq(
    @html_parser.to_html(doc, indent_size=0),
    "<html>\n<head></head>\n<body>\n" +
    "<div>\n".repeat(deep_levels - 1) +
    "<div></div>" +
    "\n</div>".repeat(deep_levels - 1) +
    "\n</body>\n</html>",
  )
  // Nested inline elements collapse onto one line.
  let inline = @html_parser.parse_fragment("<b>".repeat(deep_levels) + "x").root
  assert_eq(@html_parser.to_html(inline), deep_markup("<b>", "x", "</b>"))
}

///|
test "deep nesting: pretty print is linear in its output" {
  // Indentation makes the output quadratic in depth, so this runs shallower.
  // Before the explicit-stack rewrite each level also copied its subtree's
  // output, making the work cubic in depth.
  let levels = 1500
  let doc = @html_parser.parse_fragment("<div>".repeat(levels)).root
  let expected = StringBuilder()
  for level in 0..<(levels - 1) {
    expected.write_string(" ".repeat(2 * level) + "<div>\n")
  }
  expected.write_string(" ".repeat(2 * (levels - 1)) + "<div></div>")
  for level = levels - 2; level >= 0; level = level - 1 {
    expected.write_string("\n" + " ".repeat(2 * level) + "</div>")
  }
  assert_eq(@html_parser.to_html(doc), expected.to_string())
  // The html5lib test format also indents every level.
  let dump = @html_parser.to_test_format(doc)
  assert_eq(dump.split("\n").count(), levels)
}

///|
test "deep nesting: text extraction" {
  let doc = @html_parser.parse(
      "<div><p>".repeat(deep_levels / 2) + " hello <br> world ",
    ).root
  assert_eq(@html_parser.to_text(doc), "hello world")
  assert_eq(doc.text(), " hello  world ")
  assert_eq(
    @html_parser.to_text(doc, separator="|", separator_blocks_only=true),
    "hello|world",
  )
}

///|
test "deep nesting: sanitize" {
  let hostile = "<div><font>".repeat(deep_levels / 2) +
    "<a href=\"javascript:alert(1)\" onclick=\"x()\">link</a>" +
    "<script>alert(2)</script>"
  let parsed = @html_parser.parse(hostile, sanitize=true)
  let expected = "<html><head></head><body>" +
    "<div>".repeat(deep_levels / 2) +
    "<a>link</a>" +
    "</div>".repeat(deep_levels / 2) +
    "</body></html>"
  assert_eq(@html_parser.to_html(parsed.root, pretty=false), expected)
  let raw = @html_parser.parse(hostile).root
  let clean = @html_parser.sanitize_dom(raw)
  assert_eq(@html_parser.to_html(clean, pretty=false), expected)
}

///|
test "deep nesting: markdown" {
  let doc = @html_parser.parse(
      "<div><span>".repeat(deep_levels / 2) + "<p>hello <em>world</em></p>",
    ).root
  assert_eq(@html_parser.to_markdown(doc), "hello *world*")
  assert_eq(
    @html_parser.to_markdown(doc, html_passthrough=true),
    "hello *world*",
  )
}

///|
test "deep nesting: query and matches" {
  let doc = @html_parser.parse(
      "<div>".repeat(deep_levels) + "<a href=\"#x\">x</a>",
    ).root
  assert_eq(@html_parser.query(doc, "div").length(), deep_levels)
  let links = @html_parser.query(doc, "body div > a[href]")
  assert_eq(links.length(), 1)
  guard @html_parser.query_one(doc, "div > a") is Some(link) else {
    fail("expected to find the link")
  }
  assert_true(@html_parser.matches(link, "html body div a"))
  assert_true(@html_parser.matches(link, "div:not(p) > a"))
}

///|
test "deep nesting: linkify and transforms" {
  let doc = @html_parser.parse(
      "<div><span>".repeat(deep_levels / 2) + " see www.example.com ",
    ).root
  let linked = @html_parser.to_html(@html_parser.linkify_dom(doc), pretty=false)
  assert_true(
    linked.contains("<a href=\"http://www.example.com\">www.example.com</a>"),
  )
  let transformed = @html_parser.apply_transforms(doc, [
    @html_parser.TransformSpec::unwrap("span"),
    @html_parser.TransformSpec::set_attrs("div", { "class": Some("x") }),
    @html_parser.TransformSpec::collapse_whitespace(),
    @html_parser.TransformSpec::prune_empty("p"),
    @html_parser.TransformSpec::sanitize(),
  ])
  let html = @html_parser.to_html(transformed, pretty=false)
  assert_eq(html.contains("<span>"), false)
  assert_true(html.has_prefix("<html><head></head><body><div class=\"x\">"))
}

///|
test "deep nesting: cli" {
  let input = @utf8.encode("<div>".repeat(deep_levels) + "hello")
  let result = @html_parser.run_cli_bytes(["--format", "text", "-"], input)
  assert_eq(result.exit_code, 0)
  assert_eq(result.stdout.trim(), "hello")
}
