///|
/// Start-tag event emitted by the streaming tokenizer facade.
///
/// `name` is the normalized tag name and `attrs` contains the decoded
/// attributes for the tag.
pub(all) struct StreamStartEvent {
  name : String
  attrs : Map[String, String?]
} derive(Debug, Eq)

///|
/// Doctype event emitted by the streaming tokenizer facade.
pub(all) struct StreamDoctypeEvent {
  name : String
  public_id : String?
  system_id : String?
} derive(Debug, Eq)

///|
/// Token-level streaming event.
///
/// The stream API does not build a DOM tree. It forwards start tags, end tags,
/// text, comments, and doctypes in tokenizer order, coalescing adjacent text.
pub(all) enum StreamEvent {
  StreamStart(StreamStartEvent)
  StreamText(String)
  StreamEnd(String)
  StreamComment(String)
  StreamDoctype(StreamDoctypeEvent)
} derive(Debug, Eq)

///|
/// Parse an HTML string into streaming events.
pub fn stream(html : StringView) -> Array[StreamEvent] {
  let sink = StreamSink::new()
  @tok.tokenize_each(html, fn(token) { sink.process_token(token) })
  sink.drain()
}

///|
/// Parse an HTML string and emit streaming events incrementally.
pub fn stream_each(html : StringView, emit : (StreamEvent) -> Unit) -> Unit {
  let sink = StreamSink::new()
  @tok.tokenize_each(html, fn(token) {
    sink.process_token(token)
    sink.drain_each(emit)
  })
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
  let (decoded, _) = @enc.decode_html_bytes(input, encoding)
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
  let (decoded, _) = @enc.decode_html_bytes(input, encoding)
  stream_each(decoded, emit)
}

///|
/// Mutable sink that converts tokenizer tokens into coalesced stream events.
struct StreamSink {
  events : Array[StreamEvent]
  text_parts : Array[String]
} derive(Debug)

///|
/// Create an empty stream sink.
fn StreamSink::new() -> StreamSink {
  { events: [], text_parts: [] }
}

///|
fn StreamSink::flush_text(self : StreamSink) -> Unit {
  if !self.text_parts.is_empty() {
    self.events.push(StreamText(self.text_parts.join("")))
    self.text_parts.clear()
  }
}

///|
/// Buffer character data until the next structural token or drain.
fn StreamSink::process_characters(self : StreamSink, data : String) -> Unit {
  self.text_parts.push(data)
}

///|
/// Process one tokenizer token into this sink.
///
/// Character tokens are buffered and adjacent text is emitted as a single
/// `StreamText` event. Non-text tokens flush pending text first.
fn StreamSink::process_token(self : StreamSink, token : @tok.HtmlToken) -> Unit {
  match token {
    Characters(data) => self.process_characters(data)
    Tag(tag) => {
      self.flush_text()
      match tag.kind {
        StartTag =>
          self.events.push(
            StreamStart({ name: tag.name, attrs: tag.attrs.copy() }),
          )
        EndTag => self.events.push(StreamEnd(tag.name))
      }
    }
    CommentToken(data) => {
      self.flush_text()
      self.events.push(StreamComment(data))
    }
    DoctypeToken(info) => {
      self.flush_text()
      self.events.push(
        StreamDoctype({
          name: info.name,
          public_id: info.public_id,
          system_id: info.system_id,
        }),
      )
    }
    Eof => self.flush_text()
  }
}

///|
/// Drain buffered events from this sink.
///
/// Pending character data is flushed before the returned array is copied, and
/// the sink is empty afterward.
fn StreamSink::drain(self : StreamSink) -> Array[StreamEvent] {
  self.flush_text()
  let out = self.events.copy()
  self.events.clear()
  out
}

///|
/// Drain buffered events by invoking `emit` for each event.
///
/// Pending character data is flushed first, and the sink is empty afterward.
fn StreamSink::drain_each(
  self : StreamSink,
  emit : (StreamEvent) -> Unit,
) -> Unit {
  self.flush_text()
  for event in self.events {
    emit(event)
  }
  self.events.clear()
}
