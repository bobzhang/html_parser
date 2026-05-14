///|
test "parser and tokenizer preserve doctype external ids" {
  let source = "<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01//EN\" \"http://www.w3.org/TR/html4/strict.dtd\">"
  let doc = @html_parser.parse(source)
  assert_eq(
    doc.to_html(pretty=false),
    "<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01//EN\" \"http://www.w3.org/TR/html4/strict.dtd\"><html><head></head><body></body></html>",
  )
  let tokens = @html_parser.tokenize(source)
  guard tokens.tokens[0] is DoctypeToken(info) else {
    fail("expected doctype token")
  }
  assert_eq(info.name, "html")
  guard info.public_id is Some("-//W3C//DTD HTML 4.01//EN") else {
    fail("expected public id")
  }
  guard info.system_id is Some("http://www.w3.org/TR/html4/strict.dtd") else {
    fail("expected system id")
  }
  let system = @html_parser.tokenize(
    "<!DOCTYPE html SYSTEM \"about:legacy-compat\">",
  )
  guard system.tokens[0] is DoctypeToken(system_info) else {
    fail("expected system doctype")
  }
  guard system_info.public_id is None else { fail("expected no public id") }
  guard system_info.system_id is Some("about:legacy-compat") else {
    fail("expected system id")
  }
  let newline_ids = @html_parser.tokenize(
    "<!DOCTYPE html PUBLIC \"a\rb\" \"s\r\nt\">",
  )
  guard newline_ids.tokens[0] is DoctypeToken(newline_info) else {
    fail("expected newline-normalized doctype")
  }
  guard newline_info.public_id is Some("a\nb") else {
    fail("expected CR-normalized public id")
  }
  guard newline_info.system_id is Some("s\nt") else {
    fail("expected CRLF-normalized system id")
  }
  let newline_doc = @html_parser.parse(
    "<!DOCTYPE html PUBLIC \"a\rb\" \"s\r\nt\">",
    collect_errors=true,
  )
  assert_eq(
    newline_doc.to_html(pretty=false),
    "<!DOCTYPE html PUBLIC \"a\nb\" \"s\nt\"><html><head></head><body></body></html>",
  )
  assert_eq(newline_doc.errors.length(), 1)
  assert_eq(newline_doc.errors[0].code, "unknown-doctype")
  guard newline_doc.errors[0].line is Some(3) else {
    fail("expected unknown doctype after CRLF-normalized system id on line 3")
  }
  guard newline_doc.errors[0].column is Some(3) else {
    fail("expected unknown doctype at closing bracket column")
  }
  let public_trailing_cr = @html_parser.tokenize(
    "<!DOCTYPE html PUBLIC \"p\"\r>",
    collect_errors=true,
  )
  assert_eq(public_trailing_cr.errors.length(), 0)
  guard public_trailing_cr.tokens[0] is DoctypeToken(public_trailing_info) else {
    fail("expected public doctype with trailing CR whitespace")
  }
  guard public_trailing_info.public_id is Some("p") else {
    fail("expected public id before trailing CR")
  }
  guard public_trailing_info.system_id is None else {
    fail("expected no system id after trailing CR before bracket")
  }
}

///|
test "parser and tokenizer handle malformed doctype names" {
  let missing = @html_parser.parse("<!doctype>", collect_errors=true)
  assert_eq(
    missing.to_html(pretty=false),
    "<!DOCTYPE><html><head></head><body></body></html>",
  )
  assert_eq(missing.errors.length(), 2)
  assert_eq(
    missing.errors[0].code,
    "expected-doctype-name-but-got-right-bracket",
  )
  assert_eq(missing.errors[1].code, "unknown-doctype")
  guard missing.errors[0].column is Some(10) else {
    fail("expected missing doctype name at close bracket")
  }
  let missing_token = @html_parser.tokenize("<!doctype>", collect_errors=true)
  guard missing_token.tokens[0] is DoctypeToken(info) else {
    fail("expected doctype token")
  }
  assert_eq(info.name, "")
  assert_eq(info.force_quirks, true)
  assert_eq(
    missing_token.errors[0].code,
    "expected-doctype-name-but-got-right-bracket",
  )
  let eof = @html_parser.parse("<!doctype", collect_errors=true)
  assert_eq(
    eof.to_html(pretty=false),
    "<!DOCTYPE><html><head></head><body></body></html>",
  )
  assert_eq(eof.errors.length(), 2)
  assert_eq(eof.errors[0].code, "eof-in-doctype")
  assert_eq(eof.errors[1].code, "unknown-doctype")
  guard eof.errors[0].column is Some(9) else {
    fail("expected doctype EOF at final character")
  }
  let eof_token = @html_parser.tokenize("<!doctype", collect_errors=true)
  guard eof_token.tokens[0] is DoctypeToken(eof_info) else {
    fail("expected EOF doctype token")
  }
  assert_eq(eof_info.name, "")
  assert_eq(eof_info.force_quirks, true)
  assert_eq(eof_token.errors.length(), 1)
  assert_eq(eof_token.errors[0].code, "eof-in-doctype")
  let name_eof_token = @html_parser.tokenize(
    "<!doctype html",
    collect_errors=true,
  )
  guard name_eof_token.tokens[0] is DoctypeToken(name_eof_info) else {
    fail("expected named EOF doctype token")
  }
  assert_eq(name_eof_info.name, "html")
  assert_eq(name_eof_info.force_quirks, true)
  assert_eq(name_eof_token.errors.length(), 1)
  assert_eq(name_eof_token.errors[0].code, "eof-in-doctype")
  let name_eof = @html_parser.parse("<!doctype html", collect_errors=true)
  assert_eq(
    name_eof.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body></body></html>",
  )
  assert_eq(name_eof.errors.length(), 1)
  assert_eq(name_eof.errors[0].code, "eof-in-doctype")
  guard name_eof.errors[0].column is Some(14) else {
    fail("expected named doctype EOF at final character")
  }
}

///|
test "parser and tokenizer report doctype name whitespace errors" {
  let missing_before = @html_parser.parse("<!doctypehtml>", collect_errors=true)
  assert_eq(
    missing_before.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body></body></html>",
  )
  assert_eq(missing_before.errors.length(), 1)
  assert_eq(
    missing_before.errors[0].code,
    "missing-whitespace-before-doctype-name",
  )
  guard missing_before.errors[0].column is Some(10) else {
    fail("expected missing whitespace before doctype name at name start")
  }
  let missing_before_token = @html_parser.tokenize(
    "<!doctypehtml>",
    collect_errors=true,
  )
  assert_eq(
    missing_before_token.errors[0].code,
    "missing-whitespace-before-doctype-name",
  )
  guard missing_before_token.tokens[0] is DoctypeToken(before_info) else {
    fail("expected doctype token")
  }
  assert_eq(before_info.name, "html")
  assert_eq(before_info.force_quirks, false)
  let junk_after_name = @html_parser.tokenize(
    "<!doctype html x>",
    collect_errors=true,
  )
  assert_eq(junk_after_name.errors.length(), 1)
  assert_eq(
    junk_after_name.errors[0].code,
    "missing-whitespace-after-doctype-name",
  )
  guard junk_after_name.errors[0].column is Some(16) else {
    fail("expected missing whitespace after doctype name at junk")
  }
  guard junk_after_name.tokens[0] is DoctypeToken(junk_info) else {
    fail("expected doctype token")
  }
  assert_eq(junk_info.name, "html")
  guard junk_info.public_id is None else { fail("expected no public id") }
  assert_eq(junk_info.force_quirks, true)
  let extra_space = @html_parser.parse(
    "<!doctype html  PUBLIC \"x\">",
    collect_errors=true,
  )
  assert_eq(
    extra_space.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body></body></html>",
  )
  assert_eq(extra_space.errors.length(), 1)
  assert_eq(extra_space.errors[0].code, "missing-whitespace-after-doctype-name")
  guard extra_space.errors[0].column is Some(17) else {
    fail("expected extra-space doctype error at PUBLIC")
  }
  let fused_public = @html_parser.parse(
    "<!doctypehtml PUBLIC \"x\">",
    collect_errors=true,
  )
  assert_eq(
    fused_public.to_html(pretty=false),
    "<!DOCTYPE html PUBLIC \"x\"><html><head></head><body></body></html>",
  )
  assert_eq(fused_public.errors.length(), 2)
  assert_eq(
    fused_public.errors[0].code,
    "missing-whitespace-before-doctype-name",
  )
  assert_eq(fused_public.errors[1].code, "unknown-doctype")
}

///|
test "parser and tokenizer replace null characters in doctypes" {
  let name_null = @html_parser.tokenize(
    "<!doctype h\u{0000}tml>",
    collect_errors=true,
  )
  assert_eq(name_null.errors.length(), 1)
  assert_eq(name_null.errors[0].code, "unexpected-null-character")
  guard name_null.errors[0].column is Some(12) else {
    fail("expected null error inside doctype name")
  }
  guard name_null.tokens[0] is DoctypeToken(name_info) else {
    fail("expected doctype token")
  }
  assert_eq(name_info.name, "h�tml")
  assert_eq(name_info.force_quirks, false)
  let parsed_name_null = @html_parser.parse(
    "<!doctype h\u{0000}tml><p>x",
    collect_errors=true,
  )
  assert_eq(parsed_name_null.errors.length(), 2)
  assert_eq(parsed_name_null.errors[0].code, "unexpected-null-character")
  guard parsed_name_null.errors[0].column is Some(12) else {
    fail("expected parser null error inside doctype name")
  }
  assert_eq(parsed_name_null.errors[1].code, "unknown-doctype")
  let children = parsed_name_null.root.children()
  assert_eq(@html_parser.to_test_format(children[0]), "| <!DOCTYPE h�tml>")
  let public_null = @html_parser.tokenize(
    "<!doctype html PUBLIC \"x\u{0000}y\">",
    collect_errors=true,
  )
  assert_eq(public_null.errors.length(), 1)
  assert_eq(public_null.errors[0].code, "unexpected-null-character")
  guard public_null.errors[0].column is Some(25) else {
    fail("expected null error inside public identifier")
  }
  guard public_null.tokens[0] is DoctypeToken(public_info) else {
    fail("expected doctype token")
  }
  guard public_info.public_id is Some("x�y") else {
    fail("expected replacement character in public id")
  }
  assert_eq(public_info.force_quirks, false)
  let system_null = @html_parser.parse(
    "<!doctype html SYSTEM \"x\u{0000}y\">",
    collect_errors=true,
  )
  assert_eq(
    system_null.to_html(pretty=false),
    "<!DOCTYPE html SYSTEM \"x�y\"><html><head></head><body></body></html>",
  )
  assert_eq(system_null.errors.length(), 2)
  assert_eq(system_null.errors[0].code, "unexpected-null-character")
  guard system_null.errors[0].column is Some(25) else {
    fail("expected null error inside system identifier")
  }
  assert_eq(system_null.errors[1].code, "unknown-doctype")
}
