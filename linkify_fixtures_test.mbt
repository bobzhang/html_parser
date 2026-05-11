///|
priv struct LinkifyFixtureCase {
  line : Int
  text : String
  expected : String
}

///|
priv struct LinkifyNoLinkFixtureCase {
  line : Int
  text : String
}

///|
test "linkify matches vendored linkify-it links fixture" {
  let config = @html_parser.LinkifyConfig::new(fuzzy_ip=true)
  let failures : Array[String] = []
  for case in linkify_it_link_cases() {
    let matches = @html_parser.find_links_with_config(case.text, config)
    if matches.length() == 0 {
      failures.push(
        "line " + case.line.to_string() + ": expected match for " + case.text,
      )
    } else if matches[0].text != case.expected {
      failures.push(
        "line " +
        case.line.to_string() +
        ": expected " +
        case.expected +
        ", got " +
        matches[0].text,
      )
    }
  }
  if failures.length() > 0 {
    fail(failures.join("\n"))
  }
}

///|
test "linkify matches vendored linkify-it not-links fixture" {
  let failures : Array[String] = []
  for case in linkify_it_no_link_cases() {
    let matches = @html_parser.find_links(case.text)
    if matches.length() > 0 {
      failures.push(
        "line " +
        case.line.to_string() +
        ": expected no match for " +
        case.text +
        ", got " +
        matches[0].text,
      )
    }
  }
  if failures.length() > 0 {
    fail(failures.join("\n"))
  }
}

///|
fn linkify_it_link_cases() -> Array[LinkifyFixtureCase] {
  [
    {
      line: 4,
      text: "My http://example.com site",
      expected: "http://example.com",
    },
    {
      line: 7,
      text: "My http://example.com/ site",
      expected: "http://example.com/",
    },
    {
      line: 10,
      text: "http://example.com/foo_bar/",
      expected: "http://example.com/foo_bar/",
    },
    {
      line: 12,
      text: "http://user:pass@example.com:8080",
      expected: "http://user:pass@example.com:8080",
    },
    {
      line: 14,
      text: "http://user@example.com",
      expected: "http://user@example.com",
    },
    {
      line: 16,
      text: "http://user@example.com:8080",
      expected: "http://user@example.com:8080",
    },
    {
      line: 18,
      text: "http://user:pass@example.com",
      expected: "http://user:pass@example.com",
    },
    {
      line: 20,
      text: "[https](https://www.ibm.com)[mailto](mailto:someone@ibm.com)",
      expected: "https://www.ibm.com",
    },
    {
      line: 23,
      text: "http://example.com:8080",
      expected: "http://example.com:8080",
    },
    {
      line: 25,
      text: "http://example.com/?foo=bar",
      expected: "http://example.com/?foo=bar",
    },
    {
      line: 27,
      text: "http://example.com?foo=bar",
      expected: "http://example.com?foo=bar",
    },
    {
      line: 29,
      text: "http://example.com/#foo=bar",
      expected: "http://example.com/#foo=bar",
    },
    {
      line: 31,
      text: "http://example.com#foo=bar",
      expected: "http://example.com#foo=bar",
    },
    { line: 33, text: "http://a.in", expected: "http://a.in" },
    { line: 35, text: "HTTP://GOOGLE.COM", expected: "HTTP://GOOGLE.COM" },
    {
      line: 37,
      text: "http://example.invalid",
      expected: "http://example.invalid",
    },
    { line: 40, text: "http://inrgess2", expected: "http://inrgess2" },
    { line: 43, text: "http://999     ", expected: "http://999" },
    { line: 46, text: "http://host-name", expected: "http://host-name" },
    { line: 49, text: ">>example.com", expected: "example.com" },
    { line: 52, text: ">>http://example.com", expected: "http://example.com" },
    {
      line: 55,
      text: "http://lyricstranslate.com/en/someone-you-നിന്നെ-പോലൊരാള്\u{200D}.html",
      expected: "http://lyricstranslate.com/en/someone-you-നിന്നെ-പോലൊരാള്\u{200D}.html",
    },
    { line: 61, text: "//localhost", expected: "//localhost" },
    { line: 63, text: "//test.123", expected: "//test.123" },
    {
      line: 65,
      text: "http://localhost:8000?",
      expected: "http://localhost:8000",
    },
    {
      line: 72,
      text: "My ssl https://example.com site",
      expected: "https://example.com",
    },
    {
      line: 75,
      text: "My ftp://example.com site",
      expected: "ftp://example.com",
    },
    { line: 82, text: "My ssl //example.com site", expected: "//example.com" },
    { line: 88, text: "4.4.4.4", expected: "4.4.4.4" },
    { line: 90, text: "192.168.1.1/abc", expected: "192.168.1.1/abc" },
    { line: 96, text: "test.example@http://vk.com", expected: "http://vk.com" },
    {
      line: 99,
      text: "text:http://example.com/",
      expected: "http://example.com/",
    },
    { line: 102, text: "google.com", expected: "google.com" },
    { line: 104, text: "google.com: // no port", expected: "google.com" },
    { line: 107, text: "s.l.o.w.io", expected: "s.l.o.w.io" },
    { line: 109, text: "a-b.com", expected: "a-b.com" },
    { line: 111, text: "GOOGLE.COM.", expected: "GOOGLE.COM" },
    { line: 114, text: "google.xxx // known tld", expected: "google.xxx" },
    {
      line: 121,
      text: "(Scoped http://example.com/foo_bar)",
      expected: "http://example.com/foo_bar",
    },
    {
      line: 124,
      text: "http://example.com/foo_bar_(wiki)",
      expected: "http://example.com/foo_bar_(wiki)",
    },
    {
      line: 126,
      text: "http://foo.com/blah_blah_[other]",
      expected: "http://foo.com/blah_blah_[other]",
    },
    {
      line: 128,
      text: "http://foo.com/blah_blah_{I'm_king}",
      expected: "http://foo.com/blah_blah_{I'm_king}",
    },
    {
      line: 130,
      text: "http://foo.com/blah_blah_I'm_king",
      expected: "http://foo.com/blah_blah_I'm_king",
    },
    {
      line: 132,
      text: "http://www.kmart.com/bestway-10'-x-30inch-steel-pro-frame-pool/p-004W007538417001P",
      expected: "http://www.kmart.com/bestway-10'-x-30inch-steel-pro-frame-pool/p-004W007538417001P",
    },
    {
      line: 134,
      text: "http://foo.com/blah_blah_\"doublequoted\"",
      expected: "http://foo.com/blah_blah_\"doublequoted\"",
    },
    {
      line: 136,
      text: "http://foo.com/blah_blah_'singlequoted'",
      expected: "http://foo.com/blah_blah_'singlequoted'",
    },
    {
      line: 138,
      text: "(Scoped like http://example.com/foo_bar)",
      expected: "http://example.com/foo_bar",
    },
    {
      line: 141,
      text: "[Scoped like http://example.com/foo_bar]",
      expected: "http://example.com/foo_bar",
    },
    {
      line: 144,
      text: "{Scoped like http://example.com/foo_bar}",
      expected: "http://example.com/foo_bar",
    },
    {
      line: 147,
      text: "\"Quoted like http://example.com/foo_bar\"",
      expected: "http://example.com/foo_bar",
    },
    {
      line: 150,
      text: "'Quoted like http://example.com/foo_bar'",
      expected: "http://example.com/foo_bar",
    },
    {
      line: 153,
      text: "[example.com/foo_bar.jpg)]",
      expected: "example.com/foo_bar.jpg",
    },
    {
      line: 156,
      text: "http://example.com/foo_bar.jpg.",
      expected: "http://example.com/foo_bar.jpg",
    },
    {
      line: 159,
      text: "http://example.com/foo_bar/.",
      expected: "http://example.com/foo_bar/",
    },
    {
      line: 162,
      text: "http://example.com/foo_bar,",
      expected: "http://example.com/foo_bar",
    },
    {
      line: 165,
      text: "http://index-of.es/Android/Professional.Android.2.Application.Development.(Wrox,.2010,.0470565527).pdf",
      expected: "http://index-of.es/Android/Professional.Android.2.Application.Development.(Wrox,.2010,.0470565527).pdf",
    },
    {
      line: 167,
      text: "https://github.com/markdown-it/linkify-it/compare/360b13a733f521a8d4903d3a5e1e46c357e9d3ce...f580766349525150a80a32987bb47c2d592efc33",
      expected: "https://github.com/markdown-it/linkify-it/compare/360b13a733f521a8d4903d3a5e1e46c357e9d3ce...f580766349525150a80a32987bb47c2d592efc33",
    },
    {
      line: 169,
      text: "https://www.google.com/search?sxsrf=ACYBGNTJFmX-GjNJ8fM-2LCkqyNyxGU1Ng%3A1575534146332&ei=Qr7oXf7rE4rRrgSEgrmoAw&q=clover&oq=clover&gs_l=psy-ab.3..0i67j0l9.2986.3947..4187...0.2..0.281.1366.1j0j5......0....1..gws-wiz.......0i71j35i39j0i131.qWp1nz4IJVA&ved=0ahUKEwj-lP6Iip7mAhWKqIsKHQRBDjUQ4dUDCAs&uact=5",
      expected: "https://www.google.com/search?sxsrf=ACYBGNTJFmX-GjNJ8fM-2LCkqyNyxGU1Ng%3A1575534146332&ei=Qr7oXf7rE4rRrgSEgrmoAw&q=clover&oq=clover&gs_l=psy-ab.3..0i67j0l9.2986.3947..4187...0.2..0.281.1366.1j0j5......0....1..gws-wiz.......0i71j35i39j0i131.qWp1nz4IJVA&ved=0ahUKEwj-lP6Iip7mAhWKqIsKHQRBDjUQ4dUDCAs&uact=5",
    },
    {
      line: 171,
      text: "https://ourworldindata.org/grapher/covid-deaths-days-since-per-million?zoomToSelection=true&time=9..&country=FRA+DEU+ITA+ESP+GBR+USA+CAN",
      expected: "https://ourworldindata.org/grapher/covid-deaths-days-since-per-million?zoomToSelection=true&time=9..&country=FRA+DEU+ITA+ESP+GBR+USA+CAN",
    },
    {
      line: 173,
      text: "http://example.com/foo_bar...",
      expected: "http://example.com/foo_bar",
    },
    {
      line: 176,
      text: "http://172.26.142.48/viewerjs/#../0529/slides.pdf",
      expected: "http://172.26.142.48/viewerjs/#../0529/slides.pdf",
    },
    {
      line: 178,
      text: "http://example.com/foo_bar..",
      expected: "http://example.com/foo_bar",
    },
    {
      line: 181,
      text: "http://example.com/foo_bar?p=10.",
      expected: "http://example.com/foo_bar?p=10",
    },
    {
      line: 184,
      text: "https://www.google.ru/maps/@59.9393895,30.3165389,15z?hl=ru",
      expected: "https://www.google.ru/maps/@59.9393895,30.3165389,15z?hl=ru",
    },
    {
      line: 186,
      text: "https://www.google.com/maps/place/New+York,+NY,+USA/@40.702271,-73.9968471,11z/data=!4m2!3m1!1s0x89c24fa5d33f083b:0xc80b8f06e177fe62?hl=en",
      expected: "https://www.google.com/maps/place/New+York,+NY,+USA/@40.702271,-73.9968471,11z/data=!4m2!3m1!1s0x89c24fa5d33f083b:0xc80b8f06e177fe62?hl=en",
    },
    {
      line: 188,
      text: "https://www.google.com/analytics/web/?hl=ru&pli=1#report/visitors-overview/a26895874w20458057p96934174/",
      expected: "https://www.google.com/analytics/web/?hl=ru&pli=1#report/visitors-overview/a26895874w20458057p96934174/",
    },
    {
      line: 190,
      text: "http://business.timesonline.co.uk/article/0,,9065-2473189,00.html",
      expected: "http://business.timesonline.co.uk/article/0,,9065-2473189,00.html",
    },
    {
      line: 192,
      text: "https://google.com/mail/u/0/#label/!!!Today/15c9b8193da01e65",
      expected: "https://google.com/mail/u/0/#label/!!!Today/15c9b8193da01e65",
    },
    {
      line: 194,
      text: "http://example.com/123!",
      expected: "http://example.com/123",
    },
    {
      line: 197,
      text: "http://example.com/123!!!",
      expected: "http://example.com/123",
    },
    {
      line: 200,
      text: "http://example.com/foo--bar",
      expected: "http://example.com/foo--bar",
    },
    {
      line: 202,
      text: "See http://example.com/123; Example link.",
      expected: "http://example.com/123",
    },
    {
      line: 205,
      text: "http://example.com/123;123",
      expected: "http://example.com/123;123",
    },
    {
      line: 208,
      text: "http://www.bloomberg.com/news/articles/2015-06-26/from-deutsche-bank-to-siemens-what-s-troubling-germany-inc-",
      expected: "http://www.bloomberg.com/news/articles/2015-06-26/from-deutsche-bank-to-siemens-what-s-troubling-germany-inc-",
    },
    {
      line: 210,
      text: "http://example.com/foo-with-trailing-dash-dot-.",
      expected: "http://example.com/foo-with-trailing-dash-dot-",
    },
    { line: 213, text: "<http://domain.com>", expected: "http://domain.com" },
    { line: 216, text: "<http://domain.com>.", expected: "http://domain.com" },
    {
      line: 219,
      text: "<http://domain.com/foo>",
      expected: "http://domain.com/foo",
    },
    {
      line: 222,
      text: "<http://domain.com/foo>.",
      expected: "http://domain.com/foo",
    },
    { line: 225, text: "<domain.com>", expected: "domain.com" },
    { line: 228, text: "<domain.com>.", expected: "domain.com" },
    { line: 231, text: "<domain.com/foo>", expected: "domain.com/foo" },
    { line: 234, text: "<user@domain.com>", expected: "user@domain.com" },
    { line: 237, text: "<user@domain.com>.", expected: "user@domain.com" },
    {
      line: 240,
      text: "<mailto:user@domain.com>",
      expected: "mailto:user@domain.com",
    },
    {
      line: 248,
      text: "test.\"foo\".bar@gmail.co.uk!",
      expected: "test.\"foo\".bar@gmail.co.uk",
    },
    { line: 251, text: "\"test@example.com\"", expected: "test@example.com" },
    { line: 254, text: "name@example.com", expected: "name@example.com" },
    { line: 256, text: ">>name@example.com", expected: "name@example.com" },
    {
      line: 259,
      text: "mailto:name@example.com",
      expected: "mailto:name@example.com",
    },
    {
      line: 261,
      text: "MAILTO:NAME@EXAMPLE.COM",
      expected: "MAILTO:NAME@EXAMPLE.COM",
    },
    {
      line: 263,
      text: "mailto:foo_bar@example.com",
      expected: "mailto:foo_bar@example.com",
    },
    { line: 265, text: "foo+bar@gmail.com", expected: "foo+bar@gmail.com" },
    {
      line: 267,
      text: "192.168.1.1@gmail.com",
      expected: "192.168.1.1@gmail.com",
    },
    { line: 269, text: "mailto:foo@bar     ", expected: "mailto:foo@bar" },
    {
      line: 272,
      text: "(foobar email@example.com)",
      expected: "email@example.com",
    },
    {
      line: 275,
      text: "(email@example.com foobar)",
      expected: "email@example.com",
    },
    { line: 278, text: "(email@example.com)", expected: "email@example.com" },
    { line: 285, text: "http://✪df.ws/123", expected: "http://✪df.ws/123" },
    {
      line: 287,
      text: "http://xn--df-oiy.ws/123",
      expected: "http://xn--df-oiy.ws/123",
    },
    { line: 289, text: "a.ws", expected: "a.ws" },
    { line: 291, text: "➡.ws/䨹", expected: "➡.ws/䨹" },
    { line: 293, text: "example.com/䨹", expected: "example.com/䨹" },
    {
      line: 295,
      text: "президент.рф",
      expected: "президент.рф",
    },
    {
      line: 301,
      text: "http://www.bürgerentscheid-krankenhäuser.de",
      expected: "http://www.bürgerentscheid-krankenhäuser.de",
    },
    {
      line: 303,
      text: "http://www.xn--brgerentscheid-krankenhuser-xkc78d.de",
      expected: "http://www.xn--brgerentscheid-krankenhuser-xkc78d.de",
    },
    {
      line: 305,
      text: "http://bündnis-für-krankenhäuser.de/wp-content/uploads/2011/11/cropped-logohp.jpg",
      expected: "http://bündnis-für-krankenhäuser.de/wp-content/uploads/2011/11/cropped-logohp.jpg",
    },
    {
      line: 307,
      text: "http://xn--bndnis-fr-krankenhuser-i5b27cha.de/wp-content/uploads/2011/11/cropped-logohp.jpg",
      expected: "http://xn--bndnis-fr-krankenhuser-i5b27cha.de/wp-content/uploads/2011/11/cropped-logohp.jpg",
    },
    {
      line: 309,
      text: "http://ﻡﻮﻘﻋ.ﻭﺯﺍﺭﺓ-ﺍﻼﺘﺻﺍﻼﺗ.ﻢﺻﺭ/",
      expected: "http://ﻡﻮﻘﻋ.ﻭﺯﺍﺭﺓ-ﺍﻼﺘﺻﺍﻼﺗ.ﻢﺻﺭ/",
    },
    {
      line: 311,
      text: "http://xn--4gbrim.xn----ymcbaaajlc6dj7bxne2c.xn--wgbh1c/",
      expected: "http://xn--4gbrim.xn----ymcbaaajlc6dj7bxne2c.xn--wgbh1c/",
    },
    {
      line: 316,
      text: "｜www.google.com/www.google.com/foo｜bar   ",
      expected: "www.google.com/www.google.com/foo",
    },
    { line: 319, text: "｜test@google.com｜bar", expected: "test@google.com" },
    {
      line: 322,
      text: "｜http://google.com｜bar",
      expected: "http://google.com",
    },
    {
      line: 329,
      text: "https://5b0ee223b312746c1659db3f--thelounge-chat.netlify.com/docs/",
      expected: "https://5b0ee223b312746c1659db3f--thelounge-chat.netlify.com/docs/",
    },
    { line: 331, text: "www.a--b.com", expected: "www.a--b.com" },
    { line: 333, text: "www.c--u.com", expected: "www.c--u.com" },
    { line: 335, text: "http://a---b.com/", expected: "http://a---b.com/" },
  ]
}

///|
fn linkify_it_no_link_cases() -> Array[LinkifyNoLinkFixtureCase] {
  [
    { line: 4, text: "example.invalid" },
    { line: 5, text: "example.invalid/" },
    { line: 6, text: "http://.example.com" },
    { line: 7, text: "http://-example.com" },
    { line: 8, text: "hppt://example.com" },
    { line: 9, text: "example.coma" },
    { line: 10, text: "-example.coma" },
    { line: 11, text: "foo.123" },
    { line: 12, text: "localhost          " },
    { line: 13, text: "localhost/" },
    { line: 14, text: "///localhost       " },
    { line: 15, text: "///test.com" },
    { line: 16, text: "//test             " },
    { line: 18, text: "_http://example.com" },
    { line: 19, text: "_//example.com" },
    { line: 20, text: "_example.com" },
    { line: 21, text: "http://example.com_" },
    { line: 22, text: "@example.com" },
    { line: 24, text: "node.js and io.js" },
    { line: 26, text: "http://" },
    { line: 27, text: "http://." },
    { line: 28, text: "http://.." },
    { line: 29, text: "http://#" },
    { line: 30, text: "http://##" },
    { line: 31, text: "http://?" },
    { line: 32, text: "http://??" },
    { line: 33, text: "google.com:500000 // invalid port" },
    { line: 34, text: "show image.jpg" },
    { line: 35, text: "path:to:file.pm" },
    { line: 36, text: "/path/to/file.pl" },
    { line: 41, text: "1.2.3.4.5" },
    { line: 42, text: "1.2.3" },
    { line: 43, text: "1.2.3.400" },
    { line: 44, text: "1000.2.3.4" },
    { line: 45, text: "a1.2.3.4" },
    { line: 46, text: "1.2.3.4a" },
    { line: 51, text: "foo@bar    " },
    { line: 52, text: "mailto:bar" },
  ]
}
