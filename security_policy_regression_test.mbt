///|
test "public default sanitizer security corpus stays stable" {
  let doc = @html_parser.parse_fragment(
    "<p onclick=bad style=\"color:red;background:url(javascript:bad)\">ok</p><!--x--><a href=javascript:bad rel=nofollow>bad</a><math><mtext><img src=x onerror=1></mtext></math><script>bad</script>",
    sanitize=true,
  )
  assert_eq(doc.to_html(pretty=false), "<p>ok</p><a>bad</a>")
  assert_eq(doc.to_text(separator="|", strip=true), "ok|bad")
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

  let collect_policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    allowed_attributes={ "p": ["title"] },
    unsafe_handling=Collect,
  )
  let attr_fragment = @html_parser.parse_fragment(
    "<p title='a\u{200B}b'>x</p>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(attr_fragment.root, policy=collect_policy).to_html(
      pretty=false,
    ),
    "<p title=\"ab\">x</p>",
  )
  let errors = collect_policy.collected_security_errors()
  assert_eq(errors.length(), 1)
  assert_eq(
    errors[0].message,
    "Stripped invisible Unicode from attribute(s): title",
  )

  let raise_policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    allowed_attributes={ "p": ["title"] },
    unsafe_handling=Raise,
  )
  let raise_fragment = @html_parser.parse_fragment(
    "<p title='a\u{200B}b'>x</p>",
    sanitize=false,
  )
  let result = try? @html_parser.sanitize_dom(
    raise_fragment.root,
    policy=raise_policy,
  )
  match result {
    Err(UnsafeHtml(message)) =>
      assert_eq(message, "Stripped invisible Unicode from attribute(s): title")
    _ => fail("expected invisible Unicode attribute stripping to raise")
  }
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
test "url filter debug representation stays opaque" {
  let url_filter = @html_parser.UrlFilter::new(fn(_tag, _attr, value) {
    Some(value)
  })
  let repr = url_filter.to_repr().to_string()
  assert_true(repr.contains("UrlFilter"))
  assert_eq(repr.contains("callback"), false)
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
    "<a ping=' https://trusted.example/a  https://trusted.example/b '>ok</a><a ping='   '>empty</a><a ping='\u{000C}'>form-feed</a><a ping='https://trusted.example/a https://evil.example/b'>bad-final</a><a ping='https://evil.example/b https://trusted.example/a'>bad-first</a><img attributionsrc=' https://trusted.example/i  https://trusted.example/j '>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<a ping=\"https://trusted.example/a https://trusted.example/b\">ok</a><a>empty</a><a>form-feed</a><a>bad-final</a><a>bad-first</a><img attributionsrc=\"https://trusted.example/i https://trusted.example/j\">",
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
  assert_eq(errors.length(), 3)
  assert_eq(errors[0].code, "unsafe-html")
  assert_eq(errors[0].category, "security")
  assert_eq(errors[0].message, "Unsafe attribute 'foo' (not allowed)")
  assert_eq(errors[1].message, "Unsafe tag 'script' (dropped content)")
  assert_eq(errors[2].message, "Unsafe URL in attribute 'href'")
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
      assert_eq(message, "Unsafe attribute 'foo' (not allowed)")
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
        message, "Unsafe attribute 'onclick' (matched forbidden pattern 'on*')",
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
      assert_eq(message, "Unsafe URL in attribute 'href'")
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
      assert_eq(message, "Unsafe URL in attribute 'content' (meta refresh)")
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
      assert_eq(message, "Unsafe URL in attribute 'imagesrcset'")
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
      assert_eq(message, "Unsafe URL in attribute 'href' (base tag)")
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
      assert_eq(message, "Unsafe URL in attribute 'attributionsrc'")
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
      assert_eq(message, "Unsafe tag 'x-foo' (not allowed)")
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
      assert_eq(message, "Unsafe tag 'script' (dropped content)")
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
      assert_eq(message, "Unsafe tag 'script' (dropped content)")
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
      assert_eq(message, "Unsafe tag 'foo' (not allowed)")
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
      assert_eq(message, "Unsafe tag 'svg' (foreign namespace)")
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
      assert_eq(message, "Unsafe tag 'svg' (foreign namespace)")
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
      assert_eq(message, "Unsafe tag 'svg' (foreign namespace)")
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
  let raise_policy = @html_parser.SanitizationPolicy::new(
    [],
    allowed_attributes={},
    unsafe_handling=Raise,
  )
  let comment_result = try? @html_parser.sanitize_dom(
    @html_parser.comment("x"),
    policy=raise_policy,
  )
  match comment_result {
    Ok(clean) => assert_eq(clean.to_html(pretty=false), "")
    Err(_) => fail("dropped comments should not use unsafe raise handling")
  }
  let doctype_result = try? @html_parser.sanitize_dom(
    @html_parser.doctype(),
    policy=raise_policy,
  )
  match doctype_result {
    Ok(clean) => assert_eq(clean.to_html(pretty=false), "")
    Err(_) => fail("dropped doctypes should not use unsafe raise handling")
  }
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
    "<b>Hello &lt;sarcasm title='tone' onclick=x&gt;<i>world</i>&lt;/sarcasm&gt;</b>",
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
test "sanitize_dom removes parser escape-only text outside escape mode" {
  let fragment = @html_parser.parse_fragment(
    "safe <!DOCTYPE and y>z",
    context=@html_parser.FragmentContext::new("div"),
    sanitize=false,
  )
  let policy = @html_parser.SanitizationPolicy::new(
    [],
    allowed_attributes={ "*": [] },
    disallowed_tag_handling=Drop,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "safe z",
  )
}

///|
test "public URL proxy policy rewrites and strips URLs stably" {
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
        "src",
        @html_parser.UrlRule::new(
          allowed_schemes=["https"],
          handling=UrlProxy,
          proxy=@html_parser.UrlProxy::new("/asset-proxy", param="src"),
        ),
      ),
    ],
  )
  let policy = @html_parser.SanitizationPolicy::new(
    ["a", "img"],
    allowed_attributes={ "*": [], "a": ["href"], "img": ["src"] },
    url_policy~,
  )
  let doc = @html_parser.parse_fragment(
    "<a href=\"https://example.com/a?b=1\">A</a><img src=\"https://cdn.example/i.png\"><a href=\"http://bad\">B</a>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(doc.root, policy~).to_html(pretty=false),
    "<a href=\"/proxy?url=https%3A%2F%2Fexample.com%2Fa%3Fb%3D1\">A</a><img src=\"/asset-proxy?src=https%3A%2F%2Fcdn.example%2Fi.png\"><a>B</a>",
  )
}

///|
test "public unsafe handling collect and raise modes stay stable" {
  let doc = @html_parser.parse_fragment(
    "<p onclick=x>ok</p><script>x</script><a href=javascript:x>link</a>",
    sanitize=false,
  )
  let collect_policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    allowed_attributes={ "*": [], "p": [] },
    unsafe_handling=Collect,
  )
  let clean = @html_parser.sanitize_dom(doc.root, policy=collect_policy)
  assert_eq(clean.to_html(pretty=false), "<p>ok</p>link")
  let errors = collect_policy.collected_security_errors()
  assert_eq(errors.length(), 3)
  for error in errors {
    assert_eq(error.code, "unsafe-html")
    assert_eq(error.category, "security")
  }

  let raise_policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    allowed_attributes={ "*": [], "p": [] },
    unsafe_handling=Raise,
  )
  let raise_doc = @html_parser.parse_fragment(
    "<p onclick=x>ok</p><script>x</script><a href=javascript:x>link</a>",
    sanitize=false,
  )
  let raised : Result[@html_parser.Node, @html_parser.HtmlError] = try? @html_parser.sanitize_dom(
    raise_doc.root,
    policy=raise_policy,
  )
  match raised {
    Err(UnsafeHtml(message)) =>
      assert_true(message.contains("Unsafe attribute 'onclick'"))
    _ => fail("expected unsafe sanitizer policy to raise")
  }
}

///|
test "public unsafe handling collect reset and copy stay stable" {
  let policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    allowed_attributes={ "*": [], "p": [] },
    unsafe_handling=Collect,
  )
  let first = @html_parser.parse_fragment(
    "<p onclick=x>ok</p><script>x</script>",
    sanitize=false,
  )
  ignore(@html_parser.sanitize_dom(first.root, policy~))
  let errors = policy.collected_security_errors()
  assert_eq(errors.length(), 2)
  errors.clear()
  assert_eq(policy.collected_security_errors().length(), 2)

  policy.reset_collected_security_errors()
  assert_eq(policy.collected_security_errors().length(), 0)
  let second = @html_parser.parse_fragment(
    "<p style='position:fixed'>ok</p>",
    sanitize=false,
  )
  ignore(@html_parser.sanitize_dom(second.root, policy~))
  let reset_errors = policy.collected_security_errors()
  assert_eq(reset_errors.length(), 1)
  assert_eq(reset_errors[0].code, "unsafe-html")
}

///|
test "public URL filter callback and validation order stay stable" {
  let seen : Array[String] = []
  let url_filter = @html_parser.UrlFilter::new(fn(tag, attr, value) {
    seen.push(tag + "/" + attr + "=" + value)
    match value {
      "/ok" => Some("https://trusted.example/ok")
      "drop" => None
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
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    ["a"],
    allowed_attributes={ "*": [], "a": ["href"] },
    url_policy~,
  )
  let doc = @html_parser.parse_fragment(
    "<A HREF='/ok'>ok</A><a href='drop'>drop</a><a href='https://evil.example/x'>bad</a>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(doc.root, policy~).to_html(pretty=false),
    "<a href=\"https://trusted.example/ok\">ok</a><a>drop</a><a>bad</a>",
  )
  assert_eq(seen.length(), 3)
  assert_eq(seen[0], "a/href=/ok")
  assert_eq(seen[1], "a/href=drop")
  assert_eq(seen[2], "a/href=https://evil.example/x")
}

///|
test "public default document sanitizer preserves shell and doctype" {
  let doc = @html_parser.parse(
    "<!doctype html><html><head><title>T</title><script>x</script></head><body><p onclick=x>ok</p></body></html>",
    sanitize=false,
  )
  let clean = @html_parser.sanitize_dom(
    doc.root,
    policy=@html_parser.default_document_sanitization_policy(),
  )
  assert_eq(
    clean.to_html(pretty=false),
    "<!DOCTYPE html><html><head><title>T</title></head><body><p>ok</p></body></html>",
  )
}

///|
test "public css text preset returns independent conservative lists" {
  let mutated = @html_parser.css_preset_text()
  assert_true(mutated.length() > 0)
  mutated.clear()
  let policy = @html_parser.SanitizationPolicy::new(
    ["span"],
    allowed_attributes={ "*": [], "span": ["style"] },
    allowed_css_properties=@html_parser.css_preset_text(),
  )
  let doc = @html_parser.parse_fragment(
    "<span style='font-weight:700; position:fixed; color:red'>ok</span>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(doc.root, policy~).to_html(pretty=false),
    "<span style=\"font-weight: 700; color: red\">ok</span>",
  )
}
