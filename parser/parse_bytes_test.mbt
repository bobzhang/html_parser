// Blackbox snapshot tests for `parse_bytes` — byte input with BOM
// sniffing, meta-charset prescan, and transport-label-driven decoding.

///|
test "parse_bytes sniffs windows-1252 fallback for naked 0x80" {
  // 0x80 has no valid UTF-8 interpretation, so the parser falls back
  // to windows-1252 (€).
  let doc = @parser.parse_bytes(b"<p>\x80</p>")
  debug_inspect(
    (@ser.to_html(doc.root, pretty=false), doc.encoding),
    content=(
      #|(
      #|  "<html><head></head><body><p>€</p></body></html>",
      #|  Some("windows-1252"),
      #|)
    ),
  )
}

///|
test "parse_bytes honors meta charset prescan" {
  let doc = @parser.parse_bytes(b"<meta charset=utf-8><p>\xe2\x82\xac</p>")
  debug_inspect(
    (@ser.to_html(doc.root, pretty=false), doc.encoding),
    content=(
      #|(
      #|  "<html><head><meta charset=\"utf-8\"></head><body><p>€</p></body></html>",
      #|  Some("utf-8"),
      #|)
    ),
  )
}

///|
test "parse_bytes honors explicit encoding argument" {
  let doc = @parser.parse_bytes(b"<p>\xe2\x82\xac</p>", encoding="utf-8")
  debug_inspect(
    (@ser.to_html(doc.root, pretty=false), doc.encoding),
    content=(
      #|("<html><head></head><body><p>€</p></body></html>", Some("utf-8"))
    ),
  )
}

///|
test "parse_bytes strips UTF-8 BOM and reports utf-8 encoding" {
  let doc = @parser.parse_bytes(b"\xef\xbb\xbf<p>hi</p>")
  debug_inspect(
    (@ser.to_html(doc.root, pretty=false), doc.encoding),
    content=(
      #|("<html><head></head><body><p>hi</p></body></html>", Some("utf-8"))
    ),
  )
}
