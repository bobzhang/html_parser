///|
pub using @stream {type StreamStartEvent}

///|
pub using @stream {type StreamDoctypeEvent}

///|
pub using @stream {type StreamEvent}

///|
pub using @stream {type StreamSink}

///|
/// Parse an HTML string into streaming events.
pub fn stream(html : StringView) -> Array[StreamEvent] {
  let events : Array[StreamEvent] = []
  stream_each(html, fn(event) { events.push(event) })
  events
}

///|
/// Parse an HTML string and emit streaming events incrementally.
pub fn stream_each(html : StringView, emit : (StreamEvent) -> Unit) -> Unit {
  let tokenizer = SourceTokenizer::new(
    html,
    collect_errors=false,
    xml_coercion=false,
  )
  let sink = StreamSink::new()
  while !tokenizer.is_eof() {
    tokenizer.tokens.clear()
    ignore(tokenizer.step())
    for token in tokenizer.tokens {
      sink.process_token(token)
    }
    sink.drain_each(emit)
  }
  sink.drain_each(emit)
}

///|
/// Decode HTML bytes and return streaming events.
///
/// When `encoding` is omitted, the same byte-sniffing path used by
/// `parse_bytes` chooses the input encoding.
pub fn stream_bytes(
  input : BytesView,
  encoding? : String,
) -> Array[StreamEvent] {
  let events : Array[StreamEvent] = []
  let (decoded, _) = decode_html_bytes(input, encoding)
  stream_each(decoded, fn(event) { events.push(event) })
  events
}

///|
/// Decode HTML bytes and emit streaming events incrementally.
///
/// When `encoding` is omitted, the same byte-sniffing path used by
/// `parse_bytes` chooses the input encoding.
pub fn stream_bytes_each(
  input : BytesView,
  emit : (StreamEvent) -> Unit,
  encoding? : String,
) -> Unit {
  let (decoded, _) = decode_html_bytes(input, encoding)
  stream_each(decoded, emit)
}
