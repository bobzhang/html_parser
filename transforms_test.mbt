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
  assert_eq(events, [
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
  assert_eq(events, ["outer:#document-fragment", "report:Stage 1"])
  assert_eq(
    root.to_html(pretty=false),
    "<p><a href=\"http://example.com\">example.com</a></p>",
  )
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
  assert_eq(events, [
    "hook:p", "report:Unsafe attribute 'onclick' on <p> was dropped because it is not allowed",
    "node:p", "hook:#text", "report:Stripped invisible Unicode from text node", "node:#text",
    "hook:#comment", "report:Unsafe comment was dropped", "node:#comment", "hook:script",
    "report:Unsafe tag 'script' was dropped with its content", "node:script",
  ])
  assert_eq(doc.root.to_html(pretty=false), "<p>x</p>")
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
  assert_eq(events, [])
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
  assert_eq(seen, ["#document-fragment"])
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
  assert_eq(seen, ["p"])
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
  assert_eq(events, [
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
  assert_eq(events, [
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
  assert_eq(events, [])
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
  assert_eq(events, [
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
  assert_eq(events, [
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
  assert_eq(events, [
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
  assert_eq(events, [])
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
  assert_eq(events, ["hook:#text", "report:Linkified 1 link(s) in text node"])
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
