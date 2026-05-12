///|
priv struct EncodingFixtureCase {
  line : Int
  input : Bytes
  transport_encoding : String?
  expected_text : String?
  expected_encoding : String
}

///|
fn assert_encoding_fixture(case : EncodingFixtureCase) -> Unit raise {
  let parsed = match case.transport_encoding {
    Some(encoding) => @html_parser.parse_bytes(case.input, encoding~)
    None => @html_parser.parse_bytes(case.input)
  }
  match case.expected_text {
    Some(expected_text) => {
      let actual_text = parsed.to_text(separator="", strip=false)
      if actual_text != expected_text {
        fail(
          "encoding fixture line " +
          case.line.to_string() +
          " decoded different text",
        )
      }
    }
    None => ()
  }
  guard parsed.encoding is Some(actual_encoding) &&
    actual_encoding == case.expected_encoding else {
    fail(
      "encoding fixture line " +
      case.line.to_string() +
      " selected different encoding",
    )
  }
}

///|
test "parse_bytes matches reference encoding fixtures" {
  for case in encoding_fixture_cases() {
    assert_encoding_fixture(case)
  }
}

///|
fn encoding_fixture_cases() -> Array[EncodingFixtureCase] {
  [
    {
      line: 70,
      input: b"<p>\x80</p>",
      transport_encoding: None,
      expected_text: Some("\u{20AC}"),
      expected_encoding: "windows-1252",
    },
    {
      line: 74,
      input: b"<p>abc</p>",
      transport_encoding: Some("iso-8859-2"),
      expected_text: Some("abc"),
      expected_encoding: "iso-8859-2",
    },
    {
      line: 86,
      input: b"\xff\xfeh\x00i\x00",
      transport_encoding: Some("utf-16"),
      expected_text: Some("hi"),
      expected_encoding: "utf-16",
    },
    {
      line: 90,
      input: b"<p>hi</p>",
      transport_encoding: Some("utf-8"),
      expected_text: Some("hi"),
      expected_encoding: "utf-8",
    },
    {
      line: 96,
      input: b"<p>\x80</p>",
      transport_encoding: Some("utf7"),
      expected_text: Some("\u{20AC}"),
      expected_encoding: "windows-1252",
    },
    {
      line: 117,
      input: b"\xff\xfe<\x00p\x00>\x00h\x00i\x00<\x00/\x00p\x00>\x00",
      transport_encoding: None,
      expected_text: Some("hi"),
      expected_encoding: "utf-16le",
    },
    {
      line: 118,
      input: b"\xfe\xff\x00<\x00p\x00>\x00h\x00i\x00<\x00/\x00p\x00>",
      transport_encoding: None,
      expected_text: Some("hi"),
      expected_encoding: "utf-16be",
    },
    {
      line: 120,
      input: b"\xff\xfe<\x00p\x00>\x00h\x00i\x00<\x00/\x00p\x00>\x00",
      transport_encoding: Some("utf-16"),
      expected_text: Some("hi"),
      expected_encoding: "utf-16",
    },
    {
      line: 123,
      input: b"<meta charset=iso8859-2><p>\xa1</p>",
      transport_encoding: Some("utf-8"),
      expected_text: Some("\u{FFFD}"),
      expected_encoding: "utf-8",
    },
    {
      line: 126,
      input: b"<meta charset=utf-8><p>\x80</p>",
      transport_encoding: Some("windows-1252"),
      expected_text: Some("\u{20AC}"),
      expected_encoding: "windows-1252",
    },
    {
      line: 132,
      input: b"<meta charset=utf-8><p>\xe2\x82\xac</p>",
      transport_encoding: Some("bogus"),
      expected_text: Some("\u{20AC}"),
      expected_encoding: "utf-8",
    },
    {
      line: 139,
      input: b"<!--<meta charset=utf-8>--><p>\x80</p>",
      transport_encoding: None,
      expected_text: Some("\u{20AC}"),
      expected_encoding: "windows-1252",
    },
    {
      line: 144,
      input: b"<p title=\"x><meta charset=utf-8>\x80</p>",
      transport_encoding: None,
      expected_text: None,
      expected_encoding: "windows-1252",
    },
    {
      line: 150,
      input: b"<meta charset=\"utf-8><p>\x80</p>",
      transport_encoding: None,
      expected_text: None,
      expected_encoding: "windows-1252",
    },
    {
      line: 158,
      input: b"<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\"><p>\xe2\x82\xac</p>",
      transport_encoding: None,
      expected_text: Some("\u{20AC}"),
      expected_encoding: "utf-8",
    },
    {
      line: 164,
      input: b"<meta http-equiv=\"Content-Type\" content=\"charset   =utf-8\"><p>\xe2\x82\xac</p>",
      transport_encoding: None,
      expected_text: Some("\u{20AC}"),
      expected_encoding: "utf-8",
    },
    {
      line: 171,
      input: b"<meta http-equiv=\"Content-Type\" content=\"text/html; charset=bogus\"><p>\x80</p>",
      transport_encoding: None,
      expected_text: Some("\u{20AC}"),
      expected_encoding: "windows-1252",
    },
  ]
}
