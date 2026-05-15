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
