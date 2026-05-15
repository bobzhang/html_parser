///|
test "parser honors scripting enabled for noscript text mode" {
  let enabled = @html_parser.parse_fragment(
    "<noscript><b>Hi</b></noscript>",
    scripting_enabled=true,
  )
  assert_eq(
    enabled.to_html(pretty=false),
    "<noscript>&lt;b&gt;Hi&lt;/b&gt;</noscript>",
  )
  assert_eq(enabled.query("b").length(), 0)
  let disabled = @html_parser.parse_fragment(
    "<noscript><b>Hi</b></noscript>",
    scripting_enabled=false,
  )
  assert_eq(disabled.to_html(pretty=false), "<noscript><b>Hi</b></noscript>")
  assert_eq(disabled.query("b").length(), 1)
}

///|
test "parser handles disabled scripting noscript in head" {
  let doctype = @html_parser.parse(
    "<head><noscript><!DOCTYPE html></noscript>",
    collect_errors=true,
    scripting_enabled=false,
  )
  assert_eq(
    doctype.to_html(pretty=false),
    "<html><head><noscript></noscript></head><body></body></html>",
  )
  assert_eq(doctype.errors.length(), 2)
  assert_eq(doctype.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(doctype.errors[1].code, "unexpected-doctype")
  let stray_end = @html_parser.parse(
    "<head><noscript></p></noscript>",
    collect_errors=true,
    scripting_enabled=false,
  )
  assert_eq(
    stray_end.to_html(pretty=false),
    "<html><head><noscript></noscript></head><body></body></html>",
  )
  assert_eq(stray_end.errors.length(), 2)
  assert_eq(stray_end.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(stray_end.errors[1].code, "unexpected-end-tag")
  let stray_head = @html_parser.parse(
    "<head><noscript><head></noscript>",
    collect_errors=true,
    scripting_enabled=false,
  )
  assert_eq(
    stray_head.to_html(pretty=false),
    "<html><head><noscript></noscript></head><body></body></html>",
  )
  assert_eq(stray_head.errors.length(), 2)
  assert_eq(stray_head.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(stray_head.errors[1].code, "unexpected-start-tag")
  let stray_br = @html_parser.parse(
    "<head><noscript></br>x",
    collect_errors=true,
    scripting_enabled=false,
  )
  assert_eq(
    stray_br.to_html(pretty=false),
    "<html><head><noscript></noscript></head><body><br>x</body></html>",
  )
  assert_eq(stray_br.errors.length(), 3)
  assert_eq(stray_br.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(stray_br.errors[1].code, "unexpected-end-tag")
  assert_eq(stray_br.errors[2].code, "unexpected-end-tag")
  let paragraph = @html_parser.parse(
    "<head><noscript><p>x</noscript>",
    collect_errors=true,
    scripting_enabled=false,
  )
  assert_eq(
    paragraph.to_html(pretty=false),
    "<html><head><noscript></noscript></head><body><p>x</p></body></html>",
  )
  assert_eq(paragraph.errors.length(), 3)
  assert_eq(paragraph.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(paragraph.errors[1].code, "unexpected-start-tag")
  assert_eq(paragraph.errors[2].code, "unexpected-end-tag")
  let text = @html_parser.parse(
    "<head><noscript>x</noscript>",
    collect_errors=true,
    scripting_enabled=false,
  )
  assert_eq(
    text.to_html(pretty=false),
    "<html><head><noscript></noscript></head><body>x</body></html>",
  )
  assert_eq(text.errors.length(), 3)
  assert_eq(text.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(text.errors[1].code, "unexpected-start-tag")
  assert_eq(text.errors[2].code, "unexpected-end-tag")
  let leading_space = @html_parser.parse(
    "<head><noscript> x</noscript>",
    collect_errors=true,
    scripting_enabled=false,
  )
  assert_eq(
    leading_space.to_html(pretty=false),
    "<html><head><noscript></noscript> </head><body>x</body></html>",
  )
  assert_eq(leading_space.errors.length(), 3)
  assert_eq(leading_space.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(leading_space.errors[1].code, "unexpected-start-tag")
  assert_eq(leading_space.errors[2].code, "unexpected-end-tag")
  let coerced_leading_space = @html_parser.parse(
    "<head><noscript>\u{000C} x</noscript>",
    collect_errors=true,
    scripting_enabled=false,
    xml_coercion=true,
  )
  assert_eq(
    coerced_leading_space.to_html(pretty=false),
    "<html><head><noscript></noscript>  </head><body>x</body></html>",
  )
  assert_eq(coerced_leading_space.errors.length(), 3)
  assert_eq(
    coerced_leading_space.errors[0].code,
    "expected-doctype-but-got-start-tag",
  )
  assert_eq(coerced_leading_space.errors[1].code, "unexpected-start-tag")
  assert_eq(coerced_leading_space.errors[2].code, "unexpected-end-tag")
  let allowed = @html_parser.parse(
    "<head><noscript><link rel=x></noscript><p>y",
    collect_errors=true,
    scripting_enabled=false,
  )
  assert_eq(
    allowed.to_html(pretty=false),
    "<html><head><noscript><link rel=\"x\"></noscript></head><body><p>y</p></body></html>",
  )
  assert_eq(allowed.errors.length(), 1)
  assert_eq(allowed.errors[0].code, "expected-doctype-but-got-start-tag")
}
