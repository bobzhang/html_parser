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
