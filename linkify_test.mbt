///|
test "linkify finds scheme urls and trims trailing punctuation" {
  let matches = @html_parser.find_links("See https://example.com/a?b=1.")
  assert_eq(matches.length(), 1)
  let link = matches[0]
  assert_eq(link.start, 4)
  assert_eq(link.end, 29)
  assert_eq(link.text, "https://example.com/a?b=1")
  assert_eq(link.href, "https://example.com/a?b=1")
  assert_eq(link.kind, "url")
}

///|
test "linkify finds fuzzy domains and emails" {
  let domain = @html_parser.find_links("Go to example.com/path now")
  assert_eq(domain.length(), 1)
  assert_eq(domain[0].text, "example.com/path")
  assert_eq(domain[0].href, "http://example.com/path")
  assert_eq(domain[0].kind, "url")
  let email = @html_parser.find_links("Mail test@example.com now")
  assert_eq(email.length(), 1)
  assert_eq(email[0].start, 5)
  assert_eq(email[0].text, "test@example.com")
  assert_eq(email[0].href, "mailto:test@example.com")
  assert_eq(email[0].kind, "email")
}

///|
test "linkify config controls extra tlds and fuzzy ips" {
  assert_eq(@html_parser.find_links("site.internal").length(), 0)
  let custom = @html_parser.find_links_with_config(
    "site.internal",
    @html_parser.LinkifyConfig::with_extra_tlds(["internal"]),
  )
  assert_eq(custom.length(), 1)
  assert_eq(custom[0].href, "http://site.internal")
  assert_eq(@html_parser.find_links("192.168.0.1").length(), 0)
  let ips = @html_parser.find_links_with_config(
    "192.168.0.1",
    @html_parser.LinkifyConfig::new(fuzzy_ip=true),
  )
  assert_eq(ips.length(), 1)
  assert_eq(ips[0].href, "http://192.168.0.1")
}

///|
test "linkify validates protocol relative and invalid fuzzy tlds" {
  let proto = @html_parser.find_links("See //example.com/x")
  assert_eq(proto.length(), 1)
  assert_eq(proto[0].start, 4)
  assert_eq(proto[0].href, "//example.com/x")
  assert_eq(@html_parser.find_links("import app.js").length(), 0)
  assert_eq(@html_parser.find_links("bad hppt://example.com").length(), 0)
  assert_eq(@html_parser.find_links("bad //localhost/x").length(), 1)
  assert_eq(@html_parser.find_links("bad ///example.com").length(), 0)
}

///|
test "linkify handles unicode tlds as utf16 offsets" {
  let matches = @html_parser.find_links("См пример.рф!")
  assert_eq(matches.length(), 1)
  assert_eq(matches[0].text, "пример.рф")
  assert_eq(matches[0].href, "http://пример.рф")
  assert_eq(matches[0].kind, "url")
}

///|
test "linkify matches representative upstream linkify-it link fixtures" {
  let cases : Array[(String, String)] = [
    ("My http://example.com site", "http://example.com"),
    ("My http://example.com/ site", "http://example.com/"),
    ("http://user:pass@example.com:8080", "http://user:pass@example.com:8080"),
    ("http://example.com/?foo=bar", "http://example.com/?foo=bar"),
    ("http://example.invalid", "http://example.invalid"),
    ("http://localhost:8000?", "http://localhost:8000"),
    ("//localhost", "//localhost"),
    ("//test.123", "//test.123"),
    ("HTTP://GOOGLE.COM", "HTTP://GOOGLE.COM"),
    (">>example.com", "example.com"),
    (
      "[https](https://www.ibm.com)[mailto](mailto:someone@ibm.com)", "https://www.ibm.com",
    ),
  ]
  for pair in cases {
    let (text, expected) = pair
    let matches = @html_parser.find_links(text)
    guard matches.length() > 0 else {
      fail("expected link fixture match for " + text)
    }
    assert_eq(matches[0].text, expected)
  }
}

///|
test "linkify matches representative upstream linkify-it not-link fixtures" {
  let cases : Array[String] = [
    "example.invalid", "example.invalid/", "http://.example.com", "http://-example.com",
    "hppt://example.com", "foo.123", "localhost", "///localhost", "///test.com",
    "//test", "_http://example.com", "_//example.com", "_example.com", "http://example.com_",
    "@example.com", "node.js and io.js", "http://", "http://.", "http://..", "google.com:500000 // invalid port",
    "show image.jpg", "path:to:file.pm", "/path/to/file.pl", "1.2.3.4.5", "1.2.3",
    "1.2.3.400", "1000.2.3.4", "a1.2.3.4", "1.2.3.4a", "foo@bar", "mailto:bar",
  ]
  for text in cases {
    guard @html_parser.find_links(text).length() == 0 else {
      fail("expected no link for " + text)
    }
  }
}
