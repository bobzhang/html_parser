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
test "query supports attribute presence and exact selectors" {
  let doc = @html_parser.parse_fragment(
    "<div id='main' data-id='123'><a href='http://example.com' data-id='link'>Link</a><button disabled>Push</button></div>",
  )
  assert_eq(doc.query("[href]").length(), 1)
  assert_eq(doc.query("a[href]").length(), 1)
  assert_eq(doc.query("[id]").length(), 1)
  assert_eq(doc.query("[data-id]").length(), 2)
  assert_eq(doc.query("[id=\"main\"]").length(), 1)
  assert_eq(doc.query("[id='main']").length(), 1)
  assert_eq(doc.query("[id=main]").length(), 1)
  assert_eq(doc.query("[ id = 'main' ]").length(), 1)
  assert_eq(doc.query("[id=wrong]").length(), 0)
  assert_eq(doc.query("[]").length(), 0)
  assert_eq(doc.query("[=main]").length(), 0)
  assert_eq(doc.query("a[href][data-id='link']").length(), 1)
  assert_eq(doc.query("button[disabled='']").length(), 1)
  let upper = @html_parser.fragment(children=[
    @html_parser.element("a", attrs={ "DATA-ID": Some("42") }),
  ])
  assert_eq(upper.query("[data-id='42']").length(), 1)
}

///|
test "query supports attribute operator selectors" {
  let doc = @html_parser.parse_fragment(
    "<div class='container secondary' lang='en-US' data-tags='alpha\tbeta' data-name='example item' data-quote='hello&quot;world' data-slash='a\\b' data-escape='x'><a href='http://example.com'>Link</a><p data-empty=''></p></div>",
  )
  assert_eq(doc.query("[class~='container']").length(), 1)
  assert_eq(doc.query("[class~='contain']").length(), 0)
  assert_eq(doc.query("[class~='']").length(), 0)
  assert_eq(doc.query("[data-tags~=beta]").length(), 1)
  assert_eq(doc.query("[lang|=en]").length(), 1)
  assert_eq(doc.query("[lang|=eng]").length(), 0)
  assert_eq(doc.query("[href^='http']").length(), 1)
  assert_eq(doc.query("[href^='https']").length(), 0)
  assert_eq(doc.query("[href$='.com']").length(), 1)
  assert_eq(doc.query("[href$='.org']").length(), 0)
  assert_eq(doc.query("[href*='example']").length(), 1)
  assert_eq(doc.query("[href *= 'example']").length(), 1)
  assert_eq(doc.query("[href*='google']").length(), 0)
  assert_eq(doc.query("[data-name='example item']").length(), 1)
  assert_eq(doc.query("[data-name=example item]").length(), 0)
  assert_eq(doc.query("[href^='']").length(), 0)
  assert_eq(doc.query("[href$='']").length(), 0)
  assert_eq(doc.query("[href*='']").length(), 0)
  assert_eq(doc.query("[data-quote=\"hello\\\"world\"]").length(), 1)
  assert_eq(doc.query("[data-slash=\"a\\\\b\"]").length(), 1)
  assert_eq(doc.query("[data-escape=\"\\x\"]").length(), 1)
  assert_eq(doc.query("[data-quote=\"hello\\\"world\"], p").length(), 2)
  assert_eq(doc.query("div > [data-quote=\"hello\\\"world\"]").length(), 0)
  assert_eq(doc.query("[~=container]").length(), 0)
  assert_eq(doc.query("[href!=http://example.com]").length(), 0)
  assert_eq(doc.query("[lang|=e]").length(), 0)
  let exact_lang = @html_parser.parse_fragment(
    "<p lang='en'></p><p lang='en-US'></p><p lang='eng'></p>",
  )
  assert_eq(exact_lang.query("[lang|=en]").length(), 2)
  let empty = @html_parser.parse_fragment(
    "<p data-empty=''></p><p data-empty='x'></p>",
  )
  assert_eq(empty.query("[data-empty=]").length(), 1)
  let punctuation = @html_parser.fragment(children=[
    @html_parser.element("p", attrs={
      "data-id": Some("x"),
      "data-id!": Some("x"),
      "1data": Some("x"),
      "xlink:href": Some("url"),
      "日本語": Some("yes"),
    }),
  ])
  assert_eq(punctuation.query("[data-id=x]").length(), 1)
  assert_eq(punctuation.query("[data-id!=x]").length(), 0)
  assert_eq(punctuation.query("[1data=x]").length(), 0)
  assert_eq(punctuation.query("[xlink:href]").length(), 0)
  assert_eq(punctuation.query("[日本語=yes]").length(), 1)
}

///|
test "query supports comma selector lists" {
  let doc = @html_parser.parse_fragment(
    "<section><h1>Title</h1><p class='intro'>One</p><p>Two</p><a href='a,b'>Link</a></section>",
  )
  assert_eq(doc.query("h1, a").length(), 2)
  assert_eq(doc.query("h1, p, a").length(), 4)
  assert_eq(doc.query(".intro, [href]").length(), 2)
  assert_eq(doc.query("p, p").length(), 2)
  assert_eq(doc.query("[href='a,b'], p").length(), 3)
  assert_eq(doc.query("p,").length(), 2)
  assert_eq(doc.query("p,, a").length(), 3)
  assert_eq(doc.query(", p").length(), 0)
  let ordered = doc.query("a, h1")
  assert_eq(ordered.length(), 2)
  assert_eq(ordered[0].name(), "h1")
  assert_eq(ordered[1].name(), "a")
  guard doc.query_one("a, h1") is Some(first) else {
    fail("expected selector list query_one")
  }
  assert_eq(first.name(), "h1")
}

///|
test "query treats malformed selector pieces as no match" {
  let doc = @html_parser.parse_fragment(
    "<section><h1>Title</h1><p id='intro' class='lead'>One</p><a href='x'>Link</a></section>",
  )
  assert_eq(doc.query("").length(), 0)
  assert_eq(doc.query("   ").length(), 0)
  assert_eq(doc.query("div@foo").length(), 0)
  assert_eq(doc.query("p[").length(), 0)
  assert_eq(doc.query("p.").length(), 0)
  assert_eq(doc.query("p#").length(), 0)
  assert_eq(doc.query("p[id]]").length(), 0)
  assert_eq(doc.query("[attr=\"unclosed]").length(), 0)
  assert_eq(doc.query(":contains(foo").length(), 0)
  assert_eq(doc.query("p >").length(), 0)
  assert_eq(doc.query("> p").length(), 0)
  assert_eq(doc.query("section > > p").length(), 0)
  assert_eq(doc.query("section,, p").length(), 2)
  assert_eq(doc.query("p, p[").length(), 0)
  assert_eq(doc.query("p, :hover").length(), 0)
  assert_eq(doc.query("p, > a").length(), 0)
  assert_eq(doc.query("p, .").length(), 0)
  guard doc.query_one("p") is Some(paragraph) else {
    fail("expected paragraph")
  }
  assert_eq(@html_parser.matches(paragraph, "p["), false)
  assert_eq(@html_parser.matches(paragraph, "p."), false)
  assert_eq(@html_parser.matches(paragraph, "> p"), false)
  assert_eq(@html_parser.matches(paragraph, "p, p["), false)
}

///|
test "query supports descendant selectors" {
  let doc = @html_parser.parse_fragment(
    "<div id='main'><p class='intro'>One</p><section><a href='x'>Link</a><span data-name='a b'>Span</span></section></div><aside><p>Two</p></aside>",
  )
  assert_eq(doc.query("div p").length(), 1)
  assert_eq(doc.query("div   p").length(), 1)
  assert_eq(doc.query("#main a").length(), 1)
  assert_eq(doc.query("div [href]").length(), 1)
  assert_eq(doc.query("div [data-name='a b']").length(), 1)
  assert_eq(doc.query("aside a").length(), 0)
  assert_eq(doc.query("#main p, aside p").length(), 2)
  guard doc.query_one("p.intro") is Some(intro) else {
    fail("expected intro paragraph")
  }
  assert_true(@html_parser.matches(intro, "div p"))
  assert_eq(@html_parser.matches(intro, "aside p"), false)
}

///|
test "query supports child selectors" {
  let doc = @html_parser.parse_fragment(
    "<div id='main'><h1>Top</h1><section><h1>Nested</h1><a href='x'>Link</a></section><span data-name='a > b'>Span</span></div>",
  )
  assert_eq(doc.query("div > h1").length(), 1)
  assert_eq(doc.query("div>h1").length(), 1)
  assert_eq(doc.query("#main > section > a").length(), 1)
  assert_eq(doc.query("#main > a").length(), 0)
  assert_eq(doc.query("div > [data-name='a > b']").length(), 1)
  assert_eq(doc.query("div > section a").length(), 1)
  guard doc.query_one("a") is Some(link) else { fail("expected link") }
  assert_true(@html_parser.matches(link, "#main > section > a"))
  assert_eq(@html_parser.matches(link, "#main > a"), false)
}

///|
test "query supports adjacent sibling selectors" {
  let doc = @html_parser.parse_fragment(
    "<div><h1>Heading</h1>\n<p class='first'>First</p><p class='second'>Second</p><span>Other</span><p class='third'>Third</p></div>",
  )
  assert_eq(doc.query("h1 + p").length(), 1)
  assert_eq(doc.query(".first + p").length(), 1)
  assert_eq(doc.query(".first + span").length(), 0)
  assert_eq(doc.query("span + p").length(), 1)
  assert_eq(doc.query("h1+p").length(), 1)
  assert_eq(doc.query("p + h1").length(), 0)
  guard doc.query_one(".second") is Some(second) else {
    fail("expected second paragraph")
  }
  assert_true(@html_parser.matches(second, ".first + p"))
  assert_eq(@html_parser.matches(second, "h1 + p"), false)
}

///|
test "query supports general sibling selectors" {
  let doc = @html_parser.parse_fragment(
    "<div><h1>Heading</h1><p class='first'><span>Inside</span></p><p class='second'>Second</p><span>Other</span><p class='third'>Third</p></div>",
  )
  assert_eq(doc.query("h1 ~ p").length(), 3)
  assert_eq(doc.query(".first ~ p").length(), 2)
  assert_eq(doc.query(".second ~ span").length(), 1)
  assert_eq(doc.query("span ~ h1").length(), 0)
  assert_eq(doc.query("h1~p").length(), 3)
  assert_eq(doc.query("p ~ h1").length(), 0)
  assert_eq(doc.query("h1 ~ p span").length(), 1)
  assert_eq(doc.query("h1 ~ p ~ span").length(), 1)
  assert_eq(doc.query("div > h1 ~ p").length(), 3)
  guard doc.query_one(".third") is Some(third) else {
    fail("expected third paragraph")
  }
  assert_true(@html_parser.matches(third, "h1 ~ p"))
  assert_true(@html_parser.matches(third, ".second ~ p"))
}

///|
test "query supports first and last child pseudo selectors" {
  let doc = @html_parser.parse_fragment(
    "<ul><li class='first'>One</li><li class='middle'>Two</li><li class='last'>Three</li></ul><div><span>Only</span></div>",
  )
  assert_eq(doc.query("li:first-child").length(), 1)
  assert_eq(doc.query("li:last-child").length(), 1)
  assert_eq(doc.query(".middle:first-child").length(), 0)
  assert_eq(doc.query(".middle:last-child").length(), 0)
  assert_eq(doc.query("div > :first-child").length(), 1)
  assert_eq(doc.query("span:first-child").length(), 1)
  assert_eq(doc.query("span:last-child").length(), 1)
  guard doc.query_one("li.first") is Some(first) else {
    fail("expected first list item")
  }
  assert_true(@html_parser.matches(first, "ul > li:first-child"))
  assert_eq(@html_parser.matches(first, "li:last-child"), false)
}

///|
test "query supports only child pseudo selector" {
  let doc = @html_parser.parse_fragment(
    "<div><span>Only</span></div><ul><li>One</li><li>Two</li></ul>",
  )
  assert_eq(doc.query("span:only-child").length(), 1)
  assert_eq(doc.query("li:only-child").length(), 0)
  guard doc.query_one("span") is Some(span) else { fail("expected span") }
  assert_true(@html_parser.matches(span, "div > span:only-child"))
}

///|
test "query supports empty pseudo selector" {
  let doc = @html_parser.parse_fragment(
    "<div class='empty'></div><div class='whitespace'>   </div><div class='text'>content</div><div class='nested'><span></span></div><!-- ignored -->",
  )
  assert_eq(doc.query(".empty:empty").length(), 1)
  assert_eq(doc.query(".whitespace:empty").length(), 1)
  assert_eq(doc.query(".text:empty").length(), 0)
  assert_eq(doc.query(".nested:empty").length(), 0)
}

///|
test "query supports root pseudo selector" {
  let doc = @html_parser.parse("<!doctype html><p>x</p>")
  assert_eq(doc.query(":root").length(), 1)
  assert_eq(doc.query("html:root").length(), 1)
  assert_eq(doc.query("body:root").length(), 0)
  let fragment = @html_parser.parse_fragment("<div>x</div>")
  assert_eq(fragment.query(":root").length(), 1)
  assert_eq(fragment.query("div:root").length(), 1)
}

///|
test "query supports first and last of type pseudo selectors" {
  let doc = @html_parser.parse_fragment(
    "<div><h1>Heading</h1><p class='first'>First</p><p class='second'>Second</p><span>Other</span><p class='third'>Third</p></div>",
  )
  assert_eq(doc.query("p:first-of-type").length(), 1)
  assert_eq(doc.query("p:last-of-type").length(), 1)
  assert_eq(doc.query("h1:first-of-type").length(), 1)
  assert_eq(doc.query("h1:last-of-type").length(), 1)
  assert_eq(doc.query(".second:first-of-type").length(), 0)
  assert_eq(doc.query(".second:last-of-type").length(), 0)
  guard doc.query_one(".first") is Some(first) else {
    fail("expected first paragraph")
  }
  assert_true(@html_parser.matches(first, "p:first-of-type"))
  assert_eq(@html_parser.matches(first, "p:last-of-type"), false)
}

///|
test "query supports only of type pseudo selector" {
  let doc = @html_parser.parse_fragment(
    "<div><h1>Heading</h1><p>First</p><p>Second</p><span>Other</span></div>",
  )
  assert_eq(doc.query("h1:only-of-type").length(), 1)
  assert_eq(doc.query("span:only-of-type").length(), 1)
  assert_eq(doc.query("p:only-of-type").length(), 0)
  guard doc.query_one("h1") is Some(heading) else { fail("expected heading") }
  assert_true(@html_parser.matches(heading, "div > h1:only-of-type"))
}

///|
test "query supports nth child pseudo selector" {
  let doc = @html_parser.parse_fragment(
    "<ul><li>1</li><li class='special'>2</li><li>3</li><li>4</li><li>5</li></ul>",
  )
  assert_eq(doc.query("li:nth-child(2)").length(), 1)
  assert_eq(doc.query("li:nth-child(odd)").length(), 3)
  assert_eq(doc.query("li:nth-child(even)").length(), 2)
  assert_eq(doc.query("li:nth-child(2n+1)").length(), 3)
  assert_eq(doc.query("li:nth-child(2n)").length(), 2)
  assert_eq(doc.query("li:nth-child(n)").length(), 5)
  assert_eq(doc.query("li:nth-child(-n+3)").length(), 3)
  assert_eq(doc.query("li:nth-child(ODD)").length(), 3)
  assert_eq(doc.query("li:nth-child(+n)").length(), 5)
  assert_eq(doc.query("li:nth-child(-2n+5)").length(), 3)
  assert_eq(doc.query("li:nth-child(-2n+4)").length(), 2)
  assert_eq(doc.query("li:nth-child( 2n + 1 )").length(), 3)
  assert_eq(doc.query("li:nth-child(0)").length(), 0)
  assert_eq(doc.query("li:nth-child(-1)").length(), 0)
  assert_eq(doc.query("li:nth-child(100)").length(), 0)
  assert_eq(doc.query("li:nth-child(abc)").length(), 0)
  assert_eq(doc.query("li:nth-child(+)").length(), 0)
  assert_eq(doc.query("li:nth-child(xn+1)").length(), 0)
  assert_eq(doc.query("li:nth-child(2n+)").length(), 0)
  assert_eq(doc.query("li:nth-child(2n+n)").length(), 0)
  assert_eq(doc.query("li:nth-child(2n+x)").length(), 0)
  assert_eq(doc.query("li:nth-child()").length(), 0)
  guard doc.query_one(".special") is Some(special) else {
    fail("expected special list item")
  }
  assert_true(@html_parser.matches(special, "li:nth-child(2)"))
  assert_eq(@html_parser.matches(special, "li:nth-child(odd)"), false)
}

///|
test "query supports nth of type pseudo selector" {
  let doc = @html_parser.parse_fragment(
    "<div><h1>Heading</h1><p class='first'>First</p><p class='second'>Second</p><span>Other</span><p class='third'>Third</p></div>",
  )
  assert_eq(doc.query("p:nth-of-type(2)").length(), 1)
  assert_eq(doc.query("p:nth-of-type(odd)").length(), 2)
  assert_eq(doc.query("p:nth-of-type(even)").length(), 1)
  assert_eq(doc.query("p:nth-of-type(2n+1)").length(), 2)
  assert_eq(doc.query("h1:nth-of-type(1)").length(), 1)
  assert_eq(doc.query("span:nth-of-type(n)").length(), 1)
  guard doc.query_one(".second") is Some(second) else {
    fail("expected second paragraph")
  }
  assert_true(@html_parser.matches(second, "p:nth-of-type(2)"))
  assert_eq(@html_parser.matches(second, "p:nth-of-type(odd)"), false)
}

///|
test "matches handles detached nodes for structural pseudo selectors" {
  let item = @html_parser.element("li")
  assert_eq(@html_parser.matches(item, ":first-child"), false)
  assert_eq(@html_parser.matches(item, ":last-child"), false)
  assert_eq(@html_parser.matches(item, ":first-of-type"), false)
  assert_eq(@html_parser.matches(item, ":last-of-type"), false)
  assert_eq(@html_parser.matches(item, ":nth-child(1)"), false)
  assert_eq(@html_parser.matches(item, ":nth-of-type(1)"), false)
  assert_eq(@html_parser.matches(item, "p + li"), false)
  assert_eq(@html_parser.matches(item, "p ~ li"), false)
  let comment_root = @html_parser.fragment(children=[@html_parser.comment("x")])
  guard comment_root.query_one(":comment") is Some(comment) else {
    fail("expected comment")
  }
  assert_true(@html_parser.matches(comment, ":comment"))
  assert_true(@html_parser.matches(comment, ":empty"))
  assert_eq(@html_parser.matches(comment, ":last-child"), false)
  assert_eq(@html_parser.matches(comment, ":only-child"), false)
  assert_eq(@html_parser.matches(comment, ":last-of-type"), false)
  assert_eq(@html_parser.matches(comment, ":only-of-type"), false)
}

///|
test "query supports not pseudo selector" {
  let doc = @html_parser.parse_fragment(
    "<div id='main'><p class='intro'>One</p><p class='content'>Two</p></div><div id='sidebar'><p>Side</p></div>",
  )
  assert_eq(doc.query("div:not(#sidebar)").length(), 1)
  assert_eq(doc.query("p:not(.intro)").length(), 2)
  assert_eq(doc.query("div > p:not(.content)").length(), 2)
  assert_eq(doc.query("p:not(.intro, .content)").length(), 1)
  assert_eq(doc.query("p:not()").length(), 3)
  guard doc.query_one(".intro") is Some(intro) else {
    fail("expected intro paragraph")
  }
  assert_true(@html_parser.matches(intro, "p:not(.content)"))
  assert_eq(@html_parser.matches(intro, "p:not(.intro)"), false)
}

///|
test "query supports comment pseudo selector" {
  let doc = @html_parser.parse_fragment(
    "<div>Before<!-- first --><span>Inside</span><!-- second --></div><!-- outside -->",
  )
  assert_eq(doc.query(":comment").length(), 3)
  assert_eq(doc.query("div > :comment").length(), 2)
  assert_eq(doc.query("div :comment").length(), 2)
  assert_eq(doc.query("div, :comment").length(), 4)
  assert_eq(doc.query(":comment:empty").length(), 3)
  assert_eq(doc.query(":comment:not(.missing)").length(), 3)
  assert_eq(doc.query(":comment(x)").length(), 3)
  guard doc.query_one(":comment") is Some(comment) else {
    fail("expected comment")
  }
  assert_eq(comment.name(), "#comment")
  assert_true(@html_parser.matches(comment, ":comment"))
  assert_true(@html_parser.matches(comment, ":empty"))
  assert_true(@html_parser.matches(comment, ":not(span)"))
  assert_eq(@html_parser.matches(comment, ":not(:comment)"), false)
  assert_eq(@html_parser.matches(comment, ":hover"), false)
  assert_eq(@html_parser.matches(comment, ":hover(2)"), false)
  assert_eq(@html_parser.matches(comment, ":contains(   )"), false)
  assert_true(@html_parser.matches(comment, "div > :empty"))
  assert_eq(@html_parser.matches(comment, "*"), false)
  let mixed = @html_parser.parse_fragment(
    "<div>A<!-- note --><p>text</p></div>",
  )
  assert_eq(mixed.query(":empty").length(), 0)
  assert_eq(mixed.query("div > :empty").length(), 0)
  assert_eq(mixed.query("div > :comment:empty").length(), 1)
  assert_eq(mixed.query(":comment, :empty").length(), 3)
  assert_eq(mixed.query("[data-note=':comment'], :empty").length(), 0)
  assert_eq(mixed.query(":contains(':comment'), :empty").length(), 0)
  assert_eq(mixed.query(":1comment, :empty").length(), 0)
}

///|
test "query treats pseudo selector names case insensitively" {
  let doc = @html_parser.parse_fragment(
    "<ul><li>One</li><li class='special'>Two</li><li>Three</li></ul><button>Click</button><button>click</button><!-- note -->",
  )
  assert_eq(doc.query("li:FIRST-CHILD").length(), 1)
  assert_eq(doc.query("li:LAST-CHILD").length(), 1)
  assert_eq(doc.query("li:Nth-Child(2)").length(), 1)
  assert_eq(doc.query("li:nth-OF-type(2)").length(), 1)
  assert_eq(doc.query("li:NOT(.special)").length(), 2)
  assert_eq(doc.query("li:HOVER(2)").length(), 0)
  assert_eq(doc.query("button:CONTAINS(\"Click\")").length(), 1)
  assert_eq(doc.query("button:CONTAINS(\"CLICK\")").length(), 0)
  assert_eq(doc.query(":COMMENT").length(), 1)
  guard doc.query_one(":COMMENT") is Some(comment) else {
    fail("expected uppercase comment pseudo selector")
  }
  assert_true(@html_parser.matches(comment, ":COMMENT"))
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
