// Exact-output tests for the Markdown constructs whose rendering finishes
// after their children: emphasis and heading wrappers (including the
// rollback of an empty wrapper), blockquote quoting, link text, nested
// lists and `html_passthrough`. Each case renders a small tree and the
// snapshots pin the full output, so they double as a behaviour check of the
// work-stack walker against the former recursive one.

///|
fn mx_el(name : String, children : Array[@dom.Node]) -> @dom.Node {
  @dom.element(name, children~)
}

///|
fn mx_t(data : String) -> @dom.Node {
  @dom.text(data)
}

///|
fn mx_link(href : String?, children : Array[@dom.Node]) -> @dom.Node {
  let attrs : Map[String, String?] = match href {
    Some(value) => { "href": Some(value) }
    None => Map([])
  }
  @dom.element("a", attrs~, children~)
}

///|
fn mx_render(
  nodes : Array[@dom.Node],
  html_passthrough? : Bool = false,
) -> Array[String] raise {
  nodes.map(node => @markdown.to_markdown(node, html_passthrough~))
}

///|
test "to_markdown rolls back empty inline wrappers after pending whitespace" {
  debug_inspect(
    mx_render([
      mx_el("p", [mx_t("a "), mx_el("b", []), mx_t("c")]),
      mx_el("p", [mx_t("a "), mx_el("b", [mx_t(" ")]), mx_t(" c")]),
      mx_el("p", [mx_t("a "), mx_el("em", [mx_t("\n  \t")]), mx_t("c")]),
      mx_el("p", [
        mx_t("a "),
        mx_el("strong", [mx_el("em", [mx_t(" ")])]),
        mx_t("c"),
      ]),
      mx_el("p", [mx_t("a "), mx_el("b", [@dom.comment("x")]), mx_t("c")]),
      mx_el("p", [
        mx_t("a "),
        mx_el("i", [mx_el("span", [mx_t(" ")]), mx_el("b", [])]),
        mx_t("c"),
      ]),
      mx_el("p", [mx_t("a "), mx_el("b", [mx_el("p", [mx_t(" ")])]), mx_t("c")]),
      mx_el("p", [mx_t("a  "), mx_el("b", [mx_el("br", [])]), mx_t("c")]),
      mx_el("p", [
        mx_t("a"),
        mx_el("br", []),
        mx_el("b", [mx_t(" ")]),
        mx_t("c"),
      ]),
      mx_el("p", [mx_t("a "), mx_el("b", [mx_t(" x ")]), mx_t("c")]),
      mx_el("p", [mx_t("a "), mx_el("em", [mx_t(" x")]), mx_t(" c")]),
      @dom.fragment(children=[
        mx_el("p", [mx_t("a")]),
        mx_el("em", [mx_t(" ")]),
        mx_el("p", [mx_t("b")]),
      ]),
      @dom.fragment(children=[
        mx_t("a "),
        mx_el("b", [mx_el("div", [mx_el("section", [])])]),
        mx_t("b"),
      ]),
    ]),
    content=(
      #|[
      #|  "a c",
      #|  "a c",
      #|  "a c",
      #|  "a c",
      #|  "a c",
      #|  "a c",
      #|  "a c",
      #|  "a c",
      #|  "a\nc",
      #|  "a **x**c",
      #|  "a *x* c",
      #|  "a\n\nb",
      #|  "a b",
      #|]
    ),
  )
}

///|
test "to_markdown rolls back empty blockquotes, headings and links" {
  debug_inspect(
    mx_render([
      @dom.fragment(children=[
        mx_t("a "),
        mx_el("blockquote", [mx_t(" ")]),
        mx_t("b"),
      ]),
      @dom.fragment(children=[
        mx_t("a "),
        mx_el("blockquote", [mx_el("p", [mx_t(" ")]), mx_el("b", [])]),
        mx_t("b"),
      ]),
      @dom.fragment(children=[
        mx_el("p", [mx_t("a")]),
        mx_el("blockquote", [mx_el("blockquote", [mx_el("em", [])])]),
        mx_el("p", [mx_t("b")]),
      ]),
      mx_el("h2", []),
      mx_el("h2", [mx_t(" ")]),
      mx_el("h3", [mx_el("b", [mx_t(" ")])]),
      @dom.fragment(children=[mx_t("a "), mx_el("h2", []), mx_t("b")]),
      @dom.fragment(children=[
        mx_t("a "),
        mx_el("h4", [mx_el("em", []), mx_t(" ")]),
        mx_t(" b"),
      ]),
      mx_link(Some("u"), []),
      mx_link(Some("u"), [mx_t(" ")]),
      mx_link(Some("u"), [mx_el("b", [mx_t(" ")])]),
      mx_link(Some(""), [mx_t("x")]),
      mx_link(None, [mx_t("x")]),
      mx_link(Some(" u v "), [mx_t("x")]),
      mx_link(Some("u"), [mx_t("x "), mx_el("b", [mx_t(" ")]), mx_t("y")]),
      mx_link(Some("u"), [
        mx_t("x "),
        mx_el("strong", [mx_el("em", [mx_t(" ")]), mx_t(" ")]),
        mx_t(" y"),
      ]),
      @dom.fragment(children=[
        mx_t("a "),
        mx_link(Some("u"), [mx_t(" ")]),
        mx_t(" b"),
      ]),
      mx_el("p", [mx_t("a "), mx_el("b", [mx_link(Some("u"), [])]), mx_t("c")]),
    ]),
    content=(
      #|[
      #|  "a b",
      #|  "a b",
      #|  "a\n\nb",
      #|  "##",
      #|  "##",
      #|  "###",
      #|  "a\n\n##\n\nb",
      #|  "a\n\n####\n\nb",
      #|  "[](u)",
      #|  "[](u)",
      #|  "[](u)",
      #|  "[x]",
      #|  "[x]",
      #|  "[x](<u%20v>)",
      #|  "[x y](u)",
      #|  "[x y](u)",
      #|  "a [](u) b",
      #|  "a **[](u)**c",
      #|]
    ),
  )
}

///|
test "to_markdown escapes line starts at the start of nested output" {
  debug_inspect(
    mx_render([
      mx_el("h2", [mx_t("# x")]),
      mx_el("h2", [mx_t("1. x")]),
      mx_el("p", [mx_t("a "), mx_el("b", [mx_t("- y")])]),
      mx_el("p", [mx_t("a "), mx_el("em", [mx_t(" > y")])]),
      mx_el("blockquote", [mx_t("# x"), mx_el("br", []), mx_t("- y")]),
      mx_link(Some("u"), [mx_t("+ x")]),
      mx_el("h1", [mx_t("a"), mx_el("br", []), mx_t("=== b")]),
      mx_el("h2", [mx_el("h3", [mx_t("x")])]),
      mx_el("h2", [mx_t("a "), mx_el("p", [mx_t("b")]), mx_t(" c")]),
    ]),
    content=(
      #|[
      #|  "## \\# x",
      #|  "## 1\\. x",
      #|  "a **\\- y**",
      #|  "a *\\> y*",
      #|  "> \\# x\n> \\- y",
      #|  "[\\+ x](u)",
      #|  "# a\n=== b",
      #|  "## ### x",
      #|  "## a\n\nb\n\nc",
      #|]
    ),
  )
}

///|
test "to_markdown quotes nested multiline blockquotes" {
  debug_inspect(
    mx_render([
      mx_el("blockquote", [
        mx_el("p", [mx_t("one")]),
        mx_el("p", [mx_t("two")]),
        mx_el("blockquote", [
          mx_el("p", [mx_t("three")]),
          mx_el("blockquote", [mx_t("four"), mx_el("br", []), mx_t("five")]),
        ]),
        mx_t("six"),
      ]),
      mx_el("blockquote", [
        mx_t("a"),
        mx_el("blockquote", [
          mx_t("b"),
          mx_el("blockquote", [mx_t("c")]),
          mx_t("d"),
        ]),
        mx_t("e"),
      ]),
      mx_el("blockquote", [
        mx_el("ul", [
          mx_el("li", [mx_t("a")]),
          mx_el("li", [mx_t("b"), mx_el("blockquote", [mx_t("c")])]),
        ]),
        mx_el("ol", [
          mx_el("li", [mx_t("x"), mx_el("ul", [mx_el("li", [mx_t("y")])])]),
        ]),
      ]),
      mx_el("ul", [
        mx_el("li", [
          mx_el("blockquote", [
            mx_t("q"),
            mx_el("ul", [mx_el("li", [mx_el("blockquote", [mx_t("r")])])]),
          ]),
        ]),
      ]),
      mx_el("h2", [mx_t("a"), mx_el("blockquote", [mx_t("b")])]),
      mx_el("p", [
        mx_t("x "),
        mx_el("b", [
          mx_el("blockquote", [mx_t("q"), mx_el("br", []), mx_t("r")]),
        ]),
        mx_t(" y"),
      ]),
      mx_el("em", [mx_el("blockquote", [mx_el("blockquote", [mx_t("deep")])])]),
      mx_el("blockquote", [
        mx_el("pre", [mx_t("l1\n\nl2\n")]),
        mx_el("hr", []),
        mx_el("blockquote", [mx_el("h3", [mx_t("h")])]),
      ]),
      mx_link(Some("u"), [
        mx_el("blockquote", [mx_t("q"), mx_el("p", [mx_t("p")])]),
      ]),
      @dom.fragment(children=[
        mx_t("before  "),
        mx_el("blockquote", [mx_t("  in  ")]),
        mx_t("  after"),
      ]),
    ]),
    content=(
      #|[
      #|  "> one\n> \n> two\n> \n> > three\n> > \n> > > four\n> > > five\n> \n> six",
      #|  "> a\n> \n> > b\n> > \n> > > c\n> > \n> > d\n> \n> e",
      #|  "> - a\n> - b\n> \n> > c\n> \n> 1. x\n> \n>   - y",
      #|  "-\n\n> q\n> \n>   -\n> \n> > r",
      #|  "## a\n\n> b",
      #|  "x **> q\n> r** y",
      #|  "*> > deep*",
      #|  "> ```\n> l1\n> \n> l2\n> ```\n> \n> ---\n> \n> > ### h",
      #|  "[qp](u)",
      #|  "before\n\n> in\n\nafter",
      #|]
    ),
  )
}

///|
test "to_markdown renders nested lists" {
  debug_inspect(
    mx_render([
      mx_el("ul", [
        mx_el("li", [
          mx_t("a"),
          mx_el("ul", [
            mx_el("li", [
              mx_t("b"),
              mx_el("ol", [mx_el("li", [mx_t("c")]), mx_el("li", [mx_t("d")])]),
            ]),
            mx_el("li", [mx_t("e")]),
          ]),
        ]),
        mx_el("li", [mx_t("f")]),
      ]),
      mx_el("ol", [
        mx_t("ignored"),
        mx_el("li", [mx_t("a")]),
        mx_el("p", [mx_t("dropped")]),
        mx_el("li", [mx_t("b")]),
      ]),
      mx_el("ul", [
        mx_el("li", []),
        mx_el("li", [mx_t(" ")]),
        mx_el("li", [mx_t("x")]),
      ]),
      mx_el("ul", [
        mx_el("li", [mx_el("p", [mx_t("a")]), mx_el("p", [mx_t("b")])]),
        mx_el("li", [mx_t("c")]),
      ]),
      @dom.fragment(children=[
        mx_el("p", [mx_t("intro")]),
        mx_el("ul", [mx_el("li", [mx_t("a")])]),
        mx_t("outro"),
      ]),
      mx_el("ul", [
        mx_el("li", [
          mx_el("strong", [mx_el("ul", [mx_el("li", [mx_t("x")])])]),
          mx_el("em", [mx_t("y")]),
        ]),
      ]),
      mx_el("ol", [
        mx_el("li", [mx_el("h2", [mx_el("ol", [mx_el("li", [mx_t("h")])])])]),
        mx_el("li", [mx_el("div", [mx_t("d")]), mx_t("tail")]),
      ]),
      mx_link(Some("u"), [
        mx_el("ul", [
          mx_el("li", [mx_t("a")]),
          mx_el("li", [mx_t("b"), mx_el("ol", [mx_el("li", [mx_t("c")])])]),
        ]),
        mx_t("z"),
      ]),
    ]),
    content=(
      #|[
      #|  "- a\n\n  - b\n\n    1. c\n    2. d\n\n\n  - e\n\n\n- f",
      #|  "1. a\n2. b",
      #|  "-\n-\n- x",
      #|  "-\n\na\n\nb\n\n\n- c",
      #|  "intro\n\n- a\n\noutro",
      #|  "- **- x***y*",
      #|  "1.\n\n## 1. h\n\n\n2. d\n\ntail",
      #|  "[a b cz](u)",
      #|]
    ),
  )
}

///|
test "to_markdown passes through raw HTML only when asked" {
  let nodes = [
    @dom.fragment(children=[
      mx_el("p", [mx_t("a")]),
      mx_el("script", [mx_t("x<y")]),
      mx_el("p", [mx_t("b")]),
    ]),
    mx_el("p", [
      mx_t("x "),
      mx_el("b", [mx_el("script", [mx_t("s")])]),
      mx_t("y"),
    ]),
    mx_el("p", [
      mx_t("x "),
      mx_el("em", [mx_el("textarea", [mx_t("t")])]),
      mx_t("y"),
    ]),
    mx_el("h2", [mx_t("h "), mx_el("style", [mx_t("p{}")])]),
    mx_el("blockquote", [mx_t("q"), mx_el("script", [mx_t("s")]), mx_t("r")]),
    mx_link(Some("u"), [mx_t("a "), mx_el("script", [mx_t("s")]), mx_t(" b")]),
    mx_link(Some("u"), [mx_el("textarea", [mx_t("t")])]),
    mx_el("ul", [
      mx_el("li", [mx_el("style", [mx_t("s")])]),
      mx_el("li", [mx_t("x")]),
    ]),
    mx_el("p", [
      mx_el("img", []),
      mx_el("table", [mx_el("tr", [mx_el("td", [mx_t("c")])])]),
    ]),
  ]
  debug_inspect(
    mx_render(nodes),
    content=(
      #|[
      #|  "a\n\nb",
      #|  "x y",
      #|  "x y",
      #|  "## h",
      #|  "> q\n> \n> r",
      #|  "[a b](u)",
      #|  "[](u)",
      #|  "-\n\n\n- x",
      #|  "<img>\n\n<table><tr><td>c</td></tr></table>",
      #|]
    ),
  )
  debug_inspect(
    mx_render(nodes, html_passthrough=true),
    content=(
      #|[
      #|  "a\n\n<script>x<y</script>\n\nb",
      #|  "x **<script>s</script>**y",
      #|  "x *<textarea>t</textarea>*y",
      #|  "## h\n\n<style>p{}</style>",
      #|  "> q\n> \n> <script>s</script>\n> \n> r",
      #|  "[a <script>s</script> b](u)",
      #|  "[<textarea>t</textarea>](u)",
      #|  "-\n\n<style>s</style>\n\n\n- x",
      #|  "<img>\n\n<table><tr><td>c</td></tr></table>",
      #|]
    ),
  )
}

///|
/// The repeating unit of the mixed deep-nesting chain, outermost first. Every
/// level renders on a single line, so `mixed_chain` has an exact closed-form
/// rendering (see `mixed_chain_markdown`): the containers are transparent,
/// the list item, strong, blockquote, emphasis and heading each contribute a
/// fixed prefix, and the strong/emphasis pair a fixed suffix.
let mixed_chain_unit : Array[String] = [
  "ul", "li", "strong", "blockquote", "section", "em", "h3", "x-unknown", "template",
  "span", "p", "div",
]

///|
fn mixed_chain(periods : Int) -> @dom.Node {
  let mut current = mx_el("p", [mx_t("leaf "), mx_el("code", [mx_t("c")])])
  for _ in 0..<periods {
    for index = mixed_chain_unit.length() - 1; index >= 0; index = index - 1 {
      current = mx_el(mixed_chain_unit[index], [current])
    }
  }
  current
}

///|
fn mixed_chain_markdown(periods : Int) -> String {
  "- **> *### ".repeat(periods) + "leaf `c`" + "***".repeat(periods)
}

///|
test "to_markdown renders the mixed nesting chain exactly" {
  debug_inspect(
    [
      @markdown.to_markdown(mixed_chain(0)),
      @markdown.to_markdown(mixed_chain(1)),
      @markdown.to_markdown(mixed_chain(2)),
      @markdown.to_markdown(mixed_chain(3), html_passthrough=true),
    ],
    content=(
      #|[
      #|  "leaf `c`",
      #|  "- **> *### leaf `c`***",
      #|  "- **> *### - **> *### leaf `c`******",
      #|  "- **> *### - **> *### - **> *### leaf `c`*********",
      #|]
    ),
  )
  for periods in 0..<4 {
    assert_eq(
      @markdown.to_markdown(mixed_chain(periods)),
      mixed_chain_markdown(periods),
    )
  }
}
