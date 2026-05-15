///|
fn encoding_public_name(doc : @html_parser.ParsedHtml) -> String {
  match doc.encoding {
    Some(name) => name
    None => ""
  }
}

///|
test "parse_bytes decodes explicit utf8 and records encoding" {
  let bytes = @utf8.encode("<p>bytes</p>")
  let doc = @html_parser.parse_bytes(bytes, encoding="utf-8")
  assert_eq(
    doc.to_html(pretty=false),
    "<html><head></head><body><p>bytes</p></body></html>",
  )
  guard doc.encoding is Some("utf-8") else { fail("expected utf-8 encoding") }
}

///|
test "parse_bytes defaults to windows1252 and normalizes compatible labels" {
  let bytes = b"\x3c\x70\x3e\x80\x3c\x2f\x70\x3e"
  let doc = @html_parser.parse_bytes(bytes)
  assert_eq(
    doc.to_html(pretty=false),
    "<html><head></head><body><p>\u{20AC}</p></body></html>",
  )
  guard doc.encoding is Some("windows-1252") else {
    fail("expected default windows-1252 encoding")
  }
  let latin1 = @html_parser.parse_bytes(bytes, encoding="iso-8859-1")
  assert_eq(
    latin1.to_html(pretty=false),
    "<html><head></head><body><p>\u{20AC}</p></body></html>",
  )
  guard latin1.encoding is Some("windows-1252") else {
    fail("expected latin1 label to normalize to windows-1252")
  }
  let utf7 = @html_parser.parse_bytes(bytes, encoding="utf7")
  assert_eq(
    utf7.to_html(pretty=false),
    "<html><head></head><body><p>\u{20AC}</p></body></html>",
  )
  guard utf7.encoding is Some("windows-1252") else {
    fail("expected utf7 label to normalize to windows-1252")
  }
  let c1_letters = @html_parser.parse_bytes(b"<p>\x83\x9f</p>")
  assert_eq(c1_letters.to_text(separator="", strip=false), "\u{0192}\u{0178}")
  guard c1_letters.encoding is Some("windows-1252") else {
    fail("expected C1 default bytes to use windows-1252")
  }
  let c1_punctuation = @html_parser.parse_bytes(b"<p>\x84\x8c</p>")
  assert_eq(
    c1_punctuation.to_text(separator="", strip=false),
    "\u{201E}\u{0152}",
  )
  guard c1_punctuation.encoding is Some("windows-1252") else {
    fail("expected sparse C1 bytes to use windows-1252")
  }
}

///|
test "public parse_bytes meta charset and transport override stay stable" {
  let meta = @html_parser.parse_bytes(
    b"<meta charset=utf-8><p>\xe2\x82\xac</p>",
  )
  assert_eq(encoding_public_name(meta), "utf-8")
  assert_eq(meta.to_text(separator="", strip=false), "€")
  assert_eq(
    meta.to_html(pretty=false),
    "<html><head><meta charset=\"utf-8\"></head><body><p>€</p></body></html>",
  )

  let override_doc = @html_parser.parse_bytes(
    b"<meta charset=utf-8><p>\x80</p>",
    encoding="windows-1252",
  )
  assert_eq(encoding_public_name(override_doc), "windows-1252")
  assert_eq(override_doc.to_text(separator="", strip=false), "€")
  assert_eq(
    override_doc.to_html(pretty=false),
    "<html><head><meta charset=\"utf-8\"></head><body><p>€</p></body></html>",
  )
}

///|
test "public parse_bytes UTF-16 BOM handling stays stable" {
  let little = @html_parser.parse_bytes(
    b"\xff\xfe\x3c\x00\x70\x00\x3e\x00\x68\x00\x69\x00\x3c\x00\x2f\x00\x70\x00\x3e\x00",
  )
  assert_eq(encoding_public_name(little), "utf-16le")
  assert_eq(little.to_text(separator="", strip=false), "hi")
  assert_eq(
    little.to_html(pretty=false),
    "<html><head></head><body><p>hi</p></body></html>",
  )

  let big = @html_parser.parse_bytes(
    b"\xfe\xff\x00\x3c\x00\x70\x00\x3e\x00\x68\x00\x69\x00\x3c\x00\x2f\x00\x70\x00\x3e",
  )
  assert_eq(encoding_public_name(big), "utf-16be")
  assert_eq(big.to_text(separator="", strip=false), "hi")
  assert_eq(
    big.to_html(pretty=false),
    "<html><head></head><body><p>hi</p></body></html>",
  )
}

///|
test "public parse_bytes meta prescan fail-closed behavior stays stable" {
  let comment = @html_parser.parse_bytes(
    b"<!--<meta charset=utf-8>--><p>\x80</p>",
  )
  assert_eq(encoding_public_name(comment), "windows-1252")
  assert_eq(comment.to_text(separator="", strip=false), "€")
  assert_eq(
    comment.to_html(pretty=false),
    "<!--<meta charset=utf-8>--><html><head></head><body><p>€</p></body></html>",
  )

  let http_equiv = @html_parser.parse_bytes(
    b"<meta http-equiv=\"Content-Type\" content=\"charset   =utf-8\"><p>\xe2\x82\xac</p>",
  )
  assert_eq(encoding_public_name(http_equiv), "utf-8")
  assert_eq(http_equiv.to_text(separator="", strip=false), "€")
  assert_eq(
    http_equiv.to_html(pretty=false),
    "<html><head><meta http-equiv=\"Content-Type\" content=\"charset   =utf-8\"></head><body><p>€</p></body></html>",
  )
}
