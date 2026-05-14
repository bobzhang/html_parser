///|
fn selector_public_doc() -> @html_parser.ParsedHtml raise {
  @html_parser.parse_fragment(
    "<main id=root><article id=a class=card featured data-kind=new><h2>Alpha</h2><p id=p1 class=lead data-tags=one>Needle <a id=link href=/x data-role=cta>Go</a></p><p id=p0 class=trail>Other</p><span id=empty></span></article><article id=b class=card data-kind=old><h2>Beta</h2><p id=p2 class=lead data-tags=two>Needle</p></article><aside id=side><p id=sidep class=lead>Side</p></aside><!--note--></main>",
  )
}

///|
fn selector_public_id_or_name(node : @html_parser.Node) -> String {
  match node.attrs().get("id") {
    Some(Some(id)) => id
    _ => node.name()
  }
}

///|
fn selector_public_ids(nodes : Array[@html_parser.Node]) -> String {
  let out = StringBuilder::new()
  let mut first = true
  for node in nodes {
    if !first {
      out.write_string(",")
    }
    first = false
    out.write_string(selector_public_id_or_name(node))
  }
  out.to_string()
}

///|
test "query supports tag class id and tag class selectors" {
  let doc = @html_parser.parse_fragment(
    "<div><p id='first' class='intro lead first'>One</p><p>Two</p></div>",
  )
  assert_eq(doc.query("p").length(), 2)
  assert_eq(doc.query(".intro").length(), 1)
  assert_eq(doc.query(".intro.first").length(), 1)
  assert_eq(doc.query(".intro.missing").length(), 0)
  assert_eq(doc.query("#first").length(), 1)
  assert_eq(doc.query("p#first").length(), 1)
  assert_eq(doc.query("div#first").length(), 0)
  assert_eq(doc.query("p.intro.first").length(), 1)
  assert_eq(doc.query("div.intro").length(), 0)
  assert_eq(doc.query("*").length(), 3)
  assert_eq(doc.query("*.intro").length(), 1)
  assert_eq(doc.query("*foo").length(), 0)
  let first = doc.query_one("p.lead")
  guard first is Some(node) else { fail("expected p.lead") }
  assert_eq(node.to_text(separator="", strip=false), "One")
  assert_true(@html_parser.matches(node, "*"))
  assert_eq(@html_parser.matches(node, "*foo"), false)
  assert_true(@html_parser.matches(node, "p#first.lead"))
  assert_eq(doc.query("p#first.lead").length(), 1)
  let spaced = @html_parser.fragment(children=[
    @html_parser.element("p", attrs={
      "class": Some("alpha\tbeta\ngamma\u{000C}delta\repsilon"),
    }),
  ])
  assert_eq(spaced.query(".beta").length(), 1)
  assert_eq(spaced.query("p.gamma").length(), 1)
  assert_eq(spaced.query(".delta").length(), 1)
  assert_eq(spaced.query(".epsilon").length(), 1)
  assert_eq(spaced.query(".alpha.epsilon").length(), 1)
  assert_eq(spaced.query("p.beta.delta").length(), 1)
  assert_eq(spaced.query(".ta").length(), 0)
  let leading_space = @html_parser.fragment(children=[
    @html_parser.element("p", attrs={ "class": Some(" alpha") }),
  ])
  assert_eq(leading_space.query(".alpha").length(), 1)
  let compound = @html_parser.parse_fragment(
    "<div id='main' class='container featured'><p>Text</p></div>",
  )
  assert_eq(compound.query("div#main").length(), 1)
  assert_eq(compound.query("span#main").length(), 0)
  assert_eq(compound.query("*.container").length(), 1)
  assert_eq(compound.query("div.container#main").length(), 1)
  assert_eq(compound.query("#main.container.featured").length(), 1)
  assert_eq(compound.query("div#main.missing").length(), 0)
  assert_eq(@html_parser.query(compound.root, "p").length(), 1)
  let identifiers = @html_parser.fragment(children=[
    @html_parser.element("1box", attrs={
      "id": Some("1id"),
      "class": Some("1lead ok _under -dash 日本語"),
    }),
    @html_parser.element("-box", attrs={ "id": Some("_id") }),
    @html_parser.element("日本語"),
  ])
  assert_eq(identifiers.query("1box").length(), 0)
  assert_eq(identifiers.query("#1id").length(), 0)
  assert_eq(identifiers.query(".1lead").length(), 0)
  assert_eq(identifiers.query(".ok").length(), 1)
  assert_eq(identifiers.query("._under").length(), 1)
  assert_eq(identifiers.query(".-dash").length(), 1)
  assert_eq(identifiers.query(".日本語").length(), 1)
  assert_eq(identifiers.query("-box").length(), 1)
  assert_eq(identifiers.query("#_id").length(), 1)
  assert_eq(identifiers.query("日本語").length(), 1)
  let css_identifiers = @html_parser.parse_fragment(
    "<my-element id='my-id' class='my-class class1 über'>Test</my-element>",
  )
  assert_eq(css_identifiers.query("my-element").length(), 1)
  assert_eq(css_identifiers.query("#my-id").length(), 1)
  assert_eq(css_identifiers.query(".my-class").length(), 1)
  assert_eq(css_identifiers.query(".class1").length(), 1)
  assert_eq(css_identifiers.query(".über").length(), 1)
}

///|
test "public selector query corpus keeps combinators and pseudos stable" {
  let doc = selector_public_doc()
  assert_eq(
    selector_public_ids(
      doc.query(
        "article.card[data-kind=new] > p.lead:contains(Needle), aside > p.lead",
      ),
    ),
    "p1,sidep",
  )
  assert_eq(
    selector_public_ids(doc.query("main#root article.card + article.card")),
    "b",
  )
  assert_eq(selector_public_ids(doc.query("article.card ~ aside")), "side")
  assert_eq(
    selector_public_ids(doc.query("article:nth-of-type(2) p:nth-child(2)")),
    "p2",
  )
  assert_eq(selector_public_ids(doc.query("span:empty")), "empty")
}

///|
test "public selector query corpus keeps attributes and lists stable" {
  let doc = selector_public_doc()
  assert_eq(
    selector_public_ids(doc.query("a[href^='/'][data-role~=cta], :comment")),
    "link,#comment",
  )
  assert_eq(
    selector_public_ids(doc.query("p[data-tags|=one], p[data-tags~=two]")),
    "p1,p2",
  )
  assert_eq(selector_public_ids(doc.query("article.card, article.card")), "a,b")
  assert_eq(doc.query("article:unknown, [").length(), 0)
}

///|
test "public selector query_one and matches stay stable" {
  let doc = selector_public_doc()
  guard doc.query_one("article.card[data-kind=old]") is Some(old_article) else {
    fail("expected old article")
  }
  assert_eq(selector_public_id_or_name(old_article), "b")
  guard doc.query_one("p.lead") is Some(first_lead) else {
    fail("expected first lead paragraph")
  }
  assert_eq(selector_public_id_or_name(first_lead), "p1")
  assert_eq(first_lead.to_text(separator="", strip=true), "NeedleGo")
  guard doc.query_one("#link") is Some(link) else { fail("expected link") }
  assert_true(@html_parser.matches(link, "article.card p.lead > a[href$='x']"))
  assert_eq(@html_parser.matches(link, "aside a"), false)
  assert_eq(@html_parser.matches(link, "["), false)
}
