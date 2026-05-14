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
test "tree builder matches reference iframe srcdoc doctype edge" {
  let doc = @html_parser.parse(
    "<!DOCTYPE foo><p><table></table>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(doc.root),
    "| <!DOCTYPE foo>\n| <html>\n|   <head>\n|   <body>\n|     <p>\n|     <table>",
  )
  assert_eq(doc.errors.length(), 1)
  assert_eq(doc.errors[0].code, "unknown-doctype")
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
test "tree builder matches reference legacy loose doctype fixture" {
  let doc = @html_parser.parse(
    "<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//\" \"http://www.w3.org/TR/html4/loose.dtd\">",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(doc.root),
    "| <!DOCTYPE html \"-//W3C//DTD HTML 4.01 Transitional//\" \"http://www.w3.org/TR/html4/loose.dtd\">\n| <html>\n|   <head>\n|   <body>",
  )
  assert_eq(doc.errors.length(), 1)
  assert_eq(doc.errors[0].code, "unknown-doctype")
  guard doc.errors[0].column is Some(100) else {
    fail("expected unknown loose doctype at close bracket")
  }
}

///|
test "tree builder matches reference MathML text form-feed fixture" {
  let doc = @html_parser.parse(
    "<math><mi>\u{000C}text</mi></math>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(doc.root),
    "| <html>\n|   <head>\n|   <body>\n|     <math math>\n|       <math mi>\n|         \" text\"",
  )
  assert_eq(doc.errors.length(), 1)
  assert_eq(doc.errors[0].code, "expected-doctype-but-got-start-tag")
}

///|
test "tree builder matches reference after-head stray template end fixture" {
  let doc = @html_parser.parse(
    "<head></head></template>text",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(doc.root),
    "| <html>\n|   <head>\n|   <body>\n|     \"text\"",
  )
  assert_eq(doc.errors.length(), 2)
  assert_eq(doc.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(doc.errors[1].code, "unexpected-end-tag")
  guard doc.errors[1].column is Some(24) else {
    fail("expected stray template end at close bracket")
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
test "tree builder matches Python reference MathML null text fixtures" {
  let null_only = @html_parser.parse(
    "<math><mi>\u{0000}</mi></math>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(null_only.root),
    "| <html>\n|   <head>\n|   <body>\n|     <math math>\n|       <math mi>",
  )
  assert_eq(null_only.errors.length(), 2)
  assert_eq(null_only.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(null_only.errors[1].code, "unexpected-null-character")
  guard null_only.errors[0].column is Some(6) else {
    fail("expected MathML doctype error at math start close")
  }
  guard null_only.errors[1].column is Some(11) else {
    fail("expected MathML null error at null character")
  }
  let null_form_feed = @html_parser.parse(
    "<math><mi>\u{0000}\u{000C}</mi></math>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(null_form_feed.root),
    "| <html>\n|   <head>\n|   <body>\n|     <math math>\n|       <math mi>\n|         \" \"",
  )
  assert_eq(null_form_feed.errors.length(), 2)
  assert_eq(null_form_feed.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(null_form_feed.errors[1].code, "unexpected-null-character")
  guard null_form_feed.errors[1].column is Some(11) else {
    fail("expected MathML mixed null error at null character")
  }
  let whitespace = @html_parser.parse(
    "<math><mi>   </mi></math>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(whitespace.root),
    "| <html>\n|   <head>\n|   <body>\n|     <math math>\n|       <math mi>\n|         \"   \"",
  )
  assert_eq(whitespace.errors.length(), 1)
  assert_eq(whitespace.errors[0].code, "expected-doctype-but-got-start-tag")
  guard whitespace.errors[0].column is Some(6) else {
    fail("expected MathML whitespace doctype error at math start close")
  }
}

///|
test "tree builder matches Python reference table fostered text behavior" {
  let doc = @html_parser.parse("<table>text</table>", collect_errors=true)
  assert_eq(
    @html_parser.to_test_format(doc.root),
    "| <html>\n|   <head>\n|   <body>\n|     \"text\"\n|     <table>",
  )
  assert_eq(doc.errors.length(), 5)
  assert_eq(doc.errors[0].code, "expected-doctype-but-got-start-tag")
  for index in 1..<doc.errors.length() {
    assert_eq(doc.errors[index].code, "foster-parenting-character")
  }
  guard doc.errors[0].column is Some(7) else {
    fail("expected table doctype error at table start close")
  }
}

///|
test "tree builder matches Python reference table form-feed behavior" {
  let doc = @html_parser.parse("<table>\u{000C}</table>", collect_errors=true)
  assert_eq(
    @html_parser.to_test_format(doc.root),
    "| <html>\n|   <head>\n|   <body>\n|     <table>\n|       \" \"",
  )
  assert_eq(doc.errors.length(), 1)
  assert_eq(doc.errors[0].code, "expected-doctype-but-got-start-tag")
  guard doc.errors[0].column is Some(7) else {
    fail("expected table form-feed doctype error at table start close")
  }
}

///|
test "tree builder matches Python reference mixed frameset recovery behavior" {
  let doc = @html_parser.parse(
    "<figure><frameset><h1><aside><figcaption><html><frameset>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(doc.root),
    "| <html>\n|   <head>\n|   <frameset>",
  )
  assert_eq(doc.errors.length(), 7)
  assert_eq(doc.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(doc.errors[1].code, "unexpected-token-in-frameset")
  assert_eq(doc.errors[2].code, "unexpected-token-in-frameset")
  assert_eq(doc.errors[3].code, "unexpected-token-in-frameset")
  assert_eq(doc.errors[4].code, "unexpected-start-tag")
  assert_eq(doc.errors[5].code, "unexpected-start-tag-ignored")
  assert_eq(doc.errors[6].code, "expected-closing-tag-but-got-eof")
  guard doc.errors[0].column is Some(8) else {
    fail("expected figure doctype error at start tag close")
  }
  guard doc.errors[1].column is Some(22) else {
    fail("expected h1 frameset error at close bracket")
  }
  guard doc.errors[2].column is Some(29) else {
    fail("expected aside frameset error at close bracket")
  }
  guard doc.errors[3].column is Some(41) else {
    fail("expected figcaption frameset error at close bracket")
  }
  guard doc.errors[4].column is Some(47) else {
    fail("expected html frameset recovery error at close bracket")
  }
  guard doc.errors[5].column is Some(57) else {
    fail("expected ignored nested frameset error at close bracket")
  }
  guard doc.errors[6].column is Some(57) else {
    fail("expected open frameset EOF at final column")
  }
}

///|
test "tree builder matches Python reference select optgroup branch fixtures" {
  let nested_group = @html_parser.parse(
    "<select><optgroup><option>1</option></optgroup></select>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(nested_group.root),
    "| <html>\n|   <head>\n|   <body>\n|     <select>\n|       <optgroup>\n|         <option>\n|           \"1\"",
  )
  assert_eq(nested_group.errors.length(), 1)
  assert_eq(nested_group.errors[0].code, "expected-doctype-but-got-start-tag")
  guard nested_group.errors[0].column is Some(8) else {
    fail("expected select doctype error at select start close")
  }
  let stray_group = @html_parser.parse(
    "<select><option>1</option></optgroup></select>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(stray_group.root),
    "| <html>\n|   <head>\n|   <body>\n|     <select>\n|       <option>\n|         \"1\"",
  )
  assert_eq(stray_group.errors.length(), 2)
  assert_eq(stray_group.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(stray_group.errors[1].code, "unexpected-end-tag-in-select")
  guard stray_group.errors[1].column is Some(37) else {
    fail("expected stray optgroup end at close bracket")
  }
}

///|
test "tree builder matches Python reference selectedcontent branch fixtures" {
  let selected = @html_parser.parse(
    "<select><selectedcontent></selectedcontent><option>A</option><option selected>B</option></select>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(selected.root),
    "| <html>\n|   <head>\n|   <body>\n|     <select>\n|       <selectedcontent>\n|         \"B\"\n|       <option>\n|         \"A\"\n|       <option>\n|         selected=\"\"\n|         \"B\"",
  )
  assert_eq(selected.errors.length(), 3)
  assert_eq(selected.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(selected.errors[1].code, "unexpected-start-tag-in-select")
  assert_eq(selected.errors[2].code, "unexpected-end-tag-in-select")
  guard selected.errors[1].column is Some(25) else {
    fail("expected selectedcontent start error at start tag close")
  }
  guard selected.errors[2].column is Some(43) else {
    fail("expected selectedcontent end error at end tag close")
  }
  let default_first = @html_parser.parse(
    "<select><selectedcontent></selectedcontent><option>A</option><option>B</option></select>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(default_first.root),
    "| <html>\n|   <head>\n|   <body>\n|     <select>\n|       <selectedcontent>\n|         \"A\"\n|       <option>\n|         \"A\"\n|       <option>\n|         \"B\"",
  )
  assert_eq(default_first.errors.length(), 3)
  assert_eq(default_first.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(default_first.errors[1].code, "unexpected-start-tag-in-select")
  assert_eq(default_first.errors[2].code, "unexpected-end-tag-in-select")
  guard default_first.errors[1].column is Some(25) else {
    fail("expected default selectedcontent start error at start tag close")
  }
  guard default_first.errors[2].column is Some(43) else {
    fail("expected default selectedcontent end error at end tag close")
  }
}

///|
test "tree builder matches Python reference select aside and selectedcontent attribute branch fixtures" {
  let aside = @html_parser.parse(
    "<select><aside>text</aside></select>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(aside.root),
    "| <html>\n|   <head>\n|   <body>\n|     <select>\n|       \"text\"",
  )
  assert_eq(aside.errors.length(), 3)
  assert_eq(aside.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(aside.errors[1].code, "unexpected-start-tag-in-select")
  assert_eq(aside.errors[2].code, "unexpected-end-tag")
  guard aside.errors[1].column is Some(15) else {
    fail("expected aside start error at start tag close")
  }
  guard aside.errors[2].column is Some(27) else {
    fail("expected aside end error at end tag close")
  }
  let disabled = @html_parser.parse(
    "<select><selectedcontent></selectedcontent><option disabled>A</option></select>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(disabled.root),
    "| <html>\n|   <head>\n|   <body>\n|     <select>\n|       <selectedcontent>\n|         \"A\"\n|       <option>\n|         disabled=\"\"\n|         \"A\"",
  )
  assert_eq(disabled.errors.length(), 3)
  assert_eq(disabled.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(disabled.errors[1].code, "unexpected-start-tag-in-select")
  assert_eq(disabled.errors[2].code, "unexpected-end-tag-in-select")
  let classed = @html_parser.parse(
    "<select><selectedcontent></selectedcontent><option class=\"x\">A</option><option selected>B</option></select>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(classed.root),
    "| <html>\n|   <head>\n|   <body>\n|     <select>\n|       <selectedcontent>\n|         \"B\"\n|       <option>\n|         class=\"x\"\n|         \"A\"\n|       <option>\n|         selected=\"\"\n|         \"B\"",
  )
  assert_eq(classed.errors.length(), 3)
  assert_eq(classed.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(classed.errors[1].code, "unexpected-start-tag-in-select")
  assert_eq(classed.errors[2].code, "unexpected-end-tag-in-select")
}

///|
test "tree builder matches Python reference select formatting end branch fixtures" {
  let bold = @html_parser.parse("<b><select></b></select>", collect_errors=true)
  assert_eq(
    @html_parser.to_test_format(bold.root),
    "| <html>\n|   <head>\n|   <body>\n|     <b>\n|       <select>",
  )
  assert_eq(bold.errors.length(), 3)
  assert_eq(bold.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(bold.errors[1].code, "unexpected-end-tag-in-select")
  assert_eq(bold.errors[2].code, "expected-closing-tag-but-got-eof")
  guard bold.errors[1].column is Some(15) else {
    fail("expected bold end tag in select at close bracket")
  }
  guard bold.errors[2].column is Some(24) else {
    fail("expected bold EOF recovery at EOF column")
  }
  let link = @html_parser.parse(
    "<a href=\"x\"><select></a></select>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(link.root),
    "| <html>\n|   <head>\n|   <body>\n|     <a>\n|       href=\"x\"\n|       <select>",
  )
  assert_eq(link.errors.length(), 3)
  assert_eq(link.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(link.errors[1].code, "unexpected-end-tag-in-select")
  assert_eq(link.errors[2].code, "expected-closing-tag-but-got-eof")
  guard link.errors[1].column is Some(24) else {
    fail("expected link end tag in select at close bracket")
  }
  guard link.errors[2].column is Some(33) else {
    fail("expected link EOF recovery at EOF column")
  }
}

///|
test "tree builder matches Python reference select formatting stray branch fixtures" {
  let link_end = @html_parser.parse(
    "<select></a></select>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(link_end.root),
    "| <html>\n|   <head>\n|   <body>\n|     <select>",
  )
  assert_eq(link_end.errors.length(), 2)
  assert_eq(link_end.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(link_end.errors[1].code, "unexpected-end-tag-in-select")
  guard link_end.errors[1].column is Some(12) else {
    fail("expected stray link end in select at close bracket")
  }
  let bold_end = @html_parser.parse(
    "<select></b></select>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(bold_end.root),
    "| <html>\n|   <head>\n|   <body>\n|     <select>",
  )
  assert_eq(bold_end.errors.length(), 2)
  assert_eq(bold_end.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(bold_end.errors[1].code, "unexpected-end-tag-in-select")
  guard bold_end.errors[1].column is Some(12) else {
    fail("expected stray bold end in select at close bracket")
  }
}

///|
test "tree builder matches Python reference select plaintext branch fixture" {
  let doc = @html_parser.parse(
    "<select><plaintext></select>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(doc.root),
    "| <html>\n|   <head>\n|   <body>\n|     <select>\n|       <plaintext>\n|         \"</select>\"",
  )
  assert_eq(doc.errors.length(), 3)
  assert_eq(doc.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(doc.errors[1].code, "unexpected-start-tag-in-select")
  assert_eq(doc.errors[2].code, "expected-closing-tag-but-got-eof")
  guard doc.errors[1].column is Some(19) else {
    fail("expected plaintext start error at start tag close")
  }
  guard doc.errors[2].column is Some(28) else {
    fail("expected plaintext EOF recovery at EOF column")
  }
}

///|
test "tree builder matches Python reference hidden input in table branch fixture" {
  let document_hidden = @html_parser.parse(
    "<table><input id=\"x\" class=\"y\" type=\"hidden\"></table>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(document_hidden.root),
    "| <html>\n|   <head>\n|   <body>\n|     <table>\n|       <input>\n|         class=\"y\"\n|         id=\"x\"\n|         type=\"hidden\"",
  )
  assert_eq(document_hidden.errors.length(), 2)
  assert_eq(
    document_hidden.errors[0].code,
    "expected-doctype-but-got-start-tag",
  )
  assert_eq(document_hidden.errors[1].code, "unexpected-hidden-input-in-table")
  guard document_hidden.errors[1].column is Some(45) else {
    fail("expected hidden input table error at input start close")
  }
}

///|
test "tree builder matches vendored empty stack edge fixtures" {
  for case in empty_stack_edge_fixture_cases() {
    assert_tree_fixture(case)
  }
}

///|
test "tree builder matches reference empty-stack foreign select edge" {
  let doc = @html_parser.parse(
    "<!><svg><th><title><n><select><td>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(doc.root),
    "| <!--  -->\n| <html>\n|   <head>\n|   <body>\n|     <svg svg>\n|       <svg th>\n|         <svg title>\n|           <n>\n|             <select>\n|   <td>",
  )
  assert_eq(doc.errors.length(), 3)
  assert_eq(doc.errors[0].code, "incorrectly-opened-comment")
  assert_eq(doc.errors[1].code, "expected-doctype-but-got-start-tag")
  assert_eq(doc.errors[2].code, "unexpected-start-tag-in-select")
  guard doc.errors[0].column is Some(2) else {
    fail("expected malformed declaration at bang")
  }
  let td_siblings = @html_parser.parse(
    "<!><svg><th><title><n><select><td>x<td>y",
    collect_errors=true,
  )
  assert_eq(
    td_siblings.to_html(pretty=false),
    "<!----><html><head></head><body><svg><th><title><n><select></select></n></title></th></svg></body><td>x</td><td>y</td></html>",
  )
  assert_eq(td_siblings.errors.length(), 3)
  assert_eq(td_siblings.errors[0].code, "incorrectly-opened-comment")
  assert_eq(td_siblings.errors[1].code, "expected-doctype-but-got-start-tag")
  assert_eq(td_siblings.errors[2].code, "unexpected-start-tag-in-select")
  let th_then_td = @html_parser.parse(
    "<!><svg><th><title><n><select><th>x<td>y",
    collect_errors=true,
  )
  assert_eq(
    th_then_td.to_html(pretty=false),
    "<!----><html><head></head><body><svg><th><title><n><select></select></n></title></th></svg></body><th>x</th><td>y</td></html>",
  )
  assert_eq(th_then_td.errors.length(), 3)
  assert_eq(th_then_td.errors[0].code, "incorrectly-opened-comment")
  assert_eq(th_then_td.errors[1].code, "expected-doctype-but-got-start-tag")
  assert_eq(th_then_td.errors[2].code, "unexpected-start-tag-in-select")
}

///|
test "tree builder matches reference empty-stack nested select edge" {
  let doc = @html_parser.parse(
    "<svg><slot><select/e><title/a><select><select></slot></select>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(doc.root),
    "| <html>\n|   <head>\n|   <body>\n|     <svg svg>\n|       <svg slot>\n|         <svg select>\n|           e=\"\"\n|           <svg title>\n|             a=\"\"\n|             <select>",
  )
  assert_eq(doc.errors.length(), 6)
  assert_eq(doc.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(doc.errors[1].code, "unexpected-character-after-solidus-in-tag")
  assert_eq(doc.errors[2].code, "unexpected-character-after-solidus-in-tag")
  assert_eq(doc.errors[3].code, "unexpected-select-in-select")
  assert_eq(doc.errors[4].code, "unexpected-end-tag")
  assert_eq(doc.errors[5].code, "unexpected-end-tag")
}

///|
test "tree builder matches reference empty-stack foreign table row edge" {
  let doc = @html_parser.parse(
    "<svg><tr><title><section\n><math><p><tr>>",
    collect_errors=true,
  )
  assert_eq(
    @html_parser.to_test_format(doc.root),
    "| <html>\n|   <head>\n|   <body>\n|     <svg svg>\n|       <svg tr>\n|         <svg title>\n|           <section>\n|             <math math>\n|             <p>\n|   <tr>\n|     \">\"",
  )
  assert_eq(doc.errors.length(), 3)
  assert_eq(doc.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(doc.errors[1].code, "unexpected-html-element-in-foreign-content")
  assert_eq(doc.errors[2].code, "unexpected-character-implies-table-voodoo")
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
