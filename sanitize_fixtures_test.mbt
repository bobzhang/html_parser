///|
priv struct SanitizeFixtureCase {
  index : Int
  name : String
  input_html : String
  expected_html : String
  policy : @html_parser.SanitizationPolicy
}

///|
fn sanitize_fixture_output(
  input_html : String,
  policy : @html_parser.SanitizationPolicy,
) -> String raise {
  let parsed = @html_parser.parse_fragment(
    input_html,
    context=@html_parser.FragmentContext::new("div"),
    sanitize=false,
  )
  @html_parser.sanitize_dom(parsed.root, policy~).to_html(pretty=false)
}

///|
fn assert_sanitize_fixture(case : SanitizeFixtureCase) -> Unit raise {
  let actual = sanitize_fixture_output(case.input_html, case.policy)
  if actual != case.expected_html {
    fail(
      "sanitize fixture " +
      case.index.to_string() +
      " " +
      case.name +
      " produced " +
      actual,
    )
  }
}

///|
fn sanitize_fixture_img_src_proxy_policy(
  proxy_url : String,
  allow_relative : Bool,
) -> @html_parser.SanitizationPolicy {
  let url_policy = @html_parser.UrlPolicy::new(allow_rules=[
    @html_parser.UrlPolicyRule::new(
      "img",
      "src",
      @html_parser.UrlRule::new(
        allowed_schemes=["https"],
        handling=UrlProxy,
        allow_relative~,
        proxy=@html_parser.UrlProxy::new(proxy_url),
      ),
    ),
  ])
  @html_parser.SanitizationPolicy::new(
    ["img"],
    allowed_attributes={ "*": [], "img": ["src"] },
    url_policy~,
  )
}

///|
fn sanitize_fixture_anchor_policy(
  rule : @html_parser.UrlRule,
  url_filter? : @html_parser.UrlFilter,
) -> @html_parser.SanitizationPolicy {
  let allow_rules = [@html_parser.UrlPolicyRule::new("a", "href", rule)]
  let url_policy = match url_filter {
    Some(filter) => @html_parser.UrlPolicy::new(url_filter=filter, allow_rules~)
    None => @html_parser.UrlPolicy::new(allow_rules~)
  }
  @html_parser.SanitizationPolicy::new(
    ["a"],
    allowed_attributes={ "*": [], "a": ["href"] },
    url_policy~,
  )
}

///|
fn sanitize_fixture_drop_or_rewrite_filter() -> @html_parser.UrlFilter {
  @html_parser.UrlFilter::new(fn(_tag, _attr, value) {
    match value {
      "https://drop.me" => None
      "https://rewrite.me" => Some("https://example.com")
      _ => Some(value)
    }
  })
}

///|
fn sanitize_fixture_template_policy(
  allowed_tags : Array[String],
) -> @html_parser.SanitizationPolicy {
  @html_parser.SanitizationPolicy::new(
    allowed_tags,
    allowed_attributes={ "*": [], "template": [], "p": [] },
    url_policy=@html_parser.UrlPolicy::new(allow_rules=[]),
  )
}

///|
fn sanitize_fixture_url_template_cases() -> Array[SanitizeFixtureCase] {
  [
    {
      index: 39,
      name: "url_rules_proxy_absolute_https_img_src",
      input_html: "<img src='https://google.com'>",
      expected_html: "<img src=\"/proxy?url=https%3A%2F%2Fgoogle.com\">",
      policy: sanitize_fixture_img_src_proxy_policy("/proxy", false),
    },
    {
      index: 40,
      name: "url_rules_proxy_absolute_https_existing_query_img_src",
      input_html: "<img src='https://google.com'>",
      expected_html: "<img src=\"/proxy?x=1&amp;url=https%3A%2F%2Fgoogle.com\">",
      policy: sanitize_fixture_img_src_proxy_policy("/proxy?x=1", false),
    },
    {
      index: 41,
      name: "url_rules_proxy_allows_relative_without_colon",
      input_html: "<img src='noscheme'>",
      expected_html: "<img src=\"/proxy?url=noscheme\">",
      policy: sanitize_fixture_img_src_proxy_policy("/proxy", true),
    },
    {
      index: 42,
      name: "url_rules_proxy_allows_relative_colon_in_path",
      input_html: "<img src='/path:foo'>",
      expected_html: "<img src=\"/proxy?url=%2Fpath%3Afoo\">",
      policy: sanitize_fixture_img_src_proxy_policy("/proxy", true),
    },
    {
      index: 43,
      name: "url_rules_proxy_blocks_scheme_obfuscation_backslash",
      input_html: "<img src='https\\://google.com'>",
      expected_html: "<img>",
      policy: sanitize_fixture_img_src_proxy_policy("/proxy", true),
    },
    {
      index: 47,
      name: "protocol_relative_disallowed",
      input_html: "<a href='//example.com/path'></a>",
      expected_html: "<a></a>",
      policy: sanitize_fixture_anchor_policy(
        @html_parser.UrlRule::new(
          allowed_schemes=["https"],
          resolve_protocol_relative=None,
        ),
      ),
    },
    {
      index: 48,
      name: "protocol_relative_allowed_hosts",
      input_html: "<a href='//example.com/path'></a><a href='//evil.com/path'></a>",
      expected_html: "<a href=\"https://example.com/path\"></a><a></a>",
      policy: sanitize_fixture_anchor_policy(
        @html_parser.UrlRule::new(allowed_schemes=["https"], allowed_hosts=[
          "example.com",
        ]),
      ),
    },
    {
      index: 53,
      name: "url_filter_drop_and_rewrite",
      input_html: "<a href='https://drop.me'></a><a href='https://rewrite.me'></a>",
      expected_html: "<a></a><a href=\"https://example.com\"></a>",
      policy: sanitize_fixture_anchor_policy(
        @html_parser.UrlRule::new(allowed_schemes=["https"]),
        url_filter=sanitize_fixture_drop_or_rewrite_filter(),
      ),
    },
    {
      index: 54,
      name: "invalid_scheme_treated_as_relative_and_blocked_when_allow_relative_false",
      input_html: "<a href='1http://x'></a><a href='ht$tp://x'></a>",
      expected_html: "<a></a><a></a>",
      policy: sanitize_fixture_anchor_policy(
        @html_parser.UrlRule::new(
          allowed_schemes=["https"],
          allow_relative=false,
        ),
      ),
    },
    {
      index: 55,
      name: "scheme_separator_before_path_is_not_a_scheme",
      input_html: "<a href='/path:foo'></a>",
      expected_html: "<a></a>",
      policy: sanitize_fixture_anchor_policy(
        @html_parser.UrlRule::new(
          allowed_schemes=["https"],
          allow_relative=false,
        ),
      ),
    },
    {
      index: 56,
      name: "url_normalization_strips_whitespace_in_scheme_obfuscation",
      input_html: "<a href='java\t\nscript:alert(1)'></a>",
      expected_html: "<a></a>",
      policy: sanitize_fixture_anchor_policy(
        @html_parser.UrlRule::new(allowed_schemes=["https"]),
      ),
    },
    {
      index: 60,
      name: "template_allowed_sanitizes_template_content",
      input_html: "<template><p>ok</p></template>",
      expected_html: "<template><p>ok</p></template>",
      policy: sanitize_fixture_template_policy(["template", "p"]),
    },
    {
      index: 61,
      name: "template_disallowed_keeps_template_content",
      input_html: "<template><p>ok</p></template>",
      expected_html: "<p>ok</p>",
      policy: sanitize_fixture_template_policy(["p"]),
    },
  ]
}

///|
test "sanitizer matches vendored URL and template fixture rows" {
  for case in sanitize_fixture_url_template_cases() {
    assert_sanitize_fixture(case)
  }
}

///|
test "sanitizer fixture table covers translated URL and template rows" {
  assert_eq(sanitize_fixture_url_template_cases().length(), 13)
}
