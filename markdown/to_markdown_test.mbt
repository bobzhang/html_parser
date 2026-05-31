// Blackbox snapshot tests for `to_markdown` — convert a DOM tree to
// Markdown source.
//
// Tests build DOM nodes with the `@dom.*` constructors rather than
// going through the parser, both to keep the inputs small and to
// avoid a circular package dependency (the parser already imports
// the markdown package).

///|
test "to_markdown renders bold and italic inline" {
  let node = @dom.element("p", children=[
    @dom.text("hello "),
    @dom.element("b", children=[@dom.text("bold")]),
    @dom.text(" and "),
    @dom.element("i", children=[@dom.text("italic")]),
  ])
  inspect(
    @markdown.to_markdown(node),
    content=(
      #|hello **bold** and *italic*
    ),
  )
}

///|
test "to_markdown renders headings with leading hashes" {
  let frag = @dom.fragment(children=[
    @dom.element("h1", children=[@dom.text("Title")]),
    @dom.element("h2", children=[@dom.text("Subtitle")]),
    @dom.element("p", children=[@dom.text("body")]),
  ])
  inspect(
    @markdown.to_markdown(frag),
    content=(
      #|# Title
      #|
      #|## Subtitle
      #|
      #|body
    ),
  )
}

///|
test "to_markdown renders an unordered list" {
  let ul = @dom.element("ul", children=[
    @dom.element("li", children=[@dom.text("one")]),
    @dom.element("li", children=[@dom.text("two")]),
  ])
  inspect(
    @markdown.to_markdown(ul),
    content=(
      #|- one
      #|- two
    ),
  )
}

///|
test "to_markdown renders a link as inline reference" {
  let a = @dom.element("a", attrs={ "href": Some("https://example.com") }, children=[
    @dom.text("example"),
  ])
  inspect(
    @markdown.to_markdown(a),
    content=(
      #|[example](https://example.com)
    ),
  )
}

///|
test "to_markdown renders inline code and a code block" {
  let frag = @dom.fragment(children=[
    @dom.element("p", children=[
      @dom.text("inline "),
      @dom.element("code", children=[@dom.text("code()")]),
    ]),
    @dom.element("pre", children=[
      @dom.element("code", children=[@dom.text("let x = 1\nlet y = 2\n")]),
    ]),
  ])
  inspect(
    @markdown.to_markdown(frag),
    content=(
      #|inline `code()`
      #|
      #|```
      #|let x = 1
      #|let y = 2
      #|```
    ),
  )
}

///|
test "to_markdown drops markdown-unknown tags by default" {
  // <kbd> has no Markdown equivalent. Both the default and the
  // `html_passthrough=true` path emit the inner text only — the
  // tag itself does not survive. (Pass-through targets a different
  // set of constructs, e.g. raw HTML blocks the converter cannot
  // safely round-trip.)
  let p = @dom.element("p", children=[
    @dom.text("press "),
    @dom.element("kbd", children=[@dom.text("Enter")]),
  ])
  let stripped = @markdown.to_markdown(p)
  let passed = @markdown.to_markdown(p, html_passthrough=true)
  debug_inspect(
    (stripped, passed),
    content=(
      #|("press Enter", "press Enter")
    ),
  )
}
