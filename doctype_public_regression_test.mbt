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
