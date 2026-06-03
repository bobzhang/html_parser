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

  let collect_policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
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

  let raise_policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
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
  let policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
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
  let policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
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
  let policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
    ["button"],
    allowed_attributes={ "*": [], "button": ["disabled", "title"] },
  )
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
test "sanitize_dom preserves allowed valueless non-url attributes" {
  let policy : @html_parser.SanitizationPolicy = SanitizationPolicy(["div"], allowed_attributes={
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
  let url_policy : @html_parser.UrlPolicy = UrlPolicy(
    default_handling=UrlAllow,
    allow_rules=[UrlPolicyRule("a", "href", UrlRule(allowed_schemes=["https"]))],
  )
  let policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
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
