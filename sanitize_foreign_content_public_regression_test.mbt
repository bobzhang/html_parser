///|
test "sanitize_dom strips html descendants inside foreign text integration points" {
  let policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
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
  let policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
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
  let url_policy : @html_parser.UrlPolicy = UrlPolicy(allow_rules=[
    UrlPolicyRule(
      "image",
      "href",
      UrlRule(allowed_schemes=[], allow_fragment=true, allow_relative=false),
    ),
    UrlPolicyRule(
      "set",
      "href",
      UrlRule(allowed_schemes=[], allow_fragment=true, allow_relative=false),
    ),
    UrlPolicyRule(
      "animate",
      "href",
      UrlRule(allowed_schemes=[], allow_fragment=true, allow_relative=false),
    ),
  ])
  let policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
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
  let policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
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
  let url_filter : @html_parser.UrlFilter = UrlFilter(fn(tag, attr, value) {
    if tag == "rect" && attr == "fill" && value == "#grad" {
      Some("#rewritten")
    } else {
      None
    }
  })
  let policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
    ["svg", "rect"],
    allowed_attributes={ "rect": ["fill", "width", "height", "filter"] },
    url_policy=UrlPolicy(url_filter~, allow_rules=[
      UrlPolicyRule(
        "rect",
        "fill",
        UrlRule(
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
test "sanitize_dom raise mode reports active foreign mutation tags" {
  let fragment_rule : @html_parser.UrlRule = UrlRule(
    allowed_schemes=[],
    allow_relative=false,
    allow_fragment=true,
  )
  let policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
    ["svg", "image", "set"],
    allowed_attributes={
      "image": ["id", "href", "width", "height"],
      "set": ["href", "attributeName", "to", "begin"],
    },
    url_policy=UrlPolicy(allow_rules=[
      UrlPolicyRule("image", "href", fragment_rule),
      UrlPolicyRule("set", "href", fragment_rule),
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
  try @html_parser.sanitize_dom(svg, policy~) catch {
    UnsafeHtml(message) =>
      assert_eq(message, "Unsafe tag 'set' (active foreign content)")
    _ => fail("expected active foreign content to raise UnsafeHtml")
  } noraise {
    _ => fail("expected active foreign content to raise UnsafeHtml")
  }
}

///|
test "sanitize_dom treats html namespace svg roots as foreign for active tags" {
  let policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
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
  let policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
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
  let url_policy : @html_parser.UrlPolicy = UrlPolicy(allow_rules=[
    UrlPolicyRule(
      "img",
      "src",
      UrlRule(
        allowed_schemes=[],
        allow_relative=true,
        resolve_protocol_relative=None,
      ),
    ),
  ])
  let policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
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
  let url_policy : @html_parser.UrlPolicy = UrlPolicy(allow_rules=[
    UrlPolicyRule(
      "img",
      "src",
      UrlRule(
        allowed_schemes=[],
        allow_relative=true,
        resolve_protocol_relative=None,
      ),
    ),
  ])
  let policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
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
  let url_policy : @html_parser.UrlPolicy = UrlPolicy(allow_rules=[
    UrlPolicyRule(
      "img",
      "src",
      UrlRule(
        allowed_schemes=[],
        allow_relative=true,
        resolve_protocol_relative=None,
      ),
    ),
  ])
  let policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
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
  let url_policy : @html_parser.UrlPolicy = UrlPolicy(allow_rules=[
    UrlPolicyRule(
      "img",
      "src",
      UrlRule(
        allowed_schemes=[],
        allow_relative=true,
        resolve_protocol_relative=None,
      ),
    ),
  ])
  let policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
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
  let url_policy : @html_parser.UrlPolicy = UrlPolicy(allow_rules=[
    UrlPolicyRule(
      "img",
      "src",
      UrlRule(
        allowed_schemes=[],
        allow_relative=true,
        resolve_protocol_relative=None,
      ),
    ),
  ])
  let policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
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
