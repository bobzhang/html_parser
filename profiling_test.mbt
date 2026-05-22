///|
fn make_parser_profile_html(repeats : Int) -> String {
  let chunk = "<section class=\"card\" data-kind=\"profile\"><h2>Profile title</h2><p>Alpha beta gamma <em>delta</em> epsilon &amp; zeta.</p><!-- profile comment payload --><script>let total = 0; for (let i = 0; i < 12; i++) { total += i; }</script><ul><li>one</li><li>two</li><li>three</li></ul></section>"
  let out = StringBuilder::new(size_hint=chunk.length() * repeats + 96)
  out.write_string(
    "<!doctype html><html><head><title>Profile</title></head><body>",
  )
  for _ in 0..<repeats {
    out.write_string(chunk)
  }
  out.write_string("</body></html>")
  out.to_string()
}

///|
#skip("profiling-only workload")
test "profile parser large valid document" {
  let input = make_parser_profile_html(4000)
  let mut total_errors = 0
  for _ in 0..<10 {
    let parsed = @html_parser.parse(input, strict=true)
    total_errors += parsed.errors.length()
  }
  assert_eq(total_errors, 0)
}
