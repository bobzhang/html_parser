// Basic `find_links` / `find_links_with_config` shapes (scheme URL,
// fuzzy domain, email, `extra_tlds`, `fuzzy_ip`) are snapshotted in
// `linkify/find_links_test.mbt`. Cases below cover specific upstream
// regressions and validation edges that those snapshots do not.

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
test "linkify matches upstream internal validation regressions" {
  assert_eq(@html_parser.find_links("").length(), 0)
  let no_links : Array[String] = [
    "hppt://example.com", "//[::1]", "//a_b.com", "a@b_c.com", "a@b.example", "http://example.com:99999",
    "http://exa_mple.com", "http://999.999.999.999", "abc://example.com", "nodot",
    "a@nodot",
  ]
  for text in no_links {
    guard @html_parser.find_links(text).length() == 0 else {
      fail("expected no link for " + text)
    }
  }
  let custom = @html_parser.find_links_with_config(
    "a@b.example",
    @html_parser.LinkifyConfig::with_extra_tlds(["EXAMPLE"]),
  )
  assert_eq(custom.length(), 1)
  assert_eq(custom[0].href, "mailto:a@b.example")
  let proto_with_userinfo = @html_parser.find_links("See //user@a.com:8080/x")
  assert_eq(proto_with_userinfo.length(), 1)
  assert_eq(proto_with_userinfo[0].href, "//user@a.com:8080/x")
  let quoted = @html_parser.find_links("'example.com")
  assert_eq(quoted.length(), 1)
  assert_eq(quoted[0].text, "example.com")
}

///|
test "linkify rejects malformed host email and port edges" {
  let no_links : Array[String] = [
    "mailto:@example.com", "mailto:user@", "bad exa_mple.com", "http://example.com:abc",
    "user@.com", "//:8080/path",
  ]
  for text in no_links {
    guard @html_parser.find_links(text).length() == 0 else {
      fail("expected no malformed edge link for " + text)
    }
  }

  let punycode_tld = @html_parser.find_links("see site.xn--p1ai")
  assert_eq(punycode_tld.length(), 1)
  assert_eq(punycode_tld[0].text, "site.xn--p1ai")
  assert_eq(punycode_tld[0].href, "http://site.xn--p1ai")
}

///|
test "linkify handles long punctuation runs without widening matches" {
  for ch in ["\"", "-", ".", "!"] {
    assert_eq(@html_parser.find_links(ch.repeat(2000)).length(), 0)
  }
  for ch in [")", "]", "}", ">"] {
    let matches = @html_parser.find_links(
      "http://example.com/" + ch.repeat(2000),
    )
    assert_eq(matches.length(), 1)
    assert_eq(matches[0].text, "http://example.com/")
  }
}

///|
test "linkify handles unicode tlds as utf16 offsets" {
  let matches = @html_parser.find_links("См пример.рф!")
  assert_eq(matches.length(), 1)
  assert_eq(matches[0].text, "пример.рф")
  assert_eq(matches[0].href, "http://xn--e1afmkfd.xn--p1ai")
  assert_eq(matches[0].kind, "url")
  let after_emoji = @html_parser.find_links("😀http://example.com")
  assert_eq(after_emoji.length(), 1)
  assert_eq(after_emoji[0].start, 2)
  assert_eq(after_emoji[0].end, 20)
  assert_eq(after_emoji[0].text, "http://example.com")
}

///|
test "linkify punycodes unicode URL hosts in hrefs" {
  let mailto = @html_parser.find_links("mailto:foo@bar")
  assert_eq(mailto.length(), 1)
  assert_eq(mailto[0].href, "mailto:foo@bar")
  assert_eq(mailto[0].kind, "email")
  let ipv6 = @html_parser.find_links("http://[::1]/")
  assert_eq(ipv6.length(), 1)
  assert_eq(ipv6[0].href, "http://[::1]/")
  let german = @html_parser.find_links(
    "Visit http://www.bürgerentscheid-krankenhäuser.de now",
  )
  assert_eq(german.length(), 1)
  assert_eq(
    german[0].href,
    "http://www.xn--brgerentscheid-krankenhuser-xkc78d.de",
  )
  let path = @html_parser.find_links(
    "http://bündnis-für-krankenhäuser.de/wp-content/uploads/2011/11/cropped-logohp.jpg",
  )
  assert_eq(path.length(), 1)
  assert_eq(
    path[0].href,
    "http://xn--bndnis-fr-krankenhuser-i5b27cha.de/wp-content/uploads/2011/11/cropped-logohp.jpg",
  )
  let symbol = @html_parser.find_links("http://✪df.ws/123")
  assert_eq(symbol.length(), 1)
  assert_eq(symbol[0].href, "http://xn--df-oiy.ws/123")
  let fuzzy = @html_parser.find_links("➡.ws/䨹")
  assert_eq(fuzzy.length(), 1)
  assert_eq(fuzzy[0].href, "http://xn--hgi.ws/䨹")
  let userinfo = @html_parser.find_links(
    "http://user:pass@пример.рф:8080/x",
  )
  assert_eq(userinfo.length(), 1)
  assert_eq(userinfo[0].href, "http://user:pass@xn--e1afmkfd.xn--p1ai:8080/x")
  let proto = @html_parser.find_links("//пример.рф/x")
  assert_eq(proto.length(), 1)
  assert_eq(proto[0].href, "//xn--e1afmkfd.xn--p1ai/x")
  let arabic = @html_parser.find_links(
    "http://ﻡﻮﻘﻋ.ﻭﺯﺍﺭﺓ-ﺍﻼﺘﺻﺍﻼﺗ.ﻢﺻﺭ/",
  )
  assert_eq(arabic.length(), 1)
  assert_eq(
    arabic[0].href,
    "http://xn--4gbrim.xn----ymcbaaajlc6dj7bxne2c.xn--wgbh1c/",
  )
  let sharp_s = @html_parser.find_links("http://Straße.de/")
  assert_eq(sharp_s.length(), 1)
  assert_eq(sharp_s[0].href, "http://strasse.de/")
  let uppercase = @html_parser.find_links("http://BÜRGER.de/")
  assert_eq(uppercase.length(), 1)
  assert_eq(uppercase[0].href, "http://xn--brger-kva.de/")
  let high_codepoint = @html_parser.find_links("http://a𠀀.ws/")
  assert_eq(high_codepoint.length(), 1)
  assert_eq(high_codepoint[0].href, "http://xn--a-t17s.ws/")
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
