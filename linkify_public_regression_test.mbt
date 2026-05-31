///|
test "public linkify mixed corpus keeps matches and UTF-16 offsets stable" {
  let matches = @html_parser.find_links(
    "See https://example.com/a?b=1, mail test@example.com, пример.рф, 😀http://example.com.",
  )
  assert_eq(matches.length(), 4)
  assert_eq(matches[0].start, 4)
  assert_eq(matches[0].end, 29)
  assert_eq(matches[0].text, "https://example.com/a?b=1")
  assert_eq(matches[0].href, "https://example.com/a?b=1")
  assert_eq(matches[0].kind, "url")
  assert_eq(matches[1].start, 36)
  assert_eq(matches[1].end, 52)
  assert_eq(matches[1].text, "test@example.com")
  assert_eq(matches[1].href, "mailto:test@example.com")
  assert_eq(matches[1].kind, "email")
  assert_eq(matches[2].start, 54)
  assert_eq(matches[2].end, 63)
  assert_eq(matches[2].text, "пример.рф")
  assert_eq(matches[2].href, "http://xn--e1afmkfd.xn--p1ai")
  assert_eq(matches[2].kind, "url")
  assert_eq(matches[3].start, 67)
  assert_eq(matches[3].end, 85)
  assert_eq(matches[3].text, "http://example.com")
  assert_eq(matches[3].href, "http://example.com")
  assert_eq(matches[3].kind, "url")
}

///|
test "public linkify config corpus keeps fuzzy options stable" {
  let configured = @html_parser.find_links_with_config(
    "site.internal 192.168.0.1 bad.local",
    @html_parser.LinkifyConfig(fuzzy_ip=true, extra_tlds=["internal"]),
  )
  assert_eq(configured.length(), 2)
  assert_eq(configured[0].start, 0)
  assert_eq(configured[0].end, 13)
  assert_eq(configured[0].text, "site.internal")
  assert_eq(configured[0].href, "http://site.internal")
  assert_eq(configured[0].kind, "url")
  assert_eq(configured[1].start, 14)
  assert_eq(configured[1].end, 25)
  assert_eq(configured[1].text, "192.168.0.1")
  assert_eq(configured[1].href, "http://192.168.0.1")
  assert_eq(configured[1].kind, "url")
  assert_eq(@html_parser.find_links("site.internal 192.168.0.1").length(), 0)
}

///|
test "public linkify DOM corpus keeps skip tags and hrefs stable" {
  let doc = @html_parser.parse_fragment(
    "<p>See example.com and test@example.com</p><a href=/x>example.com</a><code>example.com</code><span>site.internal</span>",
  )
  ignore(
    @html_parser.linkify_dom(
      doc.root,
      config=@html_parser.LinkifyConfig::with_extra_tlds(["internal"]),
      skip_tags=["a", "code", "span"],
    ),
  )
  assert_eq(
    doc.to_html(pretty=false),
    "<p>See <a href=\"http://example.com\">example.com</a> and <a href=\"mailto:test@example.com\">test@example.com</a></p><a href=\"/x\">example.com</a><code>example.com</code><span>site.internal</span>",
  )
}
