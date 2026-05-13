///|
test "public tokenizer corpus keeps structured tokens stable" {
  let result = @html_parser.tokenize(
    "<!DOCTYPE html><p class='x'>Hi<br/><!--ok--><script>a < b</script></p>",
    collect_errors=true,
  )
  assert_eq(result.errors.length(), 0)
  assert_eq(result.tokens.length(), 10)
  guard result.tokens[0] is DoctypeToken(info) else {
    fail("expected doctype token")
  }
  assert_eq(info.name, "html")
  assert_true(info.public_id is None)
  assert_true(info.system_id is None)
  guard result.tokens[1] is Tag(paragraph) else {
    fail("expected paragraph start token")
  }
  assert_true(paragraph.kind is StartTag)
  assert_eq(paragraph.name, "p")
  guard paragraph.attrs["class"] is Some("x") else {
    fail("expected paragraph class")
  }
  guard result.tokens[2] is Characters("Hi") else {
    fail("expected text token")
  }
  guard result.tokens[3] is Tag(br) else { fail("expected br token") }
  assert_true(br.kind is StartTag)
  assert_eq(br.name, "br")
  assert_eq(br.self_closing, true)
  guard result.tokens[4] is CommentToken("ok") else {
    fail("expected comment token")
  }
  guard result.tokens[5] is Tag(script_start) else {
    fail("expected script start")
  }
  assert_eq(script_start.name, "script")
  guard result.tokens[6] is Characters("a < b") else {
    fail("expected raw script text")
  }
  guard result.tokens[7] is Tag(script_end) else { fail("expected script end") }
  assert_true(script_end.kind is EndTag)
  assert_eq(script_end.name, "script")
  guard result.tokens[9] is Eof else { fail("expected EOF") }
}

///|
test "public tokenizer malformed-input errors stay stable" {
  let null_attr = @html_parser.tokenize(
    "<div a\u{0000}b='c'>",
    collect_errors=true,
  )
  guard null_attr.tokens[0] is Tag(null_attr_tag) else {
    fail("expected null attribute start tag")
  }
  guard null_attr_tag.attrs["a\u{FFFD}b"] is Some("c") else {
    fail("expected replacement character in attribute name")
  }
  assert_eq(null_attr.errors.length(), 1)
  assert_eq(null_attr.errors[0].code, "unexpected-null-character")
  assert_eq(null_attr.errors[0].category, "tokenizer")
  guard null_attr.errors[0].line is Some(1) else {
    fail("expected null attribute error line")
  }
  guard null_attr.errors[0].column is Some(7) else {
    fail("expected null attribute error column")
  }

  let raw_end = @html_parser.tokenize("</div attr=x>", collect_errors=true)
  assert_eq(raw_end.errors.length(), 0)
  guard raw_end.tokens[0] is Tag(raw_end_tag) else {
    fail("expected raw end tag")
  }
  assert_true(raw_end_tag.kind is EndTag)
  assert_eq(raw_end_tag.name, "div")
  assert_eq(raw_end_tag.self_closing, false)
  guard raw_end_tag.attrs["attr"] is Some("x") else {
    fail("expected raw end tag attr")
  }
  let self_closing_end = @html_parser.tokenize("</div/>", collect_errors=true)
  assert_eq(self_closing_end.errors.length(), 0)
  guard self_closing_end.tokens[0] is Tag(self_closing_end_tag) else {
    fail("expected self-closing end tag")
  }
  assert_true(self_closing_end_tag.kind is EndTag)
  assert_eq(self_closing_end_tag.name, "div")
  assert_eq(self_closing_end_tag.self_closing, true)
}

///|
test "public stream and sink corpus keeps incremental events stable" {
  let events : Array[@html_parser.StreamEvent] = []
  @html_parser.stream_each(
    "<!doctype html><p>A<script>B < C</script><!--x--></p>",
    fn(event) { events.push(event) },
  )
  assert_true(
    events ==
    [
      StreamDoctype({ name: "html", public_id: None, system_id: None }),
      StreamStart({ name: "p", attrs: {} }),
      StreamText("A"),
      StreamStart({ name: "script", attrs: {} }),
      StreamText("B < C"),
      StreamEnd("script"),
      StreamComment("x"),
      StreamEnd("p"),
    ],
  )

  let sink = @html_parser.StreamSink::new()
  let tokenized = @html_parser.tokenize("<p class=x>y</p>")
  guard tokenized.tokens[0] is Tag(tag) else {
    fail("expected start tag token")
  }
  sink.process_token(Tag(tag))
  tag.attrs["class"] = Some("changed")
  assert_true(
    sink.drain() == [StreamStart({ name: "p", attrs: { "class": Some("x") } })],
  )
  sink.process_token(tokenized.tokens[1])
  sink.process_token(tokenized.tokens[2])
  sink.process_token(tokenized.tokens[3])
  assert_true(sink.drain() == [StreamText("y"), StreamEnd("p")])
  assert_true(sink.drain().is_empty())
}
