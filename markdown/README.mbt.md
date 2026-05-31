# `@markdown`

Convert a DOM tree to Markdown source. The single public function is
`to_markdown(node, html_passthrough?)` and it raises
`@core.HtmlError` if the tree is malformed.

The examples below are `mbt check` blocks and run as part of
`moon test markdown`.

## Inline formatting

```mbt check
///|
test "readme markdown inline" {
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
```

## Headings, lists, and links

```mbt check
///|
test "readme markdown headings list link" {
  let frag = @dom.fragment(children=[
    @dom.element("h1", children=[@dom.text("Title")]),
    @dom.element("ul", children=[
      @dom.element("li", children=[@dom.text("first")]),
      @dom.element("li", children=[@dom.text("second")]),
    ]),
    @dom.element("p", children=[
      @dom.element("a", attrs={ "href": Some("https://example.com") }, children=[
        @dom.text("link"),
      ]),
    ]),
  ])
  inspect(
    @markdown.to_markdown(frag),
    content=(
      #|# Title
      #|
      #|- first
      #|- second
      #|
      #|[link](https://example.com)
    ),
  )
}
```

## Code spans and fenced code blocks

`<code>` inside `<pre>` becomes a fenced block; bare `<code>`
becomes an inline span.

```mbt check
///|
test "readme markdown code" {
  let frag = @dom.fragment(children=[
    @dom.element("p", children=[
      @dom.text("run "),
      @dom.element("code", children=[@dom.text("moon test")]),
    ]),
    @dom.element("pre", children=[
      @dom.element("code", children=[@dom.text("let x = 1\n")]),
    ]),
  ])
  inspect(
    @markdown.to_markdown(frag),
    content=(
      #|run `moon test`
      #|
      #|```
      #|let x = 1
      #|```
    ),
  )
}
```

## Composing with the parser

Reach for `@parser.parse_fragment(...).to_markdown()` (or
`@html_parser.parse(...).to_markdown()`) when you have HTML source —
no need to build the tree by hand.
