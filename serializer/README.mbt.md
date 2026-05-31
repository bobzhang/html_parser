# `@serializer`

Convert a DOM tree back to HTML source. Also exposes plain-text
extraction (`to_text`), an html5lib-style dump (`to_test_format`),
and a few standalone predicates used elsewhere in the pipeline.

The examples below are `mbt check` blocks and run as part of
`moon test serializer`.

## `to_html` — compact and pretty

```mbt check
///|
test "readme serializer compact" {
  let node = @dom.element("article", children=[
    @dom.element("p", attrs={ "class": Some("intro") }, children=[
      @dom.text("Hello "),
      @dom.element("b", children=[@dom.text("MoonBit")]),
    ]),
  ])
  inspect(
    @serializer.to_html(node, pretty=false),
    content=(
      #|<article><p class="intro">Hello <b>MoonBit</b></p></article>
    ),
  )
}
```

`pretty=true` indents block-level elements; `indent_size` controls
how many spaces are added per level.

```mbt check
///|
test "readme serializer pretty" {
  let node = @dom.element("article", children=[
    @dom.element("p", children=[@dom.text("body")]),
  ])
  inspect(
    @serializer.to_html(node, pretty=true),
    content=(
      #|<article>
      #|  <p>body</p>
      #|</article>
    ),
  )
}
```

## Escaping in text and attributes

Text content gets `&`, `<`, `>` escaped automatically. Attribute
values use the quote character you pass via `quote=` (default `"`).

```mbt check
///|
test "readme serializer escapes" {
  let node = @dom.element("p", children=[@dom.text("a < b && c > d")])
  inspect(
    @serializer.to_html(node, pretty=false),
    content=(
      #|<p>a &lt; b &amp;&amp; c &gt; d</p>
    ),
  )
}
```

## Void elements

Tags from the HTML5 void list never get an end tag.

```mbt check
///|
test "readme serializer void elements" {
  let node = @dom.fragment(children=[
    @dom.element("br"),
    @dom.element("img", attrs={ "src": Some("/x.png") }),
  ])
  inspect(
    @serializer.to_html(node, pretty=false),
    content=(
      #|<br><img src="/x.png">
    ),
  )
}
```

## `to_text` — plain-text extraction

```mbt check
///|
test "readme serializer to_text" {
  let node = @dom.element("p", children=[
    @dom.text("Hello "),
    @dom.element("b", children=[@dom.text("MoonBit")]),
  ])
  inspect(
    @serializer.to_text(node),
    content=(
      #|Hello MoonBit
    ),
  )
}
```

## `to_test_format` — html5lib-style dump

Useful when you want to diff DOM structure rather than serialized
HTML — it shows attributes and text children on their own indented
lines, the format upstream html5lib fixtures use.

```mbt check
///|
test "readme serializer to_test_format" {
  let node = @dom.element("p", attrs={ "class": Some("intro") }, children=[
    @dom.text("hi"),
  ])
  inspect(
    @serializer.to_test_format(node),
    content=(
      #|| <p>
      #||   class="intro"
      #||   "hi"
    ),
  )
}
```
