///|
test "apply_transforms drops unwraps escapes and empties selected elements" {
  let dropped = @html_parser.parse_fragment(
    "<p>ok</p><script>alert(1)</script>",
  )
  ignore(
    @html_parser.apply_transforms(dropped.root, [
      @html_parser.TransformSpec::drop("script"),
    ]),
  )
  assert_eq(dropped.root.to_html(pretty=false), "<p>ok</p>")

  let unwrapped = @html_parser.parse_fragment("<p>Hello <span>world</span></p>")
  ignore(
    @html_parser.apply_transforms(unwrapped.root, [
      @html_parser.TransformSpec::unwrap("span"),
    ]),
  )
  assert_eq(unwrapped.root.to_html(pretty=false), "<p>Hello world</p>")

  let escaped = @html_parser.parse_fragment("<p>Hello <span>world</span></p>")
  ignore(
    @html_parser.apply_transforms(escaped.root, [
      @html_parser.TransformSpec::escape("span"),
    ]),
  )
  assert_eq(
    escaped.root.to_html(pretty=false),
    "<p>Hello &lt;span&gt;world&lt;/span&gt;</p>",
  )

  let emptied = @html_parser.parse_fragment("<div><b>x</b>y</div>")
  ignore(
    @html_parser.apply_transforms(emptied.root, [
      @html_parser.TransformSpec::empty("div"),
    ]),
  )
  assert_eq(emptied.root.to_html(pretty=false), "<div></div>")
}

///|
test "apply_transforms drops comments doctypes and collapses whitespace" {
  let root = @html_parser.document(children=[
    @html_parser.doctype(),
    @html_parser.comment("lead"),
    @html_parser.element("p", children=[@html_parser.text("Hello \n\t world")]),
    @html_parser.element("pre", children=[@html_parser.text("a  b")]),
  ])
  ignore(
    @html_parser.apply_transforms(root, [
      @html_parser.TransformSpec::drop_doctype(),
      @html_parser.TransformSpec::drop_comments(),
      @html_parser.TransformSpec::collapse_whitespace(),
    ]),
  )
  assert_eq(root.to_html(pretty=false), "<p>Hello world</p><pre>a  b</pre>")
}

///|
test "collapse_whitespace preserves edge spaces and supports custom skip tags" {
  let edge = @html_parser.parse_fragment("<p> a \n\t b </p><span>a  b</span>")
  ignore(
    @html_parser.apply_transforms(edge.root, [
      @html_parser.TransformSpec::collapse_whitespace(skip_tags=["span"]),
    ]),
  )
  assert_eq(edge.root.to_html(pretty=false), "<p> a b </p><span>a  b</span>")
}

///|
test "apply_transforms runs linkify and selector transforms in order" {
  let drop_first = @html_parser.parse_fragment("<p>example.com</p>")
  ignore(
    @html_parser.apply_transforms(drop_first.root, [
      @html_parser.TransformSpec::drop("a"),
      @html_parser.TransformSpec::linkify(),
    ]),
  )
  assert_eq(
    drop_first.root.to_html(pretty=false),
    "<p><a href=\"http://example.com\">example.com</a></p>",
  )

  let linkify_first = @html_parser.parse_fragment("<p>example.com</p>")
  ignore(
    @html_parser.apply_transforms(linkify_first.root, [
      @html_parser.TransformSpec::linkify(),
      @html_parser.TransformSpec::drop("a"),
    ]),
  )
  assert_eq(linkify_first.root.to_html(pretty=false), "<p></p>")
}

///|
test "apply_transforms sets and drops attributes by selector" {
  let doc = @html_parser.parse_fragment(
    "<p>Hello</p><div onclick='x' xml:lang='sv' srcdoc='x' data-ok='1'></div>",
  )
  ignore(
    @html_parser.apply_transforms(doc.root, [
      @html_parser.TransformSpec::set_attrs("p", {
        "id": Some("intro"),
        "data-empty": None,
      }),
      @html_parser.TransformSpec::drop_attrs("*", ["on*", "*:*", "srcdoc"]),
    ]),
  )
  assert_eq(
    doc.root.to_html(pretty=false),
    "<p id=\"intro\" data-empty>Hello</p><div data-ok=\"1\"></div>",
  )
}

///|
test "drop_attrs lowercases rewritten safe attributes and noops without match" {
  let div = @html_parser.element("div", attrs={
    "Data-X": Some("1"),
    "OnClick": Some("run()"),
  })
  let root = @html_parser.fragment(children=[div])
  ignore(
    @html_parser.apply_transforms(root, [
      @html_parser.TransformSpec::drop_attrs("div", ["on*"]),
    ]),
  )
  assert_eq(root.to_html(pretty=false), "<div data-x=\"1\"></div>")

  let no_match = @html_parser.element("div", attrs={ "Data-X": Some("1") })
  let wrapper = @html_parser.fragment(children=[no_match])
  ignore(
    @html_parser.apply_transforms(wrapper, [
      @html_parser.TransformSpec::drop_attrs("div", ["srcdoc"]),
    ]),
  )
  assert_eq(wrapper.to_html(pretty=false), "<div Data-X=\"1\"></div>")

  let hot_path = @html_parser.fragment(children=[
    @html_parser.element("div", attrs={
      "Data-X": Some("1"),
      "OnClick": Some("run()"),
      "SrcDoc": Some("x"),
    }),
  ])
  ignore(
    @html_parser.apply_transforms(hot_path, [
      @html_parser.TransformSpec::drop_attrs("*", ["on*", "*:*", "srcdoc"]),
    ]),
  )
  assert_eq(hot_path.to_html(pretty=false), "<div Data-X=\"1\"></div>")
}

///|
test "allowlist_attrs keeps global and tag-specific attributes" {
  let root = @html_parser.fragment(children=[
    @html_parser.element(
      "a",
      attrs={
        "HREF": Some("https://example.com"),
        "Rel": Some("noreferrer"),
        "BAD": Some("x"),
        "id": Some("link"),
      },
      children=[@html_parser.text("x")],
    ),
    @html_parser.element("span", attrs={ "id": Some("s"), "href": Some("nope") }),
  ])
  ignore(
    @html_parser.apply_transforms(root, [
      @html_parser.TransformSpec::allowlist_attrs("*", {
        "*": ["id"],
        "a": ["href", "rel"],
      }),
    ]),
  )
  assert_eq(
    root.to_html(pretty=false),
    "<a href=\"https://example.com\" rel=\"noreferrer\" id=\"link\">x</a><span id=\"s\"></span>",
  )
}

///|
test "merge_attrs normalizes duplicate tokens and mixed-case keys" {
  let root = @html_parser.parse_fragment(
      "<a></a><a rel='NoOpEnEr noopener'></a><a rel='noreferrer'></a>",
    ).root
  ignore(
    @html_parser.apply_transforms(root, [
      @html_parser.TransformSpec::merge_attrs("a", attr="rel", tokens=[
        "noopener",
      ]),
    ]),
  )
  assert_eq(
    root.to_html(pretty=false),
    "<a rel=\"noopener\"></a><a rel=\"noopener\"></a><a rel=\"noreferrer noopener\"></a>",
  )

  let mixed = @html_parser.fragment(children=[
    @html_parser.element("a", attrs={ "Rel": Some("noreferrer") }),
  ])
  ignore(
    @html_parser.apply_transforms(mixed, [
      @html_parser.TransformSpec::merge_attrs("a", attr="rel", tokens=[
        "noopener",
      ]),
    ]),
  )
  assert_eq(mixed.to_html(pretty=false), "<a rel=\"noreferrer noopener\"></a>")
}

///|
test "sanitize transform runs in order and can resanitize later mutations" {
  let first = @html_parser.parse_fragment("<p><a href='javascript:x'>x</a></p>")
  ignore(
    @html_parser.apply_transforms(first.root, [
      @html_parser.TransformSpec::sanitize(),
      @html_parser.TransformSpec::set_attrs("a", {
        "href": Some("javascript:y"),
        "onclick": Some("run()"),
      }),
    ]),
  )
  assert_eq(
    first.root.to_html(pretty=false),
    "<p><a href=\"javascript:y\" onclick=\"run()\">x</a></p>",
  )

  let second = @html_parser.parse_fragment(
    "<p><a href='javascript:x'>x</a></p>",
  )
  ignore(
    @html_parser.apply_transforms(second.root, [
      @html_parser.TransformSpec::sanitize(),
      @html_parser.TransformSpec::set_attrs("a", {
        "href": Some("javascript:y"),
        "onclick": Some("run()"),
      }),
      @html_parser.TransformSpec::sanitize(),
    ]),
  )
  assert_eq(second.root.to_html(pretty=false), "<p><a>x</a></p>")
}

///|
test "sanitize transform accepts custom policy and can replace standalone root" {
  let policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    allowed_attributes={ "*": ["id"] },
    drop_comments=false,
  )
  let custom = @html_parser.parse_fragment(
    "<!--c--><p id='ok' class='bad'>x</p><span>y</span>",
  )
  ignore(
    @html_parser.apply_transforms(custom.root, [
      @html_parser.TransformSpec::sanitize(policy~),
    ]),
  )
  assert_eq(custom.root.to_html(pretty=false), "<!--c--><p id=\"ok\">x</p>y")

  let script = @html_parser.element("script", children=[@html_parser.text("x")])
  let clean = @html_parser.apply_transforms(script, [
    @html_parser.TransformSpec::sanitize(),
  ])
  assert_eq(clean.to_html(pretty=false), "")
}

///|
test "sanitize transform propagates unsafe raise policy errors" {
  let policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    allowed_attributes={ "p": [] },
    unsafe_handling=Raise,
  )
  let doc = @html_parser.parse_fragment("<p foo='1'>safe</p>")
  let result = try? @html_parser.apply_transforms(doc.root, [
    @html_parser.TransformSpec::sanitize(policy~),
  ])
  match result {
    Err(UnsafeHtml(message)) =>
      assert_eq(
        message, "Unsafe attribute 'foo' on <p> was dropped because it is not allowed",
      )
    _ => fail("expected sanitize transform to raise UnsafeHtml")
  }
}
