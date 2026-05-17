///|
test "public structural transform pipeline stays stable" {
  let doc = @html_parser.parse_fragment(
    "<article><!--x--><p>Visit example.com</p><section><span>A \n B</span><b>keep  space</b></section><p class=empty>   </p></article>",
    sanitize=false,
  )
  ignore(
    @html_parser.apply_transforms(doc.root, [
      @html_parser.TransformSpec::stage([
        @html_parser.TransformSpec::drop_comments(),
        @html_parser.TransformSpec::collapse_whitespace(skip_tags=["b"]),
        @html_parser.TransformSpec::linkify(),
      ]),
      @html_parser.TransformSpec::unwrap("section"),
      @html_parser.TransformSpec::prune_empty("p.empty"),
      @html_parser.TransformSpec::merge_attrs("a", attr="rel", tokens=[
        "noopener", "noreferrer",
      ]),
    ]),
  )
  assert_eq(
    doc.to_html(pretty=false),
    "<article><p>Visit <a href=\"http://example.com\" rel=\"noopener noreferrer\">example.com</a></p><span>A B</span><b>keep  space</b></article>",
  )
}

///|
test "public attribute policy transform pipeline stays stable" {
  let url_policy = @html_parser.UrlPolicy::new(default_allow_relative=false, allow_rules=[
    @html_parser.UrlPolicyRule::new(
      "a",
      "href",
      @html_parser.UrlRule::new(
        allowed_schemes=["https"],
        allowed_hosts=["trusted.example"],
        allow_relative=false,
      ),
    ),
  ])
  let doc = @html_parser.parse_fragment(
    "<p id=keep onclick=x data-x=1 style='color: red; position: fixed'>Hi</p><a href='javascript:alert(1)' rel='NoOpener'>bad</a><a href='https://trusted.example/path' rel='nofollow'>ok</a>",
    sanitize=false,
  )
  ignore(
    @html_parser.apply_transforms(doc.root, [
      @html_parser.TransformSpec::allowlist_attrs("*", {
        "*": ["id", "data-x", "style", "href", "rel"],
      }),
      @html_parser.TransformSpec::drop_attrs("*", ["on*"]),
      @html_parser.TransformSpec::drop_url_attrs("*", url_policy~),
      @html_parser.TransformSpec::allow_style_attrs("*", allowed_css_properties=[
        "color",
      ]),
      @html_parser.TransformSpec::merge_attrs("a", attr="rel", tokens=[
        "noopener", "noreferrer",
      ]),
    ]),
  )
  assert_eq(
    doc.to_html(pretty=false),
    "<p id=\"keep\" data-x=\"1\" style=\"color: red\">Hi</p><a rel=\"noopener noreferrer\">bad</a><a href=\"https://trusted.example/path\" rel=\"nofollow noopener noreferrer\">ok</a>",
  )
}

///|
test "public callback transform pipeline stays stable" {
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
  let doc = @html_parser.parse_fragment(
    "<div><p class=drop>Drop</p><p class=keep>Keep <span>x</span></p></div>",
    sanitize=false,
  )
  ignore(
    @html_parser.apply_transforms(doc.root, [
      @html_parser.TransformSpec::edit_document(
        fn(root) { root.append_child(@html_parser.comment("done")) },
        hook~,
        report~,
      ),
      @html_parser.TransformSpec::decide(
        "p",
        fn(node) {
          if node.attrs().get("class") is Some(Some("drop")) {
            Drop
          } else {
            Keep
          }
        },
        hook~,
        report~,
      ),
      @html_parser.TransformSpec::edit(
        "span",
        fn(node) { node.append_child(@html_parser.text("!")) },
        hook~,
        report~,
      ),
      @html_parser.TransformSpec::edit_attrs(
        "p.keep",
        fn(node) { Some({ "data-seen": Some(node.name()) }) },
        hook~,
        report~,
      ),
    ]),
  )
  assert_eq(
    doc.to_html(pretty=false),
    "<div><p data-seen=\"p\">Keep <span>x!</span></p></div><!--done-->",
  )
  @test.assert_eq(events, [
    "hook:#document-fragment", "report:Edited document root", "node:#document-fragment",
    "hook:p", "report:Decide -> drop 'p' (matched selector 'p')", "node:p", "hook:span",
    "report:Edited <span> (matched selector 'span')", "node:span", "hook:p", "report:Edited attributes on <p> (matched selector 'p.keep')",
    "node:p",
  ])
}
