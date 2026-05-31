// Blackbox snapshot tests for `to_html` — serialize a DOM node back
// to HTML source. Both compact and pretty modes are supported, as
// is escaping for non-HTML contexts (JS strings, URLs).

///|
fn sample_tree() -> @dom.Node {
  @dom.element("article", children=[
    @dom.element("p", attrs={ "class": Some("intro") }, children=[
      @dom.text("Hello "),
      @dom.element("b", children=[@dom.text("MoonBit")]),
    ]),
  ])
}

///|
test "to_html compact emits one line with no indentation" {
  inspect(
    @serializer.to_html(sample_tree(), pretty=false),
    content=(
      #|<article><p class="intro">Hello <b>MoonBit</b></p></article>
    ),
  )
}

///|
test "to_html pretty indents block-level elements" {
  inspect(
    @serializer.to_html(sample_tree(), pretty=true),
    content=(
      #|<article>
      #|  <p class="intro">Hello <b>MoonBit</b></p>
      #|</article>
    ),
  )
}

///|
test "to_html pretty respects indent_size" {
  inspect(
    @serializer.to_html(sample_tree(), pretty=true, indent_size=4),
    content=(
      #|<article>
      #|    <p class="intro">Hello <b>MoonBit</b></p>
      #|</article>
    ),
  )
}

///|
test "to_html escapes ampersand and angle brackets in text" {
  let node = @dom.element("p", children=[@dom.text("a < b && c > d")])
  inspect(
    @serializer.to_html(node, pretty=false),
    content=(
      #|<p>a &lt; b &amp;&amp; c &gt; d</p>
    ),
  )
}

///|
test "to_html serializes void elements without an end tag" {
  let node = @dom.fragment(children=[
    @dom.element("br"),
    @dom.element("img", attrs={ "src": Some("/x.png") }),
    @dom.element("hr"),
  ])
  inspect(
    @serializer.to_html(node, pretty=false),
    content=(
      #|<br><img src="/x.png"><hr>
    ),
  )
}

///|
test "to_html quote parameter switches attribute quoting" {
  let node = @dom.element("a", attrs={ "href": Some("/x") })
  let dbl = @serializer.to_html(node, pretty=false, quote='"')
  let sgl = @serializer.to_html(node, pretty=false, quote='\'')
  debug_inspect(
    (dbl, sgl),
    content=(
      #|("<a href=\"/x\"></a>", "<a href='/x'></a>")
    ),
  )
}
