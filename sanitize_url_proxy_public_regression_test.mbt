///|
test "sanitize_dom proxies validated URL values" {
  let url_policy = @html_parser.UrlPolicy(
    default_handling=UrlProxy,
    proxy=@html_parser.UrlProxy("/proxy"),
    allow_rules=[
      @html_parser.UrlPolicyRule(
        "a",
        "href",
        @html_parser.UrlRule(allowed_schemes=["https"]),
      ),
      @html_parser.UrlPolicyRule(
        "img",
        "srcset",
        @html_parser.UrlRule(allowed_schemes=["https"]),
      ),
      @html_parser.UrlPolicyRule(
        "p",
        "style:background-image",
        @html_parser.UrlRule(
          allowed_schemes=["https"],
          proxy=@html_parser.UrlProxy("/asset-proxy", param="src"),
        ),
      ),
    ],
  )
  let policy = @html_parser.SanitizationPolicy(
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
  let missing_proxy_policy = @html_parser.UrlPolicy(default_handling=UrlProxy, allow_rules=[
    @html_parser.UrlPolicyRule(
      "a",
      "href",
      @html_parser.UrlRule(allowed_schemes=["https"]),
    ),
  ])
  let missing_policy = @html_parser.SanitizationPolicy(
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
  let empty_proxy_policy = @html_parser.UrlPolicy(
    default_handling=UrlProxy,
    proxy=@html_parser.UrlProxy(""),
    allow_rules=[
      @html_parser.UrlPolicyRule(
        "a",
        "href",
        @html_parser.UrlRule(allowed_schemes=["https"]),
      ),
    ],
  )
  let empty_policy = @html_parser.SanitizationPolicy(
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
  let url_policy = @html_parser.UrlPolicy(
    default_handling=UrlProxy,
    proxy=@html_parser.UrlProxy("/proxy"),
    allow_rules=[
      @html_parser.UrlPolicyRule(
        "a",
        "href",
        @html_parser.UrlRule(allowed_schemes=["https"]),
      ),
      @html_parser.UrlPolicyRule(
        "img",
        "srcset",
        @html_parser.UrlRule(allowed_schemes=["https"]),
      ),
      @html_parser.UrlPolicyRule(
        "p",
        "style:background-image",
        @html_parser.UrlRule(allowed_schemes=["https"]),
      ),
    ],
  )
  let policy = @html_parser.SanitizationPolicy(
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
test "public URL proxy policy rewrites and strips URLs stably" {
  let url_policy = @html_parser.UrlPolicy(
    default_handling=UrlProxy,
    proxy=@html_parser.UrlProxy("/proxy"),
    allow_rules=[
      @html_parser.UrlPolicyRule(
        "a",
        "href",
        @html_parser.UrlRule(allowed_schemes=["https"]),
      ),
      @html_parser.UrlPolicyRule(
        "img",
        "src",
        @html_parser.UrlRule(
          allowed_schemes=["https"],
          handling=UrlProxy,
          proxy=@html_parser.UrlProxy("/asset-proxy", param="src"),
        ),
      ),
    ],
  )
  let policy = @html_parser.SanitizationPolicy(
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
