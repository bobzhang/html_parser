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
  @stream.stream(html)
}

///|
/// Parse an HTML string and emit streaming events incrementally.
pub fn stream_each(html : StringView, emit : (StreamEvent) -> Unit) -> Unit {
  @stream.stream_each(html, emit)
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
  match encoding {
    Some(value) => @stream.stream_bytes(input, encoding=value)
    None => @stream.stream_bytes(input)
  }
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
  match encoding {
    Some(value) => @stream.stream_bytes_each(input, emit, encoding=value)
    None => @stream.stream_bytes_each(input, emit)
  }
}
