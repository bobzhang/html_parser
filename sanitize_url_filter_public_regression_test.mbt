///|
test "sanitize_dom rejects malformed URL schemes when relatives are disabled" {
  let url_policy : @html_parser.UrlPolicy = UrlPolicy(
    default_allow_relative=false,
    allow_rules=[
      UrlPolicyRule(
        "a",
        "href",
        UrlRule(allowed_schemes=["https"], allow_relative=false),
      ),
    ],
  )
  let policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
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
  let url_filter : @html_parser.UrlFilter = UrlFilter(fn(_tag, attr, value) {
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
  let url_policy : @html_parser.UrlPolicy = UrlPolicy(url_filter~, allow_rules=[
    UrlPolicyRule(
      "a",
      "href",
      UrlRule(allowed_schemes=["https"], allowed_hosts=["trusted.example"]),
    ),
    UrlPolicyRule(
      "a",
      "ping",
      UrlRule(allowed_schemes=["https"], allowed_hosts=["trusted.example"]),
    ),
    UrlPolicyRule(
      "img",
      "srcset",
      UrlRule(allowed_schemes=["https"], allowed_hosts=["trusted.example"]),
    ),
    UrlPolicyRule(
      "p",
      "style:background-image",
      UrlRule(allowed_schemes=["https"], allowed_hosts=["trusted.example"]),
    ),
  ])
  let policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
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
  let url_filter : @html_parser.UrlFilter = UrlFilter(fn(_tag, _attr, value) {
    Some(value)
  })
  let repr = url_filter.to_repr().to_string()
  assert_true(repr.contains("UrlFilter"))
  assert_eq(repr.contains("callback"), false)
}

///|
test "sanitize_dom validates css url filter rewrites" {
  let url_filter : @html_parser.UrlFilter = UrlFilter(fn(_tag, attr, value) {
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
  let css_rule : @html_parser.UrlRule = UrlRule(
    allowed_schemes=[],
    allow_relative=true,
    resolve_protocol_relative=None,
  )
  let url_policy : @html_parser.UrlPolicy = UrlPolicy(url_filter~, allow_rules=[
    UrlPolicyRule("*", "style:background-image", css_rule),
  ])
  let policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
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
  let url_filter : @html_parser.UrlFilter = UrlFilter(fn(_tag, attr, value) {
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
  let trusted_rule : @html_parser.UrlRule = UrlRule(allowed_schemes=["https"], allowed_hosts=[
    "trusted.example",
  ])
  let url_policy : @html_parser.UrlPolicy = UrlPolicy(url_filter~, allow_rules=[
    UrlPolicyRule("a", "href", trusted_rule),
    UrlPolicyRule("a", "ping", trusted_rule),
    UrlPolicyRule("img", "src", trusted_rule),
    UrlPolicyRule("img", "srcset", trusted_rule),
    UrlPolicyRule("img", "attributionsrc", trusted_rule),
  ])
  let policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
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
  let trusted_rule : @html_parser.UrlRule = UrlRule(
    allowed_schemes=["https"],
    allowed_hosts=["trusted.example"],
    allow_relative=false,
  )
  let url_policy : @html_parser.UrlPolicy = UrlPolicy(
    default_allow_relative=false,
    allow_rules=[UrlPolicyRule("img", "srcset", trusted_rule)],
  )
  let policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
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
  let trusted_rule : @html_parser.UrlRule = UrlRule(
    allowed_schemes=["https"],
    allowed_hosts=["trusted.example"],
    allow_relative=false,
  )
  let url_policy : @html_parser.UrlPolicy = UrlPolicy(
    default_allow_relative=false,
    allow_rules=[
      UrlPolicyRule("a", "ping", trusted_rule),
      UrlPolicyRule("img", "attributionsrc", trusted_rule),
    ],
  )
  let policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
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
  let host_rule : @html_parser.UrlRule = UrlRule(
    allowed_schemes=["https", "mailto"],
    allowed_hosts=["trusted.example", "::1"],
    allow_relative=false,
  )
  let url_policy : @html_parser.UrlPolicy = UrlPolicy(
    default_allow_relative=false,
    allow_rules=[
      UrlPolicyRule("a", "href", host_rule),
      UrlPolicyRule("img", "src", host_rule),
    ],
  )
  let policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
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
test "public URL filter callback and validation order stay stable" {
  let seen : Array[String] = []
  let url_filter : @html_parser.UrlFilter = UrlFilter(fn(tag, attr, value) {
    seen.push(tag + "/" + attr + "=" + value)
    match value {
      "/ok" => Some("https://trusted.example/ok")
      "drop" => None
      _ => Some(value)
    }
  })
  let url_policy : @html_parser.UrlPolicy = UrlPolicy(url_filter~, allow_rules=[
    UrlPolicyRule(
      "a",
      "href",
      UrlRule(allowed_schemes=["https"], allowed_hosts=["trusted.example"]),
    ),
  ])
  let policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
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
