///|
test "sanitize_dom can collect and raise unsafe findings" {
  let safe_policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
    ["p"],
    allowed_attributes={ "p": [] },
    unsafe_handling=Collect,
  )
  let safe_fragment = @html_parser.parse_fragment("<p>ok</p>", sanitize=false)
  assert_eq(
    @html_parser.sanitize_dom(safe_fragment.root, policy=safe_policy).to_html(
      pretty=false,
    ),
    "<p>ok</p>",
  )
  assert_eq(safe_policy.collected_security_errors().length(), 0)

  let collect_policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
    ["p", "a"],
    allowed_attributes={ "p": [], "a": ["href"] },
    unsafe_handling=Collect,
  )
  let fragment = @html_parser.parse_fragment(
    "<p foo=1>safe<script>bad</script><a href='javascript:alert(1)'>bad</a></p><!--x-->",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy=collect_policy).to_html(
      pretty=false,
    ),
    "<p>safe<a>bad</a></p>",
  )
  let errors = collect_policy.collected_security_errors()
  assert_eq(errors.length(), 3)
  assert_eq(errors[0].code, "unsafe-html")
  assert_eq(errors[0].category, "security")
  assert_eq(errors[0].message, "Unsafe attribute 'foo' (not allowed)")
  assert_eq(errors[1].message, "Unsafe tag 'script' (dropped content)")
  assert_eq(errors[2].message, "Unsafe URL in attribute 'href'")
  collect_policy.reset_collected_security_errors()
  assert_eq(collect_policy.collected_security_errors().length(), 0)

  let raise_policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
    ["p"],
    allowed_attributes={ "p": [] },
    unsafe_handling=Raise,
  )
  let unsafe_fragment = @html_parser.parse_fragment(
    "<p foo=1>safe</p>",
    sanitize=false,
  )
  let result : Result[@html_parser.Node, @html_parser.HtmlError] = try? @html_parser.sanitize_dom(
    unsafe_fragment.root,
    policy=raise_policy,
  )
  match result {
    Err(UnsafeHtml(message)) =>
      assert_eq(message, "Unsafe attribute 'foo' (not allowed)")
    _ => fail("expected sanitize_dom to raise UnsafeHtml")
  }
}

///|
test "sanitize_dom raise mode reports dangerous attributes and urls" {
  let attr_policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
    ["p"],
    allowed_attributes={ "p": ["onclick"] },
    unsafe_handling=Raise,
  )
  let attr_fragment = @html_parser.parse_fragment(
    "<p onclick='alert(1)'>x</p>",
    sanitize=false,
  )
  let attr_result : Result[@html_parser.Node, @html_parser.HtmlError] = try? @html_parser.sanitize_dom(
    attr_fragment.root,
    policy=attr_policy,
  )
  match attr_result {
    Err(UnsafeHtml(message)) =>
      assert_eq(
        message, "Unsafe attribute 'onclick' (matched forbidden pattern 'on*')",
      )
    _ => fail("expected dangerous attribute to raise UnsafeHtml")
  }

  let url_policy : @html_parser.UrlPolicy = UrlPolicy(allow_rules=[
    UrlPolicyRule("a", "href", UrlRule(allowed_schemes=["https"])),
  ])
  let link_policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
    ["a"],
    allowed_attributes={ "a": ["href"] },
    unsafe_handling=Raise,
    url_policy~,
  )
  let link_fragment = @html_parser.parse_fragment(
    "<a href='javascript:alert(1)'>x</a>",
    sanitize=false,
  )
  let link_result : Result[@html_parser.Node, @html_parser.HtmlError] = try? @html_parser.sanitize_dom(
    link_fragment.root,
    policy=link_policy,
  )
  match link_result {
    Err(UnsafeHtml(message)) =>
      assert_eq(message, "Unsafe URL in attribute 'href'")
    _ => fail("expected unsafe URL to raise UnsafeHtml")
  }

  let meta_policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
    ["meta"],
    allowed_attributes={ "meta": ["http-equiv", "content"] },
    drop_content_tags=[],
    unsafe_handling=Raise,
  )
  let meta_fragment = @html_parser.parse_fragment(
    "<meta http-equiv='refresh' content='0;url=javascript:alert(1)'>",
    sanitize=false,
  )
  let meta_result : Result[@html_parser.Node, @html_parser.HtmlError] = try? @html_parser.sanitize_dom(
    meta_fragment.root,
    policy=meta_policy,
  )
  match meta_result {
    Err(UnsafeHtml(message)) =>
      assert_eq(message, "Unsafe URL in attribute 'content' (meta refresh)")
    _ => fail("expected meta refresh content to raise UnsafeHtml")
  }
}

///|
test "sanitize_dom raise mode reports URL list and base drops" {
  let srcset_rule : @html_parser.UrlRule = UrlRule(
    allowed_schemes=["https"],
    allowed_hosts=["trusted.example"],
    allow_relative=false,
  )
  let srcset_policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
    ["link"],
    allowed_attributes={ "link": ["rel", "as", "imagesrcset"] },
    unsafe_handling=Raise,
    url_policy=UrlPolicy(allow_rules=[
      UrlPolicyRule("link", "imagesrcset", srcset_rule),
    ]),
    drop_content_tags=[],
  )
  let srcset_fragment = @html_parser.parse_fragment(
    "<link rel='preload' as='image' imagesrcset='https://evil.example/a 1x'>",
    sanitize=false,
  )
  let srcset_result : Result[@html_parser.Node, @html_parser.HtmlError] = try? @html_parser.sanitize_dom(
    srcset_fragment.root,
    policy=srcset_policy,
  )
  match srcset_result {
    Err(UnsafeHtml(message)) =>
      assert_eq(message, "Unsafe URL in attribute 'imagesrcset'")
    _ => fail("expected unsafe imagesrcset to raise UnsafeHtml")
  }

  let base_policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
    ["base"],
    allowed_attributes={ "base": ["href"] },
    unsafe_handling=Raise,
    url_policy=UrlPolicy(allow_rules=[
      UrlPolicyRule("base", "href", UrlRule(allowed_schemes=["https"])),
    ]),
    drop_content_tags=[],
  )
  let base_fragment = @html_parser.parse_fragment(
    "<base href='https://evil.example/assets/'>",
    sanitize=false,
  )
  let base_result : Result[@html_parser.Node, @html_parser.HtmlError] = try? @html_parser.sanitize_dom(
    base_fragment.root,
    policy=base_policy,
  )
  match base_result {
    Err(UnsafeHtml(message)) =>
      assert_eq(message, "Unsafe URL in attribute 'href' (base tag)")
    _ => fail("expected base href to raise UnsafeHtml")
  }

  let attr_rule : @html_parser.UrlRule = UrlRule(
    allowed_schemes=["https"],
    allowed_hosts=["trusted.example"],
    allow_relative=false,
  )
  let attr_policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
    ["img"],
    allowed_attributes={ "img": ["src", "attributionsrc"] },
    unsafe_handling=Raise,
    url_policy=UrlPolicy(allow_rules=[
      UrlPolicyRule("img", "src", attr_rule),
      UrlPolicyRule("img", "attributionsrc", attr_rule),
    ]),
  )
  let attr_fragment = @html_parser.parse_fragment(
    "<img src='https://trusted.example/x.png' attributionsrc='https://evil.example/register'>",
    sanitize=false,
  )
  let attr_result : Result[@html_parser.Node, @html_parser.HtmlError] = try? @html_parser.sanitize_dom(
    attr_fragment.root,
    policy=attr_policy,
  )
  match attr_result {
    Err(UnsafeHtml(message)) =>
      assert_eq(message, "Unsafe URL in attribute 'attributionsrc'")
    _ => fail("expected unsafe attributionsrc to raise UnsafeHtml")
  }
}

///|
test "sanitize_dom raises for disallowed standalone root" {
  let policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
    ["p"],
    allowed_attributes={},
    unsafe_handling=Raise,
  )
  let fragment = @html_parser.parse_fragment("<x-foo></x-foo>", sanitize=false)
  guard fragment.root.children().get(0) is Some(root) else {
    fail("expected standalone root")
  }
  let result : Result[@html_parser.Node, @html_parser.HtmlError] = try? @html_parser.sanitize_dom(
    root,
    policy~,
  )
  match result {
    Err(UnsafeHtml(message)) =>
      assert_eq(message, "Unsafe tag 'x-foo' (not allowed)")
    _ => fail("expected sanitize_dom to raise UnsafeHtml")
  }
}

///|
test "sanitize_dom raise mode reports dropped content and child tags" {
  let root_script_policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
    ["p"],
    allowed_attributes={},
    unsafe_handling=Raise,
  )
  let root_script_fragment = @html_parser.parse_fragment(
    "<script>alert(1)</script>",
    sanitize=false,
  )
  guard root_script_fragment.root.children().get(0) is Some(root_script) else {
    fail("expected script root")
  }
  let root_script_result : Result[@html_parser.Node, @html_parser.HtmlError] = try? @html_parser.sanitize_dom(
    root_script,
    policy=root_script_policy,
  )
  match root_script_result {
    Err(UnsafeHtml(message)) =>
      assert_eq(message, "Unsafe tag 'script' (dropped content)")
    _ => fail("expected dropped-content root to raise UnsafeHtml")
  }

  let child_script_policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
    ["div"],
    allowed_attributes={ "div": [] },
    unsafe_handling=Raise,
  )
  let child_script_fragment = @html_parser.parse_fragment(
    "<div><script>alert(1)</script></div>",
    sanitize=false,
  )
  guard child_script_fragment.root.children().get(0) is Some(child_script_root) else {
    fail("expected div root")
  }
  let child_script_result : Result[@html_parser.Node, @html_parser.HtmlError] = try? @html_parser.sanitize_dom(
    child_script_root,
    policy=child_script_policy,
  )
  match child_script_result {
    Err(UnsafeHtml(message)) =>
      assert_eq(message, "Unsafe tag 'script' (dropped content)")
    _ => fail("expected dropped-content child to raise UnsafeHtml")
  }

  let child_tag_policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
    ["div"],
    allowed_attributes={ "div": [] },
    unsafe_handling=Raise,
  )
  let child_tag_fragment = @html_parser.parse_fragment(
    "<div><foo></foo></div>",
    sanitize=false,
  )
  guard child_tag_fragment.root.children().get(0) is Some(child_tag_root) else {
    fail("expected div root")
  }
  let child_tag_result : Result[@html_parser.Node, @html_parser.HtmlError] = try? @html_parser.sanitize_dom(
    child_tag_root,
    policy=child_tag_policy,
  )
  match child_tag_result {
    Err(UnsafeHtml(message)) =>
      assert_eq(message, "Unsafe tag 'foo' (not allowed)")
    _ => fail("expected disallowed child tag to raise UnsafeHtml")
  }
}

///|
test "sanitize_dom raise mode reports foreign namespace drops" {
  let root_policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
    ["svg"],
    allowed_attributes={ "svg": [] },
    drop_foreign_namespaces=true,
    unsafe_handling=Raise,
  )
  let root_fragment = @html_parser.parse_fragment(
    "<svg><title>foo</title></svg>",
    sanitize=false,
  )
  guard root_fragment.root.children().get(0) is Some(svg_root) else {
    fail("expected svg root")
  }
  let root_result : Result[@html_parser.Node, @html_parser.HtmlError] = try? @html_parser.sanitize_dom(
    svg_root,
    policy=root_policy,
  )
  match root_result {
    Err(UnsafeHtml(message)) =>
      assert_eq(message, "Unsafe tag 'svg' (foreign namespace)")
    _ => fail("expected foreign namespace root to raise UnsafeHtml")
  }

  let child_policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
    ["div"],
    allowed_attributes={ "div": [] },
    drop_foreign_namespaces=true,
    unsafe_handling=Raise,
  )
  let child_fragment = @html_parser.parse_fragment(
    "<div><svg></svg></div>",
    sanitize=false,
  )
  guard child_fragment.root.children().get(0) is Some(div_root) else {
    fail("expected div root")
  }
  let child_result : Result[@html_parser.Node, @html_parser.HtmlError] = try? @html_parser.sanitize_dom(
    div_root,
    policy=child_policy,
  )
  match child_result {
    Err(UnsafeHtml(message)) =>
      assert_eq(message, "Unsafe tag 'svg' (foreign namespace)")
    _ => fail("expected foreign namespace child to raise UnsafeHtml")
  }
}

///|
test "sanitize_dom raise mode reports html namespace foreign root drops" {
  let policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
    ["svg", "rect"],
    allowed_attributes={ "rect": ["width", "height"] },
    drop_foreign_namespaces=true,
    drop_content_tags=[],
    unsafe_handling=Raise,
  )
  let svg = @html_parser.element("svg", ns="html", children=[
    @html_parser.element("rect", ns="html", attrs={
      "width": Some("10"),
      "height": Some("10"),
    }),
  ])
  let result : Result[@html_parser.Node, @html_parser.HtmlError] = try? @html_parser.sanitize_dom(
    svg,
    policy~,
  )
  match result {
    Err(UnsafeHtml(message)) =>
      assert_eq(message, "Unsafe tag 'svg' (foreign namespace)")
    _ => fail("expected html namespace svg root to raise UnsafeHtml")
  }
}

///|
test "public unsafe handling collect and raise modes stay stable" {
  let doc = @html_parser.parse_fragment(
    "<p onclick=x>ok</p><script>x</script><a href=javascript:x>link</a>",
    sanitize=false,
  )
  let collect_policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
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

  let raise_policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
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
  let policy : @html_parser.SanitizationPolicy = SanitizationPolicy(
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
