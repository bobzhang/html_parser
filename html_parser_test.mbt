///|
fn test_attr_id(node : @html_parser.Node) -> String {
  match node.attrs().get("id") {
    Some(Some(value)) => value
    _ => ""
  }
}

///|
fn assert_node_origin(
  node : @html_parser.Node,
  offset : Int,
  line : Int,
  col : Int,
) -> Unit raise {
  guard node.origin_offset() is Some(actual_offset) && actual_offset == offset else {
    fail("unexpected origin offset")
  }
  guard node.origin_line() is Some(actual_line) && actual_line == line else {
    fail("unexpected origin line")
  }
  guard node.origin_col() is Some(actual_col) && actual_col == col else {
    fail("unexpected origin column")
  }
  guard node.origin_location() is Some((actual_line, actual_col)) &&
    actual_line == line &&
    actual_col == col else {
    fail("unexpected origin location")
  }
}

///|
fn repeat_for_test(value : String, count : Int) -> String {
  let out = StringBuilder::new(size_hint=value.length() * count)
  for _ in 0..<count {
    out.write_string(value)
  }
  out.to_string()
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
test "sanitize_dom default policy keeps table captions" {
  let root = @html_parser.fragment(children=[
    @html_parser.element("table", children=[
      @html_parser.element("caption", children=[@html_parser.text("Summary")]),
    ]),
  ])
  assert_eq(
    @html_parser.sanitize_dom(root).to_html(pretty=false),
    "<table><caption>Summary</caption></table>",
  )
}

///|
test "sanitize_dom document policy preserves shell and doctype" {
  let doc = @html_parser.parse(
    "<!DOCTYPE html><!--x--><html><head><title>T</title><script>bad</script></head><body><p onclick=x>ok</p></body></html>",
    sanitize=false,
  )
  let sanitized = @html_parser.sanitize_dom(doc.root)
  assert_eq(
    sanitized.to_html(pretty=false),
    "<!DOCTYPE html><html><head><title>T</title></head><body><p>ok</p></body></html>",
  )
}

///|
test "sanitize_dom custom policy keeps comments and can drop subtrees" {
  let keep_shell = @html_parser.parse(
    "<!DOCTYPE html><!--x--><p>ok</p><span>kept text</span>",
    sanitize=false,
  )
  let keep_policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    allowed_attributes={ "*": [], "p": [] },
    drop_comments=false,
    drop_doctype=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(keep_shell.root, policy=keep_policy).to_html(
      pretty=false,
    ),
    "<!DOCTYPE html><!--x--><p>ok</p>kept text",
  )
  let fragment = @html_parser.parse_fragment(
    "<div>keep<sarcasm><b>drop</b></sarcasm><p>ok</p></div>",
    sanitize=false,
  )
  let drop_policy = @html_parser.SanitizationPolicy::new(
    ["div", "p"],
    allowed_attributes={ "*": [], "div": [], "p": [] },
    disallowed_tag_handling=Drop,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy=drop_policy).to_html(
      pretty=false,
    ),
    "<div>keep<p>ok</p></div>",
  )
}

///|
test "sanitize_dom handles standalone text comment and doctype roots" {
  assert_eq(@html_parser.sanitize_dom(@html_parser.text("x")).to_html(), "x")
  let keep_policy = @html_parser.SanitizationPolicy::new(
    [],
    allowed_attributes={},
    drop_comments=false,
    drop_doctype=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(@html_parser.comment("x"), policy=keep_policy).to_html(
      pretty=false,
    ),
    "<!--x-->",
  )
  assert_eq(
    @html_parser.sanitize_dom(@html_parser.doctype(), policy=keep_policy).to_html(
      pretty=false,
    ),
    "<!DOCTYPE html>",
  )
  assert_eq(
    @html_parser.sanitize_dom(@html_parser.comment("x")).to_html(pretty=false),
    "",
  )
  assert_eq(
    @html_parser.sanitize_dom(@html_parser.doctype()).to_html(pretty=false),
    "",
  )
  let raise_policy = @html_parser.SanitizationPolicy::new(
    [],
    allowed_attributes={},
    unsafe_handling=Raise,
  )
  let comment_result = try? @html_parser.sanitize_dom(
    @html_parser.comment("x"),
    policy=raise_policy,
  )
  match comment_result {
    Ok(clean) => assert_eq(clean.to_html(pretty=false), "")
    Err(_) => fail("dropped comments should not use unsafe raise handling")
  }
  let doctype_result = try? @html_parser.sanitize_dom(
    @html_parser.doctype(),
    policy=raise_policy,
  )
  match doctype_result {
    Ok(clean) => assert_eq(clean.to_html(pretty=false), "")
    Err(_) => fail("dropped doctypes should not use unsafe raise handling")
  }
}

///|
test "sanitize_dom recurses through nested containers and empty templates" {
  let text_policy = @html_parser.SanitizationPolicy::new([], allowed_attributes={
    "*": [],
  })
  let nested = @html_parser.fragment(children=[
    @html_parser.fragment(children=[@html_parser.text("t")]),
  ])
  assert_eq(
    @html_parser.sanitize_dom(nested, policy=text_policy).to_html(pretty=false),
    "t",
  )
  let template_policy = @html_parser.SanitizationPolicy::new(["template"], allowed_attributes={
    "*": [],
    "template": [],
  })
  let root = @html_parser.fragment(children=[@html_parser.element("template")])
  assert_eq(
    @html_parser.sanitize_dom(root, policy=template_policy).to_html(
      pretty=false,
    ),
    "<template></template>",
  )
}

///|
test "sanitize_dom handles standalone root element edge cases" {
  let unwrap_policy = @html_parser.SanitizationPolicy::new(["div"], allowed_attributes={
    "*": [],
    "div": [],
  })
  assert_eq(
    @html_parser.sanitize_dom(
      @html_parser.element("div", ns="svg"),
      policy=unwrap_policy,
    ).to_html(pretty=false),
    "",
  )
  assert_eq(
    @html_parser.sanitize_dom(
      @html_parser.element("span", children=[@html_parser.text("x")]),
      policy=unwrap_policy,
    ).to_html(pretty=false),
    "x",
  )
  let drop_content_policy = @html_parser.SanitizationPolicy::new(
    ["div", "img"],
    allowed_attributes={ "*": [], "div": [], "img": ["src"] },
    url_policy=@html_parser.UrlPolicy::new(allow_rules=[]),
    drop_content_tags=["SCRIPT"],
    disallowed_tag_handling=Unwrap,
  )
  assert_eq(
    @html_parser.sanitize_dom(
      @html_parser.element("ScRiPt", children=[
        @html_parser.element("img", attrs={
          "src": Some("pixel"),
          "onerror": Some("alert(1)"),
        }),
      ]),
      policy=drop_content_policy,
    ).to_html(pretty=false),
    "",
  )
}

///|
test "sanitize_dom escape handling emits disallowed tags as text" {
  let fragment = @html_parser.parse_fragment(
    "<b>Hello <sarcasm title='tone' onclick=x><i onclick=y>world</i><script>bad</script></sarcasm></b>",
    sanitize=false,
  )
  let policy = @html_parser.SanitizationPolicy::new(
    ["b", "i"],
    allowed_attributes={ "*": [], "b": [], "i": [] },
    disallowed_tag_handling=Escape,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<b>Hello &lt;sarcasm title='tone' onclick=x&gt;<i>world</i>&lt;/sarcasm&gt;</b>",
  )
}

///|
test "sanitize_dom escape handling can return fragments for standalone roots" {
  let policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    allowed_attributes={ "*": [], "p": [] },
    drop_content_tags=[],
    disallowed_tag_handling=Escape,
  )
  let standalone = @html_parser.element(
    "widget",
    attrs={ "data-x": Some("1") },
    children=[@html_parser.text("ok")],
  )
  let sanitized = @html_parser.sanitize_dom(standalone, policy~)
  assert_true(sanitized.kind() is Fragment)
  assert_eq(
    sanitized.to_html(pretty=false),
    "&lt;widget data-x=\"1\"&gt;ok&lt;/widget&gt;",
  )
  let image = @html_parser.fragment(children=[
    @html_parser.element("img", attrs={ "src": Some("/safe.png") }),
  ])
  assert_eq(
    @html_parser.sanitize_dom(image, policy~).to_html(pretty=false),
    "&lt;img src=\"/safe.png\"&gt;",
  )
}

///|
test "sanitize_dom escape handling preserves disallowed template children" {
  let policy = @html_parser.SanitizationPolicy::new(
    ["b"],
    allowed_attributes={ "*": [], "b": [] },
    drop_content_tags=[],
    disallowed_tag_handling=Escape,
  )
  let fragment = @html_parser.parse_fragment(
    "<template><b>x</b></template>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "&lt;template&gt;<b>x</b>&lt;/template&gt;",
  )
}

///|
test "sanitize_dom removes parser escape-only text outside escape mode" {
  let fragment = @html_parser.parse_fragment(
    "safe <!DOCTYPE and y>z",
    context=@html_parser.FragmentContext::new("div"),
    sanitize=false,
  )
  let policy = @html_parser.SanitizationPolicy::new(
    [],
    allowed_attributes={ "*": [] },
    disallowed_tag_handling=Drop,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "safe z",
  )
}

///|
test "parser escape-only sentinels stay hidden from serializers" {
  let fragment = @html_parser.parse_fragment(
    "safe <!DOCTYPE and y>z",
    context=@html_parser.FragmentContext::new("div"),
    sanitize=false,
  )
  assert_eq(fragment.to_html(pretty=false), "safe z")
  assert_eq(fragment.to_html(pretty=true), "safe\nz")
  assert_eq(fragment.to_text(separator="", strip=false), "safe z")
  assert_eq(
    fragment.to_text(separator="|", strip=false, separator_blocks_only=true),
    "safe z",
  )
  assert_eq(fragment.to_markdown(), "safe z")

  let inline = @html_parser.parse_fragment(
    "<p>safe <!DOCTYPE and y>z</p>",
    context=@html_parser.FragmentContext::new("div"),
    sanitize=false,
  )
  assert_eq(inline.to_html(pretty=false), "<p>safe z</p>")
  assert_eq(inline.to_html(pretty=true), "<p>safe z</p>")
  assert_eq(inline.to_text(separator="", strip=false), "safe z")

  let inline_run = @html_parser.parse_fragment(
    "<div>safe <!DOCTYPE and y> <span>ok</span></div>",
    context=@html_parser.FragmentContext::new("div"),
    sanitize=false,
  )
  assert_eq(inline_run.to_html(pretty=true), "<div>safe  <span>ok</span></div>")

  let compact_inline = @html_parser.parse_fragment(
    "<div>safe <!DOCTYPE and y><span>ok</span></div>",
    context=@html_parser.FragmentContext::new("div"),
    sanitize=false,
  )
  assert_eq(
    compact_inline.to_html(pretty=true),
    "<div>safe <span>ok</span></div>",
  )

  let hidden_only = @html_parser.parse_fragment(
    "<div> <!DOCTYPE and y> </div>",
    context=@html_parser.FragmentContext::new("div"),
    sanitize=false,
  )
  assert_eq(hidden_only.to_html(pretty=true), "<div></div>")
}

///|
test "sanitize_dom filters attributes and dangerous URLs" {
  let fragment = @html_parser.parse_fragment(
    "<div id=x onclick=alert(1) srcdoc='<p>p</p>' x:y=z title=t class=c data-x=y><a href='javascript:alert(1)' title='t'>x</a><a href='//example.com/path'>y</a><img src='https://x' alt=abs><img src='/safe.png' onerror=x alt=ok></div>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root).to_html(pretty=false),
    "<div id=\"x\" title=\"t\" class=\"c\"><a title=\"t\">x</a><a href=\"https://example.com/path\">y</a><img alt=\"abs\"><img src=\"/safe.png\" alt=\"ok\"></div>",
  )
}

///|
test "sanitize_dom preserves allowed valueless non-url attributes" {
  let policy = @html_parser.SanitizationPolicy::new(["div"], allowed_attributes={
    "*": [],
    "div": ["disabled"],
  })
  let fragment = @html_parser.parse_fragment(
    "<div disabled></div>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<div disabled></div>",
  )
}

///|
test "sanitize_dom lowercases manual DOM attribute names" {
  let root = @html_parser.element(
    "a",
    attrs={ "HREF": Some("https://example.com") },
    children=[@html_parser.text("x")],
  )
  assert_eq(
    @html_parser.sanitize_dom(root).to_html(pretty=false),
    "<a href=\"https://example.com\">x</a>",
  )
}

///|
test "sanitize_dom reports valueless url and style attributes" {
  let url_policy = @html_parser.UrlPolicy::new(default_handling=UrlAllow, allow_rules=[
    @html_parser.UrlPolicyRule::new(
      "a",
      "href",
      @html_parser.UrlRule::new(allowed_schemes=["https"]),
    ),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    ["a", "span", "div"],
    allowed_attributes={
      "*": [],
      "a": ["href"],
      "span": ["style"],
      "div": ["disabled"],
    },
    allowed_css_properties=["color"],
    unsafe_handling=Collect,
    url_policy~,
  )
  policy.reset_collected_security_errors()
  let root = @html_parser.fragment(children=[
    @html_parser.element("a", attrs={ "href": None }, children=[
      @html_parser.text("link"),
    ]),
    @html_parser.element("span", attrs={ "style": None }, children=[
      @html_parser.text("style"),
    ]),
    @html_parser.element("div", attrs={ "disabled": None }, children=[
      @html_parser.text("ok"),
    ]),
  ])
  assert_eq(
    @html_parser.sanitize_dom(root, policy~).to_html(pretty=false),
    "<a>link</a><span>style</span><div disabled>ok</div>",
  )
  let errors = policy.collected_security_errors()
  assert_eq(errors.length(), 2)
  assert_eq(errors[0].code, "unsafe-html")
  assert_eq(errors[0].category, "security")
  assert_eq(errors[1].code, "unsafe-html")
  assert_eq(errors[1].category, "security")
}

///|
test "sanitize_dom can collect and raise unsafe findings" {
  let safe_policy = @html_parser.SanitizationPolicy::new(
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

  let collect_policy = @html_parser.SanitizationPolicy::new(
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

  let raise_policy = @html_parser.SanitizationPolicy::new(
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
  let attr_policy = @html_parser.SanitizationPolicy::new(
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

  let url_policy = @html_parser.UrlPolicy::new(allow_rules=[
    @html_parser.UrlPolicyRule::new(
      "a",
      "href",
      @html_parser.UrlRule::new(allowed_schemes=["https"]),
    ),
  ])
  let link_policy = @html_parser.SanitizationPolicy::new(
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

  let meta_policy = @html_parser.SanitizationPolicy::new(
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
  let srcset_rule = @html_parser.UrlRule::new(
    allowed_schemes=["https"],
    allowed_hosts=["trusted.example"],
    allow_relative=false,
  )
  let srcset_policy = @html_parser.SanitizationPolicy::new(
    ["link"],
    allowed_attributes={ "link": ["rel", "as", "imagesrcset"] },
    unsafe_handling=Raise,
    url_policy=@html_parser.UrlPolicy::new(allow_rules=[
      @html_parser.UrlPolicyRule::new("link", "imagesrcset", srcset_rule),
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

  let base_policy = @html_parser.SanitizationPolicy::new(
    ["base"],
    allowed_attributes={ "base": ["href"] },
    unsafe_handling=Raise,
    url_policy=@html_parser.UrlPolicy::new(allow_rules=[
      @html_parser.UrlPolicyRule::new(
        "base",
        "href",
        @html_parser.UrlRule::new(allowed_schemes=["https"]),
      ),
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

  let attr_rule = @html_parser.UrlRule::new(
    allowed_schemes=["https"],
    allowed_hosts=["trusted.example"],
    allow_relative=false,
  )
  let attr_policy = @html_parser.SanitizationPolicy::new(
    ["img"],
    allowed_attributes={ "img": ["src", "attributionsrc"] },
    unsafe_handling=Raise,
    url_policy=@html_parser.UrlPolicy::new(allow_rules=[
      @html_parser.UrlPolicyRule::new("img", "src", attr_rule),
      @html_parser.UrlPolicyRule::new("img", "attributionsrc", attr_rule),
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
  let policy = @html_parser.SanitizationPolicy::new(
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
  let root_script_policy = @html_parser.SanitizationPolicy::new(
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

  let child_script_policy = @html_parser.SanitizationPolicy::new(
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

  let child_tag_policy = @html_parser.SanitizationPolicy::new(
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
  let root_policy = @html_parser.SanitizationPolicy::new(
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

  let child_policy = @html_parser.SanitizationPolicy::new(
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
  let policy = @html_parser.SanitizationPolicy::new(
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
test "sanitize_dom drop mode returns empty fragment for disallowed standalone root" {
  let policy = @html_parser.SanitizationPolicy::new(
    [],
    allowed_attributes={},
    disallowed_tag_handling=Drop,
  )
  let root = @html_parser.element("x-foo", children=[@html_parser.text("bad")])
  let sanitized = @html_parser.sanitize_dom(root, policy~)
  assert_true(sanitized.kind() is Fragment)
  assert_eq(sanitized.children().length(), 0)
  assert_eq(sanitized.to_html(pretty=false), "")
}

///|
test "sanitize_dom collects rawtext and foreign integration findings" {
  let rawtext_policy = @html_parser.SanitizationPolicy::new(
    ["style"],
    allowed_attributes={ "style": [] },
    drop_content_tags=[],
    unsafe_handling=Collect,
  )
  let rawtext = @html_parser.fragment(children=[
    @html_parser.element("style", children=[
      @html_parser.text("</style><b>x</b>"),
    ]),
  ])
  assert_eq(
    @html_parser.sanitize_dom(rawtext, policy=rawtext_policy).to_html(
      pretty=false,
    ),
    "<style>&lt;/style><b>x</b></style>",
  )
  let rawtext_errors = rawtext_policy.collected_security_errors()
  assert_eq(rawtext_errors.length(), 1)
  assert_eq(rawtext_errors[0].code, "unsafe-html")
  assert_eq(rawtext_errors[0].category, "security")
  assert_eq(
    rawtext_errors[0].message,
    "Unsafe raw text inside <style> contains a closing tag sequence",
  )

  let foreign_policy = @html_parser.SanitizationPolicy::new(
    ["svg", "title", "script"],
    allowed_attributes={ "svg": [], "title": [], "script": [] },
    drop_foreign_namespaces=false,
    drop_content_tags=[],
    unsafe_handling=Collect,
  )
  let foreign = @html_parser.parse_fragment(
    "<svg><title>Hello<script>bad</script></title></svg>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(foreign.root, policy=foreign_policy).to_html(
      pretty=false,
    ),
    "<svg><title>Hello</title></svg>",
  )
  let foreign_errors = foreign_policy.collected_security_errors()
  assert_eq(foreign_errors.length(), 1)
  assert_eq(foreign_errors[0].code, "unsafe-html")
  assert_eq(foreign_errors[0].category, "security")
  assert_eq(
    foreign_errors[0].message,
    "Unsafe HTML child inside foreign integration point <title> was dropped",
  )
}

///|
test "sanitize_dom strips invisible unicode from text and attributes" {
  let invisible = "\u{FE00}\u{E0100}\u{200B}\u{202E}\u{E000}"
  let fragment = @html_parser.parse_fragment(
    "<p title=\"a" +
    invisible +
    "b\">a" +
    invisible +
    "b<a href=\"java\u{200B}script:alert(1)\">x</a></p>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root).to_html(pretty=false),
    "<p title=\"ab\">ab<a>x</a></p>",
  )

  let collect_policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    allowed_attributes={ "p": ["title"] },
    unsafe_handling=Collect,
  )
  let attr_fragment = @html_parser.parse_fragment(
    "<p title='a\u{200B}b'>x</p>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(attr_fragment.root, policy=collect_policy).to_html(
      pretty=false,
    ),
    "<p title=\"ab\">x</p>",
  )
  let errors = collect_policy.collected_security_errors()
  assert_eq(errors.length(), 1)
  assert_eq(
    errors[0].message,
    "Stripped invisible Unicode from attribute(s): title",
  )

  let raise_policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    allowed_attributes={ "p": ["title"] },
    unsafe_handling=Raise,
  )
  let raise_fragment = @html_parser.parse_fragment(
    "<p title='a\u{200B}b'>x</p>",
    sanitize=false,
  )
  let result = try? @html_parser.sanitize_dom(
    raise_fragment.root,
    policy=raise_policy,
  )
  match result {
    Err(UnsafeHtml(message)) =>
      assert_eq(message, "Stripped invisible Unicode from attribute(s): title")
    _ => fail("expected invisible Unicode attribute stripping to raise")
  }
}

///|
test "sanitize_dom can preserve invisible unicode by policy" {
  let invisible = "\u{FE00}\u{200B}\u{202E}\u{E000}"
  let fragment = @html_parser.parse_fragment(
    "<p title=\"a" + invisible + "b\">a" + invisible + "b</p>",
    sanitize=false,
  )
  let policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    allowed_attributes={ "p": ["title"] },
    strip_invisible_unicode=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<p title=\"a" + invisible + "b\">a" + invisible + "b</p>",
  )
}

///|
test "sanitize_dom force_link_rel permits and merges anchor rel tokens" {
  let default_rel = @html_parser.parse_fragment(
    "<a href='/x' rel='noopener'>x</a>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(default_rel.root).to_html(pretty=false),
    "<a href=\"/x\">x</a>",
  )
  let forced = @html_parser.parse_fragment(
    "<a href='https://example.com'>one</a><a href='/x' rel='External\tNOOPENER\nfriend'>two</a><a rel>three</a><a href='javascript:evil' rel='friend'>bad</a>",
    sanitize=false,
  )
  let policy = @html_parser.SanitizationPolicy::new(
    ["a"],
    allowed_attributes={ "*": [], "a": ["href"] },
    force_link_rel=["NoOpener", "noreferrer", "noopener"],
  )
  assert_eq(
    @html_parser.sanitize_dom(forced.root, policy~).to_html(pretty=false),
    "<a href=\"https://example.com\" rel=\"noopener noreferrer\">one</a><a href=\"/x\" rel=\"external noopener friend noreferrer\">two</a><a rel=\"noopener noreferrer\">three</a><a rel=\"friend noopener noreferrer\">bad</a>",
  )
}

///|
test "sanitize_dom normalizes mixed-case valueless attributes" {
  let policy = @html_parser.SanitizationPolicy::new(["button"], allowed_attributes={
    "*": [],
    "button": ["disabled", "title"],
  })
  let button = @html_parser.element("button", attrs={
    "DISABLED": None,
    "TITLE": Some("ok"),
    "DATA-X": Some("drop"),
  })
  assert_eq(
    @html_parser.sanitize_dom(button, policy~).to_html(pretty=false),
    "<button disabled title=\"ok\"></button>",
  )
}

///|
test "sanitize_dom filters inline style declarations by property allowlist" {
  let no_css = @html_parser.parse_fragment(
    "<p style='color: red'>x</p>",
    sanitize=false,
  )
  let no_css_policy = @html_parser.SanitizationPolicy::new(["p"], allowed_attributes={
    "*": [],
    "p": ["style"],
  })
  assert_eq(
    @html_parser.sanitize_dom(no_css.root, policy=no_css_policy).to_html(
      pretty=false,
    ),
    "<p>x</p>",
  )
  let styled = @html_parser.parse_fragment(
    "<p style='; color; color: ; co_lor: red; margin: 0; COLOR: red; font-weight: 700; background-image: url(/x.png); width: expression(alert(1))'>ok</p><p style>empty</p><p STYLE='color: blue; text-align: center; background-image: u/**/rl(/x.png)'>case</p><p style='color: /*unterminated'>comment</p><p style=': red; color: orange'>empty-prop</p>",
    sanitize=false,
  )
  let style_policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    allowed_attributes={ "*": [], "p": ["style"] },
    allowed_css_properties=[
      "color", "font-weight", "background-image", "width", "text-align",
    ],
  )
  assert_eq(
    @html_parser.sanitize_dom(styled.root, policy=style_policy).to_html(
      pretty=false,
    ),
    "<p style=\"color: red; font-weight: 700\">ok</p><p>empty</p><p style=\"color: blue; text-align: center\">case</p><p>comment</p><p style=\"color: orange\">empty-prop</p>",
  )
}

///|
test "sanitize_dom applies css url function policy rules" {
  let css_url_rule = @html_parser.UrlRule::new(
    allowed_schemes=[],
    allow_relative=true,
    resolve_protocol_relative=None,
  )
  let url_policy = @html_parser.UrlPolicy::new(allow_rules=[
    @html_parser.UrlPolicyRule::new("*", "style:background-image", css_url_rule),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    allowed_attributes={ "*": [], "p": ["style"] },
    allowed_css_properties=["background-image", "color"],
    url_policy~,
  )
  let fragment = @html_parser.parse_fragment(
    "<p style='background-image: url(/safe.png); color: red'>ok</p><p style=\"background-image: url('https://evil.example/x.png'); color: blue\">bad</p><p style=\"background-image: image-set(url('/safe.png') 1x); color: green\">blocked</p><p style='background-image: URL(  \"/safe-2.png\"  )'>case</p>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<p style=\"background-image: url('/safe.png'); color: red\">ok</p><p style=\"color: blue\">bad</p><p style=\"color: green\">blocked</p><p style=\"background-image: url('/safe-2.png')\">case</p>",
  )
}

///|
test "sanitize_dom rejects comments in css url function values" {
  let css_url_rule = @html_parser.UrlRule::new(
    allowed_schemes=[],
    allow_relative=true,
    resolve_protocol_relative=None,
  )
  let url_policy = @html_parser.UrlPolicy::new(allow_rules=[
    @html_parser.UrlPolicyRule::new("*", "style:background-image", css_url_rule),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    allowed_attributes={ "*": [], "p": ["style"] },
    allowed_css_properties=["background-image", "color"],
    url_policy~,
  )
  let fragment = @html_parser.parse_fragment(
    "<p style='background-image: url(/x.png)/*comment*/; color: red'>comment</p><p style='background-image: linear-gradient(red, blue), url(/y.png); color: blue'>gradient</p>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<p style=\"color: red\">comment</p><p style=\"background-image: linear-gradient(red, blue), url('/y.png'); color: blue\">gradient</p>",
  )
}

///|
test "sanitize_dom rejects malformed css url function values" {
  let css_url_rule = @html_parser.UrlRule::new(
    allowed_schemes=[],
    allow_relative=true,
    resolve_protocol_relative=None,
  )
  let url_policy = @html_parser.UrlPolicy::new(allow_rules=[
    @html_parser.UrlPolicyRule::new("*", "style:background-image", css_url_rule),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    allowed_attributes={ "*": [], "p": ["style"] },
    allowed_css_properties=["background-image", "color"],
    url_policy~,
  )
  let fragment = @html_parser.parse_fragment(
    "<p style=\"background-image: url('/x\\y.png'); color: red\">backslash</p><p style='background-image: url(/x y); color: blue'>space</p><p style='background-image: url(/x\u{007F}y); color: green'>del</p><p style='background-image: url(); color: black'>empty</p><p style=\"background-image: url('/x')x; color: purple\">tail</p><p style=\"background-image: url('/unterminated); color: olive\">missing-quote</p><p style=\"background-image: url('/missing-paren'; color: maroon\">missing-paren</p><p style='background-image: u rl(/x.png); color: lime'>obfuscated</p><p style='background-image: u\trl(/x.png); color: aqua'>tab</p><p style=\"background-image: url('/spaced.png'   ); color: navy\">spaced</p><p style=\"background-image: url(/ok.png), url('/next.png'); color: teal\">ok</p>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<p style=\"color: red\">backslash</p><p style=\"color: blue\">space</p><p style=\"color: green\">del</p><p style=\"color: black\">empty</p><p style=\"color: purple\">tail</p><p style=\"color: olive\">missing-quote</p><p style=\"color: maroon\">missing-paren</p><p style=\"color: lime\">obfuscated</p><p style=\"color: aqua\">tab</p><p style=\"background-image: url('/spaced.png'); color: navy\">spaced</p><p style=\"background-image: url('/ok.png'), url('/next.png'); color: teal\">ok</p>",
  )
}

///|
test "sanitize_dom drops unquoted css url with missing close paren" {
  let css_url_rule = @html_parser.UrlRule::new(
    allowed_schemes=[],
    allow_relative=true,
    resolve_protocol_relative=None,
  )
  let url_policy = @html_parser.UrlPolicy::new(allow_rules=[
    @html_parser.UrlPolicyRule::new("*", "style:background-image", css_url_rule),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    allowed_attributes={ "*": [], "p": ["style"] },
    allowed_css_properties=["background-image", "color"],
    url_policy~,
  )
  let fragment = @html_parser.parse_fragment(
    "<p style='background-image: url(/missing; color: silver'>missing-raw-paren</p>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<p style=\"color: silver\">missing-raw-paren</p>",
  )
}

///|
test "sanitize_dom proxies validated URL values" {
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
        "srcset",
        @html_parser.UrlRule::new(allowed_schemes=["https"]),
      ),
      @html_parser.UrlPolicyRule::new(
        "p",
        "style:background-image",
        @html_parser.UrlRule::new(
          allowed_schemes=["https"],
          proxy=@html_parser.UrlProxy::new("/asset-proxy", param="src"),
        ),
      ),
    ],
  )
  let policy = @html_parser.SanitizationPolicy::new(
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
  let missing_proxy_policy = @html_parser.UrlPolicy::new(
    default_handling=UrlProxy,
    allow_rules=[
      @html_parser.UrlPolicyRule::new(
        "a",
        "href",
        @html_parser.UrlRule::new(allowed_schemes=["https"]),
      ),
    ],
  )
  let missing_policy = @html_parser.SanitizationPolicy::new(
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
  let empty_proxy_policy = @html_parser.UrlPolicy::new(
    default_handling=UrlProxy,
    proxy=@html_parser.UrlProxy::new(""),
    allow_rules=[
      @html_parser.UrlPolicyRule::new(
        "a",
        "href",
        @html_parser.UrlRule::new(allowed_schemes=["https"]),
      ),
    ],
  )
  let empty_policy = @html_parser.SanitizationPolicy::new(
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
        "srcset",
        @html_parser.UrlRule::new(allowed_schemes=["https"]),
      ),
      @html_parser.UrlPolicyRule::new(
        "p",
        "style:background-image",
        @html_parser.UrlRule::new(allowed_schemes=["https"]),
      ),
    ],
  )
  let policy = @html_parser.SanitizationPolicy::new(
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
test "sanitize_dom rejects malformed URL schemes when relatives are disabled" {
  let url_policy = @html_parser.UrlPolicy::new(default_allow_relative=false, allow_rules=[
    @html_parser.UrlPolicyRule::new(
      "a",
      "href",
      @html_parser.UrlRule::new(allowed_schemes=["https"], allow_relative=false),
    ),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
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
  let url_filter = @html_parser.UrlFilter::new(fn(_tag, attr, value) {
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
  let url_policy = @html_parser.UrlPolicy::new(url_filter~, allow_rules=[
    @html_parser.UrlPolicyRule::new(
      "a",
      "href",
      @html_parser.UrlRule::new(allowed_schemes=["https"], allowed_hosts=[
        "trusted.example",
      ]),
    ),
    @html_parser.UrlPolicyRule::new(
      "a",
      "ping",
      @html_parser.UrlRule::new(allowed_schemes=["https"], allowed_hosts=[
        "trusted.example",
      ]),
    ),
    @html_parser.UrlPolicyRule::new(
      "img",
      "srcset",
      @html_parser.UrlRule::new(allowed_schemes=["https"], allowed_hosts=[
        "trusted.example",
      ]),
    ),
    @html_parser.UrlPolicyRule::new(
      "p",
      "style:background-image",
      @html_parser.UrlRule::new(allowed_schemes=["https"], allowed_hosts=[
        "trusted.example",
      ]),
    ),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
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
  let url_filter = @html_parser.UrlFilter::new(fn(_tag, _attr, value) {
    Some(value)
  })
  let repr = url_filter.to_repr().to_string()
  assert_true(repr.contains("UrlFilter"))
  assert_eq(repr.contains("callback"), false)
}

///|
test "sanitize_dom validates css url filter rewrites" {
  let url_filter = @html_parser.UrlFilter::new(fn(_tag, attr, value) {
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
  let css_rule = @html_parser.UrlRule::new(
    allowed_schemes=[],
    allow_relative=true,
    resolve_protocol_relative=None,
  )
  let url_policy = @html_parser.UrlPolicy::new(url_filter~, allow_rules=[
    @html_parser.UrlPolicyRule::new("*", "style:background-image", css_rule),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
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
  let url_filter = @html_parser.UrlFilter::new(fn(_tag, attr, value) {
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
  let trusted_rule = @html_parser.UrlRule::new(allowed_schemes=["https"], allowed_hosts=[
    "trusted.example",
  ])
  let url_policy = @html_parser.UrlPolicy::new(url_filter~, allow_rules=[
    @html_parser.UrlPolicyRule::new("a", "href", trusted_rule),
    @html_parser.UrlPolicyRule::new("a", "ping", trusted_rule),
    @html_parser.UrlPolicyRule::new("img", "src", trusted_rule),
    @html_parser.UrlPolicyRule::new("img", "srcset", trusted_rule),
    @html_parser.UrlPolicyRule::new("img", "attributionsrc", trusted_rule),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
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
  let trusted_rule = @html_parser.UrlRule::new(
    allowed_schemes=["https"],
    allowed_hosts=["trusted.example"],
    allow_relative=false,
  )
  let url_policy = @html_parser.UrlPolicy::new(default_allow_relative=false, allow_rules=[
    @html_parser.UrlPolicyRule::new("img", "srcset", trusted_rule),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
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
  let trusted_rule = @html_parser.UrlRule::new(
    allowed_schemes=["https"],
    allowed_hosts=["trusted.example"],
    allow_relative=false,
  )
  let url_policy = @html_parser.UrlPolicy::new(default_allow_relative=false, allow_rules=[
    @html_parser.UrlPolicyRule::new("a", "ping", trusted_rule),
    @html_parser.UrlPolicyRule::new("img", "attributionsrc", trusted_rule),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
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
  let host_rule = @html_parser.UrlRule::new(
    allowed_schemes=["https", "mailto"],
    allowed_hosts=["trusted.example", "::1"],
    allow_relative=false,
  )
  let url_policy = @html_parser.UrlPolicy::new(default_allow_relative=false, allow_rules=[
    @html_parser.UrlPolicyRule::new("a", "href", host_rule),
    @html_parser.UrlPolicyRule::new("img", "src", host_rule),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
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
test "css_preset_text allows conservative inline text styling" {
  let policy = @html_parser.SanitizationPolicy::new(
    ["div"],
    allowed_attributes={ "*": [], "div": ["style"] },
    allowed_css_properties=@html_parser.css_preset_text(),
  )
  let styled = @html_parser.parse_fragment(
    "<div style='color: red; position: fixed; top: 0'>x</div><div style='position: fixed'>y</div>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(styled.root, policy~).to_html(pretty=false),
    "<div style=\"color: red\">x</div><div>y</div>",
  )

  let mutated = @html_parser.css_preset_text()
  mutated.clear()
  let fresh = @html_parser.SanitizationPolicy::new(
    ["span"],
    allowed_attributes={ "span": ["style"] },
    allowed_css_properties=@html_parser.css_preset_text(),
  )
  let span = @html_parser.parse_fragment(
    "<span style='font-weight: 700'>ok</span>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(span.root, policy=fresh).to_html(pretty=false),
    "<span style=\"font-weight: 700\">ok</span>",
  )
}

///|
test "sanitize_dom hardens allowed rawtext element contents" {
  let policy = @html_parser.SanitizationPolicy::new(
    ["style", "script", "img", "span"],
    allowed_attributes={ "img": ["src", "alt"], "span": [] },
    drop_content_tags=[],
  )
  let style = @html_parser.element("style", children=[
    @html_parser.text("</sty"),
    @html_parser.text("le><img src=x onerror=1>"),
  ])
  let script = @html_parser.element("script", children=[
    @html_parser.text("a"),
    @html_parser.element("span", children=[@html_parser.text("ignored")]),
    @html_parser.text("</script><img src=x onerror=1>"),
  ])
  let fragment = @html_parser.fragment(children=[style, script])
  let clean = @html_parser.sanitize_dom(fragment, policy~)
  let out = clean.to_html(pretty=false)
  assert_eq(
    out, "<style>&lt;/style><img src=x onerror=1></style><script>a&lt;/script><img src=x onerror=1></script>",
  )
  let reparsed = @html_parser.parse_fragment(out, sanitize=false)
  assert_eq(reparsed.query("img").length(), 0)
}

///|
test "sanitize_dom textarea markdown passthrough cannot break out" {
  let policy = @html_parser.SanitizationPolicy::new(
    ["textarea", "img"],
    allowed_attributes={ "*": [], "img": ["src", "alt"] },
    url_policy=@html_parser.UrlPolicy::new(allow_rules=[]),
    drop_content_tags=[],
  )
  let fragment = @html_parser.parse_fragment(
    "<textarea>&lt;/textarea&gt;&lt;img src=x onerror=alert(1)&gt;</textarea>",
    sanitize=false,
  )
  let clean = @html_parser.sanitize_dom(fragment.root, policy~)
  let markdown = clean.to_markdown(html_passthrough=true)
  assert_true(markdown.contains("&lt;/textarea&gt;"))
  let reparsed = @html_parser.parse_fragment(markdown, sanitize=false)
  assert_eq(reparsed.query("img").length(), 0)
}

///|
test "sanitize_dom preserves empty rawtext and disabled invisible stripping" {
  let policy = @html_parser.SanitizationPolicy::new(
    ["div", "style", "script"],
    allowed_attributes={ "div": [], "style": [], "script": [] },
    drop_content_tags=[],
    strip_invisible_unicode=false,
  )
  let fragment = @html_parser.fragment(children=[
    @html_parser.element("div", children=[
      @html_parser.element("style"),
      @html_parser.element("script"),
      @html_parser.element("style", children=[@html_parser.text("a\u{200B}b")]),
    ]),
  ])
  assert_eq(
    @html_parser.sanitize_dom(fragment, policy~).to_html(pretty=false),
    "<div><style></style><script></script><style>a\u{200B}b</style></div>",
  )
}

///|
test "sanitize_dom neutralizes rawtext end tag boundaries only" {
  let policy = @html_parser.SanitizationPolicy::new(["style"], drop_content_tags=[])
  let fragment = @html_parser.fragment(children=[
    @html_parser.element("style", children=[
      @html_parser.text("</stylex> ok </style"),
    ]),
  ])
  let out = @html_parser.sanitize_dom(fragment, policy~).to_html(pretty=false)
  assert_eq(out, "<style></stylex> ok &lt;/style</style>")
  let reparsed = @html_parser.parse_fragment(out, sanitize=false)
  assert_eq(reparsed.query("style").length(), 1)
}

///|
test "sanitize_dom hardens rawtext inside template children" {
  let policy = @html_parser.SanitizationPolicy::new(
    ["template", "style", "img"],
    allowed_attributes={ "template": [], "img": ["src"] },
    drop_content_tags=[],
  )
  let fragment = @html_parser.fragment(children=[
    @html_parser.element("template", children=[
      @html_parser.element("style", children=[
        @html_parser.text("</style><img src=x>"),
      ]),
    ]),
  ])
  let out = @html_parser.sanitize_dom(fragment, policy~).to_html(pretty=false)
  assert_eq(out, "<template><style>&lt;/style><img src=x></style></template>")
  let reparsed = @html_parser.parse_fragment(out, sanitize=false)
  assert_eq(reparsed.query("img").length(), 0)
}

///|
test "sanitize_dom filters allowed style rawtext resource loads" {
  let policy = @html_parser.SanitizationPolicy::new(["style"], drop_content_tags=[])
  let fragment = @html_parser.parse_fragment(
    "<style>body{background:u\u{200B}rl(/x.png)}</style><style>body{color:red}</style>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<style></style><style>body{color:red}</style>",
  )
}

///|
test "sanitize_dom filters mixed-case style rawtext resource loads" {
  let policy = @html_parser.SanitizationPolicy::new(["style"], drop_content_tags=[])
  let style = @html_parser.element("StYlE", children=[
    @html_parser.text("@import 'https://evil.example/x.css';"),
  ])
  assert_eq(
    @html_parser.sanitize_dom(style, policy~).to_html(pretty=false),
    "<StYlE></StYlE>",
  )
}

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
test "sanitize_dom raise mode reports active foreign mutation tags" {
  let fragment_rule = @html_parser.UrlRule::new(
    allowed_schemes=[],
    allow_relative=false,
    allow_fragment=true,
  )
  let policy = @html_parser.SanitizationPolicy::new(
    ["svg", "image", "set"],
    allowed_attributes={
      "image": ["id", "href", "width", "height"],
      "set": ["href", "attributeName", "to", "begin"],
    },
    url_policy=@html_parser.UrlPolicy::new(allow_rules=[
      @html_parser.UrlPolicyRule::new("image", "href", fragment_rule),
      @html_parser.UrlPolicyRule::new("set", "href", fragment_rule),
    ]),
    drop_foreign_namespaces=false,
    drop_content_tags=[],
    unsafe_handling=Raise,
  )
  let svg = @html_parser.element("svg", ns="svg", children=[
    @html_parser.element("image", ns="svg", attrs={
      "id": Some("img"),
      "href": Some("#ok"),
      "width": Some("10"),
      "height": Some("10"),
    }),
    @html_parser.element("set", ns="svg", attrs={
      "href": Some("#img"),
      "attributeName": Some("href"),
      "to": Some("https://evil.example/pwn"),
      "begin": Some("0s"),
    }),
  ])
  let result : Result[@html_parser.Node, @html_parser.HtmlError] = try? @html_parser.sanitize_dom(
    svg,
    policy~,
  )
  match result {
    Err(UnsafeHtml(message)) =>
      assert_eq(message, "Unsafe tag 'set' (active foreign content)")
    _ => fail("expected active foreign content to raise UnsafeHtml")
  }
}

///|
test "sanitize_dom treats html namespace svg roots as foreign for active tags" {
  let policy = @html_parser.SanitizationPolicy::new(
    ["svg", "rect", "set"],
    allowed_attributes={ "rect": ["width"], "set": ["begin"] },
    drop_foreign_namespaces=false,
    drop_content_tags=[],
  )
  let svg = @html_parser.element("svg", ns="html", children=[
    @html_parser.element("set", ns="html", attrs={ "begin": Some("0s") }),
    @html_parser.element("rect", ns="html", attrs={ "width": Some("10") }),
  ])
  assert_eq(
    @html_parser.sanitize_dom(svg, policy~).to_html(pretty=false),
    "<svg><rect width=\"10\"></rect></svg>",
  )
}

///|
test "sanitize_dom drops html namespace foreign roots when namespace dropping is enabled" {
  let policy = @html_parser.SanitizationPolicy::new(
    ["svg", "rect", "math", "mtext", "p"],
    allowed_attributes={ "rect": ["width"], "p": ["id"] },
    drop_foreign_namespaces=true,
    drop_content_tags=[],
  )
  let fragment = @html_parser.fragment(children=[
    @html_parser.element("svg", ns="html", children=[
      @html_parser.element("rect", ns="html", attrs={ "width": Some("10") }),
    ]),
    @html_parser.element("math", ns="html", children=[
      @html_parser.element("mtext", ns="html", children=[@html_parser.text("x")]),
    ]),
    @html_parser.element("p", ns="html", attrs={ "id": Some("kept") }),
  ])
  assert_eq(
    @html_parser.sanitize_dom(fragment, policy~).to_html(pretty=false),
    "<p id=\"kept\"></p>",
  )
}

///|
test "sanitize_dom stabilizes foreign namespace mXSS after reparse" {
  let url_policy = @html_parser.UrlPolicy::new(allow_rules=[
    @html_parser.UrlPolicyRule::new(
      "img",
      "src",
      @html_parser.UrlRule::new(
        allowed_schemes=[],
        allow_relative=true,
        resolve_protocol_relative=None,
      ),
    ),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    ["form", "math", "mtext", "mglyph", "style", "img"],
    allowed_attributes={ "img": ["src"] },
    url_policy~,
    drop_foreign_namespaces=false,
    drop_content_tags=[],
  )
  let parsed = @html_parser.parse_fragment(
    "<form><math><mtext></form><form><mglyph><style></math><img src onerror=alert(1)>",
    sanitize=false,
  )
  let sanitized = @html_parser.sanitize_dom(parsed.root, policy~)
  assert_eq(
    sanitized.to_html(pretty=false),
    "<form><math><mtext></mtext></math></form>",
  )
  let reparsed = @html_parser.parse_fragment(
    sanitized.to_html(pretty=false),
    sanitize=false,
  )
  assert_eq(
    reparsed.to_html(pretty=false),
    "<form><math><mtext></mtext></math></form>",
  )
  assert_true(!sanitized.to_markdown(html_passthrough=true).contains("onerror"))
}

///|
test "sanitize_dom stabilizes cloned foreign namespace mXSS after reparse" {
  let url_policy = @html_parser.UrlPolicy::new(allow_rules=[
    @html_parser.UrlPolicyRule::new(
      "img",
      "src",
      @html_parser.UrlRule::new(
        allowed_schemes=[],
        allow_relative=true,
        resolve_protocol_relative=None,
      ),
    ),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    ["form", "math", "mtext", "mglyph", "style", "img"],
    allowed_attributes={ "img": ["src"] },
    url_policy~,
    drop_foreign_namespaces=false,
    drop_content_tags=[],
  )
  let parsed = @html_parser.parse_fragment(
    "<form><math><mtext></form><form><mglyph><style></math><img src onerror=alert(1)>",
    sanitize=false,
  )
  let original = parsed.to_html(pretty=false)
  let clone = parsed.root.clone_node(deep=true)
  let sanitized = @html_parser.sanitize_dom(clone, policy~)
  assert_eq(
    sanitized.to_html(pretty=false),
    "<form><math><mtext></mtext></math></form>",
  )
  assert_eq(parsed.to_html(pretty=false), original)
  let reparsed = @html_parser.parse_fragment(
    sanitized.to_html(pretty=false),
    sanitize=false,
  )
  assert_eq(
    reparsed.to_html(pretty=false),
    "<form><math><mtext></mtext></math></form>",
  )
}

///|
test "sanitize_dom stabilizes foreign namespace mXSS for document roots" {
  let url_policy = @html_parser.UrlPolicy::new(allow_rules=[
    @html_parser.UrlPolicyRule::new(
      "img",
      "src",
      @html_parser.UrlRule::new(
        allowed_schemes=[],
        allow_relative=true,
        resolve_protocol_relative=None,
      ),
    ),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    ["html", "head", "body", "form", "math", "mtext", "mglyph", "style", "img"],
    allowed_attributes={ "img": ["src"] },
    url_policy~,
    drop_foreign_namespaces=false,
    drop_content_tags=[],
    drop_doctype=false,
  )
  let parsed = @html_parser.parse(
    "<!DOCTYPE html><html><head></head><body><form><math><mtext></form><form><mglyph><style></math><img src onerror=1></body></html>",
    sanitize=false,
  )
  let sanitized = @html_parser.sanitize_dom(parsed.root, policy~)
  assert_eq(
    sanitized.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body><form><math><mtext></mtext></math></form></body></html>",
  )
}

///|
test "sanitize_dom drops active foreign integration points during stabilization" {
  let url_policy = @html_parser.UrlPolicy::new(allow_rules=[
    @html_parser.UrlPolicyRule::new(
      "img",
      "src",
      @html_parser.UrlRule::new(
        allowed_schemes=[],
        allow_relative=true,
        resolve_protocol_relative=None,
      ),
    ),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    ["svg", "style", "img"],
    allowed_attributes={ "img": ["src"] },
    url_policy~,
    drop_foreign_namespaces=false,
    drop_content_tags=[],
  )
  let parsed = @html_parser.parse_fragment(
    "<svg><foreignObject><style></svg><img src onerror=1>",
    sanitize=false,
  )
  guard parsed.root.children().get(0) is Some(svg) else {
    fail("expected svg root child")
  }
  let sanitized = @html_parser.sanitize_dom(svg, policy~)
  assert_eq(sanitized.to_html(pretty=false), "<svg></svg>")
  let reparsed = @html_parser.parse_fragment(
    sanitized.to_html(pretty=false),
    sanitize=false,
  )
  assert_eq(reparsed.to_html(pretty=false), "<svg></svg>")
}

///|
test "sanitize_dom can return fragment after foreign stabilization" {
  let url_policy = @html_parser.UrlPolicy::new(allow_rules=[
    @html_parser.UrlPolicyRule::new(
      "img",
      "src",
      @html_parser.UrlRule::new(
        allowed_schemes=[],
        allow_relative=true,
        resolve_protocol_relative=None,
      ),
    ),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    ["svg", "img"],
    allowed_attributes={ "img": ["src"] },
    url_policy~,
    drop_foreign_namespaces=false,
    drop_content_tags=[],
  )
  let parsed = @html_parser.parse_fragment(
    "<foo><svg></svg><img src onerror=1></foo>",
    sanitize=false,
  )
  guard parsed.root.children().get(0) is Some(foo) else {
    fail("expected foo root child")
  }
  let sanitized = @html_parser.sanitize_dom(foo, policy~)
  assert_true(sanitized.kind() is Fragment)
  assert_eq(sanitized.to_html(pretty=false), "<svg></svg><img>")
}

///|
test "sanitize_dom preserves allowed template content" {
  let policy = @html_parser.SanitizationPolicy::new(
    ["template", "p"],
    allowed_attributes={ "template": [], "p": [] },
    drop_foreign_namespaces=false,
    drop_content_tags=[],
  )
  let template = @html_parser.element("template", children=[
    @html_parser.element("p", children=[@html_parser.text("x")]),
  ])
  assert_eq(
    @html_parser.sanitize_dom(template, policy~).to_html(pretty=false),
    "<template><p>x</p></template>",
  )
}

///|
test "sanitize_dom unwraps disallowed template content" {
  let policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    allowed_attributes={ "*": [], "p": [] },
    drop_foreign_namespaces=false,
    drop_content_tags=[],
  )
  let fragment = @html_parser.parse_fragment(
    "<template><p>ok</p></template>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<p>ok</p>",
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

///|
test "sanitize_dom drops meta refresh content attributes" {
  let policy = @html_parser.SanitizationPolicy::new(
    ["meta", "p"],
    allowed_attributes={ "meta": ["http-equiv", "content"] },
    drop_content_tags=[],
  )
  let fragment = @html_parser.parse_fragment(
    "<meta http-equiv='refresh' content='0;url=javascript:alert(1)'><meta http-equiv='Content-Type' content='text/html; charset=utf-8'><p>ok</p>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<meta http-equiv=\"refresh\"><meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\"><p>ok</p>",
  )
}

///|
test "sanitize_dom drops base href even when allowlisted" {
  let policy = @html_parser.SanitizationPolicy::new(
    ["base", "img"],
    allowed_attributes={ "base": ["href"], "img": ["src"] },
    drop_content_tags=[],
  )
  let fragment = @html_parser.parse_fragment(
    "<base Href='https://evil.example/assets/'><img src='pixel'>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<base><img src=\"pixel\">",
  )
}

///|
test "sanitize_dom drops url-like attributes without exact url rules" {
  let policy = @html_parser.SanitizationPolicy::new(
    ["a", "img", "blockquote", "object", "p", "form", "button", "video"],
    allowed_attributes={
      "a": ["href", "ping"],
      "img": ["src", "srcset", "attributionsrc", "poster"],
      "video": ["poster"],
      "form": ["action"],
      "button": ["formaction"],
      "blockquote": ["cite"],
      "object": ["data"],
      "p": ["background", "data-x"],
    },
    url_policy=@html_parser.UrlPolicy::new(allow_rules=[]),
    drop_content_tags=[],
  )
  let fragment = @html_parser.parse_fragment(
    "<a href='https://example.com' ping='https://trusted.example/p https://evil.example/p'>x</a><img src='/ok.png' srcset='/one.png 1x' attributionsrc='https://evil.example/register' poster='/poster.png'><video poster='/poster.png'></video><form action='/submit'></form><button formaction='/submit'>go</button><blockquote cite='https://evil.example/q'></blockquote><object data='/payload'></object><p background='/bg.png' data-x='ok'>t</p>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<a>x</a><img><video></video><form></form><button>go</button><blockquote></blockquote><object></object><p data-x=\"ok\">t</p>",
  )
}

///|
test "sanitize_dom applies single url-like attribute rules" {
  let remote_rule = @html_parser.UrlRule::new(
    allowed_schemes=["https"],
    allowed_hosts=["trusted.example"],
    allow_relative=false,
  )
  let url_policy = @html_parser.UrlPolicy::new(allow_rules=[
    @html_parser.UrlPolicyRule::new("video", "poster", remote_rule),
    @html_parser.UrlPolicyRule::new("form", "action", remote_rule),
    @html_parser.UrlPolicyRule::new("button", "formaction", remote_rule),
    @html_parser.UrlPolicyRule::new("blockquote", "cite", remote_rule),
    @html_parser.UrlPolicyRule::new("object", "data", remote_rule),
    @html_parser.UrlPolicyRule::new("p", "background", remote_rule),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    ["video", "form", "button", "blockquote", "object", "p"],
    allowed_attributes={
      "video": ["poster"],
      "form": ["action"],
      "button": ["formaction"],
      "blockquote": ["cite"],
      "object": ["data"],
      "p": ["background"],
    },
    url_policy~,
    drop_content_tags=[],
  )
  let fragment = @html_parser.parse_fragment(
    "<video poster='https://trusted.example/poster.png'></video><video poster='https://evil.example/poster.png'></video><form action='//trusted.example/submit'></form><button formaction='https://trusted.example/send'>go</button><blockquote cite='https://trusted.example/q'></blockquote><object data='https://trusted.example/payload'></object><p background='https://trusted.example/bg.png'>ok</p><p background='/relative.png'>rel</p>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<video poster=\"https://trusted.example/poster.png\"></video><video></video><form action=\"https://trusted.example/submit\"></form><button formaction=\"https://trusted.example/send\">go</button><blockquote cite=\"https://trusted.example/q\"></blockquote><object data=\"https://trusted.example/payload\"></object><p background=\"https://trusted.example/bg.png\">ok</p><p>rel</p>",
  )
}

///|
test "sanitize_dom applies custom url policy rules" {
  let url_policy = @html_parser.UrlPolicy::new(
    default_handling=UrlStrip,
    default_allow_relative=false,
    allow_rules=[
      @html_parser.UrlPolicyRule::new(
        "a",
        "href",
        @html_parser.UrlRule::new(
          allowed_schemes=["https"],
          allow_fragment=false,
          allow_relative=false,
          handling=UrlAllow,
        ),
      ),
      @html_parser.UrlPolicyRule::new(
        "img",
        "src",
        @html_parser.UrlRule::new(
          allowed_schemes=["https"],
          allow_relative=false,
          resolve_protocol_relative=None,
        ),
      ),
    ],
  )
  let policy = @html_parser.SanitizationPolicy::new(
    ["a", "img"],
    allowed_attributes={ "a": ["href"], "img": ["src"] },
    url_policy~,
  )
  let fragment = @html_parser.parse_fragment(
    "<a href='http://drop.test/'>http</a><a href='https://ok.test/'>https</a><a href='/rel'>rel</a><a href='#frag'>frag</a><a href='//ok.test/path'>proto</a><img src='https://ok.test/i.png'><img src='/rel.png'>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<a>http</a><a href=\"https://ok.test/\">https</a><a>rel</a><a>frag</a><a href=\"https://ok.test/path\">proto</a><img><img>",
  )
}

///|
test "sanitize_dom drops empty url values" {
  let url_policy = @html_parser.UrlPolicy::new(allow_rules=[
    @html_parser.UrlPolicyRule::new(
      "a",
      "href",
      @html_parser.UrlRule::new(allowed_schemes=["https"], allow_relative=false),
    ),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    ["a"],
    allowed_attributes={ "a": ["href"] },
    url_policy~,
  )
  let fragment = @html_parser.parse_fragment(
    "<a href=' \t\n'></a>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<a></a>",
  )
}

///|
test "sanitize_dom drops decoded control characters in url values" {
  let url_policy = @html_parser.UrlPolicy::new(allow_rules=[
    @html_parser.UrlPolicyRule::new(
      "a",
      "href",
      @html_parser.UrlRule::new(
        allowed_schemes=["https"],
        allowed_hosts=["example.com"],
        allow_relative=false,
      ),
    ),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    ["a"],
    allowed_attributes={ "a": ["href"] },
    url_policy~,
  )
  let fragment = @html_parser.parse_fragment(
    "<a href='https://example.com/a&#10;b'>lf</a><a href='https://example.com/a&#x7F;b'>del</a><a href='https://example.com/a\\b'>slash</a><a href='https://example.com/ok'>ok</a>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<a>lf</a><a>del</a><a>slash</a><a href=\"https://example.com/ok\">ok</a>",
  )
}

///|
test "sanitize_dom applies url policy host allowlists" {
  let url_policy = @html_parser.UrlPolicy::new(allow_rules=[
    @html_parser.UrlPolicyRule::new(
      "a",
      "href",
      @html_parser.UrlRule::new(
        allowed_schemes=["https"],
        allowed_hosts=["trusted.example", "::1"],
        allow_relative=false,
      ),
    ),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    ["a"],
    allowed_attributes={ "a": ["href"] },
    url_policy~,
  )
  let fragment = @html_parser.parse_fragment(
    "<a href='https://trusted.example/path'>ok</a><a href='https://TRUSTED.example/case'>case</a><a href='https://trusted.example:443/port'>port</a><a href='https://user@trusted.example/userinfo'>userinfo</a><a href='https://[::1]/ip'>ipv6</a><a href='//trusted.example/proto'>proto</a><a href='https://evil.example/path'>evil</a><a href='https://ex[ample].com/path'>bad-bracket</a><a href='https://[::1'>missing-bracket</a><a href='https://evil.example\\@trusted.example/path'>backslash</a><a href='/relative'>relative</a>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<a href=\"https://trusted.example/path\">ok</a><a href=\"https://TRUSTED.example/case\">case</a><a href=\"https://trusted.example:443/port\">port</a><a href=\"https://user@trusted.example/userinfo\">userinfo</a><a href=\"https://[::1]/ip\">ipv6</a><a href=\"https://trusted.example/proto\">proto</a><a>evil</a><a>bad-bracket</a><a>missing-bracket</a><a>backslash</a><a>relative</a>",
  )
}

///|
test "sanitize_dom applies srcset url policy rules" {
  let srcset_rule = @html_parser.UrlRule::new(
    allowed_schemes=["https"],
    allowed_hosts=["trusted.example"],
    allow_relative=false,
  )
  let url_policy = @html_parser.UrlPolicy::new(allow_rules=[
    @html_parser.UrlPolicyRule::new("img", "srcset", srcset_rule),
    @html_parser.UrlPolicyRule::new("link", "imagesrcset", srcset_rule),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    ["img", "link"],
    allowed_attributes={
      "img": ["srcset"],
      "link": ["rel", "as", "imagesrcset"],
    },
    url_policy~,
    drop_content_tags=[],
  )
  let fragment = @html_parser.parse_fragment(
    "<img srcset=' https://trusted.example/a 1x, , //trusted.example/b 2x '><img srcset='https://trusted.example/a 1x, https://evil.example/b 2x'><img srcset='  \t\n  '><link rel='preload' as='image' imagesrcset='https://trusted.example/a 1x, https://trusted.example/b 2x'><link rel='preload' as='image' imagesrcset='https://evil.example/a 1x'>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<img srcset=\"https://trusted.example/a 1x, https://trusted.example/b 2x\"><img><img><link rel=\"preload\" as=\"image\" imagesrcset=\"https://trusted.example/a 1x, https://trusted.example/b 2x\"><link rel=\"preload\" as=\"image\">",
  )
}

///|
test "sanitize_dom applies space separated url list rules" {
  let url_list_rule = @html_parser.UrlRule::new(
    allowed_schemes=["https"],
    allowed_hosts=["trusted.example"],
    allow_relative=false,
  )
  let url_policy = @html_parser.UrlPolicy::new(allow_rules=[
    @html_parser.UrlPolicyRule::new("a", "href", url_list_rule),
    @html_parser.UrlPolicyRule::new("a", "ping", url_list_rule),
    @html_parser.UrlPolicyRule::new("img", "src", url_list_rule),
    @html_parser.UrlPolicyRule::new("img", "attributionsrc", url_list_rule),
  ])
  let policy = @html_parser.SanitizationPolicy::new(
    ["a", "img"],
    allowed_attributes={
      "a": ["href", "ping"],
      "img": ["src", "attributionsrc"],
    },
    url_policy~,
  )
  let fragment = @html_parser.parse_fragment(
    "<a href='https://trusted.example/x' ping=' https://trusted.example/p   //trusted.example/q '>ok</a><a href='https://trusted.example/x' ping='https://trusted.example/p https://evil.example/p'>bad</a><a href='https://trusted.example/x' ping='  \t\n  '>empty</a><img src='https://trusted.example/x.png' attributionsrc='https://trusted.example/register https://trusted.example/measure'><img src='https://trusted.example/x.png' attributionsrc='https://trusted.example/register https://evil.example/register'>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(fragment.root, policy~).to_html(pretty=false),
    "<a href=\"https://trusted.example/x\" ping=\"https://trusted.example/p https://trusted.example/q\">ok</a><a href=\"https://trusted.example/x\">bad</a><a href=\"https://trusted.example/x\">empty</a><img src=\"https://trusted.example/x.png\" attributionsrc=\"https://trusted.example/register https://trusted.example/measure\"><img src=\"https://trusted.example/x.png\">",
  )
}

///|
test "sanitize_dom handles standalone nodes and url edge cases" {
  let allowed = @html_parser.element(
    "p",
    attrs={ "onclick": Some("x"), "title": Some("t") },
    children=[@html_parser.text("ok")],
  )
  assert_eq(
    @html_parser.sanitize_dom(allowed).to_html(pretty=false),
    "<p title=\"t\">ok</p>",
  )
  let unwrapped = @html_parser.element("sarcasm", children=[
    @html_parser.text("a"),
    @html_parser.element("b", children=[@html_parser.text("b")]),
  ])
  assert_eq(
    @html_parser.sanitize_dom(unwrapped).to_html(pretty=false),
    "a<b>b</b>",
  )
  let strict_attrs = @html_parser.fragment(children=[
    @html_parser.element("div", attrs={ "id": Some("x") }),
  ])
  let strict_policy = @html_parser.SanitizationPolicy::new(["div"])
  assert_eq(
    @html_parser.sanitize_dom(strict_attrs, policy=strict_policy).to_html(
      pretty=false,
    ),
    "<div></div>",
  )
  let foreign = @html_parser.fragment(children=[
    @html_parser.element("svg", ns="svg", children=[
      @html_parser.element("title", ns="svg", children=[@html_parser.text("x")]),
    ]),
    @html_parser.element("p", children=[@html_parser.text("ok")]),
  ])
  assert_eq(
    @html_parser.sanitize_dom(foreign).to_html(pretty=false),
    "<p>ok</p>",
  )
  let urls = @html_parser.parse_fragment(
    "<a href='#frag'>f</a><a href='HTTP://ok'>h</a><a href='/rel'>r</a><a href='java\t\nscript:evil'>bad</a><a href='/bad\npath'>control</a><img src='//x'><img src>",
    sanitize=false,
  )
  assert_eq(
    @html_parser.sanitize_dom(urls.root).to_html(pretty=false),
    "<a href=\"#frag\">f</a><a href=\"HTTP://ok\">h</a><a href=\"/rel\">r</a><a>bad</a><a>control</a><img><img>",
  )
}

///|
test "parse sanitize flag applies default sanitizer policies" {
  let fragment = @html_parser.parse_fragment(
    "<p onclick=x>ok</p><script>bad</script>",
    sanitize=true,
  )
  assert_eq(fragment.to_html(pretty=false), "<p>ok</p>")
  let doc = @html_parser.parse(
    "<!DOCTYPE html><!--x--><html><head><title>T</title><script>bad</script></head><body><p onclick=x>ok</p></body></html>",
    sanitize=true,
  )
  assert_eq(
    doc.to_html(pretty=false),
    "<!DOCTYPE html><html><head><title>T</title></head><body><p>ok</p></body></html>",
  )
  let bytes = @html_parser.parse_bytes(
    b"<p onclick=x>bytes</p><script>bad</script>",
    sanitize=true,
  )
  assert_eq(
    bytes.to_html(pretty=false),
    "<html><head></head><body><p>bytes</p></body></html>",
  )
  guard bytes.encoding is Some("windows-1252") else {
    fail("expected sanitized bytes parse to preserve encoding")
  }
}

///|
test "builder insert and replace helpers preserve graph invariants" {
  let parent = @html_parser.element("div", attrs={ "id": Some("parent") })
  let first = @html_parser.element("span", attrs={ "id": Some("1") })
  let second = @html_parser.element("span", attrs={ "id": Some("2") })
  let third = @html_parser.element("span", attrs={ "id": Some("3") })
  parent.append_child(first)
  parent.insert_before(second, Some(first))
  parent.insert_before(third, None)
  let children = parent.children()
  assert_eq(children.length(), 3)
  assert_eq(test_attr_id(children[0]), "2")
  assert_eq(test_attr_id(children[1]), "1")
  assert_eq(test_attr_id(children[2]), "3")
  guard second.parent() is Some(second_parent) else {
    fail("expected inserted child parent")
  }
  assert_eq(test_attr_id(second_parent), "parent")
  parent.insert_before(second, Some(second))
  assert_eq(test_attr_id(parent.children()[0]), "2")
  let fallback = @html_parser.element("span", attrs={ "id": Some("4") })
  parent.insert_before(fallback, Some(@html_parser.element("missing")))
  assert_eq(test_attr_id(parent.children()[3]), "4")
  let replacement = @html_parser.element("p", attrs={ "id": Some("new") })
  guard parent.replace_child(replacement, first) is Some(replaced) else {
    fail("expected replaced child")
  }
  assert_eq(test_attr_id(replaced), "1")
  assert_true(first.parent() is None)
  guard replacement.parent() is Some(replacement_parent) else {
    fail("expected replacement parent")
  }
  assert_eq(test_attr_id(replacement_parent), "parent")
  let after_replace = parent.children()
  assert_eq(test_attr_id(after_replace[0]), "2")
  assert_eq(test_attr_id(after_replace[1]), "new")
  assert_eq(test_attr_id(after_replace[2]), "3")
  assert_eq(test_attr_id(after_replace[3]), "4")
  guard parent.replace_child(replacement, replacement) is Some(same_child) else {
    fail("expected same-child replacement")
  }
  assert_eq(test_attr_id(same_child), "new")
  assert_eq(test_attr_id(parent.children()[1]), "new")
  guard parent.replace_child(second, third) is Some(moved_out) else {
    fail("expected moved old child")
  }
  assert_eq(test_attr_id(moved_out), "3")
  assert_true(third.parent() is None)
  let after_move = parent.children()
  assert_eq(after_move.length(), 3)
  assert_eq(test_attr_id(after_move[0]), "new")
  assert_eq(test_attr_id(after_move[1]), "2")
  assert_eq(test_attr_id(after_move[2]), "4")
  assert_true(parent.replace_child(@html_parser.element("x"), first) is None)
  let nested = @html_parser.element("i", attrs={ "id": Some("nested") })
  replacement.append_child(nested)
  assert_true(replacement.replace_child(parent, nested) is None)
  assert_eq(test_attr_id(replacement.children()[0]), "nested")
}

///|
test "clone_node deep handles deep trees iteratively" {
  let root = @html_parser.document()
  let mut parent = root
  for _ in 0..<1200 {
    let child = @html_parser.element("div")
    parent.append_child(child)
    parent = child
  }
  parent.append_child(@html_parser.text("x"))
  let cloned = root.clone_node(deep=true)
  assert_eq(cloned.to_text(separator="", strip=false), "x")
  let mut current = cloned
  let mut depth = 0
  while current.children().length() > 0 {
    let children = current.children()
    current = children[0]
    depth += 1
    if current.kind() is Text {
      break
    }
  }
  assert_eq(depth, 1201)
}

///|
test "tree builder finishes deeply nested parsed HTML without recursion" {
  let html = repeat_for_test("<div>", 1200) +
    "x" +
    repeat_for_test("</div>", 1200)
  let doc = @html_parser.parse(html)
  assert_eq(doc.to_text(separator="", strip=false), "x")
  guard doc.query_one("div") is Some(first_div) else {
    fail("expected parsed deep div")
  }
  assert_eq(first_div.to_text(separator="", strip=false), "x")
}

///|
test "clone_node copies template descendants through child traversal" {
  let template = @html_parser.element("template", children=[
    @html_parser.element("div", attrs={ "id": Some("content") }),
    @html_parser.element("span"),
  ])
  assert_eq(
    template.clone_node().to_html(pretty=false),
    "<template></template>",
  )
  let cloned = template.clone_node(deep=true)
  assert_eq(
    cloned.to_html(pretty=false),
    "<template><div id=\"content\"></div><span></span></template>",
  )
  guard cloned.query_one("div") is Some(cloned_div) else {
    fail("expected cloned template content")
  }
  cloned_div.append_child(@html_parser.text("clone"))
  guard cloned_div.parent() is Some(cloned_parent) else {
    fail("expected cloned template child parent")
  }
  assert_eq(cloned_parent.name(), "template")
  assert_eq(
    template.to_html(pretty=false),
    "<template><div id=\"content\"></div><span></span></template>",
  )
  assert_eq(
    cloned.to_html(pretty=false),
    "<template><div id=\"content\">clone</div><span></span></template>",
  )
}

///|
test "builder neutralizes raw text end tag breakouts" {
  let script = @html_parser.element("script", children=[
    @html_parser.text("</script><img src=x onerror=alert(1)>"),
  ])
  let script_root = @html_parser.element("div", children=[script])
  assert_eq(
    script_root.to_html(pretty=false),
    "<div><script>&lt;/script><img src=x onerror=alert(1)></script></div>",
  )
  let style = @html_parser.element("style", children=[
    @html_parser.text("</style><img src=x>"),
  ])
  let style_root = @html_parser.element("div", children=[style])
  assert_eq(
    style_root.to_html(pretty=false),
    "<div><style>&lt;/style><img src=x></style></div>",
  )
}

///|
test "raw text serializer only neutralizes matching end tag boundaries" {
  let non_boundary = @html_parser.element("script", children=[
    @html_parser.text("</scriptx>ok"),
  ])
  assert_eq(non_boundary.to_html(pretty=false), "<script></scriptx>ok</script>")
  let vertical_tab = @html_parser.element("script", children=[
    @html_parser.text("</script\u{000B}>ok"),
  ])
  assert_eq(
    vertical_tab.to_html(pretty=false),
    "<script></script\u{000B}>ok</script>",
  )
  let mixed_case = @html_parser.element("script", children=[
    @html_parser.text("</ScRiPt >x"),
  ])
  assert_eq(mixed_case.to_html(pretty=false), "<script>&lt;/ScRiPt >x</script>")
  let parsed = @html_parser.parse_fragment("<script>a</scriptx>b</script>")
  assert_eq(parsed.to_html(pretty=false), "<script>a</scriptx>b</script>")
  let double_escaped = @html_parser.parse_fragment(
    "<script><!--<script>x</script>y</script>",
  )
  assert_eq(
    double_escaped.to_html(pretty=false),
    "<script><!--<script>x&lt;/script>y</script>",
  )
}

///|
test "url serialization context uses text content and utf8 percent encoding" {
  let text = @html_parser.text(" https://example.com/foo bar ")
  assert_eq(
    text.to_html(pretty=false, context=Url),
    "https://example.com/foo%20bar",
  )
  let div = @html_parser.element("div", children=[
    @html_parser.text("  /path/to/thing?q=a b  "),
  ])
  assert_eq(div.to_html(pretty=false, context=Url), "/path/to/thing?q=a%20b")
  let unicode = @html_parser.text("caf\u{00E9}/\u{2603}?x=1&y=two words%")
  assert_eq(
    unicode.to_html(pretty=false, context=Url),
    "caf%C3%A9/%E2%98%83?x=1&y=two%20words%25",
  )
  let controls = @html_parser.text(
    "\u{0001}\u{0004}\u{0006}\u{000B}\u{000D}\u{000F}\u{007F}",
  )
  assert_eq(
    controls.to_html(pretty=false, context=Url),
    "%01%04%06%0B%0D%0F%7F",
  )
}

///|
test "js string serialization context escapes special characters" {
  let markup = @html_parser.parse_fragment("<b>Hi</b>")
  assert_eq(
    markup.to_html(pretty=false, context=JsString),
    "\\u003cb\\u003eHi\\u003c/b\\u003e",
  )
  let amp = @html_parser.parse_fragment("<p>a & b</p>")
  assert_eq(
    amp.to_html(pretty=false, context=JsString),
    "\\u003cp\\u003ea &amp; b\\u003c/p\\u003e",
  )
  let special = @html_parser.text(
    "\\back\nline\rret\ttab\u{0008}bell\u{000C}form\u{2028}ls\u{2029}ps",
  )
  assert_eq(
    special.to_html(pretty=false, context=JsString),
    "\u{005C}\u{005C}back\u{005C}nline\u{005C}rret\u{005C}ttab\u{005C}bbell\u{005C}fform\u{005C}u2028ls\u{005C}u2029ps",
  )
  let single_quote = @html_parser.text("It's ok")
  assert_eq(
    single_quote.to_html(pretty=false, context=JsString, quote='\''),
    "It\\'s ok",
  )
}

///|
test "tokenize recovers invalid self closing start tag fixture case" {
  let result = @html_parser.tokenize("<div /a>", collect_errors=true)
  guard result.tokens[0] is Tag(tag) else { fail("expected div tag") }
  assert_eq(tag.name, "div")
  assert_eq(tag.self_closing, false)
  guard tag.attrs["a"] is Some("") else { fail("expected recovered a attr") }
  assert_eq(result.errors.length(), 1)
  assert_eq(result.errors[0].code, "unexpected-character-after-solidus-in-tag")
  guard result.errors[0].column is Some(7) else {
    fail("expected invalid self closing char at column 7")
  }
  let fragment = @html_parser.parse_fragment("<div /a>", collect_errors=true)
  assert_eq(fragment.to_html(pretty=false), "<div a></div>")
  assert_eq(fragment.errors.length(), 2)
  assert_eq(
    fragment.errors[0].code,
    "unexpected-character-after-solidus-in-tag",
  )
  assert_eq(fragment.errors[1].code, "expected-closing-tag-but-got-eof")
}

///|
test "start tag solidus does not skip following whitespace" {
  let tokenized = @html_parser.tokenize("<div/ >", collect_errors=true)
  guard tokenized.tokens[0] is Tag(tag) else { fail("expected div tag") }
  assert_eq(tag.name, "div")
  assert_eq(tag.self_closing, false)
  assert_eq(tokenized.errors.length(), 1)
  assert_eq(
    tokenized.errors[0].code,
    "unexpected-character-after-solidus-in-tag",
  )
  guard tokenized.errors[0].column is Some(6) else {
    fail("expected whitespace after solidus at column 6")
  }
  let img = @html_parser.tokenize("<img />", collect_errors=true)
  guard img.tokens[0] is Tag(img_tag) else { fail("expected img tag") }
  assert_eq(img_tag.self_closing, true)
  assert_eq(img.errors.length(), 0)
  let fragment = @html_parser.parse_fragment("<div/ >", collect_errors=true)
  assert_eq(fragment.to_html(pretty=false), "<div></div>")
  assert_eq(fragment.errors.length(), 2)
  assert_eq(
    fragment.errors[0].code,
    "unexpected-character-after-solidus-in-tag",
  )
  assert_eq(fragment.errors[1].code, "expected-closing-tag-but-got-eof")
  guard fragment.errors[0].column is Some(6) else {
    fail("expected parser whitespace after solidus at column 6")
  }
}

///|
test "tokenize normalizes BOM and CRLF edge cases" {
  let bom = @html_parser.tokenize("\u{FEFF}<div>")
  guard bom.tokens[0] is Tag(tag) else { fail("expected div start tag") }
  assert_eq(tag.name, "div")
  let text = @html_parser.tokenize("abc\r\ndef\rghi")
  guard text.tokens[0] is Characters(data) else {
    fail("expected character token")
  }
  assert_eq(data, "abc\ndef\nghi")
  let comment = @html_parser.tokenize("<!-- a\rb -->")
  guard comment.tokens[0] is CommentToken(data) else {
    fail("expected comment")
  }
  assert_eq(data, " a\nb ")
  let attr = @html_parser.tokenize("<div title=\"a\rb\">")
  guard attr.tokens[0] is Tag(attr_tag) else { fail("expected attr tag") }
  guard attr_tag.attrs["title"] is Some("a\nb") else {
    fail("expected normalized attr")
  }
}

///|
test "tokenize matches upstream CR and LF normalization fixtures" {
  let bom = @html_parser.tokenize("\u{FEFF}<div>", collect_errors=true)
  guard bom.tokens[0] is Tag(bom_tag) else {
    fail("expected BOM-stripped div start tag")
  }
  assert_eq(bom_tag.name, "div")
  assert_eq(bom.errors.length(), 0)
  let cr_text = @html_parser.tokenize("abc\rdef", collect_errors=true)
  guard cr_text.tokens[0] is Characters("abc\ndef") else {
    fail("expected CR in text to normalize to LF")
  }
  assert_eq(cr_text.errors.length(), 0)
  let crlf_text = @html_parser.tokenize("\r\n", collect_errors=true)
  guard crlf_text.tokens[0] is Characters("\n") else {
    fail("expected CRLF in text to collapse to one LF")
  }
  assert_eq(crlf_text.errors.length(), 0)
  let cr_after_name = @html_parser.tokenize("<div\r>", collect_errors=true)
  guard cr_after_name.tokens[0] is Tag(cr_after_name_tag) else {
    fail("expected CR after tag name to close div")
  }
  assert_eq(cr_after_name_tag.name, "div")
  assert_eq(cr_after_name_tag.attrs.length(), 0)
  assert_eq(cr_after_name.errors.length(), 0)
  let crlf_before_attr = @html_parser.tokenize(
    "<div\r\nattr>",
    collect_errors=true,
  )
  guard crlf_before_attr.tokens[0] is Tag(crlf_before_attr_tag) else {
    fail("expected CRLF before attribute name")
  }
  guard crlf_before_attr_tag.attrs["attr"] is Some("") else {
    fail("expected empty attr after CRLF")
  }
  assert_eq(crlf_before_attr.errors.length(), 0)
  let cr_after_attr = @html_parser.tokenize("<div attr\r>", collect_errors=true)
  guard cr_after_attr.tokens[0] is Tag(cr_after_attr_tag) else {
    fail("expected CR after attribute name")
  }
  guard cr_after_attr_tag.attrs["attr"] is Some("") else {
    fail("expected empty attr after CR")
  }
  assert_eq(cr_after_attr.errors.length(), 0)
  let cr_space_after_attr = @html_parser.tokenize(
    "<div attr\r >",
    collect_errors=true,
  )
  guard cr_space_after_attr.tokens[0] is Tag(cr_space_after_attr_tag) else {
    fail("expected CR space after attribute name")
  }
  guard cr_space_after_attr_tag.attrs["attr"] is Some("") else {
    fail("expected empty attr after CR space")
  }
  assert_eq(cr_space_after_attr.errors.length(), 0)
  let crlf_after_attr = @html_parser.tokenize(
    "<div attr\r\n>",
    collect_errors=true,
  )
  guard crlf_after_attr.tokens[0] is Tag(crlf_after_attr_tag) else {
    fail("expected CRLF after attribute name")
  }
  guard crlf_after_attr_tag.attrs["attr"] is Some("") else {
    fail("expected empty attr after CRLF")
  }
  assert_eq(crlf_after_attr.errors.length(), 0)
  let cr_tab_after_attr = @html_parser.tokenize(
    "<div attr\r\t>",
    collect_errors=true,
  )
  guard cr_tab_after_attr.tokens[0] is Tag(cr_tab_after_attr_tag) else {
    fail("expected CR tab after attribute name")
  }
  guard cr_tab_after_attr_tag.attrs["attr"] is Some("") else {
    fail("expected empty attr after CR tab")
  }
  assert_eq(cr_tab_after_attr.errors.length(), 0)
  let double_attr = @html_parser.tokenize(
    "<div attr=\"a\rb\">",
    collect_errors=true,
  )
  guard double_attr.tokens[0] is Tag(double_attr_tag) else {
    fail("expected double-quoted attr with CR")
  }
  guard double_attr_tag.attrs["attr"] is Some("a\nb") else {
    fail("expected normalized CR in double-quoted attr")
  }
  assert_eq(double_attr.errors.length(), 0)
  let single_attr = @html_parser.tokenize(
    "<div attr='a\rb'>",
    collect_errors=true,
  )
  guard single_attr.tokens[0] is Tag(single_attr_tag) else {
    fail("expected single-quoted attr with CR")
  }
  guard single_attr_tag.attrs["attr"] is Some("a\nb") else {
    fail("expected normalized CR in single-quoted attr")
  }
  assert_eq(single_attr.errors.length(), 0)
  let unquoted = @html_parser.tokenize("<div attr=abc>", collect_errors=true)
  guard unquoted.tokens[0] is Tag(unquoted_tag) else {
    fail("expected unquoted attr")
  }
  guard unquoted_tag.attrs["attr"] is Some("abc") else {
    fail("expected unquoted attr value")
  }
  assert_eq(unquoted.errors.length(), 0)
  let lf_after_name = @html_parser.tokenize("<div\n>", collect_errors=true)
  guard lf_after_name.tokens[0] is Tag(lf_after_name_tag) else {
    fail("expected LF after tag name")
  }
  assert_eq(lf_after_name_tag.name, "div")
  assert_eq(lf_after_name_tag.attrs.length(), 0)
  assert_eq(lf_after_name.errors.length(), 0)
  let lf_after_attr = @html_parser.tokenize("<div attr\n>", collect_errors=true)
  guard lf_after_attr.tokens[0] is Tag(lf_after_attr_tag) else {
    fail("expected LF after attribute name")
  }
  guard lf_after_attr_tag.attrs["attr"] is Some("") else {
    fail("expected empty attr after LF")
  }
  assert_eq(lf_after_attr.errors.length(), 0)
  let double_lf_attr = @html_parser.tokenize(
    "<div attr=\"a\nb\">",
    collect_errors=true,
  )
  guard double_lf_attr.tokens[0] is Tag(double_lf_attr_tag) else {
    fail("expected double-quoted attr with LF")
  }
  guard double_lf_attr_tag.attrs["attr"] is Some("a\nb") else {
    fail("expected LF in double-quoted attr")
  }
  assert_eq(double_lf_attr.errors.length(), 0)
  let single_lf_attr = @html_parser.tokenize(
    "<div attr='a\nb'>",
    collect_errors=true,
  )
  guard single_lf_attr.tokens[0] is Tag(single_lf_attr_tag) else {
    fail("expected single-quoted attr with LF")
  }
  guard single_lf_attr_tag.attrs["attr"] is Some("a\nb") else {
    fail("expected LF in single-quoted attr")
  }
  assert_eq(single_lf_attr.errors.length(), 0)
  let crlf_space_attr = @html_parser.tokenize(
    "<div \r\n attr>",
    collect_errors=true,
  )
  guard crlf_space_attr.tokens[0] is Tag(crlf_space_attr_tag) else {
    fail("expected CRLF space before attr")
  }
  guard crlf_space_attr_tag.attrs["attr"] is Some("") else {
    fail("expected empty attr after CRLF space")
  }
  assert_eq(crlf_space_attr.errors.length(), 0)
  let comment = @html_parser.tokenize(
    "<!-- test\rcomment -->",
    collect_errors=true,
  )
  guard comment.tokens[0] is CommentToken(" test\ncomment ") else {
    fail("expected CR in comment to normalize to LF")
  }
  assert_eq(comment.errors.length(), 0)
}

///|
test "tokenize handles comment dash EOF and null edge cases" {
  let crlf_eof = @html_parser.tokenize("<!----!\r\n", collect_errors=true)
  guard crlf_eof.tokens[0] is CommentToken("--!\n") else {
    fail("expected CRLF EOF comment data")
  }
  assert_eq(crlf_eof.errors.length(), 1)
  assert_eq(crlf_eof.errors[0].code, "eof-in-comment")
  guard crlf_eof.errors[0].line is Some(2) else {
    fail("expected EOF comment error on line 2")
  }
  guard crlf_eof.errors[0].column is Some(0) else {
    fail("expected EOF comment error at column 0")
  }
  let parsed_crlf_eof = @html_parser.parse("<!----!\r\n", collect_errors=true)
  assert_eq(parsed_crlf_eof.errors.length(), 2)
  assert_eq(parsed_crlf_eof.errors[0].code, "eof-in-comment")
  assert_eq(parsed_crlf_eof.errors[1].code, "expected-doctype-but-got-eof")
  guard parsed_crlf_eof.errors[0].column is Some(0) else {
    fail("expected parser comment EOF error at column 0")
  }
  guard parsed_crlf_eof.errors[1].column is Some(0) else {
    fail("expected parser doctype EOF error at column 0")
  }
  let bang_null = @html_parser.tokenize(
    "<!--x--!\u{0000}-->",
    collect_errors=true,
  )
  guard bang_null.tokens[0] is CommentToken("x--!�") else {
    fail("expected replacement after --! null")
  }
  assert_eq(bang_null.errors.length(), 1)
  assert_eq(bang_null.errors[0].code, "unexpected-null-character")
  guard bang_null.errors[0].column is Some(9) else {
    fail("expected --! null error at column 9")
  }
  let incorrectly_closed = @html_parser.tokenize(
    "<!--x---a-->",
    collect_errors=true,
  )
  guard incorrectly_closed.tokens[0] is CommentToken("x---a") else {
    fail("expected incorrectly closed dash run data")
  }
  assert_eq(incorrectly_closed.errors.length(), 1)
  assert_eq(incorrectly_closed.errors[0].code, "incorrectly-closed-comment")
  guard incorrectly_closed.errors[0].column is Some(9) else {
    fail("expected incorrect close error at column 9")
  }
  let dash_null = @html_parser.tokenize("<!--x--\u{0000}>", collect_errors=true)
  guard dash_null.tokens[0] is CommentToken("x--�>") else {
    fail("expected replacement after -- null")
  }
  assert_eq(dash_null.errors.length(), 2)
  assert_eq(dash_null.errors[0].code, "unexpected-null-character")
  assert_eq(dash_null.errors[1].code, "eof-in-comment")
}

///|
test "tokenize handles comment EOF branch variants" {
  let empty = @html_parser.tokenize("<!--", collect_errors=true)
  guard empty.tokens[0] is CommentToken("") else {
    fail("expected empty EOF comment")
  }
  assert_eq(empty.errors.length(), 1)
  assert_eq(empty.errors[0].code, "eof-in-comment")
  guard empty.errors[0].column is Some(4) else {
    fail("expected empty comment EOF at column 4")
  }
  let bang_eof = @html_parser.tokenize("<!--x--!", collect_errors=true)
  guard bang_eof.tokens[0] is CommentToken("x") else {
    fail("expected --! EOF comment data")
  }
  assert_eq(bang_eof.errors.length(), 1)
  assert_eq(bang_eof.errors[0].code, "eof-in-comment")
  guard bang_eof.errors[0].column is Some(8) else {
    fail("expected --! EOF at column 8")
  }
  let dash_eof = @html_parser.tokenize("<!--x--", collect_errors=true)
  guard dash_eof.tokens[0] is CommentToken("x") else {
    fail("expected -- EOF comment data")
  }
  assert_eq(dash_eof.errors.length(), 1)
  assert_eq(dash_eof.errors[0].code, "eof-in-comment")
  guard dash_eof.errors[0].column is Some(7) else {
    fail("expected -- EOF at column 7")
  }
  let null_eof = @html_parser.tokenize("<!--x\u{0000}", collect_errors=true)
  guard null_eof.tokens[0] is CommentToken("x�") else {
    fail("expected null EOF comment data")
  }
  assert_eq(null_eof.errors.length(), 2)
  assert_eq(null_eof.errors[0].code, "unexpected-null-character")
  assert_eq(null_eof.errors[1].code, "eof-in-comment")
  guard null_eof.errors[0].column is Some(6) else {
    fail("expected comment null at column 6")
  }
  guard null_eof.errors[1].column is Some(6) else {
    fail("expected null EOF at column 6")
  }
}

///|
test "parser normalizes leading BOM and CRLF in text comment and attr" {
  let doc = @html_parser.parse_fragment(
    "\u{FEFF}<p title='a\rb'>a\r\nb<!--x\ry--></p>",
  )
  assert_eq(doc.to_html(pretty=false), "<p title=\"a\nb\">a\nb<!--x\ny--></p>")
  assert_eq(doc.to_text(separator="", strip=false), "a\nb")
}

///|
test "parser handles null characters in text attributes and text modes" {
  let text = @html_parser.parse_fragment("a\u{0000}b", collect_errors=true)
  assert_eq(text.to_html(pretty=false), "ab")
  assert_eq(text.to_text(separator="", strip=false), "ab")
  assert_eq(text.errors.length(), 1)
  assert_eq(text.errors[0].code, "unexpected-null-character")
  guard text.errors[0].column is Some(2) else {
    fail("expected text null at column 2")
  }
  let attr = @html_parser.parse_fragment(
    "<div title=\"a\u{0000}b\">x</div>",
    collect_errors=true,
  )
  assert_eq(attr.to_html(pretty=false), "<div title=\"a�b\">x</div>")
  assert_eq(attr.errors.length(), 1)
  assert_eq(attr.errors[0].code, "unexpected-null-character")
  let unquoted_attr = @html_parser.parse_fragment(
    "<div title=a\u{0000}b>x</div>",
    collect_errors=true,
  )
  assert_eq(unquoted_attr.to_html(pretty=false), "<div title=\"a�b\">x</div>")
  assert_eq(unquoted_attr.errors.length(), 1)
  assert_eq(unquoted_attr.errors[0].code, "unexpected-null-character")
  let attr_name = @html_parser.parse_fragment(
    "<div a\u{0000}b='c'>x</div>",
    collect_errors=true,
  )
  let attr_name_children = attr_name.root.children()
  assert_eq(attr_name_children.length(), 1)
  assert_eq(attr_name_children[0].name(), "div")
  guard attr_name_children[0].attrs()["a\u{FFFD}b"] is Some("c") else {
    fail("expected parser replacement char in attr name")
  }
  assert_eq(attr_name.to_text(separator="", strip=false), "x")
  assert_eq(attr_name.errors.length(), 1)
  assert_eq(attr_name.errors[0].code, "unexpected-null-character")
  let tag_name = @html_parser.parse_fragment(
    "<a\u{0000}b id=x>y</a\u{0000}b>",
    collect_errors=true,
  )
  let tag_name_children = tag_name.root.children()
  assert_eq(tag_name_children.length(), 1)
  assert_eq(tag_name_children[0].name(), "a\u{FFFD}b")
  guard tag_name_children[0].attrs()["id"] is Some("x") else {
    fail("expected attr on null-mutated start tag")
  }
  assert_eq(tag_name_children[0].text(), "y")
  assert_eq(tag_name.to_text(separator="", strip=false), "y")
  assert_eq(tag_name.errors.length(), 2)
  assert_eq(tag_name.errors[0].code, "unexpected-null-character")
  assert_eq(tag_name.errors[1].code, "unexpected-null-character")
  let raw = @html_parser.parse_fragment(
    "<script>a\u{0000}b</script><title>a\u{0000}b</title>",
    collect_errors=true,
  )
  assert_eq(
    raw.to_html(pretty=false),
    "<script>a�b</script><title>a�b</title>",
  )
  assert_eq(raw.errors.length(), 2)
  assert_eq(raw.errors[0].code, "unexpected-null-character")
  assert_eq(raw.errors[1].code, "unexpected-null-character")
  let textarea = @html_parser.parse_fragment(
    "<textarea>\n\u{0000}b</textarea>",
    collect_errors=true,
  )
  assert_eq(textarea.to_html(pretty=false), "<textarea>�b</textarea>")
  assert_eq(textarea.errors[0].code, "unexpected-null-character")
}

///|
test "parser and tokenizer report noncharacters in input stream" {
  let tokens = @html_parser.tokenize("ab\u{FDD0}cd", collect_errors=true)
  guard tokens.tokens[0] is Characters("ab\u{FDD0}cd") else {
    fail("expected noncharacter to stay in character token")
  }
  assert_eq(tokens.errors.length(), 1)
  assert_eq(tokens.errors[0].code, "noncharacter-in-input-stream")
  guard tokens.errors[0].column is Some(3) else {
    fail("expected data-state noncharacter at column 3")
  }
  let multiline = @html_parser.tokenize("a\nb\u{FDD0}c", collect_errors=true)
  assert_eq(multiline.errors.length(), 1)
  assert_eq(multiline.errors[0].code, "noncharacter-in-input-stream")
  guard multiline.errors[0].line is Some(2) else {
    fail("expected multiline noncharacter on line 2")
  }
  guard multiline.errors[0].column is Some(2) else {
    fail("expected multiline noncharacter at column 2")
  }
  let invalid_open = @html_parser.tokenize("<\u{FDD0}", collect_errors=true)
  guard invalid_open.tokens[0] is Characters("<\u{FDD0}") else {
    fail("expected invalid tag open as text")
  }
  assert_eq(invalid_open.errors.length(), 3)
  assert_eq(invalid_open.errors[0].code, "noncharacter-in-input-stream")
  assert_eq(invalid_open.errors[1].code, "invalid-first-character-of-tag-name")
  assert_eq(invalid_open.errors[2].code, "noncharacter-in-input-stream")
  let invalid_xml = @html_parser.tokenize(
    "<\u{000C}\u{FDD0}&lt;",
    collect_errors=true,
    xml_coercion=true,
  )
  guard invalid_xml.tokens[0] is Characters("< �<") else {
    fail("expected invalid tag-open text to decode and XML-coerce")
  }
  assert_eq(invalid_xml.errors.length(), 2)
  assert_eq(invalid_xml.errors[0].code, "invalid-first-character-of-tag-name")
  assert_eq(invalid_xml.errors[1].code, "noncharacter-in-input-stream")
  let invalid_null = @html_parser.tokenize("<\u{0000}", collect_errors=true)
  guard invalid_null.tokens[0] is Characters("<\u{0000}") else {
    fail("expected invalid tag-open null text")
  }
  assert_eq(invalid_null.errors.length(), 2)
  assert_eq(invalid_null.errors[0].code, "invalid-first-character-of-tag-name")
  assert_eq(invalid_null.errors[1].code, "unexpected-null-character")
  let fragment = @html_parser.parse_fragment(
    "ab\u{FDD0}cd",
    collect_errors=true,
  )
  assert_eq(fragment.to_html(pretty=false), "ab\u{FDD0}cd")
  assert_eq(fragment.errors.length(), 1)
  assert_eq(fragment.errors[0].code, "noncharacter-in-input-stream")
  let invalid_fragment = @html_parser.parse_fragment(
    "<\u{FDD0}",
    collect_errors=true,
  )
  assert_eq(invalid_fragment.to_html(pretty=false), "&lt;\u{FDD0}")
  assert_eq(invalid_fragment.errors.length(), 3)
  assert_eq(invalid_fragment.errors[0].code, "noncharacter-in-input-stream")
  assert_eq(
    invalid_fragment.errors[1].code,
    "invalid-first-character-of-tag-name",
  )
  assert_eq(invalid_fragment.errors[2].code, "noncharacter-in-input-stream")
  let invalid_entity = @html_parser.parse_fragment(
    "<&notit",
    collect_errors=true,
  )
  assert_eq(invalid_entity.to_html(pretty=false), "&lt;¬it")
  assert_eq(invalid_entity.errors.length(), 2)
  assert_eq(
    invalid_entity.errors[0].code,
    "invalid-first-character-of-tag-name",
  )
  assert_eq(
    invalid_entity.errors[1].code,
    "missing-semicolon-after-character-reference",
  )
  let invalid_xml = @html_parser.parse_fragment(
    "<\u{000C}\u{FDD0}&lt;",
    collect_errors=true,
    xml_coercion=true,
  )
  assert_eq(invalid_xml.to_html(pretty=false), "&lt; �&lt;")
  assert_eq(invalid_xml.errors.length(), 2)
  assert_eq(invalid_xml.errors[0].code, "invalid-first-character-of-tag-name")
  assert_eq(invalid_xml.errors[1].code, "noncharacter-in-input-stream")
}

///|
test "parser treats script style title textarea content as text" {
  let doc = @html_parser.parse_fragment(
    "<script><!--a--<b</script><title>a &lt; b</title>",
  )
  assert_eq(
    doc.to_html(pretty=false),
    "<script><!--a--<<b</script><title>a &lt; b</title>",
  )
  assert_eq(doc.query("b").length(), 0)
  assert_eq(doc.to_text(separator="|", strip=false), "<!--a--<<b|a < b")
  let escaped_end = @html_parser.parse_fragment("<script><!--a--</script>")
  assert_eq(escaped_end.to_html(pretty=false), "<script><!--a--<</script>")
  let comment_end = @html_parser.parse_fragment("<script><!--a--></script>")
  assert_eq(comment_end.to_html(pretty=false), "<script><!--a--></script>")
  let raw_after_comment = @html_parser.parse_fragment(
    "<script><!--a-->x--</script>",
  )
  assert_eq(
    raw_after_comment.to_html(pretty=false),
    "<script><!--a-->x--</script>",
  )
  let double_escaped = @html_parser.parse_fragment(
    "<script><!--<script>x</script>y</script>",
  )
  assert_eq(
    double_escaped.to_text(separator="|", strip=false),
    "<!--<script>x</script>y",
  )
  let dash_dash_less_than = @html_parser.parse_fragment(
    "<script><!----<x</script>",
  )
  assert_eq(
    dash_dash_less_than.to_html(pretty=false),
    "<script><!----<<x</script>",
  )
  let double_escaped_dash = @html_parser.parse_fragment(
    "<script><!--<script>---x</script>tail</script>",
  )
  assert_eq(
    double_escaped_dash.to_html(pretty=false),
    "<script><!--<script>---x&lt;/script>tail</script>",
  )
  let non_script_double_escape_end = @html_parser.parse_fragment(
    "<script><!--<script></style x</script>tail</script>",
  )
  assert_eq(
    non_script_double_escape_end.to_html(pretty=false),
    "<script><!--<script></style x&lt;/script>tail</script>",
  )
}

///|
test "parser treats xmp and plaintext content as text" {
  let xmp = @html_parser.parse_fragment("<xmp><b>x</b></xmp>after")
  assert_eq(xmp.to_html(pretty=false), "<xmp>&lt;b&gt;x&lt;/b&gt;</xmp>after")
  assert_eq(xmp.query("b").length(), 0)
  let plaintext = @html_parser.parse_fragment(
    "<plaintext><b>x</b></plaintext>after",
    collect_errors=true,
  )
  assert_eq(
    plaintext.to_html(pretty=false),
    "<plaintext>&lt;b&gt;x&lt;/b&gt;&lt;/plaintext&gt;after</plaintext>",
  )
  assert_eq(plaintext.errors[0].code, "expected-closing-tag-but-got-eof")
}

///|
fn assert_script_fragment_eof(
  source : StringView,
  expected_html : String,
  expected_column : Int,
) -> Unit raise {
  let doc = @html_parser.parse_fragment(source, collect_errors=true)
  assert_eq(doc.to_html(pretty=false), expected_html)
  assert_eq(doc.errors.length(), 1)
  assert_eq(doc.errors[0].code, "expected-named-closing-tag-but-got-eof")
  guard doc.errors[0].line is Some(line) else {
    fail("expected script EOF line")
  }
  assert_eq(line, 1)
  guard doc.errors[0].column is Some(column) else {
    fail("expected script EOF column")
  }
  assert_eq(column, expected_column)
}

///|
test "parser reports special text EOF like tree builder" {
  let script = @html_parser.parse_fragment("<script>x", collect_errors=true)
  assert_eq(script.to_html(pretty=false), "<script>x</script>")
  assert_eq(script.errors.length(), 1)
  assert_eq(script.errors[0].code, "expected-named-closing-tag-but-got-eof")
  guard script.errors[0].column is Some(9) else {
    fail("expected script EOF at final text column")
  }
  let textarea = @html_parser.parse_fragment(
    "<textarea>\nx",
    collect_errors=true,
  )
  assert_eq(textarea.to_html(pretty=false), "<textarea>x</textarea>")
  assert_eq(textarea.errors.length(), 1)
  assert_eq(textarea.errors[0].code, "expected-closing-tag-but-got-eof")
  guard textarea.errors[0].line is Some(2) else {
    fail("expected textarea EOF on second line")
  }
  guard textarea.errors[0].column is Some(1) else {
    fail("expected textarea EOF at final text column")
  }
  let xmp = @html_parser.parse_fragment("<xmp>x", collect_errors=true)
  assert_eq(xmp.errors[0].code, "expected-named-closing-tag-but-got-eof")
  let iframe = @html_parser.parse_fragment("<iframe>x", collect_errors=true)
  assert_eq(iframe.errors[0].code, "expected-closing-tag-but-got-eof")
  assert_script_fragment_eof("<script><!--", "<script><!--</script>", 12)
  assert_script_fragment_eof("<script><!---", "<script><!---</script>", 13)
  assert_script_fragment_eof("<script><!--a--", "<script><!--a--</script>", 15)
  assert_script_fragment_eof(
    "<script><!--<script>x", "<script><!--<script>x</script>", 21,
  )
  assert_script_fragment_eof(
    "<script><!--<script>--", "<script><!--<script>--</script>", 22,
  )
  assert_script_fragment_eof(
    "<script><!--<script>--<", "<script><!--<script>--<</script>", 23,
  )
}

///|
test "parser matches malformed special text end tags after solidus" {
  let title = @html_parser.parse(
    "<title>a</title/foo><p>b",
    collect_errors=true,
  )
  assert_eq(
    title.to_html(pretty=false),
    "<html><head><title>a</title></head><body><p>b</p></body></html>",
  )
  assert_eq(title.errors.length(), 2)
  assert_eq(title.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(title.errors[1].code, "unexpected-character-after-solidus-in-tag")
  guard title.errors[1].column is Some(17) else {
    fail("expected title solidus recovery at column 17")
  }
  let title_attr = @html_parser.parse(
    "<title>a</title foo><p>b",
    collect_errors=true,
  )
  assert_eq(
    title_attr.to_html(pretty=false),
    "<html><head><title>a</title></head><body><p>b</p></body></html>",
  )
  assert_eq(title_attr.errors.length(), 1)
  assert_eq(title_attr.errors[0].code, "expected-doctype-but-got-start-tag")
  let title_self_closing = @html_parser.parse(
    "<title>a</title/><p>b",
    collect_errors=true,
  )
  assert_eq(
    title_self_closing.to_html(pretty=false),
    "<html><head><title>a</title></head><body><p>b</p></body></html>",
  )
  assert_eq(title_self_closing.errors.length(), 1)
  assert_eq(
    title_self_closing.errors[0].code,
    "expected-doctype-but-got-start-tag",
  )
  let title_eof = @html_parser.parse("<title>a</title/foo", collect_errors=true)
  assert_eq(
    title_eof.to_html(pretty=false),
    "<html><head><title>a</title></head><body></body></html>",
  )
  assert_eq(title_eof.errors.length(), 4)
  assert_eq(title_eof.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(
    title_eof.errors[1].code,
    "unexpected-character-after-solidus-in-tag",
  )
  assert_eq(title_eof.errors[2].code, "eof-in-tag")
  assert_eq(title_eof.errors[3].code, "expected-named-closing-tag-but-got-eof")
  guard title_eof.errors[2].column is Some(19) else {
    fail("expected title EOF-in-tag at column 19")
  }
  guard title_eof.errors[3].column is Some(19) else {
    fail("expected title tree-builder EOF at column 19")
  }
  let textarea = @html_parser.parse(
    "<textarea>a</textarea/foo><p>b",
    collect_errors=true,
  )
  assert_eq(
    textarea.to_html(pretty=false),
    "<html><head></head><body><textarea>a</textarea><p>b</p></body></html>",
  )
  assert_eq(textarea.errors.length(), 2)
  assert_eq(textarea.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(
    textarea.errors[1].code,
    "unexpected-character-after-solidus-in-tag",
  )
  guard textarea.errors[1].column is Some(23) else {
    fail("expected textarea solidus recovery at column 23")
  }
  let style = @html_parser.parse(
    "<style>a</style/foo><p>b",
    collect_errors=true,
  )
  assert_eq(
    style.to_html(pretty=false),
    "<html><head><style>a</style></head><body><p>b</p></body></html>",
  )
  assert_eq(style.errors.length(), 2)
  assert_eq(style.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(style.errors[1].code, "unexpected-character-after-solidus-in-tag")
  guard style.errors[1].column is Some(17) else {
    fail("expected style solidus recovery at column 17")
  }
  let xmp = @html_parser.parse("<xmp>a</xmp/foo><p>b", collect_errors=true)
  assert_eq(
    xmp.to_html(pretty=false),
    "<html><head></head><body><xmp>a</xmp><p>b</p></body></html>",
  )
  assert_eq(xmp.errors.length(), 2)
  assert_eq(xmp.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(xmp.errors[1].code, "unexpected-character-after-solidus-in-tag")
  guard xmp.errors[1].column is Some(13) else {
    fail("expected xmp solidus recovery at column 13")
  }
  let script = @html_parser.parse(
    "<script>a</script/foo><p>b",
    collect_errors=true,
  )
  assert_eq(
    script.to_html(pretty=false),
    "<html><head><script>a</script></head><body><p>b</p></body></html>",
  )
  assert_eq(script.errors.length(), 2)
  assert_eq(script.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(script.errors[1].code, "unexpected-character-after-solidus-in-tag")
  guard script.errors[1].column is Some(19) else {
    fail("expected script solidus recovery at column 19")
  }
  let script_eof = @html_parser.parse(
    "<script>a</script/foo",
    collect_errors=true,
  )
  assert_eq(
    script_eof.to_html(pretty=false),
    "<html><head><script>a</script></head><body></body></html>",
  )
  assert_eq(script_eof.errors.length(), 4)
  assert_eq(script_eof.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(
    script_eof.errors[1].code,
    "unexpected-character-after-solidus-in-tag",
  )
  assert_eq(script_eof.errors[2].code, "eof-in-tag")
  assert_eq(script_eof.errors[3].code, "expected-named-closing-tag-but-got-eof")
  guard script_eof.errors[2].column is Some(21) else {
    fail("expected script EOF-in-tag at column 21")
  }
  guard script_eof.errors[3].column is Some(21) else {
    fail("expected script tree-builder EOF at column 21")
  }
}

///|
test "parser treats similarly named special end tags as text" {
  let title = @html_parser.parse(
    "<title>a</titlex></title><p>b",
    collect_errors=true,
  )
  assert_eq(
    title.to_html(pretty=false),
    "<html><head><title>a&lt;/titlex&gt;</title></head><body><p>b</p></body></html>",
  )
  assert_eq(title.errors.length(), 1)
  assert_eq(title.errors[0].code, "expected-doctype-but-got-start-tag")
  let textarea = @html_parser.parse(
    "<textarea>a</textareax></textarea><p>b",
    collect_errors=true,
  )
  assert_eq(
    textarea.to_html(pretty=false),
    "<html><head></head><body><textarea>a&lt;/textareax&gt;</textarea><p>b</p></body></html>",
  )
  assert_eq(textarea.errors.length(), 1)
  assert_eq(textarea.errors[0].code, "expected-doctype-but-got-start-tag")
  let xmp = @html_parser.parse("<xmp>a</xmpx></xmp><p>b", collect_errors=true)
  assert_eq(
    xmp.to_html(pretty=false),
    "<html><head></head><body><xmp>a&lt;/xmpx&gt;</xmp><p>b</p></body></html>",
  )
  assert_eq(xmp.errors.length(), 1)
  assert_eq(xmp.errors[0].code, "expected-doctype-but-got-start-tag")
}

///|
test "parser treats legacy raw text elements as text" {
  let doc = @html_parser.parse_fragment(
    "<iframe><b>x</b></iframe><noembed><i>y</i></noembed><noscript><em>z</em></noscript>",
  )
  assert_eq(
    doc.to_html(pretty=false),
    "<iframe>&lt;b&gt;x&lt;/b&gt;</iframe><noembed>&lt;i&gt;y&lt;/i&gt;</noembed><noscript>&lt;em&gt;z&lt;/em&gt;</noscript>",
  )
  assert_eq(doc.query("b").length(), 0)
  assert_eq(doc.query("i").length(), 0)
  assert_eq(doc.query("em").length(), 0)
}

///|
test "parser honors scripting enabled for noscript text mode" {
  let enabled = @html_parser.parse_fragment(
    "<noscript><b>Hi</b></noscript>",
    scripting_enabled=true,
  )
  assert_eq(
    enabled.to_html(pretty=false),
    "<noscript>&lt;b&gt;Hi&lt;/b&gt;</noscript>",
  )
  assert_eq(enabled.query("b").length(), 0)
  let disabled = @html_parser.parse_fragment(
    "<noscript><b>Hi</b></noscript>",
    scripting_enabled=false,
  )
  assert_eq(disabled.to_html(pretty=false), "<noscript><b>Hi</b></noscript>")
  assert_eq(disabled.query("b").length(), 1)
}

///|
test "parser handles disabled scripting noscript in head" {
  let doctype = @html_parser.parse(
    "<head><noscript><!DOCTYPE html></noscript>",
    collect_errors=true,
    scripting_enabled=false,
  )
  assert_eq(
    doctype.to_html(pretty=false),
    "<html><head><noscript></noscript></head><body></body></html>",
  )
  assert_eq(doctype.errors.length(), 2)
  assert_eq(doctype.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(doctype.errors[1].code, "unexpected-doctype")
  let stray_end = @html_parser.parse(
    "<head><noscript></p></noscript>",
    collect_errors=true,
    scripting_enabled=false,
  )
  assert_eq(
    stray_end.to_html(pretty=false),
    "<html><head><noscript></noscript></head><body></body></html>",
  )
  assert_eq(stray_end.errors.length(), 2)
  assert_eq(stray_end.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(stray_end.errors[1].code, "unexpected-end-tag")
  let stray_head = @html_parser.parse(
    "<head><noscript><head></noscript>",
    collect_errors=true,
    scripting_enabled=false,
  )
  assert_eq(
    stray_head.to_html(pretty=false),
    "<html><head><noscript></noscript></head><body></body></html>",
  )
  assert_eq(stray_head.errors.length(), 2)
  assert_eq(stray_head.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(stray_head.errors[1].code, "unexpected-start-tag")
  let stray_br = @html_parser.parse(
    "<head><noscript></br>x",
    collect_errors=true,
    scripting_enabled=false,
  )
  assert_eq(
    stray_br.to_html(pretty=false),
    "<html><head><noscript></noscript></head><body><br>x</body></html>",
  )
  assert_eq(stray_br.errors.length(), 3)
  assert_eq(stray_br.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(stray_br.errors[1].code, "unexpected-end-tag")
  assert_eq(stray_br.errors[2].code, "unexpected-end-tag")
  let paragraph = @html_parser.parse(
    "<head><noscript><p>x</noscript>",
    collect_errors=true,
    scripting_enabled=false,
  )
  assert_eq(
    paragraph.to_html(pretty=false),
    "<html><head><noscript></noscript></head><body><p>x</p></body></html>",
  )
  assert_eq(paragraph.errors.length(), 3)
  assert_eq(paragraph.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(paragraph.errors[1].code, "unexpected-start-tag")
  assert_eq(paragraph.errors[2].code, "unexpected-end-tag")
  let text = @html_parser.parse(
    "<head><noscript>x</noscript>",
    collect_errors=true,
    scripting_enabled=false,
  )
  assert_eq(
    text.to_html(pretty=false),
    "<html><head><noscript></noscript></head><body>x</body></html>",
  )
  assert_eq(text.errors.length(), 3)
  assert_eq(text.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(text.errors[1].code, "unexpected-start-tag")
  assert_eq(text.errors[2].code, "unexpected-end-tag")
  let leading_space = @html_parser.parse(
    "<head><noscript> x</noscript>",
    collect_errors=true,
    scripting_enabled=false,
  )
  assert_eq(
    leading_space.to_html(pretty=false),
    "<html><head><noscript></noscript> </head><body>x</body></html>",
  )
  assert_eq(leading_space.errors.length(), 3)
  assert_eq(leading_space.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(leading_space.errors[1].code, "unexpected-start-tag")
  assert_eq(leading_space.errors[2].code, "unexpected-end-tag")
  let coerced_leading_space = @html_parser.parse(
    "<head><noscript>\u{000C} x</noscript>",
    collect_errors=true,
    scripting_enabled=false,
    xml_coercion=true,
  )
  assert_eq(
    coerced_leading_space.to_html(pretty=false),
    "<html><head><noscript></noscript>  </head><body>x</body></html>",
  )
  assert_eq(coerced_leading_space.errors.length(), 3)
  assert_eq(
    coerced_leading_space.errors[0].code,
    "expected-doctype-but-got-start-tag",
  )
  assert_eq(coerced_leading_space.errors[1].code, "unexpected-start-tag")
  assert_eq(coerced_leading_space.errors[2].code, "unexpected-end-tag")
  let allowed = @html_parser.parse(
    "<head><noscript><link rel=x></noscript><p>y",
    collect_errors=true,
    scripting_enabled=false,
  )
  assert_eq(
    allowed.to_html(pretty=false),
    "<html><head><noscript><link rel=\"x\"></noscript></head><body><p>y</p></body></html>",
  )
  assert_eq(allowed.errors.length(), 1)
  assert_eq(allowed.errors[0].code, "expected-doctype-but-got-start-tag")
}

///|
test "parser ignores one initial newline in pre listing and textarea" {
  let pre = @html_parser.parse_fragment(
    "<pre>\r\nline</pre><listing>\nitem</listing>",
  )
  assert_eq(pre.to_html(pretty=false), "<pre>line</pre><listing>item</listing>")
  let pre_cr = @html_parser.parse_fragment("<pre>\rline</pre>")
  assert_eq(pre_cr.to_html(pretty=false), "<pre>line</pre>")
  let listing_cr = @html_parser.parse_fragment("<listing>\rline</listing>")
  assert_eq(listing_cr.to_html(pretty=false), "<listing>line</listing>")
  let textarea = @html_parser.parse_fragment("<textarea>\nline</textarea>")
  assert_eq(textarea.to_html(pretty=false), "<textarea>line</textarea>")
  let textarea_cr = @html_parser.parse_fragment("<textarea>\rline</textarea>")
  assert_eq(textarea_cr.to_html(pretty=false), "<textarea>line</textarea>")
  let textarea_crlf = @html_parser.parse_fragment(
    "<textarea>\r\nline</textarea>",
  )
  assert_eq(textarea_crlf.to_html(pretty=false), "<textarea>line</textarea>")
  let title = @html_parser.parse_fragment("<title>\nline</title>")
  assert_eq(title.to_html(pretty=false), "<title>\nline</title>")
  let title_cr = @html_parser.parse_fragment("<title>\rline</title>")
  assert_eq(title_cr.to_html(pretty=false), "<title>\nline</title>")
}

///|
test "tokenize preserves rawtext and rcdata element contents" {
  let script = @html_parser.tokenize("<script><!--a--<b</script>")
  assert_eq(script.tokens.length(), 4)
  guard script.tokens[1] is Characters("<!--a--<<b") else {
    fail("expected raw script text")
  }
  guard script.tokens[2] is Tag(end_script) else { fail("expected script end") }
  assert_true(end_script.kind is EndTag)
  assert_eq(end_script.name, "script")
  let escaped_end = @html_parser.tokenize("<script><!--a--</script>")
  guard escaped_end.tokens[1] is Characters("<!--a--<") else {
    fail("expected escaped script end-tag boundary text")
  }
  let escaped_eof = @html_parser.tokenize("<script><!--a--<")
  guard escaped_eof.tokens[1] is Characters("<!--a--<<") else {
    fail("expected escaped EOF less-than text")
  }
  let comment_end = @html_parser.tokenize("<script><!--a--></script>")
  guard comment_end.tokens[1] is Characters("<!--a-->") else {
    fail("expected script comment close to return to raw text")
  }
  let nul_script = @html_parser.tokenize(
    "<script>a\u{0000}b</script>",
    collect_errors=true,
  )
  guard nul_script.tokens[1] is Characters("a\u{FFFD}b") else {
    fail("expected replacement char in script text")
  }
  assert_eq(nul_script.errors.length(), 1)
  assert_eq(nul_script.errors[0].code, "unexpected-null-character")
  guard nul_script.errors[0].column is Some(10) else {
    fail("expected script text null at column 10")
  }
  let nul_style = @html_parser.tokenize(
    "<style>a\u{0000}b</style>",
    collect_errors=true,
  )
  guard nul_style.tokens[1] is Characters("a\u{FFFD}b") else {
    fail("expected replacement char in style text")
  }
  assert_eq(nul_style.errors.length(), 1)
  assert_eq(nul_style.errors[0].code, "unexpected-null-character")
  let nul_title = @html_parser.tokenize(
    "<title>a\u{0000} &lt; b</title>",
    collect_errors=true,
  )
  guard nul_title.tokens[1] is Characters("a\u{FFFD} < b") else {
    fail("expected replacement char and entity decoding in title text")
  }
  assert_eq(nul_title.errors.length(), 1)
  assert_eq(nul_title.errors[0].code, "unexpected-null-character")
  let nul_plaintext = @html_parser.tokenize(
    "<plaintext>a\u{0000}b",
    collect_errors=true,
  )
  guard nul_plaintext.tokens[1] is Characters("a\u{FFFD}b") else {
    fail("expected replacement char in plaintext")
  }
  assert_eq(nul_plaintext.errors.length(), 1)
  assert_eq(nul_plaintext.errors[0].code, "unexpected-null-character")
  let double_escaped = @html_parser.tokenize(
    "<script><!--<script>x</script>y</script>",
  )
  guard double_escaped.tokens[1] is Characters("<!--<script>x</script>y") else {
    fail("expected inner script end tag to stay in double-escaped text")
  }
  guard double_escaped.tokens[2] is Tag(double_end) else {
    fail("expected final script end")
  }
  assert_eq(double_end.name, "script")
  let not_double_escaped = @html_parser.tokenize(
    "<script><!--<scripty>x</script>-->z</script>",
  )
  guard not_double_escaped.tokens[1] is Characters("<!--<scripty>x") else {
    fail("expected non-script word to avoid double-escaped state")
  }
  guard not_double_escaped.tokens[3] is Characters("-->z") else {
    fail("expected text after the first script end tag")
  }
  let textarea = @html_parser.tokenize("<textarea>a &lt; b</textarea>")
  guard textarea.tokens[1] is Characters("a < b") else {
    fail("expected decoded textarea text")
  }
  let textarea_lf = @html_parser.tokenize("<textarea>\nline</textarea>")
  guard textarea_lf.tokens[1] is Characters("\nline") else {
    fail("expected tokenizer to preserve textarea leading newline")
  }
  let xmp = @html_parser.tokenize("<xmp><b>x</b></xmp>")
  guard xmp.tokens[1] is Characters("<b>x</b>") else {
    fail("expected xmp raw text")
  }
  let plaintext = @html_parser.tokenize("<plaintext><b>x</b></plaintext>")
  guard plaintext.tokens[1] is Characters("<b>x</b></plaintext>") else {
    fail("expected plaintext through EOF")
  }
  let iframe = @html_parser.tokenize("<iframe><b>x</b></iframe>")
  guard iframe.tokens[1] is Characters("<b>x</b>") else {
    fail("expected iframe raw text")
  }
  let empty_title = @html_parser.tokenize("<title></title>")
  guard empty_title.tokens[1] is Tag(empty_title_end) else {
    fail("expected immediate title end tag")
  }
  assert_true(empty_title_end.kind is EndTag)
  let eof_title = @html_parser.tokenize("<title>")
  guard eof_title.tokens[1] is Eof else {
    fail("expected EOF after empty unclosed title")
  }
  let empty_plaintext = @html_parser.tokenize("<plaintext>")
  guard empty_plaintext.tokens[1] is Eof else {
    fail("expected EOF after empty plaintext")
  }
  let xml_title = @html_parser.tokenize(
    "<title>\u{000C}\u{FDD0}</title>",
    xml_coercion=true,
  )
  guard xml_title.tokens[1] is Characters(" �") else {
    fail("expected XML coercion in RCDATA text")
  }
}

///|
test "tokenize keeps similarly named special end tags in text" {
  let title = @html_parser.tokenize("<title>a</titlex></title>")
  guard title.tokens[1] is Characters("a</titlex>") else {
    fail("expected title suffix end tag to stay in text")
  }
  guard title.tokens[2] is Tag(end_title) else {
    fail("expected final title end tag")
  }
  assert_true(end_title.kind is EndTag)
  assert_eq(end_title.name, "title")
  let style = @html_parser.tokenize("<style>a</stylex></style>")
  guard style.tokens[1] is Characters("a</stylex>") else {
    fail("expected style suffix end tag to stay in text")
  }
  guard style.tokens[2] is Tag(end_style) else {
    fail("expected final style end tag")
  }
  assert_true(end_style.kind is EndTag)
  assert_eq(end_style.name, "style")
}

///|
test "tokenize does not report special text EOF tree errors" {
  let script = @html_parser.tokenize("<script>x", collect_errors=true)
  guard script.tokens[1] is Characters("x") else {
    fail("expected unclosed script text")
  }
  assert_eq(script.errors.length(), 0)
  let plaintext = @html_parser.tokenize("<plaintext>x", collect_errors=true)
  guard plaintext.tokens[1] is Characters("x") else {
    fail("expected unclosed plaintext text")
  }
  assert_eq(plaintext.errors.length(), 0)
  let title = @html_parser.tokenize("<title>x", collect_errors=true)
  guard title.tokens[1] is Characters("x") else {
    fail("expected unclosed title text")
  }
  assert_eq(title.errors.length(), 0)
}
