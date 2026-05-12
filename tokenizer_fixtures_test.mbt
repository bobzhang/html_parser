///|
priv enum TokenizerFixtureToken {
  FStartTag(String, Array[String], Bool)
  FEndTag(String)
  FCharacters(String)
  FComment(String)
  FDoctype(String, String, String, Bool)
} derive(Eq)

///|
priv struct TokenizerFixtureCase {
  line : Int
  input : String
  tokens : Array[TokenizerFixtureToken]
  collect_errors : Bool
  xml_coercion : Bool
  error_codes : Array[String]
}

///|
fn tokenizer_fixture_attr_pairs(attrs : Map[String, String?]) -> Array[String] {
  let pairs : Array[String] = []
  for key, value in attrs {
    let value = value.unwrap_or("")
    pairs.push(key + "=" + value)
  }
  pairs.sort()
  pairs
}

///|
fn tokenizer_fixture_tokens(
  tokens : Array[@html_parser.HtmlToken],
) -> Array[TokenizerFixtureToken] {
  let out : Array[TokenizerFixtureToken] = []
  for token in tokens {
    match token {
      Tag(tag) =>
        if tag.kind is StartTag {
          out.push(
            FStartTag(
              tag.name,
              tokenizer_fixture_attr_pairs(tag.attrs),
              tag.self_closing,
            ),
          )
        } else {
          out.push(FEndTag(tag.name))
        }
      Characters(data) => out.push(FCharacters(data))
      CommentToken(data) => out.push(FComment(data))
      DoctypeToken(data) =>
        out.push(
          FDoctype(
            data.name,
            data.public_id.unwrap_or(""),
            data.system_id.unwrap_or(""),
            data.force_quirks,
          ),
        )
      Eof => ()
    }
  }
  out
}

///|
fn tokenizer_fixture_error_codes(
  errors : Array[@html_parser.ParseError],
) -> Array[String] {
  let codes : Array[String] = []
  for error in errors {
    codes.push(error.code)
  }
  codes
}

///|
fn assert_tokenizer_fixture(case : TokenizerFixtureCase) -> Unit raise {
  let result = @html_parser.tokenize(
    case.input,
    collect_errors=case.collect_errors || case.error_codes.length() > 0,
    xml_coercion=case.xml_coercion,
  )
  let actual_tokens = tokenizer_fixture_tokens(result.tokens)
  if actual_tokens != case.tokens {
    fail(
      "token fixture line " +
      case.line.to_string() +
      " produced different tokens",
    )
  }
  if case.error_codes.length() > 0 {
    let actual_errors = tokenizer_fixture_error_codes(result.errors)
    if actual_errors != case.error_codes {
      fail(
        "token fixture line " +
        case.line.to_string() +
        " produced different error codes",
      )
    }
  }
}

///|
test "tokenizer matches vendored coverage gap fixture tokens" {
  for case in tokenizer_coverage_gap_fixture_cases() {
    assert_tokenizer_fixture(case)
  }
}

///|
test "tokenizer matches vendored entity fixture tokens" {
  for case in tokenizer_entity_fixture_cases() {
    assert_tokenizer_fixture(case)
  }
}

///|
test "tokenizer matches vendored edge-case fixture tokens" {
  for case in tokenizer_edge_case_fixture_cases() {
    assert_tokenizer_fixture(case)
  }
}

///|
test "tokenizer matches vendored XML coercion fixture tokens" {
  for case in tokenizer_xml_coercion_fixture_cases() {
    assert_tokenizer_fixture(case)
  }
}

///|
test "tokenizer fixture tables cover vendored JustHTML rows" {
  assert_eq(tokenizer_coverage_gap_fixture_cases().length(), 9)
  assert_eq(tokenizer_entity_fixture_cases().length(), 8)
  assert_eq(tokenizer_edge_case_fixture_cases().length(), 38)
  assert_eq(tokenizer_xml_coercion_fixture_cases().length(), 2)
}

///|
fn tokenizer_coverage_gap_fixture_cases() -> Array[TokenizerFixtureCase] {
  [
    {
      line: 5,
      input: "<div a\u{0000}b='c'>",
      tokens: [FStartTag("div", ["a\u{FFFD}b=c"], false)],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 10,
      input: "<div a=\"b\u{0000}c\">",
      tokens: [FStartTag("div", ["a=b\u{FFFD}c"], false)],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 15,
      input: "<div a='b\u{0000}c'>",
      tokens: [FStartTag("div", ["a=b\u{FFFD}c"], false)],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 20,
      input: "<div a=>",
      tokens: [FStartTag("div", ["a="], false)],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 25,
      input: "<title >",
      tokens: [FStartTag("title", [], false)],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 30,
      input: "<title id>",
      tokens: [FStartTag("title", ["id="], false)],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 35,
      input: "<title id\\\">",
      tokens: [FStartTag("title", ["id\\\"="], false)],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 40,
      input: "<title id >",
      tokens: [FStartTag("title", ["id="], false)],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 45,
      input: "<title id=>",
      tokens: [FStartTag("title", ["id="], false)],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
  ]
}

///|
fn tokenizer_entity_fixture_cases() -> Array[TokenizerFixtureCase] {
  [
    {
      line: 4,
      input: "&#65",
      tokens: [FCharacters("A")],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 9,
      input: "&#x80",
      tokens: [FCharacters("\u{20AC}")],
      collect_errors: true,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 15,
      input: "&#xFDD0;",
      tokens: [FCharacters("\u{FDD0}")],
      collect_errors: true,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 21,
      input: "&notit;",
      tokens: [FCharacters("\u{00AC}it;")],
      collect_errors: true,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 27,
      input: "&not",
      tokens: [FCharacters("\u{00AC}")],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 32,
      input: "&not",
      tokens: [FCharacters("\u{00AC}")],
      collect_errors: true,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 38,
      input: "&notit",
      tokens: [FCharacters("\u{00AC}it")],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 43,
      input: "&notit",
      tokens: [FCharacters("\u{00AC}it")],
      collect_errors: true,
      xml_coercion: false,
      error_codes: [],
    },
  ]
}

///|
fn tokenizer_edge_case_fixture_cases() -> Array[TokenizerFixtureCase] {
  [
    {
      line: 4,
      input: "\u{FEFF}<div>",
      tokens: [FStartTag("div", [], false)],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 10,
      input: "abc\rdef",
      tokens: [FCharacters("abc\ndef")],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 15,
      input: "\r\n",
      tokens: [FCharacters("\n")],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 20,
      input: "<?foo>",
      tokens: [FComment("?foo")],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 25,
      input: "</>",
      tokens: [],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 31,
      input: "</?",
      tokens: [FComment("?")],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 37,
      input: "a\u{0000}b",
      tokens: [FCharacters("a\u{0000}b")],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 43,
      input: "<",
      tokens: [FCharacters("<")],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 49,
      input: "</",
      tokens: [FCharacters("</")],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 55,
      input: "<script><!---\u{0000}",
      tokens: [FStartTag("script", [], false), FCharacters("<!---\u{FFFD}")],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 61,
      input: "<div\r>",
      tokens: [FStartTag("div", [], false)],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 66,
      input: "<div\r\nattr>",
      tokens: [FStartTag("div", ["attr="], false)],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 72,
      input: "<div attr\r>",
      tokens: [FStartTag("div", ["attr="], false)],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 78,
      input: "<div attr\r >",
      tokens: [FStartTag("div", ["attr="], false)],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 84,
      input: "<div attr\r\n>",
      tokens: [FStartTag("div", ["attr="], false)],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 90,
      input: "<div attr\r\t>",
      tokens: [FStartTag("div", ["attr="], false)],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 96,
      input: "<div attr=\"a\rb\">",
      tokens: [FStartTag("div", ["attr=a\nb"], false)],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 101,
      input: "<div attr='a\rb'>",
      tokens: [FStartTag("div", ["attr=a\nb"], false)],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 106,
      input: "<div attr=abc>",
      tokens: [FStartTag("div", ["attr=abc"], false)],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 111,
      input: "<div /a>",
      tokens: [FStartTag("div", ["a="], false)],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 117,
      input: "<div\n>",
      tokens: [FStartTag("div", [], false)],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 122,
      input: "<div attr\n>",
      tokens: [FStartTag("div", ["attr="], false)],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 128,
      input: "<div attr=\"a\nb\">",
      tokens: [FStartTag("div", ["attr=a\nb"], false)],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 133,
      input: "<div attr='a\nb'>",
      tokens: [FStartTag("div", ["attr=a\nb"], false)],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 138,
      input: "<div \r\n attr>",
      tokens: [FStartTag("div", ["attr="], false)],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 144,
      input: "<div a<b>",
      tokens: [FStartTag("div", ["a<b="], false)],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 150,
      input: "<!-- test\rcomment -->",
      tokens: [FComment(" test\ncomment ")],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 155,
      input: "<script><!--a--<b</script>",
      tokens: [
        FStartTag("script", [], false),
        FCharacters("<!--a--<<b"),
        FEndTag("script"),
      ],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 160,
      input: "<!----!\r\n",
      tokens: [FComment("--!\n")],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 165,
      input: "<div\r=abc>",
      tokens: [FStartTag("div", ["=abc="], false)],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 171,
      input: "<script\u{0000}>x</script>",
      tokens: [
        FStartTag("script\u{FFFD}", [], false),
        FCharacters("x"),
        FEndTag("script"),
      ],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 177,
      input: "<div foo=\"",
      tokens: [],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 183,
      input: "<div foo='",
      tokens: [],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 189,
      input: "<div foo=\"a\u{0000}b\">",
      tokens: [FStartTag("div", ["foo=a\u{FFFD}b"], false)],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 195,
      input: "<div foo='a\u{0000}b'>",
      tokens: [FStartTag("div", ["foo=a\u{FFFD}b"], false)],
      collect_errors: false,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 201,
      input: "ab\u{FDD0}cd",
      tokens: [FCharacters("ab\u{FDD0}cd")],
      collect_errors: true,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 207,
      input: "a\nb\u{FDD0}c",
      tokens: [FCharacters("a\nb\u{FDD0}c")],
      collect_errors: true,
      xml_coercion: false,
      error_codes: [],
    },
    {
      line: 213,
      input: "<\u{FDD0}",
      tokens: [FCharacters("<\u{FDD0}")],
      collect_errors: true,
      xml_coercion: false,
      error_codes: [],
    },
  ]
}

///|
fn tokenizer_xml_coercion_fixture_cases() -> Array[TokenizerFixtureCase] {
  [
    {
      line: 5,
      input: "\u{000C}",
      tokens: [FCharacters(" ")],
      collect_errors: false,
      xml_coercion: true,
      error_codes: [],
    },
    {
      line: 10,
      input: "\u{FDD0}",
      tokens: [FCharacters("\u{FFFD}")],
      collect_errors: false,
      xml_coercion: true,
      error_codes: [],
    },
  ]
}
