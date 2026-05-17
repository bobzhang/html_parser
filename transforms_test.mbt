///|
fn transform_repeat_for_test(value : String, count : Int) -> String {
  let out = StringBuilder::new(size_hint=value.length() * count)
  for _ in 0..<count {
    out.write_string(value)
  }
  out.to_string()
}

///|
test "transform callback debug representations stay opaque" {
  let node_spec = @html_parser.TransformSpec::edit_document(
    fn(_node) { () },
    hook=fn(_node) { () },
    report=fn(_message, _node) { () },
  )
  let attrs_spec = @html_parser.TransformSpec::edit_attrs("p", fn(_node) {
    None
  })
  let decide_spec = @html_parser.TransformSpec::decide("*", fn(_node) { Keep })
  let repr = node_spec.to_repr().to_string() +
    attrs_spec.to_repr().to_string() +
    decide_spec.to_repr().to_string()
  assert_true(repr.contains("<TransformNodeCallback: ()>"))
  assert_true(repr.contains("<TransformAttrsCallback: ()>"))
  assert_true(repr.contains("<TransformDecideCallback: ()>"))
  assert_true(repr.contains("<TransformReportCallback: ()>"))
  assert_eq(repr.contains("fn("), false)
}

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
test "escape transform does not synthesize void element end tags" {
  let doc = @html_parser.parse_fragment("<p><img src=/x><br><span>y</span></p>")
  ignore(
    @html_parser.apply_transforms(doc.root, [
      @html_parser.TransformSpec::escape("img, br, span"),
    ]),
  )
  assert_eq(
    doc.root.to_html(pretty=false),
    "<p>&lt;img src=\"/x\"&gt;&lt;br&gt;&lt;span&gt;y&lt;/span&gt;</p>",
  )
}

///|
test "unwrap skips direct moved children but walks their descendants" {
  let root = @html_parser.parse_fragment(
    "<div><div>x</div><section><div>y</div></section></div>",
  )
  ignore(
    @html_parser.apply_transforms(root.root, [
      @html_parser.TransformSpec::unwrap("div"),
    ]),
  )
  assert_eq(root.root.to_html(pretty=false), "<div>x</div><section>y</section>")

  let later = @html_parser.parse_fragment("<div><div>x</div></div>")
  ignore(
    @html_parser.apply_transforms(later.root, [
      @html_parser.TransformSpec::unwrap("div"),
      @html_parser.TransformSpec::set_attrs("div", { "class": Some("later") }),
    ]),
  )
  assert_eq(later.root.to_html(pretty=false), "<div class=\"later\">x</div>")
}

///|
test "compiled walk marker edge cases stay order preserving" {
  let escape_all = @html_parser.parse_fragment(
    "<div><span><b>x</b></span></div>",
  )
  ignore(
    @html_parser.apply_transforms(escape_all.root, [
      @html_parser.TransformSpec::escape("*"),
    ]),
  )
  assert_eq(
    escape_all.root.to_html(pretty=false),
    "&lt;div&gt;&lt;span&gt;&lt;b&gt;x&lt;/b&gt;&lt;/span&gt;&lt;/div&gt;",
  )

  let escape_then_drop = @html_parser.parse_fragment(
    "<div><span><b>x</b></span></div>",
  )
  ignore(
    @html_parser.apply_transforms(escape_then_drop.root, [
      @html_parser.TransformSpec::escape("span"),
      @html_parser.TransformSpec::drop("b"),
    ]),
  )
  assert_eq(
    escape_then_drop.root.to_html(pretty=false),
    "<div>&lt;span&gt;&lt;/span&gt;</div>",
  )

  let decide_unwrap : (@html_parser.Node) -> @html_parser.DecideAction = fn(
    node,
  ) {
    match node.name() {
      "span" => Unwrap
      "b" => Drop
      _ => Keep
    }
  }
  let decided = @html_parser.parse_fragment("<div><span><b>x</b></span></div>")
  ignore(
    @html_parser.apply_transforms(decided.root, [
      @html_parser.TransformSpec::decide("*", decide_unwrap),
    ]),
  )
  assert_eq(decided.root.to_html(pretty=false), "<div></div>")

  let linkify_then_drop = @html_parser.parse_fragment("<p>example.com</p>")
  ignore(
    @html_parser.apply_transforms(linkify_then_drop.root, [
      @html_parser.TransformSpec::linkify(),
      @html_parser.TransformSpec::drop("a"),
    ]),
  )
  assert_eq(linkify_then_drop.root.to_html(pretty=false), "<p></p>")
}

///|
test "decide star can act on comments while selectors only visit elements" {
  let seen_all : Array[String] = []
  let keep_seen : (@html_parser.Node) -> @html_parser.DecideAction = fn(node) {
    seen_all.push(node.name())
    Keep
  }
  let all_nodes = @html_parser.parse_fragment("<p>y</p>")
  ignore(
    @html_parser.apply_transforms(all_nodes.root, [
      @html_parser.TransformSpec::decide("*", keep_seen),
    ]),
  )
  @test.assert_eq(seen_all, ["p", "#text"])

  let decide_comment : (@html_parser.Node) -> @html_parser.DecideAction = fn(
    node,
  ) {
    if node.name() == "#comment" {
      Drop
    } else {
      Keep
    }
  }
  let doc = @html_parser.parse_fragment("<!--x--><p>y</p>")
  ignore(
    @html_parser.apply_transforms(doc.root, [
      @html_parser.TransformSpec::decide("*", decide_comment),
    ]),
  )
  assert_eq(doc.root.to_html(pretty=false), "<p>y</p>")

  let escape_misc = @html_parser.fragment(children=[
    @html_parser.comment("x"),
    @html_parser.element("p", children=[@html_parser.text("y")]),
  ])
  ignore(
    @html_parser.apply_transforms(escape_misc, [
      @html_parser.TransformSpec::decide("*", fn(node) {
        match node.name() {
          "#comment" => Escape
          _ => Keep
        }
      }),
    ]),
  )
  assert_eq(escape_misc.to_html(pretty=false), "<p>y</p>")

  let root_text = @html_parser.text("root")
  let root_result = @html_parser.apply_transforms(root_text, [
    @html_parser.TransformSpec::decide("*", fn(_node) { Drop }),
  ])
  assert_eq(root_result.to_html(pretty=false), "root")

  let decide_fragment : (@html_parser.Node) -> @html_parser.DecideAction = fn(
    node,
  ) {
    if node.name() == "#document-fragment" {
      Escape
    } else {
      Keep
    }
  }
  let nested_fragment = @html_parser.fragment(children=[
    @html_parser.fragment(children=[
      @html_parser.element("span", children=[@html_parser.text("z")]),
    ]),
  ])
  ignore(
    @html_parser.apply_transforms(nested_fragment, [
      @html_parser.TransformSpec::decide("*", decide_fragment),
    ]),
  )
  assert_eq(nested_fragment.to_html(pretty=false), "<span>z</span>")

  let seen : Array[String] = []
  let decide_p : (@html_parser.Node) -> @html_parser.DecideAction = fn(node) {
    seen.push(node.name())
    Drop
  }
  let selected = @html_parser.parse_fragment("<!--x--><p>y</p>")
  ignore(
    @html_parser.apply_transforms(selected.root, [
      @html_parser.TransformSpec::decide("p", decide_p),
    ]),
  )
  assert_eq(selected.root.to_html(pretty=false), "<!--x-->")
  @test.assert_eq(seen, ["p"])
}

///|
test "decide applies empty unwrap and escape structural actions" {
  let empty_div : (@html_parser.Node) -> @html_parser.DecideAction = fn(_) {
    Empty
  }
  let emptied = @html_parser.parse_fragment("<div><span>x</span>y</div>")
  ignore(
    @html_parser.apply_transforms(emptied.root, [
      @html_parser.TransformSpec::decide("div", empty_div),
    ]),
  )
  assert_eq(emptied.root.to_html(pretty=false), "<div></div>")

  let unwrap_node : (@html_parser.Node) -> @html_parser.DecideAction = fn(_) {
    Unwrap
  }
  let unwrapped = @html_parser.parse_fragment(
    "<div><template><b>x</b></template><span><i>y</i></span></div>",
  )
  ignore(
    @html_parser.apply_transforms(unwrapped.root, [
      @html_parser.TransformSpec::decide("template, span", unwrap_node),
    ]),
  )
  assert_eq(unwrapped.root.to_html(pretty=false), "<div><b>x</b><i>y</i></div>")

  let escape_div : (@html_parser.Node) -> @html_parser.DecideAction = fn(_) {
    Escape
  }
  let escaped = @html_parser.parse_fragment("<div><span>child</span></div>")
  ignore(
    @html_parser.apply_transforms(escaped.root, [
      @html_parser.TransformSpec::decide("div", escape_div),
    ]),
  )
  assert_eq(
    escaped.root.to_html(pretty=false),
    "&lt;div&gt;<span>child</span>&lt;/div&gt;",
  )
}

///|
test "decide reports non-keep actions exactly" {
  let events : Array[String] = []
  let decide : (@html_parser.Node) -> @html_parser.DecideAction = fn(node) {
    if node.name() == "p" {
      Drop
    } else {
      Keep
    }
  }
  let hook : (@html_parser.Node) -> Unit = fn(node) {
    events.push("hook:" + node.name())
  }
  let report : (String, @html_parser.Node?) -> Unit = fn(message, node) {
    events.push("report:" + message)
    match node {
      Some(hit) => events.push("node:" + hit.name())
      None => events.push("node:none")
    }
  }
  let doc = @html_parser.parse_fragment("<p>y</p><span>z</span>")
  ignore(
    @html_parser.apply_transforms(doc.root, [
      @html_parser.TransformSpec::decide("*", decide, hook~, report~),
    ]),
  )
  assert_eq(doc.root.to_html(pretty=false), "<span>z</span>")
  @test.assert_eq(events, [
    "hook:p", "report:Decide -> drop 'p' (matched selector '*')", "node:p",
  ])
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
test "drop_foreign_namespaces drops only non-html elements" {
  let events : Array[String] = []
  let hook : (@html_parser.Node) -> Unit = fn(node) {
    events.push("hook:" + node.name())
  }
  let report : (String, @html_parser.Node?) -> Unit = fn(message, node) {
    events.push("report:" + message)
    match node {
      Some(hit) => events.push("node:" + hit.name())
      None => events.push("node:none")
    }
  }
  let root = @html_parser.fragment(children=[
    @html_parser.comment("x"),
    @html_parser.doctype(),
    @html_parser.element("svg", ns="svg"),
    @html_parser.element("math", ns="math"),
    @html_parser.element("p", children=[@html_parser.text("ok")]),
  ])
  ignore(
    @html_parser.apply_transforms(root, [
      @html_parser.TransformSpec::drop_foreign_namespaces(hook~, report~),
    ]),
  )
  let names : Array[String] = []
  for child in root.children() {
    names.push(child.name())
  }
  @test.assert_eq(names, ["#comment", "#doctype", "p"])
  @test.assert_eq(events, [
    "hook:svg", "report:Unsafe tag 'svg' (foreign namespace)", "node:svg", "hook:math",
    "report:Unsafe tag 'math' (foreign namespace)", "node:math",
  ])
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
test "stage auto grouping preserves ordering and trailing transforms" {
  let stage_first = @html_parser.parse_fragment("<p>example.com</p>")
  ignore(
    @html_parser.apply_transforms(stage_first.root, [
      @html_parser.TransformSpec::drop("a"),
      @html_parser.TransformSpec::stage([@html_parser.TransformSpec::linkify()]),
    ]),
  )
  assert_eq(
    stage_first.root.to_html(pretty=false),
    "<p><a href=\"http://example.com\">example.com</a></p>",
  )

  let trailing = @html_parser.parse_fragment("<p>Hello</p>")
  ignore(
    @html_parser.apply_transforms(trailing.root, [
      @html_parser.TransformSpec::stage([
        @html_parser.TransformSpec::set_attrs("p", { "id": Some("x") }),
      ]),
      @html_parser.TransformSpec::set_attrs("p", { "class": Some("y") }),
    ]),
  )
  let paragraphs = trailing.root.query("p")
  assert_eq(paragraphs.length(), 1)
  assert_true(paragraphs[0].attrs().get("id") is Some(Some("x")))
  assert_true(paragraphs[0].attrs().get("class") is Some(Some("y")))
}

///|
test "sanitize policy selector limits apply to transform selectors" {
  let long_class = transform_repeat_for_test("a", 8192)
  let long_selector = "." + long_class
  let relaxed_policy = @html_parser.SanitizationPolicy::new(
    ["div"],
    allowed_attributes={ "*": ["class", "id"] },
    selector_limits=@html_parser.SelectorLimits::new(max_length=9000),
  )
  let relaxed = @html_parser.parse_fragment(
    "<div class=\"" + long_class + "\"></div>",
  )
  ignore(
    @html_parser.apply_transforms(relaxed.root, [
      @html_parser.TransformSpec::set_attrs(long_selector, {
        "id": Some("matched"),
      }),
      @html_parser.TransformSpec::sanitize(policy=relaxed_policy),
    ]),
  )
  let relaxed_divs = relaxed.root.query("div")
  assert_eq(relaxed_divs.length(), 1)
  assert_true(relaxed_divs[0].attrs().get("id") is Some(Some("matched")))

  let default_limited = @html_parser.parse_fragment("<div></div>")
  let default_result = try? @html_parser.apply_transforms(
    default_limited.root,
    [
      @html_parser.TransformSpec::set_attrs(long_selector, {
        "id": Some("matched"),
      }),
      @html_parser.TransformSpec::sanitize(),
    ],
  )
  match default_result {
    Err(SelectorError(message)) => assert_eq(message, "Selector too long")
    _ => fail("expected selector length limit error")
  }

  let budget_policy = @html_parser.SanitizationPolicy::new(
    ["div"],
    allowed_attributes={ "*": ["data-x"] },
    selector_limits=@html_parser.SelectorLimits::new(max_match_bytes=10),
  )
  let short_circuit = @html_parser.parse_fragment(
    "<div data-x=\"xxxxxxxxxxxxxxxxxxxx\"></div>",
  )
  ignore(
    @html_parser.apply_transforms(short_circuit.root, [
      @html_parser.TransformSpec::drop("div, [data-x*=y]"),
      @html_parser.TransformSpec::sanitize(policy=budget_policy),
    ]),
  )
  assert_eq(short_circuit.root.to_html(pretty=false), "")

  let budget = @html_parser.parse_fragment(
    "<div data-x=\"xxxxxxxxxxxxxxxxxxxx\"></div>",
  )
  let budget_result = try? @html_parser.apply_transforms(budget.root, [
    @html_parser.TransformSpec::drop("[data-x*=y]"),
    @html_parser.TransformSpec::sanitize(policy=budget_policy),
  ])
  match budget_result {
    Err(SelectorError(message)) =>
      assert_eq(message, "Selector match byte budget exceeded")
    _ => fail("expected selector match byte budget error")
  }

  let parse_depth_policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    selector_limits=@html_parser.SelectorLimits::new(max_parse_depth=1),
  )
  let parse_depth = @html_parser.parse_fragment("<p>x</p>")
  let parse_depth_result = try? @html_parser.apply_transforms(
    parse_depth.root,
    [
      @html_parser.TransformSpec::drop(":not(:not(:not(p)))"),
      @html_parser.TransformSpec::sanitize(policy=parse_depth_policy),
    ],
  )
  match parse_depth_result {
    Err(SelectorError(message)) =>
      assert_eq(message, "Selector nesting is too deep")
    _ => fail("expected selector parse depth error")
  }

  let match_depth_policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    selector_limits=@html_parser.SelectorLimits::new(max_match_depth=0),
  )
  let match_depth = @html_parser.parse_fragment("<p>x</p>")
  let match_depth_result = try? @html_parser.apply_transforms(
    match_depth.root,
    [
      @html_parser.TransformSpec::drop(":not(p)"),
      @html_parser.TransformSpec::sanitize(policy=match_depth_policy),
    ],
  )
  match match_depth_result {
    Err(SelectorError(message)) =>
      assert_eq(message, "Selector nesting is too deep")
    _ => fail("expected selector match depth error")
  }

  let step_policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    selector_limits=@html_parser.SelectorLimits::new(max_match_steps=0),
  )
  let step_budget = @html_parser.parse_fragment("<p>x</p>")
  let step_result = try? @html_parser.apply_transforms(step_budget.root, [
    @html_parser.TransformSpec::drop("p"),
    @html_parser.TransformSpec::sanitize(policy=step_policy),
  ])
  match step_result {
    Err(SelectorError(message)) =>
      assert_eq(message, "Selector match budget exceeded")
    _ => fail("expected selector step budget error")
  }

  let list_policy = @html_parser.SanitizationPolicy::new(
    ["p", "div", "span"],
    selector_limits=@html_parser.SelectorLimits::new(max_list_items=2),
  )
  let list_limited = @html_parser.parse_fragment("<p>x</p>")
  let list_result = try? @html_parser.apply_transforms(list_limited.root, [
    @html_parser.TransformSpec::drop("p, div, span"),
    @html_parser.TransformSpec::sanitize(policy=list_policy),
  ])
  match list_result {
    Err(SelectorError(message)) =>
      assert_eq(message, "Selector list has too many items")
    _ => fail("expected selector list limit error")
  }

  let complex_policy = @html_parser.SanitizationPolicy::new(
    ["article", "div", "p"],
    selector_limits=@html_parser.SelectorLimits::new(
      max_complex_selector_parts=2,
    ),
  )
  let complex_limited = @html_parser.parse_fragment(
    "<article><div><p>x</p></div></article>",
  )
  let complex_result = try? @html_parser.apply_transforms(
    complex_limited.root,
    [
      @html_parser.TransformSpec::drop("article > div > p"),
      @html_parser.TransformSpec::sanitize(policy=complex_policy),
    ],
  )
  match complex_result {
    Err(SelectorError(message)) =>
      assert_eq(message, "Selector has too many complex parts")
    _ => fail("expected complex selector part limit error")
  }

  let compound_policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    allowed_attributes={ "*": ["class", "id"] },
    selector_limits=@html_parser.SelectorLimits::new(
      max_compound_simple_selectors=2,
    ),
  )
  let compound_limited = @html_parser.parse_fragment(
    "<p class=\"a\" id=\"b\">x</p>",
  )
  let compound_result = try? @html_parser.apply_transforms(
    compound_limited.root,
    [
      @html_parser.TransformSpec::drop("p.a#b"),
      @html_parser.TransformSpec::sanitize(policy=compound_policy),
    ],
  )
  match compound_result {
    Err(SelectorError(message)) =>
      assert_eq(message, "Selector has too many simple selectors")
    _ => fail("expected compound selector limit error")
  }

  let negative_byte_policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    selector_limits=@html_parser.SelectorLimits::new(max_match_bytes=-1),
  )
  let negative_byte = @html_parser.parse_fragment("<p>x</p>")
  let negative_result = try? @html_parser.apply_transforms(negative_byte.root, [
    @html_parser.TransformSpec::drop("p"),
    @html_parser.TransformSpec::sanitize(policy=negative_byte_policy),
  ])
  match negative_result {
    Err(SelectorError(message)) =>
      assert_eq(message, "Selector match byte budget exceeded")
    _ => fail("expected negative byte budget error")
  }

  let contains_byte_policy = @html_parser.SanitizationPolicy::new(
    ["div"],
    selector_limits=@html_parser.SelectorLimits::new(max_match_bytes=4),
  )
  let contains_byte = @html_parser.parse_fragment("<div>needle</div>")
  let contains_result = try? @html_parser.apply_transforms(contains_byte.root, [
    @html_parser.TransformSpec::drop("div:contains(needle)"),
    @html_parser.TransformSpec::sanitize(policy=contains_byte_policy),
  ])
  match contains_result {
    Err(SelectorError(message)) =>
      assert_eq(message, "Selector match byte budget exceeded")
    _ => fail("expected contains text byte budget error")
  }
}

///|
test "selector transforms cover contextual combinators and pseudos" {
  let siblings = @html_parser.parse_fragment(
    "<div><em></em><span id=\"first\"></span><i></i><span id=\"second\"></span></div>",
  )
  ignore(
    @html_parser.apply_transforms(siblings.root, [
      @html_parser.TransformSpec::set_attrs("em + span", {
        "data-adjacent": Some("yes"),
      }),
      @html_parser.TransformSpec::set_attrs("em ~ span", {
        "data-general": Some("yes"),
      }),
    ]),
  )
  let spans = siblings.root.query("span")
  assert_eq(spans.length(), 2)
  assert_true(spans[0].attrs().get("data-adjacent") is Some(Some("yes")))
  assert_true(spans[0].attrs().get("data-general") is Some(Some("yes")))
  assert_true(!spans[1].attrs().contains("data-adjacent"))
  assert_true(spans[1].attrs().get("data-general") is Some(Some("yes")))

  let nested = @html_parser.parse_fragment(
    "<section><ul><li>one</li><li>two</li><li>three</li></ul><p>before</p><p>needle</p></section>",
  )
  ignore(
    @html_parser.apply_transforms(nested.root, [
      @html_parser.TransformSpec::set_attrs("section > ul li:nth-child(odd)", {
        "data-odd": Some("yes"),
      }),
      @html_parser.TransformSpec::set_attrs("section > p:nth-of-type(2)", {
        "data-second-type": Some("yes"),
      }),
      @html_parser.TransformSpec::set_attrs("section p:contains(needle)", {
        "data-found": Some("yes"),
      }),
    ]),
  )
  let items = nested.root.query("li")
  assert_eq(items.length(), 3)
  assert_true(items[0].attrs().get("data-odd") is Some(Some("yes")))
  assert_true(!items[1].attrs().contains("data-odd"))
  assert_true(items[2].attrs().get("data-odd") is Some(Some("yes")))
  let paragraphs = nested.root.query("p")
  assert_eq(paragraphs.length(), 2)
  assert_true(!paragraphs[0].attrs().contains("data-second-type"))
  assert_true(!paragraphs[0].attrs().contains("data-found"))
  assert_true(
    paragraphs[1].attrs().get("data-second-type") is Some(Some("yes")),
  )
  assert_true(paragraphs[1].attrs().get("data-found") is Some(Some("yes")))
}

///|
test "selector transforms fail closed for nonmatching contextual selectors" {
  let doc = @html_parser.parse_fragment(
    "<div><p id='first'></p><section><p id='nested'></p></section><p id='second'></p></div>",
  )
  ignore(
    @html_parser.apply_transforms(doc.root, [
      @html_parser.TransformSpec::set_attrs("article p", {
        "data-miss": Some("descendant"),
      }),
      @html_parser.TransformSpec::set_attrs("article > p", {
        "data-miss": Some("child"),
      }),
      @html_parser.TransformSpec::set_attrs("em + p", {
        "data-miss": Some("adjacent"),
      }),
      @html_parser.TransformSpec::set_attrs("em ~ p", {
        "data-miss": Some("sibling"),
      }),
      @html_parser.TransformSpec::set_attrs("p.nope", {
        "data-miss": Some("class"),
      }),
      @html_parser.TransformSpec::set_attrs("p#missing", {
        "data-miss": Some("id"),
      }),
    ]),
  )
  assert_eq(
    doc.root.to_html(pretty=false),
    "<div><p id=\"first\"></p><section><p id=\"nested\"></p></section><p id=\"second\"></p></div>",
  )
}

///|
test "selector transforms fail closed for malformed selectors" {
  let doc = @html_parser.parse_fragment("<p id='x'></p><a href='#'>x</a>")
  ignore(
    @html_parser.apply_transforms(doc.root, [
      @html_parser.TransformSpec::set_attrs("p[", {
        "data-miss": Some("unclosed-attribute"),
      }),
      @html_parser.TransformSpec::set_attrs("p, a[", {
        "data-miss": Some("bad-list"),
      }),
      @html_parser.TransformSpec::set_attrs("> p", {
        "data-miss": Some("bad-combinator"),
      }),
      @html_parser.TransformSpec::set_attrs(", p", {
        "data-miss": Some("empty-leading-list"),
      }),
    ]),
  )
  assert_eq(
    doc.root.to_html(pretty=false),
    "<p id=\"x\"></p><a href=\"#\">x</a>",
  )
}

///|
test "prune_empty drops empty elements with post-order semantics" {
  let doc = @html_parser.parse_fragment(
    "<div><p></p></div><p><img></p><p><!--x--></p><p>   </p><span> </span>",
  )
  ignore(
    @html_parser.apply_transforms(doc.root, [
      @html_parser.TransformSpec::prune_empty("p, div"),
    ]),
  )
  assert_eq(doc.root.to_html(pretty=false), "<p><img></p><span> </span>")

  let whitespace = @html_parser.parse_fragment("<p>   </p><p></p>")
  ignore(
    @html_parser.apply_transforms(whitespace.root, [
      @html_parser.TransformSpec::prune_empty("p", strip_whitespace=false),
    ]),
  )
  assert_eq(whitespace.root.to_html(pretty=false), "<p>   </p>")

  let ordered = @html_parser.parse_fragment("<p><img></p>")
  ignore(
    @html_parser.apply_transforms(ordered.root, [
      @html_parser.TransformSpec::prune_empty("p"),
      @html_parser.TransformSpec::drop("img"),
    ]),
  )
  assert_eq(ordered.root.to_html(pretty=false), "<p></p>")

  let consecutive = @html_parser.parse_fragment("<div><p></p></div>")
  ignore(
    @html_parser.apply_transforms(consecutive.root, [
      @html_parser.TransformSpec::prune_empty("div"),
      @html_parser.TransformSpec::prune_empty("p"),
    ]),
  )
  assert_eq(consecutive.root.to_html(pretty=false), "")
}

///|
test "prune_empty reports exact callbacks and preserves void roots" {
  let events : Array[String] = []
  let hook : (@html_parser.Node) -> Unit = fn(node) {
    events.push("hook:" + node.name())
  }
  let report : (String, @html_parser.Node?) -> Unit = fn(message, node) {
    events.push("report:" + message)
    match node {
      Some(hit) => events.push("node:" + hit.name())
      None => events.push("node:none")
    }
  }
  let doc = @html_parser.parse_fragment("<p></p><br><hr>")
  ignore(
    @html_parser.apply_transforms(doc.root, [
      @html_parser.TransformSpec::prune_empty("*", hook~, report~),
    ]),
  )
  assert_eq(doc.root.to_html(pretty=false), "<br><hr>")
  @test.assert_eq(events, [
    "hook:p", "report:Pruned empty <p> (matched selector '*')", "node:p",
  ])
}

///|
test "stage transform reports implicit stage index and skips disabled stage" {
  let events : Array[String] = []
  let hook : (@html_parser.Node) -> Unit = fn(node) {
    events.push("hook:" + node.name())
  }
  let report : (String, @html_parser.Node?) -> Unit = fn(message, node) {
    events.push("report:" + message)
    match node {
      Some(hit) => events.push("node:" + hit.name())
      None => events.push("node:none")
    }
  }
  let root = @html_parser.parse_fragment("<!--c--><p>example.com</p>").root
  ignore(
    @html_parser.apply_transforms(root, [
      @html_parser.TransformSpec::drop_comments(),
      @html_parser.TransformSpec::stage(
        [@html_parser.TransformSpec::linkify()],
        hook~,
        report~,
      ),
      @html_parser.TransformSpec::stage(
        [
          @html_parser.TransformSpec::set_attrs("a", { "rel": Some("noopener") }),
        ],
        enabled=false,
        hook~,
        report~,
      ),
    ]),
  )
  @test.assert_eq(events, [
    "hook:#document-fragment", "report:Stage 2", "node:#document-fragment",
  ])
  assert_eq(
    root.to_html(pretty=false),
    "<p><a href=\"http://example.com\">example.com</a></p>",
  )
}

///|
test "nested stage transforms are flattened without nested hooks" {
  let events : Array[String] = []
  let outer_hook : (@html_parser.Node) -> Unit = fn(node) {
    events.push("outer:" + node.name())
  }
  let inner_hook : (@html_parser.Node) -> Unit = fn(node) {
    events.push("inner:" + node.name())
  }
  let report : (String, @html_parser.Node?) -> Unit = fn(message, _node) {
    events.push("report:" + message)
  }
  let root = @html_parser.parse_fragment("<p>example.com</p>").root
  ignore(
    @html_parser.apply_transforms(root, [
      @html_parser.TransformSpec::stage(
        [
          @html_parser.TransformSpec::stage(
            [@html_parser.TransformSpec::linkify()],
            hook=inner_hook,
            report~,
          ),
        ],
        hook=outer_hook,
        report~,
      ),
    ]),
  )
  @test.assert_eq(events, ["outer:#document-fragment", "report:Stage 1"])
  assert_eq(
    root.to_html(pretty=false),
    "<p><a href=\"http://example.com\">example.com</a></p>",
  )
}

///|
test "nested stage sanitizer limits apply to trailing transforms" {
  let long_class = transform_repeat_for_test("s", 8192)
  let long_selector = "." + long_class
  let policy = @html_parser.SanitizationPolicy::new(
    ["div"],
    allowed_attributes={ "*": ["class", "id"] },
    selector_limits=@html_parser.SelectorLimits::new(max_length=9000),
  )
  let doc = @html_parser.parse_fragment(
    "<div class=\"" + long_class + "\"></div>",
  )
  ignore(
    @html_parser.apply_transforms(doc.root, [
      @html_parser.TransformSpec::stage([
        @html_parser.TransformSpec::sanitize(policy~),
      ]),
      @html_parser.TransformSpec::set_attrs(long_selector, {
        "id": Some("matched"),
      }),
    ]),
  )
  let divs = doc.root.query("div")
  assert_eq(divs.length(), 1)
  assert_true(divs[0].attrs().get("id") is Some(Some("matched")))
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
test "attribute transforms cover no-op and boolean attribute branches" {
  let drop_empty = @html_parser.fragment(children=[
    @html_parser.element("div", attrs={ "onclick": Some("run()") }),
  ])
  ignore(
    @html_parser.apply_transforms(drop_empty, [
      @html_parser.TransformSpec::drop_attrs("*", []),
    ]),
  )
  assert_eq(drop_empty.to_html(pretty=false), "<div onclick=\"run()\"></div>")

  let repeated_glob = @html_parser.fragment(children=[
    @html_parser.element("div", attrs={
      "data-long-id": Some("drop"),
      "data-x": Some("keep"),
    }),
  ])
  ignore(
    @html_parser.apply_transforms(repeated_glob, [
      @html_parser.TransformSpec::drop_attrs("*", ["data-**-id"]),
    ]),
  )
  assert_eq(repeated_glob.to_html(pretty=false), "<div data-x=\"keep\"></div>")

  let url_policy = @html_parser.UrlPolicy::new()
  let no_attrs = @html_parser.fragment(children=[@html_parser.element("div")])
  ignore(
    @html_parser.apply_transforms(no_attrs, [
      @html_parser.TransformSpec::allowlist_attrs("*", { "*": ["id"] }),
      @html_parser.TransformSpec::drop_url_attrs("*", url_policy~),
      @html_parser.TransformSpec::allow_style_attrs("*", allowed_css_properties=[
        "color",
      ]),
    ]),
  )
  assert_eq(no_attrs.to_html(pretty=false), "<div></div>")

  let blank_attr = @html_parser.fragment(children=[
    @html_parser.element("div", attrs={
      "": Some("blank"),
      "BAD": Some("x"),
      "id": Some("ok"),
    }),
  ])
  ignore(
    @html_parser.apply_transforms(blank_attr, [
      @html_parser.TransformSpec::allowlist_attrs("*", { "*": ["id"] }),
    ]),
  )
  assert_eq(blank_attr.to_html(pretty=false), "<div id=\"ok\"></div>")

  let meta_none = @html_parser.fragment(children=[
    @html_parser.element("meta", attrs={
      "http-equiv": None,
      "content": Some("0;url=https://evil.example/"),
    }),
  ])
  ignore(
    @html_parser.apply_transforms(meta_none, [
      @html_parser.TransformSpec::drop_url_attrs("*", url_policy~),
    ]),
  )
  assert_eq(
    meta_none.to_html(pretty=false),
    "<meta http-equiv content=\"0;url=https://evil.example/\">",
  )

  let events : Array[String] = []
  let hook : (@html_parser.Node) -> Unit = fn(node) { events.push(node.name()) }
  let merged = @html_parser.fragment(children=[
    @html_parser.element("a", attrs={ "rel": None }),
    @html_parser.element("a", attrs={ "rel": Some("noopener") }),
  ])
  ignore(
    @html_parser.apply_transforms(merged, [
      @html_parser.TransformSpec::merge_attrs(
        "a",
        attr="rel",
        tokens=["noopener"],
        hook~,
      ),
    ]),
  )
  assert_eq(
    merged.to_html(pretty=false),
    "<a rel=\"noopener\"></a><a rel=\"noopener\"></a>",
  )
  @test.assert_eq(events, ["a"])

  let merge_noops = @html_parser.fragment(children=[
    @html_parser.element("a", attrs={ "rel": Some("friend") }),
  ])
  ignore(
    @html_parser.apply_transforms(merge_noops, [
      @html_parser.TransformSpec::merge_attrs("a", attr="", tokens=["noopener"]),
      @html_parser.TransformSpec::merge_attrs("a", attr="rel", tokens=[]),
    ]),
  )
  assert_eq(merge_noops.to_html(pretty=false), "<a rel=\"friend\"></a>")
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
test "sanitize transform does not imply final markdown sanitize" {
  let doc = @html_parser.parse_fragment("<img src='/x'>")
  ignore(
    @html_parser.apply_transforms(doc.root, [
      @html_parser.TransformSpec::sanitize(),
      @html_parser.TransformSpec::set_attrs("img", {
        "onerror": Some("alert(1)"),
      }),
    ]),
  )
  assert_eq(
    doc.root.to_html(pretty=false),
    "<img src=\"/x\" onerror=\"alert(1)\">",
  )
  assert_eq(doc.to_markdown(), "<img src=\"/x\" onerror=\"alert(1)\">")
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
      assert_eq(message, "Unsafe attribute 'foo' (not allowed)")
    _ => fail("expected sanitize transform to raise UnsafeHtml")
  }
}

///|
test "sanitize transform hooks and reports unsafe mutations" {
  let events : Array[String] = []
  let hook : (@html_parser.Node) -> Unit = fn(node) {
    events.push("hook:" + node.name())
  }
  let report : (String, @html_parser.Node?) -> Unit = fn(message, node) {
    events.push("report:" + message)
    match node {
      Some(hit) => events.push("node:" + hit.name())
      None => events.push("node:none")
    }
  }
  let policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    allowed_attributes={ "p": [] },
    strip_invisible_unicode=true,
  )
  let doc = @html_parser.parse_fragment(
    "<p onclick='x'>x\u{200B}</p><!--c--><script>alert(1)</script>",
  )
  ignore(
    @html_parser.apply_transforms(doc.root, [
      @html_parser.TransformSpec::sanitize(policy~, hook~, report~),
    ]),
  )
  @test.assert_eq(events, [
    "hook:p", "report:Unsafe attribute 'onclick' (matched forbidden pattern 'on*')",
    "node:p", "hook:#text", "report:Stripped invisible Unicode from text node", "node:#text",
    "hook:#comment", "report:Dropped comment", "node:#comment", "hook:script", "report:Unsafe tag 'script' (dropped content)",
    "node:script",
  ])
  assert_eq(doc.root.to_html(pretty=false), "<p>x</p>")
}

///|
test "sanitize transform supports hook-only and report-only observers" {
  let policy = @html_parser.SanitizationPolicy::new(["p"], allowed_attributes={
    "p": [],
  })
  let hook_events : Array[String] = []
  let hook : (@html_parser.Node) -> Unit = fn(node) {
    hook_events.push(node.name())
  }
  let hook_doc = @html_parser.parse_fragment("<p foo='1'>x</p><!--c-->")
  ignore(
    @html_parser.apply_transforms(hook_doc.root, [
      @html_parser.TransformSpec::sanitize(policy~, hook~),
    ]),
  )
  @test.assert_eq(hook_events, ["p", "#comment"])
  assert_eq(hook_doc.root.to_html(pretty=false), "<p>x</p>")

  let reports : Array[String] = []
  let report : (String, @html_parser.Node?) -> Unit = fn(message, node) {
    let name = match node {
      Some(hit) => hit.name()
      None => "none"
    }
    reports.push(message + ":" + name)
  }
  let report_doc = @html_parser.parse_fragment("<p foo='1'>x</p>")
  ignore(
    @html_parser.apply_transforms(report_doc.root, [
      @html_parser.TransformSpec::sanitize(policy~, report~),
    ]),
  )
  @test.assert_eq(reports, ["Unsafe attribute 'foo' (not allowed):p"])
  assert_eq(report_doc.root.to_html(pretty=false), "<p>x</p>")
}

///|
test "sanitize transform comment and doctype drops are structural reports" {
  let events : Array[String] = []
  let hook : (@html_parser.Node) -> Unit = fn(node) {
    events.push("hook:" + node.name())
  }
  let report : (String, @html_parser.Node?) -> Unit = fn(message, node) {
    events.push("report:" + message)
    match node {
      Some(hit) => events.push("node:" + hit.name())
      None => events.push("node:none")
    }
  }
  let policy = @html_parser.SanitizationPolicy::new(
    ["p"],
    allowed_attributes={ "p": [] },
    unsafe_handling=Raise,
  )
  let doc = @html_parser.document(children=[
    @html_parser.doctype(),
    @html_parser.comment("c"),
    @html_parser.element("p", children=[@html_parser.text("ok")]),
  ])
  let result = try? @html_parser.apply_transforms(doc, [
    @html_parser.TransformSpec::sanitize(policy~, hook~, report~),
  ])
  match result {
    Ok(clean) => assert_eq(clean.to_html(pretty=false), "<p>ok</p>")
    Err(_) => fail("comment and doctype drops should not use unsafe handling")
  }
  @test.assert_eq(events, [
    "hook:#doctype", "report:Dropped doctype", "node:#doctype", "hook:#comment",
    "report:Dropped comment", "node:#comment",
  ])
}

///|
test "sanitize transform reports invisible Unicode attribute stripping" {
  let events : Array[String] = []
  let hook : (@html_parser.Node) -> Unit = fn(node) {
    events.push("hook:" + node.name())
  }
  let report : (String, @html_parser.Node?) -> Unit = fn(message, node) {
    events.push("report:" + message)
    match node {
      Some(hit) => events.push("node:" + hit.name())
      None => events.push("node:none")
    }
  }
  let policy = @html_parser.SanitizationPolicy::new(["p"], allowed_attributes={
    "p": ["title"],
  })
  let doc = @html_parser.parse_fragment(
    "<p title='a\u{200B}b'>ok</p>",
    sanitize=false,
  )
  ignore(
    @html_parser.apply_transforms(doc.root, [
      @html_parser.TransformSpec::sanitize(policy~, hook~, report~),
    ]),
  )
  @test.assert_eq(events, [
    "hook:p", "report:Stripped invisible Unicode from attribute(s): title", "node:p",
  ])
  assert_eq(doc.root.to_html(pretty=false), "<p title=\"ab\">ok</p>")
}

///|
test "unchanged sanitize transform does not call hooks" {
  let events : Array[String] = []
  let hook : (@html_parser.Node) -> Unit = fn(node) {
    events.push("hook:" + node.name())
  }
  let report : (String, @html_parser.Node?) -> Unit = fn(message, _node) {
    events.push("report:" + message)
  }
  let doc = @html_parser.parse_fragment("<p id='x'>safe</p>")
  ignore(
    @html_parser.apply_transforms(doc.root, [
      @html_parser.TransformSpec::sanitize(hook~, report~),
    ]),
  )
  @test.assert_eq(events, [])
  assert_eq(doc.root.to_html(pretty=false), "<p id=\"x\">safe</p>")
}

///|
test "edit_document invokes callback once on root" {
  let seen : Array[String] = []
  let root = @html_parser.fragment(children=[
    @html_parser.element("p", children=[@html_parser.text("x")]),
  ])
  ignore(
    @html_parser.apply_transforms(root, [
      @html_parser.TransformSpec::edit_document(fn(node) {
        seen.push(node.name())
        node.append_child(@html_parser.element("section"))
      }),
      @html_parser.TransformSpec::set_attrs("section", {
        "data-root": Some("1"),
      }),
    ]),
  )
  @test.assert_eq(seen, ["#document-fragment"])
  let sections = root.query("section")
  assert_eq(sections.length(), 1)
  assert_true(sections[0].attrs().get("data-root") is Some(Some("1")))
}

///|
test "edit invokes callback for matching elements" {
  let seen : Array[String] = []
  let p = @html_parser.element("p")
  let span = @html_parser.element("span")
  let root = @html_parser.fragment(children=[p, span])
  ignore(
    @html_parser.apply_transforms(root, [
      @html_parser.TransformSpec::edit("p", fn(node) {
        seen.push(node.name())
        node.append_child(
          @html_parser.element("b", attrs={ "class": Some("from-edit") }),
        )
      }),
      @html_parser.TransformSpec::set_attrs("b.from-edit", {
        "data-seen": Some("yes"),
      }),
    ]),
  )
  @test.assert_eq(seen, ["p"])
  assert_eq(p.query("b").length(), 1)
  assert_eq(span.query("b").length(), 0)
  assert_true(p.query("b")[0].attrs().get("data-seen") is Some(Some("yes")))
}

///|
test "edit_attrs replaces attrs and treats None as unchanged" {
  let first = @html_parser.element("p", attrs={
    "id": Some("first"),
    "old": Some("x"),
  })
  let skip = @html_parser.element("p", attrs={
    "id": Some("skip"),
    "old": Some("y"),
  })
  let root = @html_parser.fragment(children=[first, skip])
  ignore(
    @html_parser.apply_transforms(root, [
      @html_parser.TransformSpec::edit_attrs("p", fn(node) {
        if node.attrs().get("id") is Some(Some("skip")) {
          None
        } else {
          Some({ "class": Some("edited"), "disabled": None })
        }
      }),
    ]),
  )
  let first_attrs = first.attrs()
  assert_true(first_attrs.get("id") is None)
  assert_true(first_attrs.get("old") is None)
  assert_true(first_attrs.get("class") is Some(Some("edited")))
  assert_true(first_attrs.get("disabled") is Some(None))
  assert_true(skip.attrs().get("old") is Some(Some("y")))
}

///|
test "edit_attrs changes are visible to later transforms" {
  let node = @html_parser.element("p", attrs={ "id": Some("x") })
  let root = @html_parser.fragment(children=[node])
  ignore(
    @html_parser.apply_transforms(root, [
      @html_parser.TransformSpec::edit_attrs("p", fn(_node) {
        Some({ "class": Some("one") })
      }),
      @html_parser.TransformSpec::edit_attrs("p.one", fn(_node) {
        Some({ "class": Some("two") })
      }),
    ]),
  )
  assert_true(node.attrs().get("class") is Some(Some("two")))
}

///|
test "disabled transforms are skipped" {
  let calls : Array[String] = []
  let doc = @html_parser.parse_fragment(
    "<p onclick='x'>example.com<script>x</script><!--c--></p>",
  )
  let policy = @html_parser.SanitizationPolicy::new(["p"], allowed_attributes={
    "p": [],
  })
  ignore(
    @html_parser.apply_transforms(doc.root, [
      @html_parser.TransformSpec::drop("script", enabled=false),
      @html_parser.TransformSpec::drop_comments(enabled=false),
      @html_parser.TransformSpec::edit_document(
        fn(root) {
          calls.push("document")
          root.append_child(@html_parser.element("section"))
        },
        enabled=false,
      ),
      @html_parser.TransformSpec::edit(
        "p",
        fn(node) {
          calls.push("element")
          node.append_child(@html_parser.element("b"))
        },
        enabled=false,
      ),
      @html_parser.TransformSpec::edit_attrs(
        "p",
        fn(_node) {
          calls.push("attrs")
          Some({ "id": Some("changed") })
        },
        enabled=false,
      ),
      @html_parser.TransformSpec::linkify(enabled=false),
      @html_parser.TransformSpec::sanitize(policy~, enabled=false),
    ]),
  )
  assert_eq(calls.length(), 0)
  assert_eq(doc.root.query("script").length(), 1)
  assert_eq(doc.root.query(":comment").length(), 1)
  assert_eq(doc.root.query("section").length(), 0)
  assert_eq(doc.root.query("b").length(), 0)
  assert_eq(doc.root.query("a").length(), 0)
  let paragraphs = doc.root.query("p")
  assert_eq(paragraphs.length(), 1)
  assert_true(paragraphs[0].attrs().get("onclick") is Some(Some("x")))
}

///|
test "transform hooks and reports run for changed transforms" {
  let events : Array[String] = []
  let hook : (@html_parser.Node) -> Unit = fn(node) {
    events.push("hook:" + node.name())
  }
  let report : (String, @html_parser.Node?) -> Unit = fn(message, node) {
    events.push("report:" + message)
    match node {
      Some(hit) => events.push("node:" + hit.name())
      None => events.push("node:none")
    }
  }
  let doc = @html_parser.document(children=[
    @html_parser.doctype(),
    @html_parser.comment("c"),
    @html_parser.element("p", attrs={ "onclick": Some("run()") }),
    @html_parser.element("script", children=[@html_parser.text("x")]),
  ])
  ignore(
    @html_parser.apply_transforms(doc, [
      @html_parser.TransformSpec::set_attrs(
        "p",
        { "data-x": Some("1") },
        hook~,
        report~,
      ),
      @html_parser.TransformSpec::drop_attrs("p", ["on*"], hook~, report~),
      @html_parser.TransformSpec::drop("script", hook~, report~),
      @html_parser.TransformSpec::drop_comments(hook~, report~),
      @html_parser.TransformSpec::drop_doctype(hook~, report~),
    ]),
  )
  @test.assert_eq(events, [
    "hook:p", "report:Set attributes on <p> (matched selector 'p')", "node:p", "report:Unsafe attribute 'onclick' (matched forbidden pattern 'on*')",
    "node:p", "hook:p", "hook:script", "report:Dropped <script> (matched selector 'script')",
    "node:script", "hook:#comment", "report:Dropped comment", "node:#comment", "hook:#doctype",
    "report:Dropped doctype", "node:#doctype",
  ])
  assert_eq(doc.to_html(pretty=false), "<p data-x=\"1\"></p>")
}

///|
test "drop_attrs reports exact forbidden patterns before hook" {
  let events : Array[String] = []
  let hook : (@html_parser.Node) -> Unit = fn(node) {
    events.push("hook:" + node.name())
  }
  let report : (String, @html_parser.Node?) -> Unit = fn(message, node) {
    events.push("report:" + message)
    match node {
      Some(hit) => events.push("node:" + hit.name())
      None => events.push("node:none")
    }
  }
  let root = @html_parser.fragment(children=[
    @html_parser.element("div", attrs={
      "OnClick": Some("run()"),
      "Data-X": Some("1"),
    }),
    @html_parser.element("div", attrs={ "xml:lang": Some("sv") }),
    @html_parser.element("div", attrs={ "SrcDoc": Some("<p>x</p>") }),
  ])
  ignore(
    @html_parser.apply_transforms(root, [
      @html_parser.TransformSpec::drop_attrs(
        "*",
        ["on*", "*:*", "srcdoc"],
        hook~,
        report~,
      ),
    ]),
  )
  @test.assert_eq(events, [
    "report:Unsafe attribute 'onclick' (matched forbidden pattern 'on*')", "node:div",
    "hook:div", "report:Unsafe attribute 'xml:lang' (matched forbidden pattern '*:*')",
    "node:div", "hook:div", "report:Unsafe attribute 'srcdoc' (matched forbidden pattern 'srcdoc')",
    "node:div", "hook:div",
  ])
  assert_eq(
    root.to_html(pretty=false),
    "<div Data-X=\"1\"></div><div></div><div></div>",
  )
}

///|
test "allowlist_attrs reports exact unsafe attributes before hook" {
  let events : Array[String] = []
  let hook : (@html_parser.Node) -> Unit = fn(node) {
    events.push("hook:" + node.name())
  }
  let report : (String, @html_parser.Node?) -> Unit = fn(message, node) {
    events.push("report:" + message)
    match node {
      Some(hit) => events.push("node:" + hit.name())
      None => events.push("node:none")
    }
  }
  let root = @html_parser.fragment(children=[
    @html_parser.element("a", attrs={
      "HREF": Some("https://example.com"),
      "Rel": Some("noreferrer"),
      "BAD": Some("x"),
      "id": Some("link"),
    }),
    @html_parser.element("span", attrs={ "href": Some("nope") }),
  ])
  ignore(
    @html_parser.apply_transforms(root, [
      @html_parser.TransformSpec::allowlist_attrs(
        "*",
        { "*": ["id"], "a": ["href", "rel"] },
        hook~,
        report~,
      ),
    ]),
  )
  @test.assert_eq(events, [
    "report:Unsafe attribute 'bad' (not allowed)", "node:a", "hook:a", "report:Unsafe attribute 'href' (not allowed)",
    "node:span", "hook:span",
  ])
  assert_eq(
    root.to_html(pretty=false),
    "<a href=\"https://example.com\" rel=\"noreferrer\" id=\"link\"></a><span></span>",
  )
}

///|
test "unchanged attribute transforms do not call hooks" {
  let events : Array[String] = []
  let hook : (@html_parser.Node) -> Unit = fn(node) {
    events.push("hook:" + node.name())
  }
  let report : (String, @html_parser.Node?) -> Unit = fn(message, _node) {
    events.push("report:" + message)
  }
  let p = @html_parser.element("p", attrs={ "id": Some("x") })
  let span = @html_parser.element("span", attrs={ "style": Some("color: red") })
  let root = @html_parser.fragment(children=[p, span])
  ignore(
    @html_parser.apply_transforms(root, [
      @html_parser.TransformSpec::set_attrs(
        "p",
        { "id": Some("x") },
        hook~,
        report~,
      ),
      @html_parser.TransformSpec::drop_attrs("p", ["missing*"], hook~, report~),
      @html_parser.TransformSpec::allow_style_attrs(
        "span",
        allowed_css_properties=["color"],
        hook~,
        report~,
      ),
    ]),
  )
  @test.assert_eq(events, [])
  assert_eq(
    root.to_html(pretty=false),
    "<p id=\"x\"></p><span style=\"color: red\"></span>",
  )
}

///|
test "edit hooks and reports follow Python callback ordering" {
  let events : Array[String] = []
  let hook : (@html_parser.Node) -> Unit = fn(node) {
    events.push("hook:" + node.name())
  }
  let report : (String, @html_parser.Node?) -> Unit = fn(message, node) {
    events.push("report:" + message)
    match node {
      Some(hit) => events.push("node:" + hit.name())
      None => events.push("node:none")
    }
  }
  let p = @html_parser.element("p", attrs={ "id": Some("old") })
  let root = @html_parser.fragment(children=[p])
  ignore(
    @html_parser.apply_transforms(root, [
      @html_parser.TransformSpec::edit_document(
        fn(node) { events.push("edit-document:" + node.name()) },
        hook~,
        report~,
      ),
      @html_parser.TransformSpec::edit(
        "p",
        fn(node) {
          events.push("edit:" + node.name())
          node.append_child(@html_parser.text("x"))
        },
        hook~,
        report~,
      ),
      @html_parser.TransformSpec::edit_attrs(
        "p",
        fn(node) {
          events.push("edit-attrs:" + node.name())
          Some({ "class": Some("done") })
        },
        hook~,
        report~,
      ),
    ]),
  )
  @test.assert_eq(events, [
    "hook:#document-fragment", "report:Edited document root", "node:#document-fragment",
    "edit-document:#document-fragment", "hook:p", "report:Edited <p> (matched selector 'p')",
    "node:p", "edit:p", "edit-attrs:p", "hook:p", "report:Edited attributes on <p> (matched selector 'p')",
    "node:p",
  ])
  assert_eq(root.to_html(pretty=false), "<p class=\"done\">x</p>")
}

///|
test "merge_attrs hook report matches Python message" {
  let events : Array[String] = []
  let hook : (@html_parser.Node) -> Unit = fn(node) {
    events.push("hook:" + node.name())
  }
  let report : (String, @html_parser.Node?) -> Unit = fn(message, node) {
    events.push("report:" + message)
    match node {
      Some(hit) => events.push("node:" + hit.name())
      None => events.push("node:none")
    }
  }
  let root = @html_parser.fragment(children=[
    @html_parser.element("a", attrs={ "rel": Some("noreferrer") }, children=[
      @html_parser.text("x"),
    ]),
  ])
  ignore(
    @html_parser.apply_transforms(root, [
      @html_parser.TransformSpec::merge_attrs(
        "a",
        attr="rel",
        tokens=["noopener"],
        hook~,
        report~,
      ),
    ]),
  )
  @test.assert_eq(events, [
    "hook:a", "report:Merged tokens into attribute 'rel' on <a>", "node:a",
  ])
  assert_eq(root.to_html(pretty=false), "<a rel=\"noreferrer noopener\">x</a>")
}

///|
test "text transform hooks and reports run before text replacement" {
  let events : Array[String] = []
  let hook : (@html_parser.Node) -> Unit = fn(node) {
    events.push("hook:" + node.name() + ":" + node.data())
  }
  let report : (String, @html_parser.Node?) -> Unit = fn(message, node) {
    events.push("report:" + message)
    match node {
      Some(hit) => events.push("node:" + hit.name() + ":" + hit.data())
      None => events.push("node:none")
    }
  }
  let root = @html_parser.parse_fragment(
      "<p>visit example.com  now</p><pre>x  y</pre>",
    ).root
  ignore(
    @html_parser.apply_transforms(root, [
      @html_parser.TransformSpec::collapse_whitespace(hook~, report~),
      @html_parser.TransformSpec::linkify(hook~, report~),
    ]),
  )
  @test.assert_eq(events, [
    "hook:#text:visit example.com  now", "report:Collapsed whitespace in text node",
    "node:#text:visit example.com  now", "hook:#text:visit example.com now", "report:Linkified 1 link(s) in text node",
    "node:#text:visit example.com now",
  ])
  assert_eq(
    root.to_html(pretty=false),
    "<p>visit <a href=\"http://example.com\">example.com</a> now</p><pre>x  y</pre>",
  )
}

///|
test "unchanged text transforms do not call hooks" {
  let events : Array[String] = []
  let hook : (@html_parser.Node) -> Unit = fn(node) {
    events.push("hook:" + node.name())
  }
  let report : (String, @html_parser.Node?) -> Unit = fn(message, _node) {
    events.push("report:" + message)
  }
  let root = @html_parser.parse_fragment("<p>plain</p><a>example.com</a>").root
  ignore(
    @html_parser.apply_transforms(root, [
      @html_parser.TransformSpec::collapse_whitespace(hook~, report~),
      @html_parser.TransformSpec::linkify(hook~, report~),
    ]),
  )
  @test.assert_eq(events, [])
  assert_eq(root.to_html(pretty=false), "<p>plain</p><a>example.com</a>")
}

///|
test "linkify transform can replace standalone text root" {
  let events : Array[String] = []
  let hook : (@html_parser.Node) -> Unit = fn(node) {
    events.push("hook:" + node.name())
  }
  let report : (String, @html_parser.Node?) -> Unit = fn(message, _node) {
    events.push("report:" + message)
  }
  let root = @html_parser.apply_transforms(
    @html_parser.text("Go example.com"),
    [@html_parser.TransformSpec::linkify(hook~, report~)],
  )
  assert_eq(
    root.to_html(pretty=false),
    "Go <a href=\"http://example.com\">example.com</a>",
  )
  @test.assert_eq(events, [
    "hook:#text", "report:Linkified 1 link(s) in text node",
  ])
}

///|
test "root text and leaf transforms no-op when kind cannot apply" {
  let text_root = @html_parser.apply_transforms(
    @html_parser.text("plain text"),
    [
      @html_parser.TransformSpec::drop("p"),
      @html_parser.TransformSpec::collapse_whitespace(),
      @html_parser.TransformSpec::linkify(),
    ],
  )
  assert_eq(text_root.to_html(pretty=false), "plain text")

  let comment_root = @html_parser.apply_transforms(
    @html_parser.comment("example.com"),
    [
      @html_parser.TransformSpec::drop_comments(),
      @html_parser.TransformSpec::collapse_whitespace(),
      @html_parser.TransformSpec::linkify(),
    ],
  )
  assert_eq(comment_root.to_html(pretty=false), "<!--example.com-->")

  let pre_root = @html_parser.element("pre", children=[
    @html_parser.text("example.com  x"),
  ])
  ignore(
    @html_parser.apply_transforms(pre_root, [
      @html_parser.TransformSpec::collapse_whitespace(),
      @html_parser.TransformSpec::linkify(),
    ]),
  )
  assert_eq(pre_root.to_html(pretty=false), "<pre>example.com  x</pre>")
}

///|
test "text transforms recurse through nested fragment children" {
  let root = @html_parser.fragment(children=[
    @html_parser.fragment(children=[
      @html_parser.text("visit example.com  now"),
      @html_parser.element("p"),
    ]),
  ])
  ignore(
    @html_parser.apply_transforms(root, [
      @html_parser.TransformSpec::collapse_whitespace(),
      @html_parser.TransformSpec::linkify(),
      @html_parser.TransformSpec::prune_empty("p"),
    ]),
  )
  assert_eq(
    root.to_html(pretty=false),
    "visit <a href=\"http://example.com\">example.com</a> now",
  )
}

///|
test "drop_url_attrs validates URL attrs and normalizes mixed-case names" {
  let trusted_rule = @html_parser.UrlRule::new(
    allowed_schemes=["https"],
    allowed_hosts=["trusted.example"],
    allow_relative=false,
  )
  let url_policy = @html_parser.UrlPolicy::new(default_allow_relative=false, allow_rules=[
    @html_parser.UrlPolicyRule::new("a", "href", trusted_rule),
    @html_parser.UrlPolicyRule::new("a", "ping", trusted_rule),
    @html_parser.UrlPolicyRule::new("img", "srcset", trusted_rule),
    @html_parser.UrlPolicyRule::new("base", "href", trusted_rule),
  ])
  let a = @html_parser.element("a", attrs={
    "Href": Some(" https://trusted.example/x "),
    "Ping": Some("https://trusted.example/p https://evil.example/p"),
    "data-ok": Some("1"),
  })
  let img = @html_parser.element("img", attrs={
    "SrcSet": Some("https://trusted.example/a 1x, https://evil.example/b 2x"),
  })
  let refresh = @html_parser.element("meta", attrs={
    "Http-Equiv": Some("refresh"),
    "Content": Some("0;url=https://evil.example/"),
  })
  let charset = @html_parser.element("meta", attrs={
    "http-equiv": Some("content-type"),
    "content": Some("text/html; charset=utf-8"),
  })
  let base = @html_parser.element("base", attrs={
    "Href": Some("https://trusted.example/assets/"),
  })
  let root = @html_parser.fragment(children=[a, img, refresh, charset, base])
  ignore(
    @html_parser.apply_transforms(root, [
      @html_parser.TransformSpec::drop_url_attrs("*", url_policy~),
    ]),
  )

  let a_attrs = a.attrs()
  assert_true(a_attrs.get("href") is Some(Some("https://trusted.example/x")))
  assert_true(a_attrs.get("Href") is None)
  assert_true(a_attrs.get("Ping") is None)
  assert_true(a_attrs.get("data-ok") is Some(Some("1")))
  assert_true(img.attrs().get("SrcSet") is None)
  assert_true(img.attrs().get("srcset") is None)
  assert_true(refresh.attrs().get("Http-Equiv") is Some(Some("refresh")))
  assert_true(refresh.attrs().get("Content") is None)
  assert_true(
    charset.attrs().get("content") is Some(Some("text/html; charset=utf-8")),
  )
  assert_eq(base.attrs().length(), 0)
}

///|
test "drop_url_attrs reports exact unsafe URL reasons before hook" {
  let events : Array[String] = []
  let hook : (@html_parser.Node) -> Unit = fn(node) {
    events.push("hook:" + node.name())
  }
  let report : (String, @html_parser.Node?) -> Unit = fn(message, node) {
    events.push("report:" + message)
    match node {
      Some(hit) => events.push("node:" + hit.name())
      None => events.push("node:none")
    }
  }
  let trusted_rule = @html_parser.UrlRule::new(
    allowed_schemes=["https"],
    allowed_hosts=["trusted.example"],
    allow_relative=false,
  )
  let url_policy = @html_parser.UrlPolicy::new(default_allow_relative=false, allow_rules=[
    @html_parser.UrlPolicyRule::new("a", "href", trusted_rule),
    @html_parser.UrlPolicyRule::new("base", "href", trusted_rule),
  ])
  let root = @html_parser.fragment(children=[
    @html_parser.element("a", attrs={ "href": Some("javascript:alert(1)") }),
    @html_parser.element("a", attrs={ "src": Some("https://trusted.example/x") }),
    @html_parser.element("base", attrs={
      "href": Some("https://trusted.example/assets/"),
    }),
    @html_parser.element("meta", attrs={
      "http-equiv": Some("refresh"),
      "content": Some("0;url=https://evil.example/"),
    }),
    @html_parser.element("a", attrs={ "href": None }),
  ])
  ignore(
    @html_parser.apply_transforms(root, [
      @html_parser.TransformSpec::drop_url_attrs(
        "*",
        url_policy~,
        hook~,
        report~,
      ),
    ]),
  )
  @test.assert_eq(events, [
    "report:Unsafe URL in attribute 'href'", "node:a", "hook:a", "report:Unsafe URL in attribute 'src' (no rule)",
    "node:a", "hook:a", "report:Unsafe URL in attribute 'href' (base tag)", "node:base",
    "hook:base", "report:Unsafe URL in attribute 'content' (meta refresh)", "node:meta",
    "hook:meta", "report:Unsafe URL in attribute 'href'", "node:a", "hook:a",
  ])
  assert_eq(
    root.to_html(pretty=false),
    "<a></a><a></a><base><meta http-equiv=\"refresh\"><a></a>",
  )
}

///|
test "drop_url_attrs sanitizes foreign URL function attributes" {
  let url_policy = @html_parser.UrlPolicy::new(allow_rules=[
    @html_parser.UrlPolicyRule::new(
      "rect",
      "fill",
      @html_parser.UrlRule::new(allowed_schemes=["https"], allowed_hosts=[
        "trusted.example",
      ]),
    ),
  ])
  let rect = @html_parser.element("rect", ns="svg", attrs={
    "fill": Some("url(https://trusted.example/fill.svg#x) red"),
    "filter": Some("url(https://evil.example/filter.svg#f)"),
    "width": Some("10"),
  })
  let root = @html_parser.fragment(children=[rect])
  ignore(
    @html_parser.apply_transforms(root, [
      @html_parser.TransformSpec::drop_url_attrs("*", url_policy~),
    ]),
  )
  let attrs = rect.attrs()
  assert_true(
    attrs.get("fill")
    is Some(Some("url('https://trusted.example/fill.svg#x') red")),
  )
  assert_true(attrs.get("filter") is None)
  assert_true(attrs.get("width") is Some(Some("10")))
}

///|
test "allow_style_attrs sanitizes mixed-case style attributes" {
  let none = @html_parser.element("span", attrs={ "style": None })
  let bad = @html_parser.element("span", attrs={
    "style": Some("position: fixed"),
  })
  let mixed = @html_parser.element("span", attrs={
    "title": Some("x"),
    "Style": Some("color: red; position: fixed"),
  })
  let url_style = @html_parser.element("span", attrs={
    "Style": Some("background-image: url('/x.png'); color: blue"),
  })
  let untouched = @html_parser.element("p", attrs={
    "Style": Some("position: fixed"),
  })
  let root = @html_parser.fragment(children=[
    none, bad, mixed, url_style, untouched,
  ])
  ignore(
    @html_parser.apply_transforms(root, [
      @html_parser.TransformSpec::allow_style_attrs("span", allowed_css_properties=[
        "background-image", "color",
      ]),
    ]),
  )
  assert_true(none.attrs().get("style") is None)
  assert_true(bad.attrs().get("style") is None)
  assert_true(mixed.attrs().get("Style") is None)
  assert_true(mixed.attrs().get("style") is Some(Some("color: red")))
  assert_true(mixed.attrs().get("title") is Some(Some("x")))
  assert_true(url_style.attrs().get("style") is Some(Some("color: blue")))
  assert_true(untouched.attrs().get("Style") is Some(Some("position: fixed")))
}

///|
test "allow_style_attrs reports unsafe inline style before hook" {
  let events : Array[String] = []
  let hook : (@html_parser.Node) -> Unit = fn(node) {
    events.push("hook:" + node.name())
  }
  let report : (String, @html_parser.Node?) -> Unit = fn(message, node) {
    events.push("report:" + message)
    match node {
      Some(hit) => events.push("node:" + hit.name())
      None => events.push("node:none")
    }
  }
  let root = @html_parser.fragment(children=[
    @html_parser.element("span", attrs={ "style": None }),
    @html_parser.element("span", attrs={ "style": Some("position: fixed") }),
    @html_parser.element("span", attrs={
      "Style": Some("color: red; position: fixed"),
    }),
  ])
  ignore(
    @html_parser.apply_transforms(root, [
      @html_parser.TransformSpec::allow_style_attrs(
        "span",
        allowed_css_properties=["color"],
        hook~,
        report~,
      ),
    ]),
  )
  @test.assert_eq(events, [
    "report:Unsafe inline style in attribute 'style'", "node:span", "hook:span",
    "report:Unsafe inline style in attribute 'style'", "node:span", "hook:span",
    "hook:span",
  ])
  assert_eq(
    root.to_html(pretty=false),
    "<span></span><span></span><span style=\"color: red\"></span>",
  )
}
