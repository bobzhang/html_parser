///|
test "public default sanitizer security corpus stays stable" {
  let doc = @html_parser.parse_fragment(
    "<p onclick=bad style=\"color:red;background:url(javascript:bad)\">ok</p><!--x--><a href=javascript:bad rel=nofollow>bad</a><math><mtext><img src=x onerror=1></mtext></math><script>bad</script>",
    sanitize=true,
  )
  assert_eq(doc.to_html(pretty=false), "<p>ok</p><a>bad</a>")
  assert_eq(doc.to_text(separator="|", strip=true), "ok|bad")
}

///|
test "parse sanitize flag applies default sanitizer policies" {
  let fragment = @html_parser.parse_fragment(
    "<p onclick=x>ok</p><script>bad</script>",
    sanitize=true,
  )
  assert_eq(fragment.to_html(pretty=false), "<p>ok</p>")
  let doc = @html_parser.parse(
    "<!DOCTYPE html><!--x--><html><head><title>T</title><script>bad</script></head><body><p onclick=x>ok</p></body></html>",
    sanitize=true,
  )
  assert_eq(
    doc.to_html(pretty=false),
    "<!DOCTYPE html><html><head><title>T</title></head><body><p>ok</p></body></html>",
  )
  let bytes = @html_parser.parse_bytes(
    b"<p onclick=x>bytes</p><script>bad</script>",
    sanitize=true,
  )
  assert_eq(
    bytes.to_html(pretty=false),
    "<html><head></head><body><p>bytes</p></body></html>",
  )
  guard bytes.encoding is Some("windows-1252") else {
    fail("expected sanitized bytes parse to preserve encoding")
  }
}
