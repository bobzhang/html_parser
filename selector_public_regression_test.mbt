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
