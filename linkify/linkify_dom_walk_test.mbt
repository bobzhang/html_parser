// Exact tests for the `linkify_dom` walk order around skipped elements and
// template contents: an element's regular children are linkified before its
// template contents, and the skip state is inherited by both.

///|
/// A template element with template `contents` and also regular `children`.
/// `append_child` on a template inserts into its contents, so the regular
/// children are attached directly.
fn lw_template(
  children : Array[@dom.Node],
  contents : Array[@dom.Node],
) -> @dom.Node {
  let template = @dom.element("template", children=contents)
  for child in children {
    child.parent = Some(template)
    template.children.push(child)
  }
  template
}

///|
/// Compact structural dump: `name(attrs){template contents}[children]`.
fn lw_dump(node : @dom.Node) -> String {
  let out = StringBuilder()
  match node.kind {
    Text => out.write_string("'\{node.data}'")
    Comment => out.write_string("<!--\{node.data}-->")
    Doctype => out.write_string("<!doctype>")
    Document => out.write_string("#document")
    Fragment => out.write_string("#fragment")
    Element => out.write_string(node.name)
  }
  let attrs : Array[String] = []
  for name, value in node.attrs {
    let value = value.unwrap_or("")
    attrs.push("\{name}=\{value}")
  }
  if !attrs.is_empty() {
    out.write_string("(\{attrs.join(",")})")
  }
  if node.template_contents is Some(contents) {
    out.write_string("{\{contents.children.map(lw_dump).join(",")}}")
  }
  if !node.children.is_empty() {
    out.write_string("[\{node.children.map(lw_dump).join(",")}]")
  }
  out.to_string()
}

///|
test "linkify_dom walks template contents and inherits skip state" {
  let tree = () => {
    @dom.fragment(children=[
      @dom.text("a.com"),
      @dom.element("b", children=[
        @dom.text("b.com"),
        lw_template([@dom.text("c.com")], [@dom.text("d.com")]),
      ]),
      lw_template([@dom.text("e.com")], [
        @dom.text("f.com"),
        @dom.element("code", children=[@dom.text("g.com")]),
      ]),
      @dom.element("code", children=[lw_template([], [@dom.text("h.com")])]),
      @dom.element("p", children=[@dom.fragment(children=[@dom.text("i.com")])]),
    ])
  }
  debug_inspect(
    [
      lw_dump(@linkify.linkify_dom(tree())),
      lw_dump(@linkify.linkify_dom(tree(), skip_tags=[" B ", ""])),
    ],
    content=(
      #|[
      #|  "#fragment[a(href=http://a.com)['a.com'],b[a(href=http://b.com)['b.com'],template{a(href=http://d.com)['d.com']}[a(href=http://c.com)['c.com']]],template{a(href=http://f.com)['f.com'],code['g.com']}[a(href=http://e.com)['e.com']],code[template{'h.com'}],p[#fragment[a(href=http://i.com)['i.com']]]]",
      #|  "#fragment[a(href=http://a.com)['a.com'],b['b.com',template{'d.com'}['c.com']],template{a(href=http://f.com)['f.com'],code[a(href=http://g.com)['g.com']]}[a(href=http://e.com)['e.com']],code[template{a(href=http://h.com)['h.com']}],p[#fragment[a(href=http://i.com)['i.com']]]]",
      #|]
    ),
  )
}

///|
test "linkify_dom roots: skipped element, template and text" {
  debug_inspect(
    [
      lw_dump(
        @linkify.linkify_dom(
          @dom.element("pre", children=[
            @dom.text("a.com"),
            lw_template([], [@dom.text("b.com")]),
          ]),
        ),
      ),
      lw_dump(
        @linkify.linkify_dom(
          lw_template([@dom.text("c.com")], [
            @dom.text("d.com"),
            lw_template([], [@dom.text("e.com")]),
          ]),
        ),
      ),
      lw_dump(@linkify.linkify_dom(@dom.text("f.com and g.com"))),
      lw_dump(@linkify.linkify_dom(@dom.text("no links"))),
    ],
    content=(
      #|[
      #|  "pre['a.com',template{'b.com'}]",
      #|  "template{a(href=http://d.com)['d.com'],template{a(href=http://e.com)['e.com']}}[a(href=http://c.com)['c.com']]",
      #|  "#fragment[a(href=http://f.com)['f.com'],' and ',a(href=http://g.com)['g.com']]",
      #|  "'no links'",
      #|]
    ),
  )
}
