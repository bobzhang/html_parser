// Whitebox snapshots for the internal token-to-event sink. Public callers use
// `stream` or `stream_each`; these tests keep the implementation contract local.

///|
test "stream sink coalesces successive character pushes" {
  let sink = StreamSink()
  sink.process_characters("a")
  sink.process_characters("b")
  debug_inspect(
    sink.drain(),
    content=(
      #|[StreamText("ab")]
    ),
  )
}

///|
test "stream sink drain empties the buffer" {
  let sink = StreamSink()
  sink.process_characters("x")
  let first = sink.drain()
  let second_is_empty = sink.drain().is_empty()
  debug_inspect(
    (first, second_is_empty),
    content=(
      #|([StreamText("x")], true)
    ),
  )
}

///|
test "stream sink copies tag attrs so mutations do not leak" {
  // process_token snapshots attrs at the time of the call; later mutation
  // of the original token does not affect the produced StreamStart event.
  let sink = StreamSink()
  let tokenized = @tok.tokenize("<p class=x>y</p>")
  guard tokenized.tokens[0] is Tag(tag) else { fail("expected start tag") }
  sink.process_token(Tag(tag))
  tag.attrs["class"] = Some("changed")
  debug_inspect(
    sink.drain(),
    content=(
      #|[StreamStart({ name: "p", attrs: { "class": Some("x") } })]
    ),
  )
}

///|
test "stream sink streams tokens straight into events" {
  let sink = StreamSink()
  let tokenized = @tok.tokenize("<p>hi</p>")
  for token in tokenized.tokens {
    sink.process_token(token)
  }
  debug_inspect(
    sink.drain(),
    content=(
      #|[
      #|  StreamStart({ name: "p", attrs: {} }),
      #|  StreamText("hi"),
      #|  StreamEnd("p"),
      #|]
    ),
  )
}
