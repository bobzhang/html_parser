///|
test "public default sanitizer security corpus stays stable" {
  let doc = @html_parser.parse_fragment(
    "<p onclick=bad style=\"color:red;background:url(javascript:bad)\">ok</p><!--x--><a href=javascript:bad rel=nofollow>bad</a><math><mtext><img src=x onerror=1></mtext></math><script>bad</script>",
    sanitize=true,
  )
  assert_eq(doc.to_html(pretty=false), "<p>ok</p><a>bad</a>")
  assert_eq(doc.to_text(separator="|", strip=true), "ok|bad")
}

///|
test "sanitize_dom default policy drops unsafe document content" {
  let doc = @html_parser.parse(
    "<!DOCTYPE html><!--x--><p onclick=alert(1)>ok</p><script>alert(1)</script>",
    sanitize=false,
  )
  let sanitized = @html_parser.sanitize_dom(
    doc.root,
    policy=@html_parser.default_sanitization_policy(),
  )
  assert_eq(sanitized.to_html(pretty=false), "<p>ok</p>")
}

///|
test "public URL proxy policy rewrites and strips URLs stably" {
  let url_policy = @html_parser.UrlPolicy::new(
    default_handling=UrlProxy,
    proxy=@html_parser.UrlProxy::new("/proxy"),
    allow_rules=[
      @html_parser.UrlPolicyRule::new(
        "a",
        "href",
        @html_parser.UrlRule::new(allowed_schemes=["https"]),
      ),
      @html_parser.UrlPolicyRule::new(
        "img",
        "src",
        @html_parser.UrlRule::new(
          allowed_schemes=["https"],
          handling=UrlProxy,
          proxy=@html_parser.UrlProxy::new("/asset-proxy", param="src"),
        ),
      ),
    ],
  )
  let policy = @html_parser.SanitizationPolicy::new(
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

///|
test "public unsafe handling collect and raise modes stay stable" {
  let doc = @html_parser.parse_fragment(
    "<p onclick=x>ok</p><script>x</script><a href=javascript:x>link</a>",
    sanitize=false,
  )
  let collect_policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    allowed_attributes={ "*": [], "p": [] },
    unsafe_handling=Collect,
  )
  let clean = @html_parser.sanitize_dom(doc.root, policy=collect_policy)
  assert_eq(clean.to_html(pretty=false), "<p>ok</p>link")
  let errors = collect_policy.collected_security_errors()
  assert_eq(errors.length(), 3)
  for error in errors {
    assert_eq(error.code, "unsafe-html")
    assert_eq(error.category, "security")
  }

  let raise_policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    allowed_attributes={ "*": [], "p": [] },
    unsafe_handling=Raise,
  )
  let raise_doc = @html_parser.parse_fragment(
    "<p onclick=x>ok</p><script>x</script><a href=javascript:x>link</a>",
    sanitize=false,
  )
  let raised : Result[@html_parser.Node, @html_parser.HtmlError] = try? @html_parser.sanitize_dom(
    raise_doc.root,
    policy=raise_policy,
  )
  match raised {
    Err(UnsafeHtml(message)) =>
      assert_true(message.contains("Unsafe attribute 'onclick'"))
    _ => fail("expected unsafe sanitizer policy to raise")
  }
}

///|
test "public unsafe handling collect reset and copy stay stable" {
  let policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    allowed_attributes={ "*": [], "p": [] },
    unsafe_handling=Collect,
  )
  let first = @html_parser.parse_fragment(
    "<p onclick=x>ok</p><script>x</script>",
    sanitize=false,
  )
  ignore(@html_parser.sanitize_dom(first.root, policy~))
  let errors = policy.collected_security_errors()
  assert_eq(errors.length(), 2)
  errors.clear()
  assert_eq(policy.collected_security_errors().length(), 2)

  policy.reset_collected_security_errors()
  assert_eq(policy.collected_security_errors().length(), 0)
  let second = @html_parser.parse_fragment(
    "<p style='position:fixed'>ok</p>",
    sanitize=false,
  )
  ignore(@html_parser.sanitize_dom(second.root, policy~))
  let reset_errors = policy.collected_security_errors()
  assert_eq(reset_errors.length(), 1)
  assert_eq(reset_errors[0].code, "unsafe-html")
}

///|
test "public URL filter callback and validation order stay stable" {
  let seen : Array[String] = []
  let url_filter = @html_parser.UrlFilter::new(fn(tag, attr, value) {
    seen.push(tag + "/" + attr + "=" + value)
    match value {
      "/ok" => Some("https://trusted.example/ok")
      "drop" => None
      _ => Some(value)
    }
  })
  let url_policy = @html_parser.UrlPolicy::new(url_filter~, allow_rules=[
    @html_parser.UrlPolicyRule::new(
      "a",
      "href",
      @html_parser.UrlRule::new(allowed_schemes=["https"], allowed_hosts=[
        "trusted.example",
      ]),
    ),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
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

///|
test "public default document sanitizer preserves shell and doctype" {
  let doc = @html_parser.parse(
    "<!doctype html><html><head><title>T</title><script>x</script></head><body><p onclick=x>ok</p></body></html>",
    sanitize=false,
  )
  let clean = @html_parser.sanitize_dom(
    doc.root,
    policy=@html_parser.default_document_sanitization_policy(),
  )
  assert_eq(
    clean.to_html(pretty=false),
    "<!DOCTYPE html><html><head><title>T</title></head><body><p>ok</p></body></html>",
  )
}

///|
test "public css text preset returns independent conservative lists" {
  let mutated = @html_parser.css_preset_text()
  assert_true(mutated.length() > 0)
  mutated.clear()
  let policy = @html_parser.SanitizationPolicy::new(
    ["span"],
    allowed_attributes={ "*": [], "span": ["style"] },
    allowed_css_properties=@html_parser.css_preset_text(),
  )
  let doc = @html_parser.parse_fragment(
    "<span style='font-weight:700; position:fixed; color:red'>ok</span>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(doc.root, policy~).to_html(pretty=false),
    "<span style=\"font-weight: 700; color: red\">ok</span>",
  )
}
