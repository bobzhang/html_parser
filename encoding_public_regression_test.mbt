///|
fn encoding_public_name(doc : @html_parser.ParsedHtml) -> String {
  match doc.encoding {
    Some(name) => name
    None => ""
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
