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
test "tokenizer matches vendored XML coercion fixture tokens" {
  for case in tokenizer_xml_coercion_fixture_cases() {
    assert_tokenizer_fixture(case)
  }
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
