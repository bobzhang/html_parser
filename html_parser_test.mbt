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
test "sanitize_dom textarea markdown passthrough cannot break out" {
  let policy = @html_parser.SanitizationPolicy::new(
    ["textarea", "img"],
    allowed_attributes={ "*": [], "img": ["src", "alt"] },
    url_policy=@html_parser.UrlPolicy::new(allow_rules=[]),
    drop_content_tags=[],
  )
  let fragment = @html_parser.parse_fragment(
    "<textarea>&lt;/textarea&gt;&lt;img src=x onerror=alert(1)&gt;</textarea>",
    sanitize=false,
  )
  let clean = @html_parser.sanitize_dom(fragment.root, policy~)
  let markdown = clean.to_markdown(html_passthrough=true)
  assert_true(markdown.contains("&lt;/textarea&gt;"))
  let reparsed = @html_parser.parse_fragment(markdown, sanitize=false)
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
      assert_eq(message, "Unsafe tag 'set' (active foreign content)")
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
  assert_true(!sanitized.to_markdown(html_passthrough=true).contains("onerror"))
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
