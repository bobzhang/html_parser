///|
test "builder serializes compact HTML" {
  let node = @html_parser.element("p", attrs={ "class": Some("intro") }, children=[
    @html_parser.text("Hello "),
    @html_parser.element("b", children=[@html_parser.text("MoonBit")]),
  ])
  assert_eq(
    node.to_html(pretty=false),
    "<p class=\"intro\">Hello <b>MoonBit</b></p>",
  )
}

///|
test "to_text can separate only block boundaries" {
  let doc = @html_parser.parse_fragment("<p>hi</p><p>Hello <b>world</b></p>")
  assert_eq(doc.to_text(separator="\n"), "hi\nHello\nworld")
  assert_eq(
    doc.to_text(separator="\n", separator_blocks_only=true),
    "hi\nHello world",
  )
  let br = @html_parser.parse_fragment("<div>A<br>   <span>B</span></div>")
  assert_eq(br.to_text(separator="|", separator_blocks_only=true), "A|B")
  let node = @html_parser.element("div", children=[
    @html_parser.text("  A  "),
    @html_parser.element("br"),
    @html_parser.text(" B "),
  ])
  assert_eq(
    node.to_text(separator="|", separator_blocks_only=true, strip=false),
    "  A  | B ",
  )
}

///|
test "parser handles nested tags attributes comments and doctype" {
  let doc = @html_parser.parse(
    "<!doctype html><p id='x' class=\"intro lead\">Hi &amp; bye<!--ok--></p>",
    collect_errors=true,
  )
  assert_eq(
    doc.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body><p id=\"x\" class=\"intro lead\">Hi &amp; bye<!--ok--></p></body></html>",
  )
  assert_eq(doc.errors.length(), 0)
  assert_eq(doc.to_text(separator="", strip=false), "Hi & bye")
}

///|
test "document parser scaffolds explicit html children into head and body" {
  let implicit = @html_parser.parse("<html><p>x</p></html>")
  assert_eq(
    implicit.to_html(pretty=false),
    "<html><head></head><body><p>x</p></body></html>",
  )
  let existing = @html_parser.parse(
    "<html><head><title>T</title></head><p>x</p></html>",
  )
  assert_eq(
    existing.to_html(pretty=false),
    "<html><head><title>T</title></head><body><p>x</p></body></html>",
  )
}

///|
test "document parser routes initial head elements into head" {
  let doc = @html_parser.parse(
    "\n<meta charset=utf-8><title>T</title><style>b{}</style><script>h</script><p>x</p>",
  )
  assert_eq(
    doc.to_html(pretty=false),
    "<html><head><meta charset=\"utf-8\"><title>T</title><style>b{}</style><script>h</script></head><body><p>x</p></body></html>",
  )
  let explicit = @html_parser.parse(
    "<html><head></head><title>T</title><p>x</p></html>",
  )
  assert_eq(
    explicit.to_html(pretty=false),
    "<html><head><title>T</title></head><body><p>x</p></body></html>",
  )
  let late = @html_parser.parse("<html><body>x</body><title>T</title></html>")
  assert_eq(
    late.to_html(pretty=false),
    "<html><head></head><body>x<title>T</title></body></html>",
  )
}

///|
test "document parser promotes explicit root head and body elements" {
  let doc = @html_parser.parse(
    "<head><title>T</title></head><body class=x><p>p</p></body>",
  )
  assert_eq(
    doc.to_html(pretty=false),
    "<html><head><title>T</title></head><body class=\"x\"><p>p</p></body></html>",
  )
  let extra_head = @html_parser.parse(
    "<head><meta charset=utf-8></head><title>T</title><body><p>p</p></body>",
  )
  assert_eq(
    extra_head.to_html(pretty=false),
    "<html><head><meta charset=\"utf-8\"><title>T</title></head><body><p>p</p></body></html>",
  )
  let late_head_item = @html_parser.parse(
    "<body class=x><p>p</p></body><title>T</title>",
  )
  assert_eq(
    late_head_item.to_html(pretty=false),
    "<html><head></head><body class=\"x\"><p>p</p><title>T</title></body></html>",
  )
}

///|
test "document parser merges repeated body tags" {
  let repeated = @html_parser.parse(
    "<body class=a><p>one</p><body id=b><p>two</p>",
  )
  assert_eq(
    repeated.to_html(pretty=false),
    "<html><head></head><body class=\"a\" id=\"b\"><p>one</p><p>two</p></body></html>",
  )
  let first_wins = @html_parser.parse("<body class=a><body class=b id=x>text")
  assert_eq(
    first_wins.to_html(pretty=false),
    "<html><head></head><body class=\"a\" id=\"x\">text</body></html>",
  )
}

///|
test "document parser merges nested repeated html tags" {
  let nested = @html_parser.parse(
    "<html lang=en><html dir=ltr><body>x</body></html>",
  )
  assert_eq(
    nested.to_html(pretty=false),
    "<html lang=\"en\" dir=\"ltr\"><head></head><body>x</body></html>",
  )
  let after_body = @html_parser.parse(
    "<html lang=en><body>x</body><html dir=ltr><body>y</body></html>",
  )
  assert_eq(
    after_body.to_html(pretty=false),
    "<html lang=\"en\" dir=\"ltr\"><head></head><body>xy</body></html>",
  )
  let first_wins = @html_parser.parse(
    "<html lang=en><html lang=fr dir=ltr><head><title>T</title></head><body>x</body></html>",
  )
  assert_eq(
    first_wins.to_html(pretty=false),
    "<html lang=\"en\" dir=\"ltr\"><head><title>T</title></head><body>x</body></html>",
  )
}

///|
test "document parser merges root repeated html tags" {
  let repeated = @html_parser.parse(
    "<html lang=en></html><html dir=ltr><body>x</body></html>",
  )
  assert_eq(
    repeated.to_html(pretty=false),
    "<html lang=\"en\" dir=\"ltr\"><head></head><body>x</body></html>",
  )
  let with_existing_body = @html_parser.parse(
    "<html lang=en><body>x</body></html><html dir=ltr><body>y</body></html>",
  )
  assert_eq(
    with_existing_body.to_html(pretty=false),
    "<html lang=\"en\" dir=\"ltr\"><head></head><body>xy</body></html>",
  )
}

///|
test "document parser places comments around implicit head like reference" {
  let before = @html_parser.parse("<!--c--><title>T</title><p>x</p>")
  assert_eq(
    before.to_html(pretty=false),
    "<!--c--><html><head><title>T</title></head><body><p>x</p></body></html>",
  )
  let inside = @html_parser.parse("<title>T</title><!--c--><p>x</p>")
  assert_eq(
    inside.to_html(pretty=false),
    "<html><head><title>T</title><!--c--></head><body><p>x</p></body></html>",
  )
  let after_body = @html_parser.parse("<p>x</p><!--c--><title>T</title>")
  assert_eq(
    after_body.to_html(pretty=false),
    "<html><head></head><body><p>x</p><!--c--><title>T</title></body></html>",
  )
}

///|
test "parser and tokenizer preserve doctype external ids" {
  let source = "<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01//EN\" \"http://www.w3.org/TR/html4/strict.dtd\">"
  let doc = @html_parser.parse(source)
  assert_eq(
    doc.to_html(pretty=false),
    "<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01//EN\" \"http://www.w3.org/TR/html4/strict.dtd\"><html><head></head><body></body></html>",
  )
  let tokens = @html_parser.tokenize(source)
  guard tokens.tokens[0] is @html_parser.HtmlToken::DoctypeToken(info) else {
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
  guard system.tokens[0] is @html_parser.HtmlToken::DoctypeToken(system_info) else {
    fail("expected system doctype")
  }
  guard system_info.public_id is None else { fail("expected no public id") }
  guard system_info.system_id is Some("about:legacy-compat") else {
    fail("expected system id")
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
  guard missing_token.tokens[0] is @html_parser.HtmlToken::DoctypeToken(info) else {
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
  guard missing_before_token.tokens[0]
    is @html_parser.HtmlToken::DoctypeToken(before_info) else {
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
  guard junk_after_name.tokens[0]
    is @html_parser.HtmlToken::DoctypeToken(junk_info) else {
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
  guard name_null.tokens[0] is @html_parser.HtmlToken::DoctypeToken(name_info) else {
    fail("expected doctype token")
  }
  assert_eq(name_info.name, "h�tml")
  assert_eq(name_info.force_quirks, false)
  let public_null = @html_parser.tokenize(
    "<!doctype html PUBLIC \"x\u{0000}y\">",
    collect_errors=true,
  )
  assert_eq(public_null.errors.length(), 1)
  assert_eq(public_null.errors[0].code, "unexpected-null-character")
  guard public_null.errors[0].column is Some(25) else {
    fail("expected null error inside public identifier")
  }
  guard public_null.tokens[0]
    is @html_parser.HtmlToken::DoctypeToken(public_info) else {
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

///|
test "parser and tokenizer report missing doctype identifiers" {
  let public = @html_parser.parse("<!doctype html PUBLIC>", collect_errors=true)
  assert_eq(
    public.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body></body></html>",
  )
  assert_eq(public.errors.length(), 1)
  assert_eq(public.errors[0].code, "missing-doctype-public-identifier")
  guard public.errors[0].column is Some(22) else {
    fail("expected missing public identifier at close bracket")
  }
  let public_token = @html_parser.tokenize(
    "<!doctype html PUBLIC >",
    collect_errors=true,
  )
  assert_eq(public_token.errors[0].code, "missing-doctype-public-identifier")
  guard public_token.tokens[0]
    is @html_parser.HtmlToken::DoctypeToken(public_info) else {
    fail("expected doctype token")
  }
  assert_eq(public_info.name, "html")
  guard public_info.public_id is None else { fail("expected no public id") }
  assert_eq(public_info.force_quirks, true)
  let system = @html_parser.parse("<!doctype html SYSTEM>", collect_errors=true)
  assert_eq(
    system.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body></body></html>",
  )
  assert_eq(system.errors.length(), 1)
  assert_eq(system.errors[0].code, "missing-doctype-system-identifier")
  guard system.errors[0].column is Some(22) else {
    fail("expected missing system identifier at close bracket")
  }
  let system_token = @html_parser.tokenize(
    "<!doctype html SYSTEM >",
    collect_errors=true,
  )
  assert_eq(system_token.errors[0].code, "missing-doctype-system-identifier")
  guard system_token.tokens[0]
    is @html_parser.HtmlToken::DoctypeToken(system_info) else {
    fail("expected doctype token")
  }
  assert_eq(system_info.name, "html")
  guard system_info.system_id is None else { fail("expected no system id") }
  assert_eq(system_info.force_quirks, true)
}

///|
test "parser and tokenizer report missing doctype identifier quotes" {
  let public_eof = @html_parser.parse(
    "<!doctype html PUBLIC",
    collect_errors=true,
  )
  assert_eq(
    public_eof.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body></body></html>",
  )
  assert_eq(public_eof.errors.length(), 1)
  assert_eq(
    public_eof.errors[0].code,
    "missing-quote-before-doctype-public-identifier",
  )
  guard public_eof.errors[0].column is Some(21) else {
    fail("expected missing public quote at EOF")
  }
  let public_unquoted = @html_parser.tokenize(
    "<!doctype html PUBLIC x>",
    collect_errors=true,
  )
  assert_eq(
    public_unquoted.errors[0].code,
    "missing-quote-before-doctype-public-identifier",
  )
  guard public_unquoted.tokens[0]
    is @html_parser.HtmlToken::DoctypeToken(public_info) else {
    fail("expected doctype token")
  }
  assert_eq(public_info.name, "html")
  guard public_info.public_id is None else { fail("expected no public id") }
  assert_eq(public_info.force_quirks, true)
  let system_eof = @html_parser.parse(
    "<!doctype html SYSTEM",
    collect_errors=true,
  )
  assert_eq(
    system_eof.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body></body></html>",
  )
  assert_eq(system_eof.errors.length(), 1)
  assert_eq(
    system_eof.errors[0].code,
    "missing-quote-before-doctype-system-identifier",
  )
  guard system_eof.errors[0].column is Some(21) else {
    fail("expected missing system quote at EOF")
  }
  let system_unquoted = @html_parser.tokenize(
    "<!doctype html SYSTEM x>",
    collect_errors=true,
  )
  assert_eq(
    system_unquoted.errors[0].code,
    "missing-quote-before-doctype-system-identifier",
  )
  guard system_unquoted.tokens[0]
    is @html_parser.HtmlToken::DoctypeToken(system_info) else {
    fail("expected doctype token")
  }
  assert_eq(system_info.name, "html")
  guard system_info.system_id is None else { fail("expected no system id") }
  assert_eq(system_info.force_quirks, true)
}

///|
test "parser and tokenizer report post-public-identifier errors" {
  let missing_space = @html_parser.parse(
    "<!doctype html PUBLIC \"x\"",
    collect_errors=true,
  )
  assert_eq(
    missing_space.to_html(pretty=false),
    "<!DOCTYPE html PUBLIC \"x\"><html><head></head><body></body></html>",
  )
  assert_eq(missing_space.errors.length(), 2)
  assert_eq(
    missing_space.errors[0].code,
    "missing-whitespace-between-doctype-public-and-system-identifiers",
  )
  assert_eq(missing_space.errors[1].code, "unknown-doctype")
  guard missing_space.errors[0].column is Some(25) else {
    fail("expected missing whitespace error at EOF")
  }
  let unexpected = @html_parser.tokenize(
    "<!doctype html PUBLIC \"x\"x>",
    collect_errors=true,
  )
  assert_eq(
    unexpected.errors[0].code,
    "unexpected-character-after-doctype-public-identifier",
  )
  guard unexpected.tokens[0] is @html_parser.HtmlToken::DoctypeToken(info) else {
    fail("expected doctype token")
  }
  assert_eq(info.name, "html")
  guard info.public_id is Some("x") else { fail("expected public id") }
  assert_eq(info.force_quirks, true)
  let known = @html_parser.parse(
    "<!doctype html PUBLIC \"-//W3C//DTD HTML 4.01//EN\"x>",
    collect_errors=true,
  )
  assert_eq(known.errors.length(), 1)
  assert_eq(
    known.errors[0].code,
    "unexpected-character-after-doctype-public-identifier",
  )
}

///|
test "parser and tokenizer report system identifier tail errors" {
  let system_extra = @html_parser.tokenize(
    "<!doctype html SYSTEM \"x\"x>",
    collect_errors=true,
  )
  assert_eq(system_extra.errors.length(), 1)
  assert_eq(
    system_extra.errors[0].code,
    "unexpected-character-after-doctype-system-identifier",
  )
  guard system_extra.errors[0].column is Some(26) else {
    fail("expected system identifier tail error at trailing character")
  }
  guard system_extra.tokens[0]
    is @html_parser.HtmlToken::DoctypeToken(system_info) else {
    fail("expected doctype token")
  }
  guard system_info.system_id is Some("x") else { fail("expected system id") }
  assert_eq(system_info.force_quirks, false)
  let system_eof = @html_parser.tokenize(
    "<!doctype html SYSTEM \"x\"",
    collect_errors=true,
  )
  assert_eq(system_eof.errors.length(), 1)
  assert_eq(system_eof.errors[0].code, "eof-in-doctype")
  guard system_eof.tokens[0]
    is @html_parser.HtmlToken::DoctypeToken(system_eof_info) else {
    fail("expected doctype token")
  }
  guard system_eof_info.system_id is Some("x") else {
    fail("expected system id at EOF")
  }
  assert_eq(system_eof_info.force_quirks, true)
  let public_system_extra = @html_parser.parse(
    "<!doctype html PUBLIC \"p\" \"s\"x>",
    collect_errors=true,
  )
  assert_eq(
    public_system_extra.to_html(pretty=false),
    "<!DOCTYPE html PUBLIC \"p\" \"s\"><html><head></head><body></body></html>",
  )
  assert_eq(public_system_extra.errors.length(), 2)
  assert_eq(
    public_system_extra.errors[0].code,
    "unexpected-character-after-doctype-system-identifier",
  )
  guard public_system_extra.errors[0].column is Some(30) else {
    fail("expected public system tail error at trailing character")
  }
  assert_eq(public_system_extra.errors[1].code, "unknown-doctype")
  let fused = @html_parser.tokenize(
    "<!doctype html PUBLIC \"p\"\"s\"x>",
    collect_errors=true,
  )
  assert_eq(fused.errors.length(), 2)
  assert_eq(
    fused.errors[0].code,
    "missing-whitespace-between-doctype-public-and-system-identifiers",
  )
  assert_eq(
    fused.errors[1].code,
    "unexpected-character-after-doctype-system-identifier",
  )
  guard fused.errors[0].column is Some(26) else {
    fail("expected missing whitespace error at system quote")
  }
  guard fused.errors[1].column is Some(29) else {
    fail("expected fused system tail error at trailing character")
  }
  guard fused.tokens[0] is @html_parser.HtmlToken::DoctypeToken(fused_info) else {
    fail("expected fused doctype token")
  }
  guard fused_info.public_id is Some("p") else { fail("expected public id") }
  guard fused_info.system_id is Some("s") else { fail("expected system id") }
  assert_eq(fused_info.force_quirks, false)
  let immediate_public = @html_parser.parse(
    "<!doctype html PUBLIC\"x\">",
    collect_errors=true,
  )
  assert_eq(immediate_public.errors.length(), 2)
  assert_eq(
    immediate_public.errors[0].code,
    "missing-whitespace-before-doctype-public-identifier",
  )
  guard immediate_public.errors[0].column is Some(22) else {
    fail("expected missing whitespace before public identifier")
  }
  assert_eq(immediate_public.errors[1].code, "unknown-doctype")
}

///|
test "document parser reports missing initial doctype" {
  let chars = @html_parser.parse("x", collect_errors=true)
  assert_eq(
    chars.to_html(pretty=false),
    "<html><head></head><body>x</body></html>",
  )
  assert_eq(chars.errors.length(), 1)
  assert_eq(chars.errors[0].code, "expected-doctype-but-got-chars")
  guard chars.errors[0].column is Some(1) else {
    fail("expected character doctype error at first column")
  }
  let start = @html_parser.parse("<div>x", collect_errors=true)
  assert_eq(
    start.to_html(pretty=false),
    "<html><head></head><body><div>x</div></body></html>",
  )
  assert_eq(start.errors.length(), 2)
  assert_eq(start.errors[0].code, "expected-doctype-but-got-start-tag")
  assert_eq(start.errors[1].code, "expected-closing-tag-but-got-eof")
  guard start.errors[0].column is Some(5) else {
    fail("expected start tag doctype error at tag close")
  }
  let after_comment = @html_parser.parse("<!--c--><div>x", collect_errors=true)
  assert_eq(
    after_comment.to_html(pretty=false),
    "<!--c--><html><head></head><body><div>x</div></body></html>",
  )
  assert_eq(after_comment.errors[0].code, "expected-doctype-but-got-start-tag")
  guard after_comment.errors[0].column is Some(13) else {
    fail("expected doctype error after initial comment")
  }
  let whitespace_eof = @html_parser.parse("   ", collect_errors=true)
  assert_eq(
    whitespace_eof.to_html(pretty=false),
    "<html><head></head><body></body></html>",
  )
  assert_eq(whitespace_eof.errors.length(), 1)
  assert_eq(whitespace_eof.errors[0].code, "expected-doctype-but-got-eof")
  guard whitespace_eof.errors[0].column is Some(3) else {
    fail("expected EOF doctype error at final whitespace")
  }
  let empty = @html_parser.parse("", collect_errors=true)
  assert_eq(empty.errors[0].code, "expected-doctype-but-got-eof")
  guard empty.errors[0].column is Some(0) else {
    fail("expected empty input EOF at column zero")
  }
  let unfinished_start = @html_parser.parse("<div foo=\"", collect_errors=true)
  assert_eq(
    unfinished_start.to_html(pretty=false),
    "<html><head></head><body></body></html>",
  )
  assert_eq(unfinished_start.errors.length(), 2)
  assert_eq(unfinished_start.errors[0].code, "eof-in-tag")
  assert_eq(unfinished_start.errors[1].code, "expected-doctype-but-got-eof")
  guard unfinished_start.errors[1].column is Some(10) else {
    fail("expected doctype EOF after unfinished start tag")
  }
  let unfinished_end = @html_parser.parse("</span", collect_errors=true)
  assert_eq(
    unfinished_end.to_html(pretty=false),
    "<html><head></head><body></body></html>",
  )
  assert_eq(unfinished_end.errors.length(), 2)
  assert_eq(unfinished_end.errors[0].code, "eof-in-tag")
  assert_eq(unfinished_end.errors[1].code, "expected-doctype-but-got-eof")
  guard unfinished_end.errors[1].column is Some(6) else {
    fail("expected doctype EOF after unfinished end tag")
  }
  let unfinished_comment = @html_parser.parse("<!--x", collect_errors=true)
  assert_eq(
    unfinished_comment.to_html(pretty=false),
    "<!--x--><html><head></head><body></body></html>",
  )
  assert_eq(unfinished_comment.errors.length(), 2)
  assert_eq(unfinished_comment.errors[0].code, "eof-in-comment")
  assert_eq(unfinished_comment.errors[1].code, "expected-doctype-but-got-eof")
  guard unfinished_comment.errors[0].column is Some(5) else {
    fail("expected unfinished comment EOF at final character")
  }
  guard unfinished_comment.errors[1].column is Some(5) else {
    fail("expected doctype EOF after unfinished comment")
  }
  let bogus_question = @html_parser.parse("<?foo", collect_errors=true)
  assert_eq(
    bogus_question.to_html(pretty=false),
    "<!--?foo--><html><head></head><body></body></html>",
  )
  assert_eq(bogus_question.errors.length(), 2)
  assert_eq(
    bogus_question.errors[0].code,
    "unexpected-question-mark-instead-of-tag-name",
  )
  assert_eq(bogus_question.errors[1].code, "expected-doctype-but-got-eof")
  guard bogus_question.errors[0].column is Some(2) else {
    fail("expected question-mark error at column 2")
  }
  guard bogus_question.errors[1].column is Some(5) else {
    fail("expected doctype EOF after bogus question-mark comment")
  }
  let question_then_text = @html_parser.parse("<?foo>x", collect_errors=true)
  assert_eq(
    question_then_text.to_html(pretty=false),
    "<!--?foo--><html><head></head><body>x</body></html>",
  )
  assert_eq(question_then_text.errors.length(), 2)
  assert_eq(
    question_then_text.errors[0].code,
    "unexpected-question-mark-instead-of-tag-name",
  )
  assert_eq(question_then_text.errors[1].code, "expected-doctype-but-got-chars")
  guard question_then_text.errors[1].column is Some(7) else {
    fail("expected doctype chars after closed bogus question-mark comment")
  }
  let malformed_declaration = @html_parser.parse("<!foo>", collect_errors=true)
  assert_eq(
    malformed_declaration.to_html(pretty=false),
    "<!--foo--><html><head></head><body></body></html>",
  )
  assert_eq(malformed_declaration.errors.length(), 2)
  assert_eq(malformed_declaration.errors[0].code, "incorrectly-opened-comment")
  assert_eq(
    malformed_declaration.errors[1].code,
    "expected-doctype-but-got-eof",
  )
  guard malformed_declaration.errors[0].column is Some(2) else {
    fail("expected malformed declaration error at bang")
  }
  guard malformed_declaration.errors[1].column is Some(6) else {
    fail("expected doctype EOF after malformed declaration")
  }
  let cdata_then_text = @html_parser.parse("<![CDATA[]]>x", collect_errors=true)
  assert_eq(
    cdata_then_text.to_html(pretty=false),
    "<!--[CDATA[]]--><html><head></head><body>x</body></html>",
  )
  assert_eq(cdata_then_text.errors.length(), 2)
  assert_eq(cdata_then_text.errors[0].code, "cdata-in-html-content")
  assert_eq(cdata_then_text.errors[1].code, "expected-doctype-but-got-chars")
  guard cdata_then_text.errors[0].column is Some(9) else {
    fail("expected cdata error at opening bracket")
  }
  guard cdata_then_text.errors[1].column is Some(13) else {
    fail("expected doctype chars after HTML cdata bogus comment")
  }
  let empty_end = @html_parser.parse("</>", collect_errors=true)
  assert_eq(
    empty_end.to_html(pretty=false),
    "<html><head></head><body></body></html>",
  )
  assert_eq(empty_end.errors.length(), 2)
  assert_eq(empty_end.errors[0].code, "empty-end-tag")
  assert_eq(empty_end.errors[1].code, "expected-doctype-but-got-eof")
  guard empty_end.errors[0].column is Some(3) else {
    fail("expected empty end tag error at >")
  }
  guard empty_end.errors[1].column is Some(3) else {
    fail("expected doctype EOF after empty end tag")
  }
}

///|
test "parser reports unknown and unexpected doctypes" {
  let unknown = @html_parser.parse("<!DOCTYPE svg><p>x", collect_errors=true)
  assert_eq(
    unknown.to_html(pretty=false),
    "<!DOCTYPE svg><html><head></head><body><p>x</p></body></html>",
  )
  assert_eq(unknown.errors.length(), 1)
  assert_eq(unknown.errors[0].code, "unknown-doctype")
  guard unknown.errors[0].column is Some(14) else {
    fail("expected unknown doctype at close bracket")
  }
  let unknown_public = @html_parser.parse(
    "<!doctype html PUBLIC \"x\">",
    collect_errors=true,
  )
  assert_eq(unknown_public.errors.length(), 1)
  assert_eq(unknown_public.errors[0].code, "unknown-doctype")
  guard unknown_public.errors[0].column is Some(26) else {
    fail("expected unknown public doctype at close bracket")
  }
  let legacy_system = @html_parser.parse(
    "<!doctype html SYSTEM \"about:legacy-compat\">",
    collect_errors=true,
  )
  assert_eq(legacy_system.errors.length(), 0)
  let repeated = @html_parser.parse(
    "<!doctype html><!doctype html><p>x",
    collect_errors=true,
  )
  assert_eq(
    repeated.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body><p>x</p></body></html>",
  )
  assert_eq(repeated.errors.length(), 1)
  assert_eq(repeated.errors[0].code, "unexpected-doctype")
  guard repeated.errors[0].column is Some(30) else {
    fail("expected unexpected doctype at second close bracket")
  }
  let fragment = @html_parser.parse_fragment(
    "<!doctype html><p>x",
    collect_errors=true,
  )
  assert_eq(fragment.to_html(pretty=false), "<p>x</p>")
  assert_eq(fragment.errors.length(), 1)
  assert_eq(fragment.errors[0].code, "unexpected-doctype")
}

///|
test "parser cursor advances by unicode character length" {
  let doc = @html_parser.parse_fragment("<p>😀 &lt; ok</p>")
  assert_eq(doc.to_html(pretty=false), "<p>😀 &lt; ok</p>")
  assert_eq(doc.to_text(separator="", strip=false), "😀 < ok")
}

///|
test "fragment context seeds literal text modes" {
  let textarea = @html_parser.parse_fragment(
    "<b>x</b>&lt;",
    context=@html_parser.FragmentContext::new("textarea"),
  )
  assert_eq(textarea.to_html(pretty=false), "&lt;b&gt;x&lt;/b&gt;&amp;lt;")
  assert_eq(textarea.to_text(separator="", strip=false), "<b>x</b>&lt;")
  assert_eq(textarea.query("b").length(), 0)
  let after_end = @html_parser.parse_fragment(
    "a</textarea><b>x</b>",
    context=@html_parser.FragmentContext::new("textarea"),
    collect_errors=true,
  )
  assert_eq(after_end.to_html(pretty=false), "a<b>x</b>")
  assert_eq(after_end.errors[0].code, "unexpected-end-tag")
  let script = @html_parser.parse_fragment(
    "a</script><b>x</b>",
    context=@html_parser.FragmentContext::new("script"),
  )
  assert_eq(
    script.to_html(pretty=false),
    "a&lt;/script&gt;&lt;b&gt;x&lt;/b&gt;",
  )
  assert_eq(script.query("b").length(), 0)
  let div = @html_parser.parse_fragment(
    "<b>x</b>",
    context=@html_parser.FragmentContext::new("div"),
  )
  assert_eq(div.to_html(pretty=false), "<b>x</b>")
}

///|
test "query supports tag class id and tag class selectors" {
  let doc = @html_parser.parse_fragment(
    "<div><p id='first' class='intro lead'>One</p><p>Two</p></div>",
  )
  assert_eq(doc.query("p").length(), 2)
  assert_eq(doc.query(".intro").length(), 1)
  assert_eq(doc.query("#first").length(), 1)
  let first = doc.query_one("p.lead")
  guard first is Some(node) else { fail("expected p.lead") }
  assert_eq(node.to_text(separator="", strip=false), "One")
}

///|
test "collect_errors records malformed markup without raising" {
  let doc = @html_parser.parse_fragment("<p>open</span>", collect_errors=true)
  assert_eq(doc.errors.length(), 1)
  assert_eq(doc.errors[0].code, "unexpected-end-tag")
  assert_eq(doc.to_html(pretty=false), "<p>open</p>")
  let invalid_open = @html_parser.parse_fragment("<*foo>", collect_errors=true)
  assert_eq(invalid_open.to_html(pretty=false), "&lt;*foo&gt;")
  assert_eq(invalid_open.errors.length(), 1)
  assert_eq(invalid_open.errors[0].code, "invalid-first-character-of-tag-name")
  guard invalid_open.errors[0].column is Some(2) else {
    fail("expected invalid tag-open error at second character")
  }
  let empty_end = @html_parser.parse_fragment("</>", collect_errors=true)
  assert_eq(empty_end.to_html(pretty=false), "")
  assert_eq(empty_end.errors.length(), 1)
  assert_eq(empty_end.errors[0].code, "empty-end-tag")
  guard empty_end.errors[0].column is Some(3) else {
    fail("expected empty end tag error at >")
  }
  let invalid_end = @html_parser.parse_fragment("</ >", collect_errors=true)
  assert_eq(invalid_end.to_html(pretty=false), "<!-- -->")
  assert_eq(invalid_end.errors.length(), 1)
  assert_eq(invalid_end.errors[0].code, "invalid-first-character-of-tag-name")
  guard invalid_end.errors[0].column is Some(3) else {
    fail("expected invalid end tag error after slash")
  }
  let lt = @html_parser.parse_fragment("<", collect_errors=true)
  assert_eq(lt.to_html(pretty=false), "&lt;")
  assert_eq(lt.errors.length(), 1)
  assert_eq(lt.errors[0].code, "eof-before-tag-name")
  guard lt.errors[0].column is Some(1) else {
    fail("expected bare < EOF at the < character")
  }
  let end_open = @html_parser.parse_fragment("</", collect_errors=true)
  assert_eq(end_open.to_html(pretty=false), "&lt;/")
  assert_eq(end_open.errors.length(), 1)
  assert_eq(end_open.errors[0].code, "eof-before-tag-name")
  guard end_open.errors[0].column is Some(2) else {
    fail("expected bare </ EOF at the slash")
  }
}

///|
test "parser ignores unmatched end tags without closing current element" {
  let doc = @html_parser.parse_fragment(
    "<div><p>open</span>after</div>",
    collect_errors=true,
  )
  assert_eq(doc.errors.length(), 1)
  assert_eq(doc.errors[0].code, "unexpected-end-tag")
  assert_eq(doc.to_html(pretty=false), "<div><p>openafter</p></div>")
}

///|
test "parser creates empty paragraph for stray p end tags" {
  let root = @html_parser.parse_fragment("</p>after", collect_errors=true)
  assert_eq(root.to_html(pretty=false), "<p></p>after")
  assert_eq(root.errors.length(), 1)
  assert_eq(root.errors[0].code, "unexpected-end-tag")
  let nested = @html_parser.parse_fragment("<div></p>after</div>")
  assert_eq(nested.to_html(pretty=false), "<div><p></p>after</div>")
}

///|
test "parser reports early ancestor end tags after implied end tags" {
  let implied = @html_parser.parse_fragment(
    "<div><p>x</div>after",
    collect_errors=true,
  )
  assert_eq(implied.to_html(pretty=false), "<div><p>x</p></div>after")
  assert_eq(implied.errors.length(), 0)
  let early = @html_parser.parse_fragment(
    "<div><span>x</div>after",
    collect_errors=true,
  )
  assert_eq(early.to_html(pretty=false), "<div><span>x</span></div>after")
  assert_eq(early.errors.length(), 1)
  assert_eq(early.errors[0].code, "end-tag-too-early")
}

///|
test "parser reports EOF for unclosed non-implied elements" {
  let unfinished_start = @html_parser.parse_fragment(
    "<div foo=\"",
    collect_errors=true,
  )
  assert_eq(unfinished_start.to_html(pretty=false), "")
  assert_eq(unfinished_start.errors.length(), 1)
  assert_eq(unfinished_start.errors[0].code, "eof-in-tag")
  guard unfinished_start.errors[0].column is Some(10) else {
    fail("expected incomplete start tag EOF at final quote")
  }
  let unfinished_end = @html_parser.parse_fragment(
    "<p>x</span",
    collect_errors=true,
  )
  assert_eq(unfinished_end.to_html(pretty=false), "<p>x</p>")
  assert_eq(unfinished_end.errors.length(), 1)
  assert_eq(unfinished_end.errors[0].code, "eof-in-tag")
  guard unfinished_end.errors[0].column is Some(10) else {
    fail("expected incomplete end tag EOF at final name character")
  }
  let div = @html_parser.parse_fragment("<div>x", collect_errors=true)
  assert_eq(div.to_html(pretty=false), "<div>x</div>")
  assert_eq(div.errors.length(), 1)
  assert_eq(div.errors[0].code, "expected-closing-tag-but-got-eof")
  guard div.errors[0].column is Some(6) else {
    fail("expected EOF error at final input column")
  }
  let paragraph = @html_parser.parse_fragment("<p>x", collect_errors=true)
  assert_eq(paragraph.to_html(pretty=false), "<p>x</p>")
  assert_eq(paragraph.errors.length(), 0)
  let list = @html_parser.parse_fragment("<ul><li>x", collect_errors=true)
  assert_eq(list.to_html(pretty=false), "<ul><li>x</li></ul>")
  assert_eq(list.errors.length(), 1)
  assert_eq(list.errors[0].code, "expected-closing-tag-but-got-eof")
  guard list.errors[0].column is Some(9) else {
    fail("expected list EOF error at final input column")
  }
  let doc = @html_parser.parse("<!doctype html><div>x", collect_errors=true)
  assert_eq(
    doc.to_html(pretty=false),
    "<!DOCTYPE html><html><head></head><body><div>x</div></body></html>",
  )
  assert_eq(doc.errors.length(), 1)
  assert_eq(doc.errors[0].code, "expected-closing-tag-but-got-eof")
  let unicode_tail = @html_parser.parse_fragment(
    "<div>😀",
    collect_errors=true,
  )
  assert_eq(unicode_tail.errors[0].code, "expected-closing-tag-but-got-eof")
  guard unicode_tail.errors[0].column is Some(6) else {
    fail("expected EOF position to use the final character boundary")
  }
}

///|
test "parser reports EOF in unfinished tables" {
  let table = @html_parser.parse_fragment(
    "<table><tr><td>x",
    collect_errors=true,
  )
  assert_eq(
    table.to_html(pretty=false),
    "<table><tbody><tr><td>x</td></tr></tbody></table>",
  )
  assert_eq(table.errors.length(), 1)
  assert_eq(table.errors[0].code, "eof-in-table")
  guard table.errors[0].column is Some(16) else {
    fail("expected table EOF error at final input column")
  }
}

///|
test "parser closes open paragraphs before paragraph and block starts" {
  let fragment = @html_parser.parse_fragment("<p>one<p>two<div>three</div>")
  assert_eq(
    fragment.to_html(pretty=false),
    "<p>one</p><p>two</p><div>three</div>",
  )
  let doc = @html_parser.parse("<p>one<div>two</div>")
  assert_eq(
    doc.to_html(pretty=false),
    "<html><head></head><body><p>one</p><div>two</div></body></html>",
  )
}

///|
test "parser closes open list items before repeated li starts" {
  let fragment = @html_parser.parse_fragment(
    "<ul><li>one<li><p>two<li>three</ul>",
  )
  assert_eq(
    fragment.to_html(pretty=false),
    "<ul><li>one</li><li><p>two</p></li><li>three</li></ul>",
  )
  let loose = @html_parser.parse_fragment("<li>loose<li>item")
  assert_eq(loose.to_html(pretty=false), "<li>loose</li><li>item</li>")
}

///|
test "parser closes open definition items before repeated dt and dd starts" {
  let fragment = @html_parser.parse_fragment(
    "<dl><dt>term<dt>next<dd><p>def<dd>again</dl>",
  )
  assert_eq(
    fragment.to_html(pretty=false),
    "<dl><dt>term</dt><dt>next</dt><dd><p>def</p></dd><dd>again</dd></dl>",
  )
  let loose = @html_parser.parse_fragment("<dt>term<dd>def<dt>next")
  assert_eq(
    loose.to_html(pretty=false),
    "<dt>term</dt><dd>def</dd><dt>next</dt>",
  )
}

///|
test "parser closes repeated option and select optgroup starts" {
  let options = @html_parser.parse_fragment(
    "<select><option>one<option>two</select>",
  )
  assert_eq(
    options.to_html(pretty=false),
    "<select><option>one</option><option>two</option></select>",
  )
  let groups = @html_parser.parse_fragment(
    "<select><optgroup><option>one<optgroup><option>two</select>",
  )
  assert_eq(
    groups.to_html(pretty=false),
    "<select><optgroup><option>one</option></optgroup><optgroup><option>two</option></optgroup></select>",
  )
}

///|
test "parser inserts basic table row groups and rows" {
  let rows = @html_parser.parse_fragment("<table><tr><td>x</td></tr></table>")
  assert_eq(
    rows.to_html(pretty=false),
    "<table><tbody><tr><td>x</td></tr></tbody></table>",
  )
  let cells = @html_parser.parse_fragment("<table><td>x<td>y</table>")
  assert_eq(
    cells.to_html(pretty=false),
    "<table><tbody><tr><td>x</td><td>y</td></tr></tbody></table>",
  )
  let after_head = @html_parser.parse_fragment(
    "<table><thead><tr><td>h</td></tr></thead><tr><td>b</td></tr></table>",
  )
  assert_eq(
    after_head.to_html(pretty=false),
    "<table><thead><tr><td>h</td></tr></thead><tbody><tr><td>b</td></tr></tbody></table>",
  )
  let section_cells = @html_parser.parse_fragment(
    "<table><tbody><td>x<th>y</tbody></table>",
  )
  assert_eq(
    section_cells.to_html(pretty=false),
    "<table><tbody><tr><td>x</td><th>y</th></tr></tbody></table>",
  )
}

///|
test "parser closes current heading before another heading start" {
  let fragment = @html_parser.parse_fragment("<p>intro<h1>head<h2>next")
  assert_eq(
    fragment.to_html(pretty=false),
    "<p>intro</p><h1>head</h1><h2>next</h2>",
  )
  let nested_block = @html_parser.parse_fragment("<h1>head<div>body</div>")
  assert_eq(nested_block.to_html(pretty=false), "<h1>head<div>body</div></h1>")
}

///|
test "parser closes open headings for mismatched heading end tags" {
  let doc = @html_parser.parse_fragment(
    "<h1><span>one</h2>after",
    collect_errors=true,
  )
  assert_eq(doc.to_html(pretty=false), "<h1><span>one</span></h1>after")
  assert_eq(doc.errors.length(), 1)
  assert_eq(doc.errors[0].code, "end-tag-too-early")
  let stray = @html_parser.parse_fragment("</h1>after", collect_errors=true)
  assert_eq(stray.to_html(pretty=false), "after")
  assert_eq(stray.errors[0].code, "unexpected-end-tag")
}

///|
test "parser treats br end tags as recovered br elements" {
  let paragraph = @html_parser.parse_fragment(
    "<p>one</br>two",
    collect_errors=true,
  )
  assert_eq(paragraph.to_html(pretty=false), "<p>one</p><br>two")
  assert_eq(paragraph.errors.length(), 1)
  assert_eq(paragraph.errors[0].code, "unexpected-end-tag")
  let loose = @html_parser.parse_fragment("a</br>b")
  assert_eq(loose.to_html(pretty=false), "a<br>b")
}

///|
test "parser treats image start tags as img elements" {
  let doc = @html_parser.parse_fragment(
    "<p>a<image src=x>b</p>",
    collect_errors=true,
  )
  assert_eq(doc.to_html(pretty=false), "<p>a<img src=\"x\">b</p>")
  assert_eq(doc.errors.length(), 1)
  assert_eq(doc.errors[0].code, "image-start-tag")
  let loose = @html_parser.parse_fragment("<image>text</image>")
  assert_eq(loose.to_html(pretty=false), "<img>text")
}

///|
test "parser ignores self closing slash on non void html elements" {
  let div = @html_parser.parse_fragment("<div/>x")
  assert_eq(div.to_html(pretty=false), "<div>x</div>")
  let paragraph = @html_parser.parse_fragment("<p/>x")
  assert_eq(paragraph.to_html(pretty=false), "<p>x</p>")
  let script = @html_parser.parse_fragment("<script/>x</script>")
  assert_eq(script.to_html(pretty=false), "<script>x</script>")
  let voids = @html_parser.parse_fragment("<br/>x<img/>")
  assert_eq(voids.to_html(pretty=false), "<br>x<img>")
}

///|
test "strict mode raises on first parse error" {
  let result : Result[@html_parser.ParsedHtml, Error] = try? @html_parser.parse_fragment(
    "<p>open</span>",
    strict=true,
  )
  guard result is Err(_) else { fail("expected strict parse to raise") }
}

///|
test "parse_bytes decodes utf8 and records encoding" {
  let bytes = @utf8.encode("<p>bytes</p>")
  let doc = @html_parser.parse_bytes(bytes)
  assert_eq(
    doc.to_html(pretty=false),
    "<html><head></head><body><p>bytes</p></body></html>",
  )
  guard doc.encoding is Some("utf-8") else { fail("expected utf-8 encoding") }
}

///|
test "tokenize exposes stable token data structures" {
  let result = @html_parser.tokenize("<p class='x'>Hi<br><!--ok--></p>")
  assert_eq(result.tokens.length(), 6)
  guard result.tokens[0] is @html_parser.HtmlToken::Tag(start) else {
    fail("expected start tag")
  }
  assert_true(start.kind is @html_parser.TagKind::StartTag)
  assert_eq(start.name, "p")
  guard start.attrs["class"] is Some("x") else { fail("expected class attr") }
  guard result.tokens[1] is @html_parser.HtmlToken::Characters("Hi") else {
    fail("expected text token")
  }
  guard result.tokens[2] is @html_parser.HtmlToken::Tag(br) else {
    fail("expected br tag")
  }
  assert_eq(br.self_closing, false)
  guard result.tokens[3] is @html_parser.HtmlToken::CommentToken("ok") else {
    fail("expected comment token")
  }
  guard result.tokens[5] is @html_parser.HtmlToken::Eof else {
    fail("expected EOF")
  }
  let explicit = @html_parser.tokenize("<img/>")
  guard explicit.tokens[0] is @html_parser.HtmlToken::Tag(img) else {
    fail("expected img tag")
  }
  assert_eq(img.self_closing, true)
}

///|
test "entity decoding covers upstream fixture cases" {
  let numeric = @html_parser.parse_fragment("&#65")
  assert_eq(numeric.to_text(separator="", strip=false), "A")
  let control = @html_parser.parse_fragment("&#x80")
  assert_eq(control.to_text(separator="", strip=false), "\u{20AC}")
  let legacy = @html_parser.parse_fragment("&notit; &not &amp")
  assert_eq(legacy.to_text(separator="", strip=false), "¬it; ¬ &")
}

///|
test "tokenize preserves raw end tags before tree recovery" {
  let result = @html_parser.tokenize("<p>open</span>")
  assert_eq(result.tokens.length(), 4)
  guard result.tokens[0] is @html_parser.HtmlToken::Tag(start) else {
    fail("expected p start tag")
  }
  assert_true(start.kind is @html_parser.TagKind::StartTag)
  assert_eq(start.name, "p")
  guard result.tokens[2] is @html_parser.HtmlToken::Tag(end_tag) else {
    fail("expected raw span end tag")
  }
  assert_true(end_tag.kind is @html_parser.TagKind::EndTag)
  assert_eq(end_tag.name, "span")
}

///|
test "tokenize preserves end tag attributes and self closing solidus" {
  let self_closing = @html_parser.tokenize("</div/>", collect_errors=true)
  guard self_closing.tokens[0] is @html_parser.HtmlToken::Tag(tag) else {
    fail("expected end tag")
  }
  assert_true(tag.kind is @html_parser.TagKind::EndTag)
  assert_eq(tag.name, "div")
  assert_eq(tag.self_closing, true)
  assert_eq(self_closing.errors.length(), 0)
  let attrs = @html_parser.tokenize("</div attr=x>", collect_errors=true)
  guard attrs.tokens[0] is @html_parser.HtmlToken::Tag(attr_tag) else {
    fail("expected attributed end tag")
  }
  assert_true(attr_tag.kind is @html_parser.TagKind::EndTag)
  assert_eq(attr_tag.name, "div")
  guard attr_tag.attrs["attr"] is Some("x") else {
    fail("expected end tag attr")
  }
  assert_eq(attr_tag.self_closing, false)
  assert_eq(attrs.errors.length(), 0)
}

///|
test "parser matches end tags before self closing solidus" {
  let div = @html_parser.parse_fragment("<div>x</div/>y", collect_errors=true)
  assert_eq(div.to_html(pretty=false), "<div>x</div>y")
  assert_eq(div.errors.length(), 0)
  let script = @html_parser.tokenize("<script>x</script/>after")
  guard script.tokens[1] is @html_parser.HtmlToken::Characters("x") else {
    fail("expected script text before slash end tag")
  }
  guard script.tokens[2] is @html_parser.HtmlToken::Tag(end_script) else {
    fail("expected script end tag before slash")
  }
  assert_true(end_script.kind is @html_parser.TagKind::EndTag)
  assert_eq(end_script.name, "script")
  assert_eq(end_script.self_closing, true)
  guard script.tokens[3] is @html_parser.HtmlToken::Characters("after") else {
    fail("expected text after slash end tag")
  }
}

///|
test "tokenize reports malformed end tag errors when requested" {
  let result = @html_parser.tokenize("</>", collect_errors=true)
  assert_eq(result.tokens.length(), 1)
  assert_eq(result.errors.length(), 1)
  assert_eq(result.errors[0].code, "empty-end-tag")
  guard result.errors[0].column is Some(3) else {
    fail("expected empty end tag error at >")
  }
  let invalid = @html_parser.tokenize("</ >", collect_errors=true)
  guard invalid.tokens[0] is @html_parser.HtmlToken::CommentToken(" ") else {
    fail("expected invalid end tag as bogus comment")
  }
  assert_eq(invalid.errors.length(), 1)
  assert_eq(invalid.errors[0].code, "invalid-first-character-of-tag-name")
  guard invalid.errors[0].column is Some(3) else {
    fail("expected invalid end tag error after slash")
  }
}

///|
test "tokenize handles selected bogus comment fixture cases" {
  let processing = @html_parser.tokenize("<?foo>")
  guard processing.tokens[0] is @html_parser.HtmlToken::CommentToken("?foo") else {
    fail("expected bogus comment")
  }
  let invalid_end = @html_parser.tokenize("</?", collect_errors=true)
  guard invalid_end.tokens[0] is @html_parser.HtmlToken::CommentToken("?") else {
    fail("expected invalid end tag as bogus comment")
  }
  assert_eq(invalid_end.errors.length(), 1)
  assert_eq(invalid_end.errors[0].code, "invalid-first-character-of-tag-name")
  let question = @html_parser.tokenize("<?foo>", collect_errors=true)
  guard question.tokens[0] is @html_parser.HtmlToken::CommentToken("?foo") else {
    fail("expected question-mark markup as bogus comment")
  }
  assert_eq(question.errors.length(), 1)
  assert_eq(
    question.errors[0].code,
    "unexpected-question-mark-instead-of-tag-name",
  )
  guard question.errors[0].column is Some(2) else {
    fail("expected question-mark error at column 2")
  }
  let declaration = @html_parser.tokenize("<!foo>", collect_errors=true)
  guard declaration.tokens[0] is @html_parser.HtmlToken::CommentToken("foo") else {
    fail("expected malformed declaration as bogus comment")
  }
  assert_eq(declaration.errors.length(), 1)
  assert_eq(declaration.errors[0].code, "incorrectly-opened-comment")
  guard declaration.errors[0].column is Some(2) else {
    fail("expected malformed declaration error at bang")
  }
  let cdata = @html_parser.tokenize("<![CDATA[x]]>", collect_errors=true)
  guard cdata.tokens[0] is @html_parser.HtmlToken::CommentToken("[CDATA[x]]") else {
    fail("expected HTML CDATA as bogus comment")
  }
  assert_eq(cdata.errors.length(), 1)
  assert_eq(cdata.errors[0].code, "cdata-in-html-content")
  guard cdata.errors[0].column is Some(9) else {
    fail("expected cdata error at opening bracket")
  }
  let invalid_open = @html_parser.tokenize("<*foo>", collect_errors=true)
  assert_eq(invalid_open.tokens.length(), 2)
  guard invalid_open.tokens[0] is @html_parser.HtmlToken::Characters("<*foo>") else {
    fail("expected invalid tag-open sequence as text")
  }
  guard invalid_open.tokens[1] is @html_parser.HtmlToken::Eof else {
    fail("expected EOF after invalid tag-open text")
  }
  assert_eq(invalid_open.errors.length(), 1)
  assert_eq(invalid_open.errors[0].code, "invalid-first-character-of-tag-name")
  guard invalid_open.errors[0].column is Some(2) else {
    fail("expected invalid tag-open error at second character")
  }
}

///|
test "tokenize replaces nulls in bogus comment data" {
  let question = @html_parser.tokenize("<?a\u{0000}b>", collect_errors=true)
  guard question.tokens[0]
    is @html_parser.HtmlToken::CommentToken("?a\u{FFFD}b") else {
    fail("expected replacement char in question-mark bogus comment")
  }
  assert_eq(question.errors.length(), 1)
  assert_eq(
    question.errors[0].code,
    "unexpected-question-mark-instead-of-tag-name",
  )
  let declaration = @html_parser.tokenize("<!a\u{0000}b>", collect_errors=true)
  guard declaration.tokens[0]
    is @html_parser.HtmlToken::CommentToken("a\u{FFFD}b") else {
    fail("expected replacement char in malformed declaration")
  }
  assert_eq(declaration.errors.length(), 1)
  assert_eq(declaration.errors[0].code, "incorrectly-opened-comment")
  let cdata = @html_parser.tokenize(
    "<![CDATA[a\u{0000}b]]>",
    collect_errors=true,
  )
  guard cdata.tokens[0]
    is @html_parser.HtmlToken::CommentToken("[CDATA[a\u{FFFD}b]]") else {
    fail("expected replacement char in HTML CDATA bogus comment")
  }
  assert_eq(cdata.errors.length(), 1)
  assert_eq(cdata.errors[0].code, "cdata-in-html-content")
}

///|
test "parser replaces nulls in bogus comment data" {
  let question = @html_parser.parse_fragment(
    "<?a\u{0000}b>",
    collect_errors=true,
  )
  assert_eq(question.to_html(pretty=false), "<!--?a\u{FFFD}b-->")
  assert_eq(question.errors.length(), 1)
  assert_eq(
    question.errors[0].code,
    "unexpected-question-mark-instead-of-tag-name",
  )
  let declaration = @html_parser.parse_fragment(
    "<!a\u{0000}b>",
    collect_errors=true,
  )
  assert_eq(declaration.to_html(pretty=false), "<!--a\u{FFFD}b-->")
  assert_eq(declaration.errors.length(), 1)
  assert_eq(declaration.errors[0].code, "incorrectly-opened-comment")
}

///|
test "tokenize reports abrupt closing of empty comments" {
  let simple = @html_parser.tokenize("<!-->", collect_errors=true)
  guard simple.tokens[0] is @html_parser.HtmlToken::CommentToken("") else {
    fail("expected empty comment")
  }
  assert_eq(simple.errors.length(), 1)
  assert_eq(simple.errors[0].code, "abrupt-closing-of-empty-comment")
  guard simple.errors[0].column is Some(5) else {
    fail("expected abrupt empty comment at >")
  }
  let dash = @html_parser.tokenize("<!--->", collect_errors=true)
  guard dash.tokens[0] is @html_parser.HtmlToken::CommentToken("") else {
    fail("expected empty dash comment")
  }
  assert_eq(dash.errors.length(), 1)
  assert_eq(dash.errors[0].code, "abrupt-closing-of-empty-comment")
  guard dash.errors[0].column is Some(6) else {
    fail("expected abrupt empty dash comment at >")
  }
}

///|
test "parser reports abrupt closing of empty comments" {
  let simple = @html_parser.parse_fragment("<!-->", collect_errors=true)
  assert_eq(simple.to_html(pretty=false), "<!---->")
  assert_eq(simple.errors.length(), 1)
  assert_eq(simple.errors[0].code, "abrupt-closing-of-empty-comment")
  guard simple.errors[0].column is Some(5) else {
    fail("expected abrupt empty comment at >")
  }
  let dash = @html_parser.parse_fragment("<!--->", collect_errors=true)
  assert_eq(dash.to_html(pretty=false), "<!---->")
  assert_eq(dash.errors.length(), 1)
  assert_eq(dash.errors[0].code, "abrupt-closing-of-empty-comment")
  guard dash.errors[0].column is Some(6) else {
    fail("expected abrupt empty dash comment at >")
  }
}

///|
test "tokenize reports incorrectly closed comments" {
  let bang = @html_parser.tokenize("<!--x--!>", collect_errors=true)
  guard bang.tokens[0] is @html_parser.HtmlToken::CommentToken("x") else {
    fail("expected bang-closed comment")
  }
  assert_eq(bang.errors.length(), 1)
  assert_eq(bang.errors[0].code, "incorrectly-closed-comment")
  guard bang.errors[0].column is Some(9) else {
    fail("expected bang close error at >")
  }
  let text = @html_parser.tokenize("<!--x--y-->", collect_errors=true)
  guard text.tokens[0] is @html_parser.HtmlToken::CommentToken("x--y") else {
    fail("expected recovered comment data")
  }
  assert_eq(text.errors.length(), 1)
  assert_eq(text.errors[0].code, "incorrectly-closed-comment")
  guard text.errors[0].column is Some(8) else {
    fail("expected comment close error at reconsumed text")
  }
}

///|
test "parser reports incorrectly closed comments" {
  let bang = @html_parser.parse_fragment("<!--x--!>", collect_errors=true)
  assert_eq(bang.to_html(pretty=false), "<!--x-->")
  assert_eq(bang.errors.length(), 1)
  assert_eq(bang.errors[0].code, "incorrectly-closed-comment")
  guard bang.errors[0].column is Some(9) else {
    fail("expected bang close error at >")
  }
  let text = @html_parser.parse_fragment("<!--x--y-->", collect_errors=true)
  assert_eq(text.to_html(pretty=false), "<!--x- -y-->")
  assert_eq(text.errors.length(), 1)
  assert_eq(text.errors[0].code, "incorrectly-closed-comment")
  guard text.errors[0].column is Some(8) else {
    fail("expected comment close error at reconsumed text")
  }
}

///|
test "tokenize reports selected EOF and null fixture errors" {
  let lt = @html_parser.tokenize("<", collect_errors=true)
  guard lt.tokens[0] is @html_parser.HtmlToken::Characters("<") else {
    fail("expected literal <")
  }
  assert_eq(lt.errors[0].code, "eof-before-tag-name")
  guard lt.errors[0].column is Some(1) else {
    fail("expected bare < EOF at the < character")
  }
  let end_open = @html_parser.tokenize("</", collect_errors=true)
  guard end_open.tokens[0] is @html_parser.HtmlToken::Characters("</") else {
    fail("expected literal </")
  }
  assert_eq(end_open.errors[0].code, "eof-before-tag-name")
  guard end_open.errors[0].column is Some(2) else {
    fail("expected bare </ EOF at the slash")
  }
  let unfinished_start = @html_parser.tokenize(
    "<div foo=\"",
    collect_errors=true,
  )
  assert_eq(unfinished_start.tokens.length(), 1)
  guard unfinished_start.tokens[0] is @html_parser.HtmlToken::Eof else {
    fail("expected only EOF token for incomplete quoted tag")
  }
  assert_eq(unfinished_start.errors.length(), 1)
  assert_eq(unfinished_start.errors[0].code, "eof-in-tag")
  guard unfinished_start.errors[0].column is Some(10) else {
    fail("expected incomplete quoted tag EOF at final quote")
  }
  let unfinished_unquoted = @html_parser.tokenize(
    "<div foo=bar",
    collect_errors=true,
  )
  assert_eq(unfinished_unquoted.tokens.length(), 1)
  guard unfinished_unquoted.tokens[0] is @html_parser.HtmlToken::Eof else {
    fail("expected only EOF token for incomplete unquoted tag")
  }
  assert_eq(unfinished_unquoted.errors.length(), 1)
  assert_eq(unfinished_unquoted.errors[0].code, "eof-in-tag")
  guard unfinished_unquoted.errors[0].column is Some(12) else {
    fail("expected incomplete unquoted tag EOF at final value character")
  }
  let unfinished_end = @html_parser.tokenize("</span", collect_errors=true)
  assert_eq(unfinished_end.tokens.length(), 1)
  guard unfinished_end.tokens[0] is @html_parser.HtmlToken::Eof else {
    fail("expected only EOF token for incomplete end tag")
  }
  assert_eq(unfinished_end.errors.length(), 1)
  assert_eq(unfinished_end.errors[0].code, "eof-in-tag")
  guard unfinished_end.errors[0].column is Some(6) else {
    fail("expected incomplete end tag EOF at final name character")
  }
  let unfinished_comment = @html_parser.tokenize("<!--x", collect_errors=true)
  assert_eq(unfinished_comment.tokens.length(), 2)
  guard unfinished_comment.tokens[0]
    is @html_parser.HtmlToken::CommentToken("x") else {
    fail("expected comment token before EOF")
  }
  guard unfinished_comment.tokens[1] is @html_parser.HtmlToken::Eof else {
    fail("expected EOF after unfinished comment token")
  }
  assert_eq(unfinished_comment.errors.length(), 1)
  assert_eq(unfinished_comment.errors[0].code, "eof-in-comment")
  guard unfinished_comment.errors[0].column is Some(5) else {
    fail("expected unfinished comment EOF at final character")
  }
  let nul_text = @html_parser.tokenize("a\u{0000}b", collect_errors=true)
  guard nul_text.tokens[0] is @html_parser.HtmlToken::Characters("a\u{0000}b") else {
    fail("expected null-preserving text")
  }
  assert_eq(nul_text.errors[0].code, "unexpected-null-character")
  guard nul_text.errors[0].column is Some(2) else {
    fail("expected null text at column 2")
  }
  let nul_attr = @html_parser.tokenize(
    "<div foo=\"a\u{0000}b\">",
    collect_errors=true,
  )
  guard nul_attr.tokens[0] is @html_parser.HtmlToken::Tag(tag) else {
    fail("expected div tag")
  }
  guard tag.attrs["foo"] is Some("a\u{FFFD}b") else {
    fail("expected replacement char in attr")
  }
  assert_eq(nul_attr.errors[0].code, "unexpected-null-character")
  let nul_attr_name = @html_parser.tokenize(
    "<div a\u{0000}b='c'>",
    collect_errors=true,
  )
  guard nul_attr_name.tokens[0] is @html_parser.HtmlToken::Tag(attr_name_tag) else {
    fail("expected div tag")
  }
  guard attr_name_tag.attrs["a\u{FFFD}b"] is Some("c") else {
    fail("expected replacement char in attr name")
  }
  assert_eq(nul_attr_name.errors.length(), 1)
  assert_eq(nul_attr_name.errors[0].code, "unexpected-null-character")
  guard nul_attr_name.errors[0].column is Some(7) else {
    fail("expected null attr name at column 7")
  }
  let nul_tag_name = @html_parser.tokenize(
    "<script\u{0000}>x</script>",
    collect_errors=true,
  )
  guard nul_tag_name.tokens[0] is @html_parser.HtmlToken::Tag(start) else {
    fail("expected script start tag")
  }
  assert_eq(start.name, "script\u{FFFD}")
  guard nul_tag_name.tokens[1] is @html_parser.HtmlToken::Characters("x") else {
    fail("expected text after null-mutated script tag")
  }
  guard nul_tag_name.tokens[2] is @html_parser.HtmlToken::Tag(end_tag) else {
    fail("expected script end tag")
  }
  assert_true(end_tag.kind is @html_parser.TagKind::EndTag)
  assert_eq(end_tag.name, "script")
  assert_eq(nul_tag_name.errors.length(), 1)
  assert_eq(nul_tag_name.errors[0].code, "unexpected-null-character")
  guard nul_tag_name.errors[0].column is Some(8) else {
    fail("expected null tag name at column 8")
  }
}

///|
test "tokenize reports missing attribute value fixture errors" {
  let bare = @html_parser.tokenize("<div attr>", collect_errors=true)
  guard bare.tokens[0] is @html_parser.HtmlToken::Tag(bare_tag) else {
    fail("expected div tag")
  }
  guard bare_tag.attrs["attr"] is Some("") else {
    fail("expected empty attr without error")
  }
  assert_eq(bare.errors.length(), 0)
  let simple = @html_parser.tokenize("<div attr=>", collect_errors=true)
  guard simple.tokens[0] is @html_parser.HtmlToken::Tag(tag) else {
    fail("expected div tag")
  }
  guard tag.attrs["attr"] is Some("") else { fail("expected empty attr value") }
  assert_eq(simple.errors[0].code, "missing-attribute-value")
  guard simple.errors[0].column is Some(11) else {
    fail("expected missing value at column 11")
  }
  let crlf = @html_parser.tokenize("<div attr=\r\n>", collect_errors=true)
  assert_eq(crlf.errors[0].code, "missing-attribute-value")
  guard crlf.errors[0].line is Some(2) else {
    fail("expected CRLF normalized line")
  }
  guard crlf.errors[0].column is Some(1) else {
    fail("expected CRLF normalized column")
  }
}

///|
test "parser reports missing attribute value after equals only" {
  let bare = @html_parser.parse_fragment("<div attr>", collect_errors=true)
  assert_eq(bare.to_html(pretty=false), "<div attr></div>")
  assert_eq(bare.errors.length(), 1)
  assert_eq(bare.errors[0].code, "expected-closing-tag-but-got-eof")
  let missing = @html_parser.parse_fragment("<div attr=>", collect_errors=true)
  assert_eq(missing.to_html(pretty=false), "<div attr></div>")
  assert_eq(missing.errors.length(), 2)
  assert_eq(missing.errors[0].code, "missing-attribute-value")
  assert_eq(missing.errors[1].code, "expected-closing-tag-but-got-eof")
  guard missing.errors[0].column is Some(11) else {
    fail("expected missing value at column 11")
  }
}

///|
test "tokenize reports unquoted attribute value fixture errors" {
  let less = @html_parser.tokenize("<div a=b<c>", collect_errors=true)
  guard less.tokens[0] is @html_parser.HtmlToken::Tag(tag) else {
    fail("expected div tag")
  }
  guard tag.attrs["a"] is Some("b<c") else {
    fail("expected < in unquoted attr value")
  }
  assert_eq(less.errors.length(), 1)
  assert_eq(
    less.errors[0].code,
    "unexpected-character-in-unquoted-attribute-value",
  )
  guard less.errors[0].column is Some(9) else {
    fail("expected unquoted attr value error at column 9")
  }
  let backtick = @html_parser.tokenize("<div a=b`c>", collect_errors=true)
  guard backtick.tokens[0] is @html_parser.HtmlToken::Tag(backtick_tag) else {
    fail("expected div tag")
  }
  guard backtick_tag.attrs["a"] is Some("b`c") else {
    fail("expected backtick in unquoted attr value")
  }
  assert_eq(backtick.errors.length(), 1)
  assert_eq(
    backtick.errors[0].code,
    "unexpected-character-in-unquoted-attribute-value",
  )
}

///|
test "tokenize reports missing whitespace after quoted attribute value" {
  let result = @html_parser.tokenize("<div a=\"b\"c=d>", collect_errors=true)
  guard result.tokens[0] is @html_parser.HtmlToken::Tag(tag) else {
    fail("expected div tag")
  }
  guard tag.attrs["a"] is Some("b") else { fail("expected quoted attr") }
  guard tag.attrs["c"] is Some("d") else { fail("expected adjacent attr") }
  assert_eq(result.errors.length(), 1)
  assert_eq(result.errors[0].code, "missing-whitespace-between-attributes")
  guard result.errors[0].column is Some(11) else {
    fail("expected missing whitespace at adjacent attr name")
  }
}

///|
test "tokenize reports attribute name fixture errors" {
  let equals = @html_parser.tokenize("<div\r=abc>", collect_errors=true)
  guard equals.tokens[0] is @html_parser.HtmlToken::Tag(eq_tag) else {
    fail("expected div tag")
  }
  guard eq_tag.attrs["=abc"] is Some("") else { fail("expected =abc attr") }
  assert_eq(equals.errors.length(), 1)
  assert_eq(
    equals.errors[0].code,
    "unexpected-equals-sign-before-attribute-name",
  )
  guard equals.errors[0].line is Some(2) else {
    fail("expected equals error on line 2")
  }
  guard equals.errors[0].column is Some(1) else {
    fail("expected equals error at column 1")
  }
  let invalid_char = @html_parser.tokenize("<div a<b>", collect_errors=true)
  guard invalid_char.tokens[0] is @html_parser.HtmlToken::Tag(bad_tag) else {
    fail("expected div tag")
  }
  guard bad_tag.attrs["a<b"] is Some("") else { fail("expected a<b attr") }
  assert_eq(invalid_char.errors.length(), 1)
  assert_eq(
    invalid_char.errors[0].code,
    "unexpected-character-in-attribute-name",
  )
  guard invalid_char.errors[0].column is Some(7) else {
    fail("expected bad attr char at column 7")
  }
  let quote = @html_parser.tokenize("<div a\"b>", collect_errors=true)
  guard quote.tokens[0] is @html_parser.HtmlToken::Tag(quote_tag) else {
    fail("expected div tag")
  }
  guard quote_tag.attrs["a\"b"] is Some("") else {
    fail("expected quote in attr name")
  }
  assert_eq(quote.errors.length(), 1)
  assert_eq(quote.errors[0].code, "unexpected-character-in-attribute-name")
  guard quote.errors[0].column is Some(7) else {
    fail("expected quote attr error at column 7")
  }
}

///|
test "parser and tokenizer keep first duplicate attribute value" {
  let doc = @html_parser.parse_fragment(
    "<p id=first id=second class=a class=b>text</p>",
    collect_errors=true,
  )
  assert_eq(doc.to_html(pretty=false), "<p id=\"first\" class=\"a\">text</p>")
  assert_eq(doc.errors.length(), 2)
  assert_eq(doc.errors[0].code, "duplicate-attribute")
  assert_eq(doc.errors[1].code, "duplicate-attribute")
  let tokens = @html_parser.tokenize("<div a=1 a=2 a=3>", collect_errors=true)
  guard tokens.tokens[0] is @html_parser.HtmlToken::Tag(tag) else {
    fail("expected div tag")
  }
  guard tag.attrs["a"] is Some("1") else {
    fail("expected first duplicate value")
  }
  assert_eq(tokens.errors.length(), 2)
  assert_eq(tokens.errors[0].code, "duplicate-attribute")
  assert_eq(tokens.errors[1].code, "duplicate-attribute")
}

///|
test "parser reports attribute name fixture errors" {
  let equals = @html_parser.parse_fragment("<div =abc>", collect_errors=true)
  guard equals.query_one("div") is Some(eq_node) else { fail("expected div") }
  assert_true(eq_node.attrs().contains("=abc"))
  assert_eq(equals.errors.length(), 2)
  assert_eq(
    equals.errors[0].code,
    "unexpected-equals-sign-before-attribute-name",
  )
  assert_eq(equals.errors[1].code, "expected-closing-tag-but-got-eof")
  guard equals.errors[0].column is Some(6) else {
    fail("expected equals attr error at column 6")
  }
  let bad_char = @html_parser.parse_fragment("<div a\"b>", collect_errors=true)
  guard bad_char.query_one("div") is Some(bad_node) else {
    fail("expected div")
  }
  assert_true(bad_node.attrs().contains("a\"b"))
  assert_eq(bad_char.errors.length(), 2)
  assert_eq(bad_char.errors[0].code, "unexpected-character-in-attribute-name")
  assert_eq(bad_char.errors[1].code, "expected-closing-tag-but-got-eof")
  guard bad_char.errors[0].column is Some(7) else {
    fail("expected quote attr error at column 7")
  }
}

///|
test "parser reports unquoted attribute value fixture errors" {
  let less = @html_parser.parse_fragment("<div a=b<c>", collect_errors=true)
  assert_eq(less.to_html(pretty=false), "<div a=\"b&lt;c\"></div>")
  assert_eq(less.errors.length(), 2)
  assert_eq(
    less.errors[0].code,
    "unexpected-character-in-unquoted-attribute-value",
  )
  assert_eq(less.errors[1].code, "expected-closing-tag-but-got-eof")
  guard less.errors[0].column is Some(9) else {
    fail("expected unquoted attr value error at column 9")
  }
}

///|
test "parser reports missing whitespace after quoted attribute value" {
  let result = @html_parser.parse_fragment(
    "<div a=\"b\"c=d>",
    collect_errors=true,
  )
  assert_eq(result.to_html(pretty=false), "<div a=\"b\" c=\"d\"></div>")
  assert_eq(result.errors.length(), 2)
  assert_eq(result.errors[0].code, "missing-whitespace-between-attributes")
  assert_eq(result.errors[1].code, "expected-closing-tag-but-got-eof")
  guard result.errors[0].column is Some(11) else {
    fail("expected missing whitespace at adjacent attr name")
  }
}

///|
test "tokenize recovers invalid self closing start tag fixture case" {
  let result = @html_parser.tokenize("<div /a>", collect_errors=true)
  guard result.tokens[0] is @html_parser.HtmlToken::Tag(tag) else {
    fail("expected div tag")
  }
  assert_eq(tag.name, "div")
  assert_eq(tag.self_closing, false)
  guard tag.attrs["a"] is Some("") else { fail("expected recovered a attr") }
  assert_eq(result.errors.length(), 1)
  assert_eq(result.errors[0].code, "unexpected-character-after-solidus-in-tag")
  guard result.errors[0].column is Some(7) else {
    fail("expected invalid self closing char at column 7")
  }
  let fragment = @html_parser.parse_fragment("<div /a>", collect_errors=true)
  assert_eq(fragment.to_html(pretty=false), "<div a></div>")
  assert_eq(fragment.errors.length(), 2)
  assert_eq(
    fragment.errors[0].code,
    "unexpected-character-after-solidus-in-tag",
  )
  assert_eq(fragment.errors[1].code, "expected-closing-tag-but-got-eof")
}

///|
test "start tag solidus does not skip following whitespace" {
  let tokenized = @html_parser.tokenize("<div/ >", collect_errors=true)
  guard tokenized.tokens[0] is @html_parser.HtmlToken::Tag(tag) else {
    fail("expected div tag")
  }
  assert_eq(tag.name, "div")
  assert_eq(tag.self_closing, false)
  assert_eq(tokenized.errors.length(), 1)
  assert_eq(
    tokenized.errors[0].code,
    "unexpected-character-after-solidus-in-tag",
  )
  guard tokenized.errors[0].column is Some(6) else {
    fail("expected whitespace after solidus at column 6")
  }
  let img = @html_parser.tokenize("<img />", collect_errors=true)
  guard img.tokens[0] is @html_parser.HtmlToken::Tag(img_tag) else {
    fail("expected img tag")
  }
  assert_eq(img_tag.self_closing, true)
  assert_eq(img.errors.length(), 0)
  let fragment = @html_parser.parse_fragment("<div/ >", collect_errors=true)
  assert_eq(fragment.to_html(pretty=false), "<div></div>")
  assert_eq(fragment.errors.length(), 2)
  assert_eq(
    fragment.errors[0].code,
    "unexpected-character-after-solidus-in-tag",
  )
  assert_eq(fragment.errors[1].code, "expected-closing-tag-but-got-eof")
  guard fragment.errors[0].column is Some(6) else {
    fail("expected parser whitespace after solidus at column 6")
  }
}

///|
test "tokenize normalizes BOM and CRLF edge cases" {
  let bom = @html_parser.tokenize("\u{FEFF}<div>")
  guard bom.tokens[0] is @html_parser.HtmlToken::Tag(tag) else {
    fail("expected div start tag")
  }
  assert_eq(tag.name, "div")
  let text = @html_parser.tokenize("abc\r\ndef\rghi")
  guard text.tokens[0] is @html_parser.HtmlToken::Characters(data) else {
    fail("expected character token")
  }
  assert_eq(data, "abc\ndef\nghi")
  let comment = @html_parser.tokenize("<!-- a\rb -->")
  guard comment.tokens[0] is @html_parser.HtmlToken::CommentToken(data) else {
    fail("expected comment")
  }
  assert_eq(data, " a\nb ")
  let attr = @html_parser.tokenize("<div title=\"a\rb\">")
  guard attr.tokens[0] is @html_parser.HtmlToken::Tag(attr_tag) else {
    fail("expected attr tag")
  }
  guard attr_tag.attrs["title"] is Some("a\nb") else {
    fail("expected normalized attr")
  }
}

///|
test "parser normalizes leading BOM and CRLF in text comment and attr" {
  let doc = @html_parser.parse_fragment(
    "\u{FEFF}<p title='a\rb'>a\r\nb<!--x\ry--></p>",
  )
  assert_eq(doc.to_html(pretty=false), "<p title=\"a\nb\">a\nb<!--x\ny--></p>")
  assert_eq(doc.to_text(separator="", strip=false), "a\nb")
}

///|
test "parser handles null characters in text attributes and text modes" {
  let text = @html_parser.parse_fragment("a\u{0000}b", collect_errors=true)
  assert_eq(text.to_html(pretty=false), "ab")
  assert_eq(text.to_text(separator="", strip=false), "ab")
  assert_eq(text.errors.length(), 1)
  assert_eq(text.errors[0].code, "unexpected-null-character")
  guard text.errors[0].column is Some(2) else {
    fail("expected text null at column 2")
  }
  let attr = @html_parser.parse_fragment(
    "<div title=\"a\u{0000}b\">x</div>",
    collect_errors=true,
  )
  assert_eq(attr.to_html(pretty=false), "<div title=\"a�b\">x</div>")
  assert_eq(attr.errors.length(), 1)
  assert_eq(attr.errors[0].code, "unexpected-null-character")
  let raw = @html_parser.parse_fragment(
    "<script>a\u{0000}b</script><title>a\u{0000}b</title>",
    collect_errors=true,
  )
  assert_eq(
    raw.to_html(pretty=false),
    "<script>a�b</script><title>a�b</title>",
  )
  assert_eq(raw.errors.length(), 2)
  assert_eq(raw.errors[0].code, "unexpected-null-character")
  assert_eq(raw.errors[1].code, "unexpected-null-character")
  let textarea = @html_parser.parse_fragment(
    "<textarea>\n\u{0000}b</textarea>",
    collect_errors=true,
  )
  assert_eq(textarea.to_html(pretty=false), "<textarea>�b</textarea>")
  assert_eq(textarea.errors[0].code, "unexpected-null-character")
}

///|
test "parser treats script style title textarea content as text" {
  let doc = @html_parser.parse_fragment(
    "<script><!--a--<b</script><title>a &lt; b</title>",
  )
  assert_eq(
    doc.to_html(pretty=false),
    "<script><!--a--<<b</script><title>a &lt; b</title>",
  )
  assert_eq(doc.query("b").length(), 0)
  assert_eq(doc.to_text(separator="|", strip=false), "<!--a--<<b|a < b")
  let escaped_end = @html_parser.parse_fragment("<script><!--a--</script>")
  assert_eq(escaped_end.to_html(pretty=false), "<script><!--a--<</script>")
  let comment_end = @html_parser.parse_fragment("<script><!--a--></script>")
  assert_eq(comment_end.to_html(pretty=false), "<script><!--a--></script>")
  let raw_after_comment = @html_parser.parse_fragment(
    "<script><!--a-->x--</script>",
  )
  assert_eq(
    raw_after_comment.to_html(pretty=false),
    "<script><!--a-->x--</script>",
  )
  let double_escaped = @html_parser.parse_fragment(
    "<script><!--<script>x</script>y</script>",
  )
  assert_eq(
    double_escaped.to_text(separator="|", strip=false),
    "<!--<script>x</script>y",
  )
}

///|
test "parser treats xmp and plaintext content as text" {
  let xmp = @html_parser.parse_fragment("<xmp><b>x</b></xmp>after")
  assert_eq(xmp.to_html(pretty=false), "<xmp>&lt;b&gt;x&lt;/b&gt;</xmp>after")
  assert_eq(xmp.query("b").length(), 0)
  let plaintext = @html_parser.parse_fragment(
    "<plaintext><b>x</b></plaintext>after",
    collect_errors=true,
  )
  assert_eq(
    plaintext.to_html(pretty=false),
    "<plaintext>&lt;b&gt;x&lt;/b&gt;&lt;/plaintext&gt;after</plaintext>",
  )
  assert_eq(plaintext.errors[0].code, "expected-closing-tag-but-got-eof")
}

///|
test "parser reports special text EOF like tree builder" {
  let script = @html_parser.parse_fragment("<script>x", collect_errors=true)
  assert_eq(script.to_html(pretty=false), "<script>x</script>")
  assert_eq(script.errors.length(), 1)
  assert_eq(script.errors[0].code, "expected-named-closing-tag-but-got-eof")
  guard script.errors[0].column is Some(9) else {
    fail("expected script EOF at final text column")
  }
  let textarea = @html_parser.parse_fragment(
    "<textarea>\nx",
    collect_errors=true,
  )
  assert_eq(textarea.to_html(pretty=false), "<textarea>x</textarea>")
  assert_eq(textarea.errors.length(), 1)
  assert_eq(textarea.errors[0].code, "expected-closing-tag-but-got-eof")
  guard textarea.errors[0].line is Some(2) else {
    fail("expected textarea EOF on second line")
  }
  guard textarea.errors[0].column is Some(1) else {
    fail("expected textarea EOF at final text column")
  }
  let xmp = @html_parser.parse_fragment("<xmp>x", collect_errors=true)
  assert_eq(xmp.errors[0].code, "expected-named-closing-tag-but-got-eof")
  let iframe = @html_parser.parse_fragment("<iframe>x", collect_errors=true)
  assert_eq(iframe.errors[0].code, "expected-closing-tag-but-got-eof")
}

///|
test "parser treats legacy raw text elements as text" {
  let doc = @html_parser.parse_fragment(
    "<iframe><b>x</b></iframe><noembed><i>y</i></noembed><noscript><em>z</em></noscript>",
  )
  assert_eq(
    doc.to_html(pretty=false),
    "<iframe>&lt;b&gt;x&lt;/b&gt;</iframe><noembed>&lt;i&gt;y&lt;/i&gt;</noembed><noscript>&lt;em&gt;z&lt;/em&gt;</noscript>",
  )
  assert_eq(doc.query("b").length(), 0)
  assert_eq(doc.query("i").length(), 0)
  assert_eq(doc.query("em").length(), 0)
}

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
test "parser ignores one initial newline in pre listing and textarea" {
  let pre = @html_parser.parse_fragment(
    "<pre>\r\nline</pre><listing>\nitem</listing>",
  )
  assert_eq(pre.to_html(pretty=false), "<pre>line</pre><listing>item</listing>")
  let textarea = @html_parser.parse_fragment("<textarea>\nline</textarea>")
  assert_eq(textarea.to_html(pretty=false), "<textarea>line</textarea>")
  let title = @html_parser.parse_fragment("<title>\nline</title>")
  assert_eq(title.to_html(pretty=false), "<title>\nline</title>")
}

///|
test "tokenize preserves rawtext and rcdata element contents" {
  let script = @html_parser.tokenize("<script><!--a--<b</script>")
  assert_eq(script.tokens.length(), 4)
  guard script.tokens[1] is @html_parser.HtmlToken::Characters("<!--a--<<b") else {
    fail("expected raw script text")
  }
  guard script.tokens[2] is @html_parser.HtmlToken::Tag(end_script) else {
    fail("expected script end")
  }
  assert_true(end_script.kind is @html_parser.TagKind::EndTag)
  assert_eq(end_script.name, "script")
  let escaped_end = @html_parser.tokenize("<script><!--a--</script>")
  guard escaped_end.tokens[1] is @html_parser.HtmlToken::Characters("<!--a--<") else {
    fail("expected escaped script end-tag boundary text")
  }
  let escaped_eof = @html_parser.tokenize("<script><!--a--<")
  guard escaped_eof.tokens[1] is @html_parser.HtmlToken::Characters("<!--a--<<") else {
    fail("expected escaped EOF less-than text")
  }
  let comment_end = @html_parser.tokenize("<script><!--a--></script>")
  guard comment_end.tokens[1] is @html_parser.HtmlToken::Characters("<!--a-->") else {
    fail("expected script comment close to return to raw text")
  }
  let nul_script = @html_parser.tokenize(
    "<script>a\u{0000}b</script>",
    collect_errors=true,
  )
  guard nul_script.tokens[1] is @html_parser.HtmlToken::Characters("a\u{FFFD}b") else {
    fail("expected replacement char in script text")
  }
  assert_eq(nul_script.errors.length(), 1)
  assert_eq(nul_script.errors[0].code, "unexpected-null-character")
  guard nul_script.errors[0].column is Some(10) else {
    fail("expected script text null at column 10")
  }
  let double_escaped = @html_parser.tokenize(
    "<script><!--<script>x</script>y</script>",
  )
  guard double_escaped.tokens[1]
    is @html_parser.HtmlToken::Characters("<!--<script>x</script>y") else {
    fail("expected inner script end tag to stay in double-escaped text")
  }
  guard double_escaped.tokens[2] is @html_parser.HtmlToken::Tag(double_end) else {
    fail("expected final script end")
  }
  assert_eq(double_end.name, "script")
  let not_double_escaped = @html_parser.tokenize(
    "<script><!--<scripty>x</script>-->z</script>",
  )
  guard not_double_escaped.tokens[1]
    is @html_parser.HtmlToken::Characters("<!--<scripty>x") else {
    fail("expected non-script word to avoid double-escaped state")
  }
  guard not_double_escaped.tokens[3]
    is @html_parser.HtmlToken::Characters("-->z") else {
    fail("expected text after the first script end tag")
  }
  let textarea = @html_parser.tokenize("<textarea>a &lt; b</textarea>")
  guard textarea.tokens[1] is @html_parser.HtmlToken::Characters("a < b") else {
    fail("expected decoded textarea text")
  }
  let xmp = @html_parser.tokenize("<xmp><b>x</b></xmp>")
  guard xmp.tokens[1] is @html_parser.HtmlToken::Characters("<b>x</b>") else {
    fail("expected xmp raw text")
  }
  let plaintext = @html_parser.tokenize("<plaintext><b>x</b></plaintext>")
  guard plaintext.tokens[1]
    is @html_parser.HtmlToken::Characters("<b>x</b></plaintext>") else {
    fail("expected plaintext through EOF")
  }
  let iframe = @html_parser.tokenize("<iframe><b>x</b></iframe>")
  guard iframe.tokens[1] is @html_parser.HtmlToken::Characters("<b>x</b>") else {
    fail("expected iframe raw text")
  }
}

///|
test "tokenize does not report special text EOF tree errors" {
  let script = @html_parser.tokenize("<script>x", collect_errors=true)
  guard script.tokens[1] is @html_parser.HtmlToken::Characters("x") else {
    fail("expected unclosed script text")
  }
  assert_eq(script.errors.length(), 0)
  let plaintext = @html_parser.tokenize("<plaintext>x", collect_errors=true)
  guard plaintext.tokens[1] is @html_parser.HtmlToken::Characters("x") else {
    fail("expected unclosed plaintext text")
  }
  assert_eq(plaintext.errors.length(), 0)
  let title = @html_parser.tokenize("<title>x", collect_errors=true)
  guard title.tokens[1] is @html_parser.HtmlToken::Characters("x") else {
    fail("expected unclosed title text")
  }
  assert_eq(title.errors.length(), 0)
}
