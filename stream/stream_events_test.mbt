// Blackbox snapshot tests for `stream` and `stream_each` — the streaming
// event API. Each snapshot is what the documented call returns; regenerate
// with `moon test stream --update` after intentional behavior changes.

///|
test "stream emits start, text, and end events" {
  let events = @stream.stream(
    "<div class=\"container\">Hello <b>World</b></div>",
  )
  debug_inspect(
    events,
    content=(
      #|[
      #|  StreamStart({ name: "div", attrs: { "class": Some("container") } }),
      #|  StreamText("Hello "),
      #|  StreamStart({ name: "b", attrs: {} }),
      #|  StreamText("World"),
      #|  StreamEnd("b"),
      #|  StreamEnd("div"),
      #|]
    ),
  )
}

///|
test "stream emits a comment event" {
  debug_inspect(
    @stream.stream("<!-- comment -->"),
    content=(
      #|[StreamComment(" comment ")]
    ),
  )
}

///|
test "stream emits a doctype event" {
  debug_inspect(
    @stream.stream("<!DOCTYPE html>"),
    content=(
      #|[StreamDoctype({ name: "html", public_id: None, system_id: None })]
    ),
  )
}

///|
test "stream emits void elements as start events with no matching end" {
  debug_inspect(
    @stream.stream("<br><hr>"),
    content=(
      #|[
      #|  StreamStart({ name: "br", attrs: {} }),
      #|  StreamStart({ name: "hr", attrs: {} }),
      #|]
    ),
  )
}

///|
test "stream emits unmatched end tag as a standalone end event" {
  debug_inspect(
    @stream.stream("</div>"),
    content=(
      #|[StreamEnd("div")]
    ),
  )
}

///|
test "stream coalesces adjacent text into a single event" {
  // Plain text between markup boundaries is merged.
  debug_inspect(
    @stream.stream("abc"),
    content=(
      #|[StreamText("abc")]
    ),
  )
}

///|
test "stream preserves script raw text without interpreting tags inside" {
  debug_inspect(
    @stream.stream("<script>console.log('<');</script>"),
    content=(
      #|[
      #|  StreamStart({ name: "script", attrs: {} }),
      #|  StreamText("console.log('<');"),
      #|  StreamEnd("script"),
      #|]
    ),
  )
}

///|
test "stream_each delivers the same sequence incrementally" {
  // The callback variant emits one event at a time without building an
  // intermediate array — useful for backpressure or early termination.
  let events : Array[@stream.StreamEvent] = []
  @stream.stream_each("<p>a<b>b</b></p>", event => events.push(event))
  debug_inspect(
    events,
    content=(
      #|[
      #|  StreamStart({ name: "p", attrs: {} }),
      #|  StreamText("a"),
      #|  StreamStart({ name: "b", attrs: {} }),
      #|  StreamText("b"),
      #|  StreamEnd("b"),
      #|  StreamEnd("p"),
      #|]
    ),
  )
}
