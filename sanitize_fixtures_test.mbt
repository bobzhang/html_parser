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
fn sanitize_fixture_rel_policy() -> @html_parser.SanitizationPolicy {
  @html_parser.SanitizationPolicy::new(
    ["a"],
    allowed_attributes={ "*": [], "a": ["rel"] },
    url_policy=@html_parser.UrlPolicy::new(allow_rules=[]),
    force_link_rel=["noopener"],
  )
}

///|
fn sanitize_fixture_boolean_attribute_policy() -> @html_parser.SanitizationPolicy {
  @html_parser.SanitizationPolicy::new(
    ["div"],
    allowed_attributes={ "*": [], "div": ["disabled"] },
    url_policy=@html_parser.UrlPolicy::new(allow_rules=[]),
  )
}

///|
fn sanitize_fixture_foreign_namespace_policy(
  drop_foreign_namespaces : Bool,
) -> @html_parser.SanitizationPolicy {
  @html_parser.SanitizationPolicy::new(
    ["svg"],
    allowed_attributes={ "*": [], "svg": [] },
    url_policy=@html_parser.UrlPolicy::new(allow_rules=[]),
    drop_foreign_namespaces~,
  )
}

///|
fn sanitize_fixture_document_output(
  input_html : String,
  policy? : @html_parser.SanitizationPolicy,
) -> String raise {
  let parsed = @html_parser.parse(input_html, sanitize=false)
  match policy {
    Some(policy) =>
      @html_parser.sanitize_dom(parsed.root, policy~).to_html(pretty=false)
    None => @html_parser.sanitize_dom(parsed.root).to_html(pretty=false)
  }
}

///|
fn sanitize_fixture_empty_url_policy() -> @html_parser.UrlPolicy {
  @html_parser.UrlPolicy::new(allow_rules=[])
}

///|
fn sanitize_fixture_div_style_policy(
  allowed_css_properties : Array[String],
) -> @html_parser.SanitizationPolicy {
  @html_parser.SanitizationPolicy::new(
    ["div"],
    allowed_attributes={ "*": [], "div": ["style"] },
    url_policy=sanitize_fixture_empty_url_policy(),
    allowed_css_properties~,
  )
}

///|
fn sanitize_fixture_structural_style_cases() -> Array[SanitizeFixtureCase] {
  [
    {
      index: 2,
      name: "disallowed_tag_keeps_children",
      input_html: "<span>x</span>",
      expected_html: "x",
      policy: @html_parser.SanitizationPolicy::new(
        ["div"],
        allowed_attributes={ "*": [], "div": [] },
        url_policy=sanitize_fixture_empty_url_policy(),
      ),
    },
    {
      index: 29,
      name: "disallowed_tag_drop_removes_subtree",
      input_html: "<b>Hello <sarcasm>world</sarcasm></b>",
      expected_html: "<b>Hello </b>",
      policy: @html_parser.SanitizationPolicy::new(
        ["b"],
        allowed_attributes={ "*": [], "b": [] },
        url_policy=sanitize_fixture_empty_url_policy(),
        disallowed_tag_handling=Drop,
      ),
    },
    {
      index: 30,
      name: "attribute_filtering_drops_on_srcdoc_and_colon",
      input_html: "<div id=x onclick=alert(1) srcdoc='<p>p</p>' x:y=z title=t></div>",
      expected_html: "<div id=\"x\" title=\"t\"></div>",
      policy: @html_parser.SanitizationPolicy::new(
        ["div"],
        allowed_attributes={ "*": ["id"], "div": ["title"] },
        url_policy=sanitize_fixture_empty_url_policy(),
      ),
    },
    {
      index: 31,
      name: "attribute_not_in_allowlist_is_dropped",
      input_html: "<div class=x></div>",
      expected_html: "<div></div>",
      policy: @html_parser.SanitizationPolicy::new(
        ["div"],
        allowed_attributes={ "*": [], "div": [] },
        url_policy=sanitize_fixture_empty_url_policy(),
      ),
    },
    {
      index: 32,
      name: "inline_style_sanitization_allows_selected_properties",
      input_html: "<div style='color: red; position: absolute; BORDER: 1px solid red; ; invalid'></div>",
      expected_html: "<div style=\"color: red; border: 1px solid red\"></div>",
      policy: sanitize_fixture_div_style_policy(["color", "border"]),
    },
    {
      index: 34,
      name: "inline_style_drops_resource_loading_url_function",
      input_html: "<div style='background-image: url(https://evil.example/x); color: red'></div>",
      expected_html: "<div style=\"color: red\"></div>",
      policy: sanitize_fixture_div_style_policy(["background-image", "color"]),
    },
    {
      index: 35,
      name: "inline_style_drops_resource_loading_obfuscated_url_function",
      input_html: "<div style='background-image: u\\72l(https://evil.example/x); color: red'></div>",
      expected_html: "<div style=\"color: red\"></div>",
      policy: sanitize_fixture_div_style_policy(["background-image", "color"]),
    },
    {
      index: 36,
      name: "inline_style_drops_expression_even_when_allowlisted",
      input_html: "<div style='width: expression(alert(1)); color: red'></div>",
      expected_html: "<div style=\"color: red\"></div>",
      policy: sanitize_fixture_div_style_policy(["width", "color"]),
    },
    {
      index: 37,
      name: "img_valueless_src_is_dropped",
      input_html: "<img/src/onerror=prompt(8)>",
      expected_html: "<img>",
      policy: @html_parser.SanitizationPolicy::new(
        ["img"],
        allowed_attributes={ "*": [], "img": ["src"] },
        url_policy=@html_parser.UrlPolicy::new(allow_rules=[
          @html_parser.UrlPolicyRule::new(
            "img",
            "src",
            @html_parser.UrlRule::new(
              allowed_schemes=[],
              allow_relative=true,
              allow_fragment=false,
            ),
          ),
        ]),
      ),
    },
    {
      index: 38,
      name: "url_rules_drop_javascript_and_force_rel",
      input_html: "<a href='javascript:alert(1)' rel='nofollow'>x</a><a href='https://example.com'>y</a>",
      expected_html: "<a rel=\"nofollow noopener noreferrer\">x</a><a href=\"https://example.com\" rel=\"noopener noreferrer\">y</a>",
      policy: @html_parser.SanitizationPolicy::new(
        ["a"],
        allowed_attributes={ "*": [], "a": ["href"] },
        url_policy=@html_parser.UrlPolicy::new(allow_rules=[
          @html_parser.UrlPolicyRule::new(
            "a",
            "href",
            @html_parser.UrlRule::new(
              allowed_schemes=["https"],
              allow_relative=true,
              allow_fragment=true,
            ),
          ),
        ]),
        force_link_rel=["noopener", "noreferrer"],
      ),
    },
  ]
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
fn sanitize_fixture_attribute_namespace_cases() -> Array[SanitizeFixtureCase] {
  [
    {
      index: 44,
      name: "rel_deduplicates_tokens",
      input_html: "<a rel='noopener noopener'></a>",
      expected_html: "<a rel=\"noopener\"></a>",
      policy: sanitize_fixture_rel_policy(),
    },
    {
      index: 45,
      name: "url_rules_disallow_fragment_and_relative",
      input_html: "<a href='#frag'></a><a href='/rel'></a><a href='https://ok'></a>",
      expected_html: "<a></a><a></a><a href=\"https://ok\"></a>",
      policy: sanitize_fixture_anchor_policy(
        @html_parser.UrlRule::new(
          allowed_schemes=["https"],
          allow_fragment=false,
          allow_relative=false,
        ),
      ),
    },
    {
      index: 46,
      name: "empty_url_value_dropped_when_allow_relative_false",
      input_html: "<a href=' \t\n'></a>",
      expected_html: "<a></a>",
      policy: sanitize_fixture_anchor_policy(
        @html_parser.UrlRule::new(
          allowed_schemes=["https"],
          allow_relative=false,
        ),
      ),
    },
    {
      index: 49,
      name: "protocol_relative_allowed_when_allowed_hosts_null",
      input_html: "<a href='//any.example/path'></a>",
      expected_html: "<a href=\"https://any.example/path\"></a>",
      policy: sanitize_fixture_anchor_policy(
        @html_parser.UrlRule::new(allowed_schemes=["https"]),
      ),
    },
    {
      index: 50,
      name: "protocol_relative_resolved_scheme_mismatch",
      input_html: "<a href='//example.com'></a>",
      expected_html: "<a></a>",
      policy: sanitize_fixture_anchor_policy(
        @html_parser.UrlRule::new(
          allowed_schemes=["http"],
          resolve_protocol_relative=Some("https"),
        ),
      ),
    },
    {
      index: 51,
      name: "absolute_allowed_hosts_allows",
      input_html: "<a href='https://example.com/x'></a>",
      expected_html: "<a href=\"https://example.com/x\"></a>",
      policy: sanitize_fixture_anchor_policy(
        @html_parser.UrlRule::new(allowed_schemes=["https"], allowed_hosts=[
          "example.com",
        ]),
      ),
    },
    {
      index: 52,
      name: "absolute_allowed_hosts_blocks",
      input_html: "<a href='https://evil.com'></a>",
      expected_html: "<a></a>",
      policy: sanitize_fixture_anchor_policy(
        @html_parser.UrlRule::new(allowed_schemes=["https"], allowed_hosts=[
          "example.com",
        ]),
      ),
    },
    {
      index: 57,
      name: "boolean_attribute_value_none_is_preserved_when_allowed",
      input_html: "<div disabled></div>",
      expected_html: "<div disabled></div>",
      policy: sanitize_fixture_boolean_attribute_policy(),
    },
    {
      index: 58,
      name: "foreign_namespace_element_dropped_when_enabled",
      input_html: "<svg></svg>",
      expected_html: "",
      policy: sanitize_fixture_foreign_namespace_policy(true),
    },
    {
      index: 59,
      name: "foreign_namespace_element_kept_when_disabled",
      input_html: "<svg></svg>",
      expected_html: "<svg></svg>",
      policy: sanitize_fixture_foreign_namespace_policy(false),
    },
  ]
}

///|
test "sanitizer matches vendored document fixture rows" {
  assert_eq(
    sanitize_fixture_document_output(
      "<!DOCTYPE html><!--x--><p>ok</p><script>alert(1)</script>",
      policy=@html_parser.default_sanitization_policy(),
    ),
    "<p>ok</p>",
  )
  let keep_policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    allowed_attributes={ "*": [], "p": [] },
    url_policy=sanitize_fixture_empty_url_policy(),
    drop_comments=false,
    drop_doctype=false,
  )
  assert_eq(
    sanitize_fixture_document_output(
      "<!DOCTYPE html><!--x--><p>ok</p>",
      policy=keep_policy,
    ),
    "<!DOCTYPE html><!--x--><p>ok</p>",
  )
}

///|
test "sanitizer matches vendored structural and style fixture rows" {
  for case in sanitize_fixture_structural_style_cases() {
    assert_sanitize_fixture(case)
  }
}

///|
test "sanitizer matches vendored URL and template fixture rows" {
  for case in sanitize_fixture_url_template_cases() {
    assert_sanitize_fixture(case)
  }
}

///|
test "sanitizer matches vendored attribute and namespace fixture rows" {
  for case in sanitize_fixture_attribute_namespace_cases() {
    assert_sanitize_fixture(case)
  }
}

///|
test "sanitizer fixture table covers translated URL and template rows" {
  assert_eq(sanitize_fixture_structural_style_cases().length(), 10)
  assert_eq(sanitize_fixture_url_template_cases().length(), 13)
  assert_eq(sanitize_fixture_attribute_namespace_cases().length(), 10)
}
