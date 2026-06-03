///|
test "sanitize_dom collects rawtext and foreign integration findings" {
  let rawtext_policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
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

  let foreign_policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
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
test "sanitize_dom preserves allowed template content" {
  let policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
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
  let policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
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
  let policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
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
  let policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
    ["textarea", "img"],
    allowed_attributes={ "*": [], "img": ["src", "alt"] },
    url_policy=UrlPolicy(allow_rules=[]),
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
  let policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
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
  let policy : @html_parser.SanitizationPolicy = SanitizationPolicy(["style"], drop_content_tags=[])
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
  let policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
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
  let policy : @html_parser.SanitizationPolicy = SanitizationPolicy(["style"], drop_content_tags=[])
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
  let policy : @html_parser.SanitizationPolicy = SanitizationPolicy(["style"], drop_content_tags=[])
  let style = @html_parser.element("StYlE", children=[
    @html_parser.text("@import 'https://evil.example/x.css';"),
  ])
  assert_eq(
    @html_parser.sanitize_dom(style, policy~).to_html(pretty=false),
    "<StYlE></StYlE>",
  )
}
