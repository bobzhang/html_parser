///|
priv struct TreeFixtureCase {
  line : Int
  input : String
  xml_coercion : Bool
  expected_tree : String
  error_codes : Array[String]
}

///|
fn tree_fixture_error_codes(
  errors : Array[@html_parser.ParseError],
) -> Array[String] {
  let out : Array[String] = []
  for error in errors {
    out.push(error.code)
  }
  out
}

///|
fn assert_tree_fixture(case : TreeFixtureCase) -> Unit raise {
  let parsed = @html_parser.parse(
    case.input,
    collect_errors=true,
    xml_coercion=case.xml_coercion,
  )
  let actual_tree = @html_parser.to_test_format(parsed.root)
  if actual_tree != case.expected_tree {
    fail(
      "tree fixture line " +
      case.line.to_string() +
      " produced different document tree",
    )
  }
  let actual_error_codes = tree_fixture_error_codes(parsed.errors)
  if actual_error_codes != case.error_codes {
    fail(
      "tree fixture line " +
      case.line.to_string() +
      " produced different parse error codes",
    )
  }
}

///|
test "tree builder matches vendored iframe srcdoc fixture" {
  for case in iframe_srcdoc_tree_fixture_cases() {
    assert_tree_fixture(case)
  }
}

///|
test "tree builder matches vendored XML coercion fixtures" {
  for case in xml_coercion_tree_fixture_cases() {
    assert_tree_fixture(case)
  }
}

///|
fn iframe_srcdoc_tree_fixture_cases() -> Array[TreeFixtureCase] {
  [
    {
      line: 3,
      input: "<!DOCTYPE foo><p><table></table>",
      xml_coercion: false,
      expected_tree: "| <!DOCTYPE foo>\n| <html>\n|   <head>\n|   <body>\n|     <p>\n|     <table>",
      error_codes: ["unknown-doctype"],
    },
  ]
}

///|
fn xml_coercion_tree_fixture_cases() -> Array[TreeFixtureCase] {
  [
    {
      line: 3,
      input: "<!-- normal comment -->",
      xml_coercion: true,
      expected_tree: "| <!--  normal comment  -->\n| <html>\n|   <head>\n|   <body>",
      error_codes: ["expected-doctype-but-got-eof"],
    },
    {
      line: 14,
      input: "<div>normal text</div>",
      xml_coercion: true,
      expected_tree: "| <html>\n|   <head>\n|   <body>\n|     <div>\n|       \"normal text\"",
      error_codes: ["expected-doctype-but-got-start-tag"],
    },
    {
      line: 24,
      input: "<div>über</div>",
      xml_coercion: true,
      expected_tree: "| <html>\n|   <head>\n|   <body>\n|     <div>\n|       \"über\"",
      error_codes: ["expected-doctype-but-got-start-tag"],
    },
    {
      line: 34,
      input: "<div>über\u{000C}</div>",
      xml_coercion: true,
      expected_tree: "| <html>\n|   <head>\n|   <body>\n|     <div>\n|       \"über \"",
      error_codes: ["expected-doctype-but-got-start-tag"],
    },
  ]
}
