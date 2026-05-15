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
test "parse_bytes decodes iso8859-2 labels" {
  let explicit = b"<p>\xa1\xb1</p>"
  let doc = @html_parser.parse_bytes(explicit, encoding="iso8859-2")
  assert_eq(doc.to_text(separator="", strip=false), "\u{0104}\u{0105}")
  guard doc.encoding is Some("iso-8859-2") else {
    fail("expected explicit iso-8859-2 encoding")
  }
  let mixed = b"<p>\xa0\xa2\xb2\xc7\xe7</p>"
  let mixed_doc = @html_parser.parse_bytes(mixed, encoding="latin-2")
  assert_eq(
    mixed_doc.to_text(separator="", strip=false),
    "\u{00A0}\u{02D8}\u{02DB}\u{00C7}\u{00E7}",
  )
  guard mixed_doc.encoding is Some("iso-8859-2") else {
    fail("expected latin-2 label to normalize to iso-8859-2")
  }
  let polish_czech = b"<p>\xa3\xb3\xc8\xe8</p>"
  let polish_czech_doc = @html_parser.parse_bytes(
    polish_czech,
    encoding="iso-8859-2",
  )
  assert_eq(
    polish_czech_doc.to_text(separator="", strip=false),
    "\u{0141}\u{0142}\u{010C}\u{010D}",
  )
  guard polish_czech_doc.encoding is Some("iso-8859-2") else {
    fail("expected explicit iso-8859-2 encoding for Central European bytes")
  }
  let latin2_marks = b"<p>\xa5\xb5\xca\xea\xff</p>"
  let latin2_marks_doc = @html_parser.parse_bytes(
    latin2_marks,
    encoding="iso-8859-2",
  )
  assert_eq(
    latin2_marks_doc.to_text(separator="", strip=false),
    "\u{013D}\u{013E}\u{0118}\u{0119}\u{02D9}",
  )
  guard latin2_marks_doc.encoding is Some("iso-8859-2") else {
    fail("expected explicit iso-8859-2 encoding for remapped high bytes")
  }
  let identity_high_bytes = b"<p>\xa4\xb4\xc9\xe9</p>"
  let identity_high_doc = @html_parser.parse_bytes(
    identity_high_bytes,
    encoding="iso-8859-2",
  )
  assert_eq(
    identity_high_doc.to_text(separator="", strip=false),
    "\u{00A4}\u{00B4}\u{00C9}\u{00E9}",
  )
  guard identity_high_doc.encoding is Some("iso-8859-2") else {
    fail("expected explicit iso-8859-2 encoding for identity high bytes")
  }
  let identity_e_diaeresis = @html_parser.parse_bytes(
    b"<p>\xcb\xeb</p>",
    encoding="iso-8859-2",
  )
  assert_eq(
    identity_e_diaeresis.to_text(separator="", strip=false),
    "\u{00CB}\u{00EB}",
  )
  guard identity_e_diaeresis.encoding is Some("iso-8859-2") else {
    fail("expected explicit iso-8859-2 encoding for sparse identity bytes")
  }
  let latin2_mid = @html_parser.parse_bytes(
    b"<p>\xa6\xa7\xa8\xa9\xaa\xab\xac\xad\xae\xaf\xb0\xb1\xb2\xb3\xb4\xb5\xb6\xb7\xb8\xb9\xba\xbb\xbc\xbd\xbe\xbf</p>",
    encoding="iso-8859-2",
  )
  assert_eq(
    latin2_mid.to_text(separator="", strip=false),
    "\u{015A}\u{00A7}\u{00A8}\u{0160}\u{015E}\u{0164}\u{0179}\u{00AD}\u{017D}\u{017B}\u{00B0}\u{0105}\u{02DB}\u{0142}\u{00B4}\u{013E}\u{015B}\u{02C7}\u{00B8}\u{0161}\u{015F}\u{0165}\u{017A}\u{02DD}\u{017E}\u{017C}",
  )
  let latin2_upper = @html_parser.parse_bytes(
    b"<p>\xc0\xc1\xc2\xc3\xc4\xc5\xc6\xc7\xc8\xc9\xca\xcb\xcc\xcd\xce\xcf\xd0\xd1\xd2\xd3\xd4\xd5\xd6\xd7\xd8\xd9\xda\xdb\xdc\xdd\xde\xdf</p>",
    encoding="iso-8859-2",
  )
  assert_eq(
    latin2_upper.to_text(separator="", strip=false),
    "\u{0154}\u{00C1}\u{00C2}\u{0102}\u{00C4}\u{0139}\u{0106}\u{00C7}\u{010C}\u{00C9}\u{0118}\u{00CB}\u{011A}\u{00CD}\u{00CE}\u{010E}\u{0110}\u{0143}\u{0147}\u{00D3}\u{00D4}\u{0150}\u{00D6}\u{00D7}\u{0158}\u{016E}\u{00DA}\u{0170}\u{00DC}\u{00DD}\u{0162}\u{00DF}",
  )
  let latin2_lower = @html_parser.parse_bytes(
    b"<p>\xe0\xe1\xe2\xe3\xe4\xe5\xe6\xe7\xe8\xe9\xea\xeb\xec\xed\xee\xef\xf0\xf1\xf2\xf3\xf4\xf5\xf6\xf7\xf8\xf9\xfa\xfb\xfc\xfd\xfe\xff</p>",
    encoding="iso-8859-2",
  )
  assert_eq(
    latin2_lower.to_text(separator="", strip=false),
    "\u{0155}\u{00E1}\u{00E2}\u{0103}\u{00E4}\u{013A}\u{0107}\u{00E7}\u{010D}\u{00E9}\u{0119}\u{00EB}\u{011B}\u{00ED}\u{00EE}\u{010F}\u{0111}\u{0144}\u{0148}\u{00F3}\u{00F4}\u{0151}\u{00F6}\u{00F7}\u{0159}\u{016F}\u{00FA}\u{0171}\u{00FC}\u{00FD}\u{0163}\u{02D9}",
  )
  let meta = b"<meta charset=latin2><p>\xc6\xe6</p>"
  let meta_doc = @html_parser.parse_bytes(meta)
  assert_eq(meta_doc.to_text(separator="", strip=false), "\u{0106}\u{0107}")
  guard meta_doc.encoding is Some("iso-8859-2") else {
    fail("expected meta latin2 encoding")
  }
}

///|
test "parse_bytes ignores invalid transport encoding labels" {
  let bytes = b"<p>\x80</p>"
  let doc = @html_parser.parse_bytes(bytes, encoding="koi8-r")
  assert_eq(doc.to_text(separator="", strip=false), "\u{20AC}")
  guard doc.encoding is Some("windows-1252") else {
    fail("expected invalid transport label to fall back")
  }
  let meta = @utf8.encode("<meta charset=utf-8><p>\u{20AC}</p>")
  let meta_doc = @html_parser.parse_bytes(meta, encoding="bogus")
  assert_eq(meta_doc.to_text(separator="", strip=false), "\u{20AC}")
  guard meta_doc.encoding is Some("utf-8") else {
    fail("expected invalid transport label to allow meta sniff")
  }
}

///|
test "parse_bytes valid transport encoding overrides sniffing" {
  let meta = b"<meta charset=utf-8><p>\x80</p>"
  let meta_doc = @html_parser.parse_bytes(meta, encoding="windows-1252")
  assert_eq(meta_doc.to_text(separator="", strip=false), "\u{20AC}")
  guard meta_doc.encoding is Some("windows-1252") else {
    fail("expected transport encoding to override meta")
  }
  let utf16_bom = b"\xff\xfe\x3c\x00\x70\x00\x3e\x00\x80\x00\x3c\x00\x2f\x00\x70\x00\x3e\x00"
  let bom_doc = @html_parser.parse_bytes(utf16_bom, encoding="windows-1252")
  guard bom_doc.encoding is Some("windows-1252") else {
    fail("expected transport encoding to override bom")
  }
}

///|
test "parse_bytes sniffs utf8 bom before windows1252 fallback" {
  let bytes = b"\xef\xbb\xbf\x3c\x70\x3e\x62\x6f\x6d\x3c\x2f\x70\x3e"
  let doc = @html_parser.parse_bytes(bytes)
  assert_eq(
    doc.to_html(pretty=false),
    "<html><head></head><body><p>bom</p></body></html>",
  )
  guard doc.encoding is Some("utf-8") else {
    fail("expected utf-8 bom encoding")
  }
}

///|
test "parse_bytes prescans direct meta charset" {
  let utf8 = b"\x3c\x6d\x65\x74\x61\x20\x63\x68\x61\x72\x73\x65\x74\x3d\x75\x74\x66\x2d\x38\x3e\x3c\x70\x3e\xe2\x82\xac\x3c\x2f\x70\x3e"
  let doc = @html_parser.parse_bytes(utf8)
  assert_eq(doc.to_text(separator="", strip=false), "\u{20AC}")
  guard doc.encoding is Some("utf-8") else {
    fail("expected meta utf-8 encoding")
  }
  let spaced = b"<meta\tcharset\r\n=\tutf-8><p>\xe2\x82\xac</p>"
  let spaced_doc = @html_parser.parse_bytes(spaced)
  assert_eq(spaced_doc.to_text(separator="", strip=false), "\u{20AC}")
  guard spaced_doc.encoding is Some("utf-8") else {
    fail("expected whitespace around meta charset equals to sniff utf-8")
  }
  let quoted = b"\x3c\x6d\x65\x74\x61\x20\x63\x68\x61\x72\x73\x65\x74\x3d\x22\x6c\x61\x74\x69\x6e\x31\x22\x3e\x3c\x70\x3e\x80\x3c\x2f\x70\x3e"
  let quoted_doc = @html_parser.parse_bytes(quoted)
  assert_eq(quoted_doc.to_text(separator="", strip=false), "\u{20AC}")
  guard quoted_doc.encoding is Some("windows-1252") else {
    fail("expected meta latin1 to normalize to windows-1252")
  }
  let trimmed = b"<meta charset=' utf-8 '><p>\xe2\x82\xac</p>"
  let trimmed_doc = @html_parser.parse_bytes(trimmed)
  assert_eq(trimmed_doc.to_text(separator="", strip=false), "\u{20AC}")
  guard trimmed_doc.encoding is Some("utf-8") else {
    fail("expected trimmed quoted meta charset to sniff utf-8")
  }
  let meta_utf16 = b"\x3c\x6d\x65\x74\x61\x20\x63\x68\x61\x72\x73\x65\x74\x3d\x75\x74\x66\x2d\x31\x36\x3e\x3c\x70\x3e\x6f\x6b\x3c\x2f\x70\x3e"
  let meta_utf16_doc = @html_parser.parse_bytes(meta_utf16)
  assert_eq(meta_utf16_doc.to_text(separator="", strip=false), "ok")
  guard meta_utf16_doc.encoding is Some("utf-8") else {
    fail("expected meta utf-16 declaration to become utf-8")
  }
}

///|
test "parse_bytes meta prescan skips comments and quoted non-meta tags" {
  let comment = b"\x3c\x21\x2d\x2d\x20\x3c\x6d\x65\x74\x61\x20\x63\x68\x61\x72\x73\x65\x74\x3d\x75\x74\x66\x2d\x38\x3e\x20\x2d\x2d\x3e\x3c\x70\x3e\x80\x3c\x2f\x70\x3e"
  let comment_doc = @html_parser.parse_bytes(comment)
  assert_eq(comment_doc.to_text(separator="", strip=false), "\u{20AC}")
  guard comment_doc.encoding is Some("windows-1252") else {
    fail("expected charset inside comment to be ignored")
  }
  let quoted_tag = b"\x3c\x70\x20\x74\x69\x74\x6c\x65\x3d\x22\x78\x3e\x3c\x6d\x65\x74\x61\x20\x63\x68\x61\x72\x73\x65\x74\x3d\x75\x74\x66\x2d\x38\x22\x3e\x3c\x2f\x70\x3e\x3c\x70\x3e\x80\x3c\x2f\x70\x3e"
  let quoted_tag_doc = @html_parser.parse_bytes(quoted_tag)
  assert_eq(quoted_tag_doc.to_text(separator="", strip=false), "\u{20AC}")
  guard quoted_tag_doc.encoding is Some("windows-1252") else {
    fail("expected meta-like bytes inside non-meta tag attribute to be ignored")
  }
}

///|
test "parse_bytes meta prescan ignores incomplete constructs" {
  let unfinished_comment = b"\x3c\x21\x2d\x2d\x3c\x6d\x65\x74\x61\x20\x63\x68\x61\x72\x73\x65\x74\x3d\x75\x74\x66\x2d\x38\x3e"
  let unfinished_comment_doc = @html_parser.parse_bytes(unfinished_comment)
  guard unfinished_comment_doc.encoding is Some("windows-1252") else {
    fail("expected unfinished comment to prevent meta sniff")
  }
  let bogus_declaration = b"<!meta charset=utf-8><p>\x80</p>"
  let bogus_declaration_doc = @html_parser.parse_bytes(bogus_declaration)
  assert_eq(
    bogus_declaration_doc.to_text(separator="", strip=false),
    "\u{20AC}",
  )
  guard bogus_declaration_doc.encoding is Some("windows-1252") else {
    fail("expected bogus meta declaration to be ignored")
  }
  let end_tag = b"\x3c\x2f\x61\x20\x74\x69\x74\x6c\x65\x3d\x27\x78\x27\x3e\x3c\x70\x3e\x80\x3c\x2f\x70\x3e"
  let end_tag_doc = @html_parser.parse_bytes(end_tag)
  assert_eq(end_tag_doc.to_text(separator="", strip=false), "\u{20AC}")
  guard end_tag_doc.encoding is Some("windows-1252") else {
    fail("expected end tag to be skipped during meta sniff")
  }
  let unclosed_quote = b"\x3c\x6d\x65\x74\x61\x20\x63\x68\x61\x72\x73\x65\x74\x3d\x22\x75\x74\x66\x2d\x38\x3c\x70\x3e\x80\x3c\x2f\x70\x3e"
  let unclosed_quote_doc = @html_parser.parse_bytes(unclosed_quote)
  guard unclosed_quote_doc.encoding is Some("windows-1252") else {
    fail("expected unclosed meta attribute quote to be ignored")
  }
  let broken_value = b"<meta charset=   <p>\x80</p>"
  let broken_value_doc = @html_parser.parse_bytes(broken_value)
  assert_eq(broken_value_doc.to_text(separator="", strip=false), "\u{20AC}")
  guard broken_value_doc.encoding is Some("windows-1252") else {
    fail("expected meta charset interrupted by markup to fall back")
  }
  let eof_after_equals = @html_parser.parse_bytes(b"<meta charset=   ")
  guard eof_after_equals.encoding is Some("windows-1252") else {
    fail("expected eof after meta charset equals to fall back")
  }
  let missing_value = @html_parser.parse_bytes(b"<meta charset")
  guard missing_value.encoding is Some("windows-1252") else {
    fail("expected incomplete charset attribute to fall back")
  }
  let missing_gt = @html_parser.parse_bytes(b"<meta charset=utf-8")
  guard missing_gt.encoding is Some("windows-1252") else {
    fail("expected unclosed meta tag to fall back")
  }
}

///|
test "parse_bytes prescans http equiv content charset" {
  let utf8 = @utf8.encode(
    "<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\"><p>\u{20AC}</p>",
  )
  let doc = @html_parser.parse_bytes(utf8)
  assert_eq(doc.to_text(separator="", strip=false), "\u{20AC}")
  guard doc.encoding is Some("utf-8") else {
    fail("expected http-equiv content charset utf-8")
  }
  let single_quoted = @utf8.encode(
    "<meta content=\"TEXT/HTML; CHARSET='UTF-8'\" http-equiv=\"content-type\"><p>\u{20AC}</p>",
  )
  let single_quoted_doc = @html_parser.parse_bytes(single_quoted)
  assert_eq(single_quoted_doc.to_text(separator="", strip=false), "\u{20AC}")
  guard single_quoted_doc.encoding is Some("utf-8") else {
    fail("expected quoted content charset utf-8")
  }
  let spaced_equals = @utf8.encode(
    "<meta http-equiv=\"Content-Type\" content=\"charset   =utf-8\"><p>\u{20AC}</p>",
  )
  let spaced_equals_doc = @html_parser.parse_bytes(spaced_equals)
  assert_eq(spaced_equals_doc.to_text(separator="", strip=false), "\u{20AC}")
  guard spaced_equals_doc.encoding is Some("utf-8") else {
    fail("expected content charset with spaced equals")
  }
  let spaced_value = @utf8.encode(
    "<meta http-equiv=\"Content-Type\" content=\"charset=   utf-8\"><p>\u{20AC}</p>",
  )
  let spaced_value_doc = @html_parser.parse_bytes(spaced_value)
  assert_eq(spaced_value_doc.to_text(separator="", strip=false), "\u{20AC}")
  guard spaced_value_doc.encoding is Some("utf-8") else {
    fail("expected content charset with spaced value")
  }
  let invalid_direct = @utf8.encode(
    "<meta charset=bogus http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\"><p>\u{20AC}</p>",
  )
  let invalid_direct_doc = @html_parser.parse_bytes(invalid_direct)
  assert_eq(invalid_direct_doc.to_text(separator="", strip=false), "\u{20AC}")
  guard invalid_direct_doc.encoding is Some("utf-8") else {
    fail("expected http-equiv charset after invalid direct charset")
  }
  let invalid = b"<meta http-equiv=\"Content-Type\" content=\"text/html; charset=bogus\"><p>\x80</p>"
  let invalid_doc = @html_parser.parse_bytes(invalid)
  assert_eq(invalid_doc.to_text(separator="", strip=false), "\u{20AC}")
  guard invalid_doc.encoding is Some("windows-1252") else {
    fail("expected invalid http-equiv charset to fall back")
  }
  let missing_equals = b"<meta http-equiv=\"Content-Type\" content=\"charset   utf-8\"><p>\x80</p>"
  let missing_equals_doc = @html_parser.parse_bytes(missing_equals)
  assert_eq(missing_equals_doc.to_text(separator="", strip=false), "\u{20AC}")
  guard missing_equals_doc.encoding is Some("windows-1252") else {
    fail("expected malformed content charset to fall back")
  }
  let blank_content_charset = b"<meta http-equiv=\"Content-Type\" content=\"charset=   \"><p>\x80</p>"
  let blank_content_charset_doc = @html_parser.parse_bytes(
    blank_content_charset,
  )
  assert_eq(
    blank_content_charset_doc.to_text(separator="", strip=false),
    "\u{20AC}",
  )
  guard blank_content_charset_doc.encoding is Some("windows-1252") else {
    fail("expected blank content charset value to fall back")
  }
  let quoted_empty_charset = b"<meta http-equiv=\"Content-Type\" content=\"charset=''\"><p>\x80</p>"
  let quoted_empty_charset_doc = @html_parser.parse_bytes(quoted_empty_charset)
  assert_eq(
    quoted_empty_charset_doc.to_text(separator="", strip=false),
    "\u{20AC}",
  )
  guard quoted_empty_charset_doc.encoding is Some("windows-1252") else {
    fail("expected quoted empty content charset to fall back")
  }
  let valueless_http = b"<meta http-equiv content=\"text/html; charset=utf-8\"><p>\x80</p>"
  let valueless_http_doc = @html_parser.parse_bytes(valueless_http)
  assert_eq(valueless_http_doc.to_text(separator="", strip=false), "\u{20AC}")
  guard valueless_http_doc.encoding is Some("windows-1252") else {
    fail("expected valueless http-equiv to fall back")
  }
  let valueless_content = b"<meta http-equiv=\"Content-Type\" content><p>\x80</p>"
  let valueless_content_doc = @html_parser.parse_bytes(valueless_content)
  assert_eq(
    valueless_content_doc.to_text(separator="", strip=false),
    "\u{20AC}",
  )
  guard valueless_content_doc.encoding is Some("windows-1252") else {
    fail("expected valueless content to fall back")
  }
  let unterminated = b"<meta http-equiv=\"Content-Type\" content=\"text/html; charset='utf-8\"><p>\x80</p>"
  let unterminated_doc = @html_parser.parse_bytes(unterminated)
  assert_eq(unterminated_doc.to_text(separator="", strip=false), "\u{20AC}")
  guard unterminated_doc.encoding is Some("windows-1252") else {
    fail("expected unterminated content charset quote to fall back")
  }
  let quoted_charset = b"<meta http-equiv='Content-Type' content='text/html; charset=\"utf-8\"'><p>\xe2\x82\xac</p>"
  let quoted_charset_doc = @html_parser.parse_bytes(quoted_charset)
  assert_eq(quoted_charset_doc.to_text(separator="", strip=false), "\u{20AC}")
  guard quoted_charset_doc.encoding is Some("utf-8") else {
    fail("expected raw quoted content charset to sniff utf-8")
  }
  let semicolon = b"<meta http-equiv='Content-Type' content='text/html; charset=utf-8; x=y'><p>\xe2\x82\xac</p>"
  let semicolon_doc = @html_parser.parse_bytes(semicolon)
  assert_eq(semicolon_doc.to_text(separator="", strip=false), "\u{20AC}")
  guard semicolon_doc.encoding is Some("utf-8") else {
    fail("expected semicolon-terminated content charset to sniff utf-8")
  }
}

///|
test "parse_bytes decodes utf16 bom and explicit encodings" {
  let little = b"\xff\xfe\x3c\x00\x70\x00\x3e\x00\x68\x00\x69\x00\x3c\x00\x2f\x00\x70\x00\x3e\x00"
  let little_doc = @html_parser.parse_bytes(little)
  assert_eq(
    little_doc.to_html(pretty=false),
    "<html><head></head><body><p>hi</p></body></html>",
  )
  guard little_doc.encoding is Some("utf-16le") else {
    fail("expected utf-16le encoding")
  }
  let big = b"\xfe\xff\x00\x3c\x00\x70\x00\x3e\x00\x68\x00\x69\x00\x3c\x00\x2f\x00\x70\x00\x3e"
  let big_doc = @html_parser.parse_bytes(big)
  assert_eq(
    big_doc.to_html(pretty=false),
    "<html><head></head><body><p>hi</p></body></html>",
  )
  guard big_doc.encoding is Some("utf-16be") else {
    fail("expected utf-16be encoding")
  }
  let explicit = @html_parser.parse_bytes(little, encoding="utf-16")
  assert_eq(
    explicit.to_html(pretty=false),
    "<html><head></head><body><p>hi</p></body></html>",
  )
  guard explicit.encoding is Some("utf-16") else {
    fail("expected explicit utf-16 encoding")
  }
  let explicit_generic_big = @html_parser.parse_bytes(big, encoding="utf-16")
  assert_eq(
    explicit_generic_big.to_html(pretty=false),
    "<html><head></head><body><p>hi</p></body></html>",
  )
  guard explicit_generic_big.encoding is Some("utf-16") else {
    fail("expected generic utf-16 encoding to preserve label")
  }
  let explicit_big = b"\x00\x3c\x00\x70\x00\x3e\x00\x62\x00\x65\x00\x3c\x00\x2f\x00\x70\x00\x3e"
  let explicit_big_doc = @html_parser.parse_bytes(
    explicit_big,
    encoding="UTF16BE",
  )
  assert_eq(
    explicit_big_doc.to_html(pretty=false),
    "<html><head></head><body><p>be</p></body></html>",
  )
  guard explicit_big_doc.encoding is Some("utf-16be") else {
    fail("expected explicit utf-16be encoding")
  }
}

///|
test "parse_bytes handles empty labels aliases and malformed utf16 tails" {
  let empty_label = @html_parser.parse_bytes(b"<p>\x80</p>", encoding="  ")
  assert_eq(empty_label.to_text(separator="", strip=false), "\u{20AC}")
  guard empty_label.encoding is Some("windows-1252") else {
    fail("expected empty transport label to fall back")
  }
  let explicit_little = b"\x3c\x00\x70\x00\x3e\x00\x68\x00\x69\x00\x3c\x00\x2f\x00\x70\x00\x3e\x00"
  let explicit_little_doc = @html_parser.parse_bytes(
    explicit_little,
    encoding="UTF16LE",
  )
  assert_eq(
    explicit_little_doc.to_html(pretty=false),
    "<html><head></head><body><p>hi</p></body></html>",
  )
  guard explicit_little_doc.encoding is Some("utf-16le") else {
    fail("expected utf16le alias to normalize")
  }
  let odd_little = b"\xff\xfe\x3c\x00\x70\x00\x3e\x00\x41"
  let odd_little_doc = @html_parser.parse_bytes(odd_little)
  assert_eq(
    odd_little_doc.to_html(pretty=false),
    "<html><head></head><body><p>\u{FFFD}</p></body></html>",
  )
  guard odd_little_doc.encoding is Some("utf-16le") else {
    fail("expected malformed utf16le bom encoding")
  }
  let odd_big = b"\xfe\xff\x00\x3c\x00\x70\x00\x3e\x00\x42\x00"
  let odd_big_doc = @html_parser.parse_bytes(odd_big)
  assert_eq(
    odd_big_doc.to_html(pretty=false),
    "<html><head></head><body><p>B\u{FFFD}</p></body></html>",
  )
  guard odd_big_doc.encoding is Some("utf-16be") else {
    fail("expected malformed utf16be bom encoding")
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
