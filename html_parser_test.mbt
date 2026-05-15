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
