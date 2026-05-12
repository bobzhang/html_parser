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
fn stream_flush_text(
  events : Array[StreamEvent],
  text_parts : Array[String],
) -> Unit {
  if !text_parts.is_empty() {
    events.push(StreamText(text_parts.join("")))
    text_parts.clear()
  }
}

///|
pub fn stream(html : StringView) -> Array[StreamEvent] {
  let tokenized = tokenize(html)
  let events : Array[StreamEvent] = []
  let text_parts : Array[String] = []
  for token in tokenized.tokens {
    match token {
      Characters(data) => text_parts.push(data)
      Tag(tag) => {
        stream_flush_text(events, text_parts)
        match tag.kind {
          StartTag =>
            events.push(
              StreamStart({ name: tag.name, attrs: tag.attrs.copy() }),
            )
          EndTag => events.push(StreamEnd(tag.name))
        }
      }
      CommentToken(data) => {
        stream_flush_text(events, text_parts)
        events.push(StreamComment(data))
      }
      DoctypeToken(info) => {
        stream_flush_text(events, text_parts)
        events.push(
          StreamDoctype({
            name: info.name,
            public_id: info.public_id,
            system_id: info.system_id,
          }),
        )
      }
      Eof => stream_flush_text(events, text_parts)
    }
  }
  events
}
