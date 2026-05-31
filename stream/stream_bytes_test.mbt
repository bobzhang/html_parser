// Blackbox snapshot tests for the byte-input streaming entry points.

///|
test "stream_bytes sniffs windows-1252 fallback for naked 0x80" {
  // No charset hint and no BOM: 0x80 is decoded as windows-1252 €.
  debug_inspect(
    @stream.stream_bytes(b"<p>\x80</p>"),
    content=(
      #|[
      #|  StreamStart({ name: "p", attrs: {} }),
      #|  StreamText("€"),
      #|  StreamEnd("p"),
      #|]
    ),
  )
}

///|
test "stream_bytes honors meta charset prescan" {
  debug_inspect(
    @stream.stream_bytes(b"<meta charset=utf-8><p>\xe2\x82\xac</p>"),
    content=(
      #|[
      #|  StreamStart({ name: "meta", attrs: { "charset": Some("utf-8") } }),
      #|  StreamStart({ name: "p", attrs: {} }),
      #|  StreamText("€"),
      #|  StreamEnd("p"),
      #|]
    ),
  )
}

///|
test "stream_bytes honors explicit encoding argument" {
  debug_inspect(
    @stream.stream_bytes(b"<p>\xe2\x82\xac</p>", encoding="utf-8"),
    content=(
      #|[
      #|  StreamStart({ name: "p", attrs: {} }),
      #|  StreamText("€"),
      #|  StreamEnd("p"),
      #|]
    ),
  )
}

///|
test "stream_bytes_each callback variant matches stream_bytes" {
  let events : Array[@stream.StreamEvent] = []
  @stream.stream_bytes_each(b"<p>\x80</p>", event => events.push(event))
  debug_inspect(
    events,
    content=(
      #|[
      #|  StreamStart({ name: "p", attrs: {} }),
      #|  StreamText("€"),
      #|  StreamEnd("p"),
      #|]
    ),
  )
}
