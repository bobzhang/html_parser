///|
test "sanitizer attribute helpers fail closed on dangerous allowlist entries" {
  let policy = SanitizationPolicy::new(
    ["a", "p"],
    allowed_attributes={
      "*": ["data-info", "xlink:href"],
      "a": ["href", "onclick", "rel", "srcdoc"],
    },
    force_link_rel=["noopener"],
  )
  assert_eq(policy_allows_attribute(policy, "a", "onclick"), false)
  assert_eq(policy_allows_attribute(policy, "a", "srcdoc"), false)
  assert_eq(policy_allows_attribute(policy, "a", "xlink:href"), false)
  assert_eq(policy_allows_attribute(policy, "a", "rel"), true)
  assert_eq(policy_allows_attribute(policy, "p", "data-info"), true)
  assert_eq(
    sanitize_dropped_attr_report_message(
      policy,
      "p",
      "data-info",
      Some("kept-by-policy-but-dropped-by-value"),
      false,
    ),
    "Unsafe attribute 'data-info' on <p> was dropped",
  )
}

///|
test "sanitizer scanners preserve astral URL and token boundaries" {
  let trusted_rule = UrlRule::new(
    allowed_schemes=["https"],
    allowed_hosts=["trusted.example"],
    allow_relative=false,
  )
  let url_policy = UrlPolicy::new(default_allow_relative=false, allow_rules=[
    UrlPolicyRule::new("img", "srcset", trusted_rule),
    UrlPolicyRule::new("a", "ping", trusted_rule),
    UrlPolicyRule::new("*", "style:background-image", trusted_rule),
  ])
  let policy = SanitizationPolicy::new(
    ["a", "img", "p"],
    allowed_css_properties=["background-image"],
    url_policy~,
  )
  let (srcset_url, srcset_descriptor) = split_srcset_candidate(
    "https://trusted.example/a😀.png 2x",
  )
  assert_eq(srcset_url.to_owned(), "https://trusted.example/a😀.png")
  assert_eq(srcset_descriptor.to_owned(), "2x")
  guard sanitize_srcset_attribute_value(
      policy, "img", "srcset", "https://trusted.example/a😀.png 1x, https://trusted.example/b.png 2x",
    )
    is Some(srcset) else {
    fail("expected sanitized srcset")
  }
  assert_eq(
    srcset, "https://trusted.example/a😀.png 1x, https://trusted.example/b.png 2x",
  )
  guard sanitize_space_separated_url_list_attribute_value(
      policy, "a", "ping", "https://trusted.example/p😀 https://trusted.example/q",
    )
    is Some(ping) else {
    fail("expected sanitized ping")
  }
  assert_eq(ping, "https://trusted.example/p😀 https://trusted.example/q")
  guard sanitize_inline_style_value(
      policy, "p", "background-image: url('https://trusted.example/bg😀.png')",
    )
    is Some(style) else {
    fail("expected sanitized style")
  }
  assert_eq(
    style, "background-image: url('https://trusted.example/bg😀.png')",
  )
  let tokens : Array[String] = []
  push_html_whitespace_tokens(tokens, "NoOpener 😀 noreferrer")
  assert_eq(tokens, ["noopener", "😀", "noreferrer"])
}
