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
