///|
test "stream emits start text end events" {
  let events = @html_parser.stream(
    "<div class=\"container\">Hello <b>World</b></div>",
  )
  assert_true(
    events ==
    [
      StreamStart({ name: "div", attrs: { "class": Some("container") } }),
      StreamText("Hello "),
      StreamStart({ name: "b", attrs: {} }),
      StreamText("World"),
      StreamEnd("b"),
      StreamEnd("div"),
    ],
  )
}

///|
test "stream emits comments doctypes void elements and unmatched end tags" {
  assert_true(
    @html_parser.stream("<!-- comment -->") == [StreamComment(" comment ")],
  )
  assert_true(
    @html_parser.stream("<!DOCTYPE html>") ==
    [StreamDoctype({ name: "html", public_id: None, system_id: None })],
  )
  assert_true(
    @html_parser.stream("<br><hr>") ==
    [
      StreamStart({ name: "br", attrs: {} }),
      StreamStart({ name: "hr", attrs: {} }),
    ],
  )
  assert_true(@html_parser.stream("</div>") == [StreamEnd("div")])
}

///|
test "stream coalesces text and preserves script raw text" {
  assert_true(@html_parser.stream("abc") == [StreamText("abc")])
  assert_true(
    @html_parser.stream("<script>console.log('<');</script>") ==
    [
      StreamStart({ name: "script", attrs: {} }),
      StreamText("console.log('<');"),
      StreamEnd("script"),
    ],
  )
}

///|
test "stream_bytes decodes transport and sniffed encodings" {
  assert_true(
    @html_parser.stream_bytes(b"<p>\x80</p>") ==
    [
      StreamStart({ name: "p", attrs: {} }),
      StreamText("\u{20AC}"),
      StreamEnd("p"),
    ],
  )
  assert_true(
    @html_parser.stream_bytes(b"<meta charset=utf-8><p>\xe2\x82\xac</p>") ==
    [
      StreamStart({ name: "meta", attrs: { "charset": Some("utf-8") } }),
      StreamStart({ name: "p", attrs: {} }),
      StreamText("\u{20AC}"),
      StreamEnd("p"),
    ],
  )
  assert_true(
    @html_parser.stream_bytes(b"<p>\xe2\x82\xac</p>", encoding="utf-8") ==
    [
      StreamStart({ name: "p", attrs: {} }),
      StreamText("\u{20AC}"),
      StreamEnd("p"),
    ],
  )
}

///|
test "stream sink buffers text and copies tag attrs" {
  let sink = @html_parser.StreamSink::new()
  sink.process_characters("a")
  sink.process_characters("b")
  assert_true(sink.drain() == [StreamText("ab")])
  assert_true(sink.drain().is_empty())

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
}

///|
test "stream_each emits events incrementally" {
  let events : Array[@html_parser.StreamEvent] = []
  @html_parser.stream_each("<p>a<b>b</b></p>", fn(event) { events.push(event) })
  assert_true(
    events ==
    [
      StreamStart({ name: "p", attrs: {} }),
      StreamText("a"),
      StreamStart({ name: "b", attrs: {} }),
      StreamText("b"),
      StreamEnd("b"),
      StreamEnd("p"),
    ],
  )

  let bytes_events : Array[@html_parser.StreamEvent] = []
  @html_parser.stream_bytes_each(b"<p>\x80</p>", fn(event) {
    bytes_events.push(event)
  })
  assert_true(
    bytes_events ==
    [
      StreamStart({ name: "p", attrs: {} }),
      StreamText("\u{20AC}"),
      StreamEnd("p"),
    ],
  )

  let explicit_bytes_events : Array[@html_parser.StreamEvent] = []
  @html_parser.stream_bytes_each(
    b"<p>\xe2\x82\xac</p>",
    fn(event) { explicit_bytes_events.push(event) },
    encoding="utf-8",
  )
  assert_true(
    explicit_bytes_events ==
    [
      StreamStart({ name: "p", attrs: {} }),
      StreamText("\u{20AC}"),
      StreamEnd("p"),
    ],
  )
}
