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
test "tree builder matches vendored branch coverage fixtures" {
  for case in branch_coverage_fixture_cases() {
    assert_tree_fixture(case)
  }
}

///|
test "tree builder matches Python reference annotation-xml breakout branch fixtures" {
  let plain_encoding = @html_parser.parse(
    "<math><annotation-xml encoding=\"text/plain\"><div></div></annotation-xml></math>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(plain_encoding.root),
    "| <html>\n|   <head>\n|   <body>\n|     <math math>\n|       <math annotation-xml>\n|         encoding=\"text/plain\"\n|     <div>",
  )
  assert_eq(plain_encoding.errors.length(), 4)
  assert_eq(plain_encoding.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(
    plain_encoding.errors[1].code,
    "unexpected-html-element-in-foreign-content",
  )
  assert_eq(plain_encoding.errors[2].code, "unexpected-end-tag")
  assert_eq(plain_encoding.errors[3].code, "unexpected-end-tag")
  guard plain_encoding.errors[1].column is Some(49) else {
    fail("expected text/plain annotation-xml breakout at div start close")
  }
  let missing_encoding = @html_parser.parse(
    "<math><annotation-xml><div></div></annotation-xml></math>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(missing_encoding.root),
    "| <html>\n|   <head>\n|   <body>\n|     <math math>\n|       <math annotation-xml>\n|     <div>",
  )
  assert_eq(missing_encoding.errors.length(), 4)
  assert_eq(
    missing_encoding.errors[0].code,
    "expected-doctype-but-got-start-tag",
  )
  assert_eq(
    missing_encoding.errors[1].code,
    "unexpected-html-element-in-foreign-content",
  )
  assert_eq(missing_encoding.errors[2].code, "unexpected-end-tag")
  assert_eq(missing_encoding.errors[3].code, "unexpected-end-tag")
  guard missing_encoding.errors[1].column is Some(27) else {
    fail("expected missing-encoding annotation-xml breakout at div start close")
  }
}

///|
test "tree builder matches Python reference SVG font breakout branch fixture" {
  let doc = @html_parser.parse(
    "<svg><font color=\"red\">text</font></svg>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(doc.root),
    "| <html>\n|   <head>\n|   <body>\n|     <svg svg>\n|     <font>\n|       color=\"red\"\n|       \"text\"",
  )
  assert_eq(doc.errors.length(), 3)
  assert_eq(doc.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(doc.errors[1].code, "unexpected-html-element-in-foreign-content")
  assert_eq(doc.errors[2].code, "unexpected-end-tag")
  guard doc.errors[1].column is Some(23) else {
    fail("expected SVG font breakout error at font start close")
  }
  guard doc.errors[2].column is Some(40) else {
    fail("expected SVG end-tag recovery at svg end close")
  }
}

///|
test "tree builder matches Python reference foreign integration branch fixtures" {
  let svg = @html_parser.parse(
    "<svg><g><rect></rect><circle></circle><path></path></g></svg><div></div>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(svg.root),
    "| <html>\n|   <head>\n|   <body>\n|     <svg svg>\n|       <svg g>\n|         <svg rect>\n|         <svg circle>\n|         <svg path>\n|     <div>",
  )
  assert_eq(svg.errors.length(), 1)
  assert_eq(svg.errors[0].code, "expected-doctype-but-got-start-tag")
  guard svg.errors[0].column is Some(5) else {
    fail("expected SVG doctype error at svg start close")
  }
  let math = @html_parser.parse(
    "<math><annotation-xml encoding=\"text/html\"><div><table><tr></tr></table></div></annotation-xml></math>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(math.root),
    "| <html>\n|   <head>\n|   <body>\n|     <math math>\n|       <math annotation-xml>\n|         encoding=\"text/html\"\n|         <div>\n|           <table>\n|             <tbody>\n|               <tr>",
  )
  assert_eq(math.errors.length(), 1)
  assert_eq(math.errors[0].code, "expected-doctype-but-got-start-tag")
  guard math.errors[0].column is Some(6) else {
    fail("expected MathML doctype error at math start close")
  }
}

///|
test "tree builder matches Python reference nested foreign breakout branch fixtures" {
  let math = @html_parser.parse(
    "<math><annotation-xml foo=\"bar\"><div>test</div></annotation-xml></math>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(math.root),
    "| <html>\n|   <head>\n|   <body>\n|     <math math>\n|       <math annotation-xml>\n|         foo=\"bar\"\n|     <div>\n|       \"test\"",
  )
  assert_eq(math.errors.length(), 4)
  assert_eq(math.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(math.errors[1].code, "unexpected-html-element-in-foreign-content")
  assert_eq(math.errors[2].code, "unexpected-end-tag")
  assert_eq(math.errors[3].code, "unexpected-end-tag")
  guard math.errors[1].column is Some(37) else {
    fail("expected MathML annotation breakout at div start close")
  }
  guard math.errors[2].column is Some(64) else {
    fail("expected annotation-xml end recovery at close bracket")
  }
  guard math.errors[3].column is Some(71) else {
    fail("expected math end recovery at close bracket")
  }
  let svg = @html_parser.parse(
    "<svg><g><rect><circle><path><div>text</div></path></circle></rect></g></svg>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(svg.root),
    "| <html>\n|   <head>\n|   <body>\n|     <svg svg>\n|       <svg g>\n|         <svg rect>\n|           <svg circle>\n|             <svg path>\n|     <div>\n|       \"text\"",
  )
  assert_eq(svg.errors.length(), 7)
  assert_eq(svg.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(svg.errors[1].code, "unexpected-html-element-in-foreign-content")
  for index in 2..<svg.errors.length() {
    assert_eq(svg.errors[index].code, "unexpected-end-tag")
  }
  guard svg.errors[1].column is Some(33) else {
    fail("expected nested SVG breakout at div start close")
  }
  guard svg.errors[6].column is Some(76) else {
    fail("expected final SVG end recovery at close bracket")
  }
}

///|
test "tree builder matches Python reference body hidden input fixture" {
  let doc = @html_parser.parse(
    "<body><input type=\"hidden\">",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(doc.root),
    "| <html>\n|   <head>\n|   <body>\n|     <input>\n|       type=\"hidden\"",
  )
  assert_eq(doc.errors.length(), 1)
  assert_eq(doc.errors[0].code, "expected-doctype-but-got-start-tag")
  guard doc.errors[0].column is Some(6) else {
    fail("expected body doctype error at body start close")
  }
}

///|
test "tree builder matches vendored empty stack edge fixtures" {
  for case in empty_stack_edge_fixture_cases() {
    assert_tree_fixture(case)
  }
}

///|
test "tree fixture tables cover vendored JustHTML dat rows" {
  assert_eq(iframe_srcdoc_tree_fixture_cases().length(), 1)
  assert_eq(xml_coercion_tree_fixture_cases().length(), 4)
  assert_eq(treebuilder_coverage_fixture_cases().length(), 18)
  assert_eq(branch_coverage_fixture_cases().length(), 17)
  assert_eq(empty_stack_edge_fixture_cases().length(), 3)
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
fn empty_stack_edge_fixture_cases() -> Array[TreeFixtureCase] {
  [
    {
      line: 3,
      input: "<!><svg><th><title><n><select><td>",
      scripting_enabled: true,
      xml_coercion: false,
      expected_tree: "| <!--  -->\n| <html>\n|   <head>\n|   <body>\n|     <svg svg>\n|       <svg th>\n|         <svg title>\n|           <n>\n|             <select>\n|   <td>",
      error_codes: [
        "incorrectly-opened-comment", "expected-doctype-but-got-start-tag", "unexpected-start-tag-in-select",
      ],
    },
    {
      line: 19,
      input: "<svg><slot><select/e><title/a><select><select></slot></select>",
      scripting_enabled: true,
      xml_coercion: false,
      expected_tree: "| <html>\n|   <head>\n|   <body>\n|     <svg svg>\n|       <svg slot>\n|         <svg select>\n|           e=\"\"\n|           <svg title>\n|             a=\"\"\n|             <select>",
      error_codes: [
        "expected-doctype-but-got-start-tag", "unexpected-character-after-solidus-in-tag",
        "unexpected-character-after-solidus-in-tag", "unexpected-select-in-select",
        "unexpected-end-tag", "unexpected-end-tag",
      ],
    },
    {
      line: 38,
      input: "<svg><tr><title><section\n><math><p><tr>>",
      scripting_enabled: true,
      xml_coercion: false,
      expected_tree: "| <html>\n|   <head>\n|   <body>\n|     <svg svg>\n|       <svg tr>\n|         <svg title>\n|           <section>\n|             <math math>\n|             <p>\n|   <tr>\n|     \">\"",
      error_codes: [
        "expected-doctype-but-got-start-tag", "unexpected-html-element-in-foreign-content",
        "unexpected-character-implies-table-voodoo",
      ],
    },
  ]
}

///|
fn branch_coverage_fixture_cases() -> Array[TreeFixtureCase] {
  [
    {
      line: 3,
      input: "<math><mi>\u{0000}</mi></math>",
      scripting_enabled: true,
      xml_coercion: false,
      expected_tree: "| <html>\n|   <head>\n|   <body>\n|     <math math>\n|       <math mi>",
      error_codes: [
        "expected-doctype-but-got-start-tag", "unexpected-null-character",
      ],
    },
    {
      line: 15,
      input: "<math><mi>\u{0000}\u{000C}</mi></math>",
      scripting_enabled: true,
      xml_coercion: false,
      expected_tree: "| <html>\n|   <head>\n|   <body>\n|     <math math>\n|       <math mi>\n|         \" \"",
      error_codes: [
        "expected-doctype-but-got-start-tag", "unexpected-null-character",
      ],
    },
    {
      line: 28,
      input: "<math><mi>   </mi></math>",
      scripting_enabled: true,
      xml_coercion: false,
      expected_tree: "| <html>\n|   <head>\n|   <body>\n|     <math math>\n|       <math mi>\n|         \"   \"",
      error_codes: ["expected-doctype-but-got-start-tag"],
    },
    {
      line: 41,
      input: "</template>",
      scripting_enabled: true,
      xml_coercion: false,
      expected_tree: "| <html>\n|   <head>\n|   <body>",
      error_codes: [
        "expected-doctype-but-got-end-tag", "unexpected-end-tag-before-html",
      ],
    },
    {
      line: 53,
      input: "<body><input type=\"hidden\">",
      scripting_enabled: true,
      xml_coercion: false,
      expected_tree: "| <html>\n|   <head>\n|   <body>\n|     <input>\n|       type=\"hidden\"",
      error_codes: ["expected-doctype-but-got-start-tag"],
    },
    {
      line: 66,
      input: "<html><body><html attr=\"test\">",
      scripting_enabled: true,
      xml_coercion: false,
      expected_tree: "| <html>\n|   attr=\"test\"\n|   <head>\n|   <body>",
      error_codes: [
        "expected-doctype-but-got-start-tag", "unexpected-start-tag",
      ],
    },
    {
      line: 79,
      input: "<select><optgroup><option>1</option></optgroup></select>",
      scripting_enabled: true,
      xml_coercion: false,
      expected_tree: "| <html>\n|   <head>\n|   <body>\n|     <select>\n|       <optgroup>\n|         <option>\n|           \"1\"",
      error_codes: ["expected-doctype-but-got-start-tag"],
    },
    {
      line: 94,
      input: "<select><option>1</option></optgroup></select>",
      scripting_enabled: true,
      xml_coercion: false,
      expected_tree: "| <html>\n|   <head>\n|   <body>\n|     <select>\n|       <option>\n|         \"1\"",
      error_codes: [
        "expected-doctype-but-got-start-tag", "unexpected-end-tag-in-select",
      ],
    },
    {
      line: 108,
      input: "<!DOCTYPE html><html><head></head><frameset></frameset>",
      scripting_enabled: true,
      xml_coercion: false,
      expected_tree: "| <!DOCTYPE html>\n| <html>\n|   <head>\n|   <frameset>",
      error_codes: [],
    },
    {
      line: 119,
      input: "<!DOCTYPE html><html><head></head><frameset></frameset>abc",
      scripting_enabled: true,
      xml_coercion: false,
      expected_tree: "| <!DOCTYPE html>\n| <html>\n|   <head>\n|   <frameset>",
      error_codes: ["unexpected-token-after-frameset"],
    },
    {
      line: 131,
      input: "<table><input id=\"x\" class=\"y\" type=\"hidden\"></table>",
      scripting_enabled: true,
      xml_coercion: false,
      expected_tree: "| <html>\n|   <head>\n|   <body>\n|     <table>\n|       <input>\n|         class=\"y\"\n|         id=\"x\"\n|         type=\"hidden\"",
      error_codes: [
        "expected-doctype-but-got-start-tag", "unexpected-hidden-input-in-table",
      ],
    },
    {
      line: 148,
      input: "<math><annotation-xml encoding=\"text/plain\"><div></div></annotation-xml></math>",
      scripting_enabled: true,
      xml_coercion: false,
      expected_tree: "| <html>\n|   <head>\n|   <body>\n|     <math math>\n|       <math annotation-xml>\n|         encoding=\"text/plain\"\n|     <div>",
      error_codes: [
        "expected-doctype-but-got-start-tag", "unexpected-html-element-in-foreign-content",
        "unexpected-end-tag", "unexpected-end-tag",
      ],
    },
    {
      line: 164,
      input: "<math><annotation-xml><div></div></annotation-xml></math>",
      scripting_enabled: true,
      xml_coercion: false,
      expected_tree: "| <html>\n|   <head>\n|   <body>\n|     <math math>\n|       <math annotation-xml>\n|     <div>",
      error_codes: [
        "expected-doctype-but-got-start-tag", "unexpected-html-element-in-foreign-content",
        "unexpected-end-tag", "unexpected-end-tag",
      ],
    },
    {
      line: 179,
      input: "<svg><font color=\"red\">text</font></svg>",
      scripting_enabled: true,
      xml_coercion: false,
      expected_tree: "| <html>\n|   <head>\n|   <body>\n|     <svg svg>\n|     <font>\n|       color=\"red\"\n|       \"text\"",
      error_codes: [
        "expected-doctype-but-got-start-tag", "unexpected-html-element-in-foreign-content",
        "unexpected-end-tag",
      ],
    },
    {
      line: 194,
      input: "<select><selectedcontent></selectedcontent><option>A</option><option selected>B</option></select>",
      scripting_enabled: true,
      xml_coercion: false,
      expected_tree: "| <html>\n|   <head>\n|   <body>\n|     <select>\n|       <selectedcontent>\n|         \"B\"\n|       <option>\n|         \"A\"\n|       <option>\n|         selected=\"\"\n|         \"B\"",
      error_codes: [
        "expected-doctype-but-got-start-tag", "unexpected-start-tag-in-select", "unexpected-end-tag-in-select",
      ],
    },
    {
      line: 214,
      input: "<select><selectedcontent></selectedcontent><option>A</option><option>B</option></select>",
      scripting_enabled: true,
      xml_coercion: false,
      expected_tree: "| <html>\n|   <head>\n|   <body>\n|     <select>\n|       <selectedcontent>\n|         \"A\"\n|       <option>\n|         \"A\"\n|       <option>\n|         \"B\"",
      error_codes: [
        "expected-doctype-but-got-start-tag", "unexpected-start-tag-in-select", "unexpected-end-tag-in-select",
      ],
    },
    {
      line: 233,
      input: "<b><select></b></select>",
      scripting_enabled: true,
      xml_coercion: false,
      expected_tree: "| <html>\n|   <head>\n|   <body>\n|     <b>\n|       <select>",
      error_codes: [
        "expected-doctype-but-got-start-tag", "unexpected-end-tag-in-select", "expected-closing-tag-but-got-eof",
      ],
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
