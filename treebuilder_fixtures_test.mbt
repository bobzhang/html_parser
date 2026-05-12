///|
priv struct TreeFixtureCase {
  line : Int
  input : String
  scripting_enabled : Bool
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
    scripting_enabled=case.scripting_enabled,
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
test "tree builder matches vendored coverage fixtures" {
  for case in treebuilder_coverage_fixture_cases() {
    assert_tree_fixture(case)
  }
}

///|
fn iframe_srcdoc_tree_fixture_cases() -> Array[TreeFixtureCase] {
  [
    {
      line: 3,
      input: "<!DOCTYPE foo><p><table></table>",
      scripting_enabled: true,
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
      scripting_enabled: true,
      xml_coercion: true,
      expected_tree: "| <!--  normal comment  -->\n| <html>\n|   <head>\n|   <body>",
      error_codes: ["expected-doctype-but-got-eof"],
    },
    {
      line: 14,
      input: "<div>normal text</div>",
      scripting_enabled: true,
      xml_coercion: true,
      expected_tree: "| <html>\n|   <head>\n|   <body>\n|     <div>\n|       \"normal text\"",
      error_codes: ["expected-doctype-but-got-start-tag"],
    },
    {
      line: 24,
      input: "<div>über</div>",
      scripting_enabled: true,
      xml_coercion: true,
      expected_tree: "| <html>\n|   <head>\n|   <body>\n|     <div>\n|       \"über\"",
      error_codes: ["expected-doctype-but-got-start-tag"],
    },
    {
      line: 34,
      input: "<div>über\u{000C}</div>",
      scripting_enabled: true,
      xml_coercion: true,
      expected_tree: "| <html>\n|   <head>\n|   <body>\n|     <div>\n|       \"über \"",
      error_codes: ["expected-doctype-but-got-start-tag"],
    },
  ]
}

///|
fn treebuilder_coverage_fixture_cases() -> Array[TreeFixtureCase] {
  [
    {
      line: 3,
      input: "<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//\" \"http://www.w3.org/TR/html4/loose.dtd\">",
      scripting_enabled: true,
      xml_coercion: false,
      expected_tree: "| <!DOCTYPE html \"-//W3C//DTD HTML 4.01 Transitional//\" \"http://www.w3.org/TR/html4/loose.dtd\">\n| <html>\n|   <head>\n|   <body>",
      error_codes: ["unknown-doctype"],
    },
    {
      line: 14,
      input: "<math><mi>\u{000C}text</mi></math>",
      scripting_enabled: true,
      xml_coercion: false,
      expected_tree: "| <html>\n|   <head>\n|   <body>\n|     <math math>\n|       <math mi>\n|         \" text\"",
      error_codes: ["expected-doctype-but-got-start-tag"],
    },
    {
      line: 27,
      input: "<head></head></template>text",
      scripting_enabled: true,
      xml_coercion: false,
      expected_tree: "| <html>\n|   <head>\n|   <body>\n|     \"text\"",
      error_codes: ["expected-doctype-but-got-start-tag", "unexpected-end-tag"],
    },
    {
      line: 39,
      input: "<dl><dd>x</dd></dl>",
      scripting_enabled: true,
      xml_coercion: false,
      expected_tree: "| <html>\n|   <head>\n|   <body>\n|     <dl>\n|       <dd>\n|         \"x\"",
      error_codes: ["expected-doctype-but-got-start-tag"],
    },
    {
      line: 52,
      input: "<table><caption><!--comment--></caption></table>",
      scripting_enabled: true,
      xml_coercion: false,
      expected_tree: "| <html>\n|   <head>\n|   <body>\n|     <table>\n|       <caption>\n|         <!-- comment -->",
      error_codes: ["expected-doctype-but-got-start-tag"],
    },
    {
      line: 65,
      input: "<select>\u{000C}text</select>",
      scripting_enabled: true,
      xml_coercion: false,
      expected_tree: "| <html>\n|   <head>\n|   <body>\n|     <select>\n|       \" text\"",
      error_codes: ["expected-doctype-but-got-start-tag"],
    },
    {
      line: 77,
      input: "<frameset></frameset></frameset>",
      scripting_enabled: true,
      xml_coercion: false,
      expected_tree: "| <html>\n|   <head>\n|   <frameset>",
      error_codes: [
        "expected-doctype-but-got-start-tag", "unexpected-token-after-frameset",
      ],
    },
    {
      line: 90,
      input: "<table><caption><table></table></caption></table>",
      scripting_enabled: true,
      xml_coercion: false,
      expected_tree: "| <html>\n|   <head>\n|   <body>\n|     <table>\n|       <caption>\n|     <table>",
      error_codes: [
        "expected-doctype-but-got-start-tag", "unexpected-start-tag-implies-end-tag",
        "unexpected-start-tag-implies-end-tag", "unexpected-end-tag", "unexpected-end-tag",
      ],
    },
    {
      line: 108,
      input: "<table>\u{0000}</table>",
      scripting_enabled: true,
      xml_coercion: false,
      expected_tree: "| <html>\n|   <head>\n|   <body>\n|     <table>",
      error_codes: [
        "expected-doctype-but-got-start-tag", "unexpected-null-character",
      ],
    },
    {
      line: 120,
      input: "<table>text</table>",
      scripting_enabled: true,
      xml_coercion: false,
      expected_tree: "| <html>\n|   <head>\n|   <body>\n|     \"text\"\n|     <table>",
      error_codes: [
        "expected-doctype-but-got-start-tag", "foster-parenting-character", "foster-parenting-character",
        "foster-parenting-character", "foster-parenting-character",
      ],
    },
    {
      line: 133,
      input: "<table><td><!-- comment in cell --></td></table>",
      scripting_enabled: true,
      xml_coercion: false,
      expected_tree: "| <html>\n|   <head>\n|   <body>\n|     <table>\n|       <tbody>\n|         <tr>\n|           <td>\n|             <!--  comment in cell  -->",
      error_codes: [
        "expected-doctype-but-got-start-tag", "unexpected-cell-in-table-body",
      ],
    },
    {
      line: 149,
      input: "<head></head>\u{0000}",
      scripting_enabled: true,
      xml_coercion: false,
      expected_tree: "| <html>\n|   <head>\n|   <body>",
      error_codes: [
        "expected-doctype-but-got-start-tag", "unexpected-null-character",
      ],
    },
    {
      line: 161,
      input: "<table>\u{000C}</table>",
      scripting_enabled: true,
      xml_coercion: false,
      expected_tree: "| <html>\n|   <head>\n|   <body>\n|     <table>\n|       \" \"",
      error_codes: ["expected-doctype-but-got-start-tag"],
    },
    {
      line: 174,
      input: "<select></regularitem>",
      scripting_enabled: true,
      xml_coercion: false,
      expected_tree: "| <html>\n|   <head>\n|   <body>\n|     <select>",
      error_codes: [
        "expected-doctype-but-got-start-tag", "unexpected-end-tag", "expected-closing-tag-but-got-eof",
      ],
    },
    {
      line: 187,
      input: "<div><select></div>text",
      scripting_enabled: true,
      xml_coercion: false,
      expected_tree: "| <html>\n|   <head>\n|   <body>\n|     <div>\n|       <select>\n|         \"text\"",
      error_codes: [
        "expected-doctype-but-got-start-tag", "unexpected-end-tag-in-select", "expected-closing-tag-but-got-eof",
      ],
    },
    {
      line: 201,
      input: "<figure><frameset><h1><aside><figcaption><html><frameset>",
      scripting_enabled: true,
      xml_coercion: false,
      expected_tree: "| <html>\n|   <head>\n|   <frameset>",
      error_codes: [
        "expected-doctype-but-got-start-tag", "unexpected-token-in-frameset", "unexpected-token-in-frameset",
        "unexpected-token-in-frameset", "unexpected-start-tag", "unexpected-start-tag-ignored",
        "expected-closing-tag-but-got-eof",
      ],
    },
    {
      line: 216,
      input: "<head><noscript><!DOCTYPE html></noscript>",
      scripting_enabled: false,
      xml_coercion: false,
      expected_tree: "| <html>\n|   <head>\n|     <noscript>\n|   <body>",
      error_codes: ["expected-doctype-but-got-start-tag", "unexpected-doctype"],
    },
    {
      line: 229,
      input: "<head><noscript></p></noscript>",
      scripting_enabled: false,
      xml_coercion: false,
      expected_tree: "| <html>\n|   <head>\n|     <noscript>\n|   <body>",
      error_codes: ["expected-doctype-but-got-start-tag", "unexpected-end-tag"],
    },
  ]
}
