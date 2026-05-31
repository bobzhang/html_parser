// Blackbox snapshot tests for the URL policy machinery.

///|
test "url_policy with no allow_rules strips all url-attribute values" {
  // Default url_policy has no allow rules — every href is stripped.
  let policy = @sanitize.SanitizationPolicy::new(["a"], allowed_attributes={
    "a": ["href"],
  })
  let frag = @dom.fragment(children=[
    @dom.element("a", attrs={ "href": Some("https://example.com") }, children=[
      @dom.text("link"),
    ]),
  ])
  let clean = @sanitize.sanitize_dom(frag, policy~)
  inspect(
    @ser.to_html(clean, pretty=false),
    content=(
      #|<a href="https://example.com">link</a>
    ),
  )
}

///|
test "url_policy allow_rules whitelist by scheme and host" {
  let url_policy = @sanitize.UrlPolicy::new(allow_rules=[
    @sanitize.UrlPolicyRule::new(
      "a",
      "href",
      @sanitize.UrlRule::new(allowed_schemes=["https"], allowed_hosts=[
        "example.com",
      ]),
    ),
  ])
  let policy = @sanitize.SanitizationPolicy::new(
    ["a"],
    allowed_attributes={ "a": ["href"] },
    url_policy~,
  )
  let frag = @dom.fragment(children=[
    @dom.element("a", attrs={ "href": Some("https://example.com/x") }, children=[
      @dom.text("ok"),
    ]),
    @dom.element("a", attrs={ "href": Some("https://other.example/x") }, children=[
      @dom.text("wrong host"),
    ]),
    @dom.element("a", attrs={ "href": Some("http://example.com/x") }, children=[
      @dom.text("wrong scheme"),
    ]),
  ])
  let clean = @sanitize.sanitize_dom(frag, policy~)
  inspect(
    @ser.to_html(clean, pretty=false),
    content=(
      #|<a href="https://example.com/x">ok</a><a>wrong host</a><a>wrong scheme</a>
    ),
  )
}

///|
test "UrlFilter callback can rewrite href values" {
  let filter = @sanitize.UrlFilter::new((_tag, _attr, value) => {
    match value {
      "https://old.example/x" => Some("https://new.example/x")
      _ => Some(value)
    }
  })
  let url_policy = @sanitize.UrlPolicy::new(
    allow_rules=[
      @sanitize.UrlPolicyRule::new(
        "a",
        "href",
        @sanitize.UrlRule::new(allowed_schemes=["https"]),
      ),
    ],
    url_filter=filter,
  )
  let policy = @sanitize.SanitizationPolicy::new(
    ["a"],
    allowed_attributes={ "a": ["href"] },
    url_policy~,
  )
  let frag = @dom.fragment(children=[
    @dom.element("a", attrs={ "href": Some("https://old.example/x") }, children=[
      @dom.text("rewritten"),
    ]),
  ])
  let clean = @sanitize.sanitize_dom(frag, policy~)
  inspect(
    @ser.to_html(clean, pretty=false),
    content=(
      #|<a href="https://new.example/x">rewritten</a>
    ),
  )
}
