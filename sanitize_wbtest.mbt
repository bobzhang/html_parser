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
