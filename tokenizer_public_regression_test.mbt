///|
test "tokenize exposes stable token data structures" {
  let result = @html_parser.tokenize("<p class='x'>Hi<br><!--ok--></p>")
  assert_eq(result.tokens.length(), 6)
  guard result.tokens[0] is Tag(start) else { fail("expected start tag") }
  assert_true(start.kind is StartTag)
  assert_eq(start.name, "p")
  guard start.attrs["class"] is Some("x") else { fail("expected class attr") }
  guard result.tokens[1] is Characters("Hi") else {
    fail("expected text token")
  }
  guard result.tokens[2] is Tag(br) else { fail("expected br tag") }
  assert_eq(br.self_closing, false)
  guard result.tokens[3] is CommentToken("ok") else {
    fail("expected comment token")
  }
  guard result.tokens[5] is Eof else { fail("expected EOF") }
  let explicit = @html_parser.tokenize("<img/>")
  guard explicit.tokens[0] is Tag(img) else { fail("expected img tag") }
  assert_eq(img.self_closing, true)
}
