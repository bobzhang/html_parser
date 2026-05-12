///|
pub(all) struct StreamStartEvent {
  name : String
  attrs : Map[String, String?]
} derive(Debug, Eq)

///|
pub(all) struct StreamDoctypeEvent {
  name : String
  public_id : String?
  system_id : String?
} derive(Debug, Eq)

///|
pub(all) enum StreamEvent {
  StreamStart(StreamStartEvent)
  StreamText(String)
  StreamEnd(String)
  StreamComment(String)
  StreamDoctype(StreamDoctypeEvent)
} derive(Debug, Eq)

///|
pub struct StreamSink {
  priv events : Array[StreamEvent]
  priv text_parts : Array[String]
} derive(Debug)

///|
pub fn StreamSink::new() -> StreamSink {
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
pub fn StreamSink::process_characters(self : StreamSink, data : String) -> Unit {
  self.text_parts.push(data)
}

///|
pub fn StreamSink::process_token(self : StreamSink, token : HtmlToken) -> Unit {
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
pub fn stream(html : StringView) -> Array[StreamEvent] {
  let events : Array[StreamEvent] = []
  stream_each(html, fn(event) { events.push(event) })
  events
}

///|
pub fn StreamSink::drain(self : StreamSink) -> Array[StreamEvent] {
  self.flush_text()
  let out = self.events.copy()
  self.events.clear()
  out
}

///|
pub fn StreamSink::drain_each(
  self : StreamSink,
  emit : (StreamEvent) -> Unit,
) -> Unit {
  self.flush_text()
  for event in self.events {
    emit(event)
  }
  self.events.clear()
}

///|
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
pub fn stream_bytes_each(
  input : BytesView,
  emit : (StreamEvent) -> Unit,
  encoding? : String,
) -> Unit {
  let (decoded, _) = decode_html_bytes(input, encoding)
  stream_each(decoded, emit)
}
