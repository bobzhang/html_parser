# `@stream`

Event-based HTML parsing. Where `@parser` builds a full DOM and
`@tokenizer` emits raw tokens, `@stream` sits in between: it normalizes
the token sequence into a small set of high-level events — perfect for
serializers, syntax highlighters, link extractors, or any consumer that
only needs to see structure pass by.

The examples below are `mbt check` blocks and run as part of
`moon test stream`.

## Event shape

```mbt nocheck
///|
pub(all) enum StreamEvent {
  StreamStart(StreamStartEvent) // open tag with name + attrs
  StreamText(String) // decoded text (entities expanded)
  StreamEnd(String) // close tag with name
  StreamComment(String) // comment data, no delimiters
  StreamDoctype(StreamDoctypeEvent)
}
```

`stream` returns an array; `stream_each` invokes a callback per event.

## A first stream

Adjacent text is coalesced into a single `StreamText`.

```mbt check
///|
test "readme stream basic" {
  let events = @stream.stream("<p>Hello <b>World</b></p>")
  debug_inspect(
    events,
    content=(
      #|[
      #|  StreamStart({ name: "p", attrs: {} }),
      #|  StreamText("Hello "),
      #|  StreamStart({ name: "b", attrs: {} }),
      #|  StreamText("World"),
      #|  StreamEnd("b"),
      #|  StreamEnd("p"),
      #|]
    ),
  )
}
```

## Void elements and unmatched closers

The streamer reports what the input says — it does not synthesize
implicit end tags for void elements, and it does not drop unmatched
closing tags.

```mbt check
///|
test "readme stream void and unmatched" {
  debug_inspect(
    @stream.stream("<br></div>"),
    content=(
      #|[StreamStart({ name: "br", attrs: {} }), StreamEnd("div")]
    ),
  )
}
```

## Byte input with encoding detection

`stream_bytes` runs BOM sniffing and meta-charset prescan when
no encoding is provided. The byte `0x80` falls back to windows-1252
(€) when no other signal is present.

```mbt check
///|
test "readme stream_bytes fallback" {
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
```

Pass `encoding="utf-8"` (or any supported label) to skip detection.

## Incremental delivery

`stream_each` is `stream` without the intermediate array — useful when
you want to bail out early or write events straight to a sink.

```mbt check
///|
test "readme stream_each counts text events" {
  let mut text_events = 0
  @stream.stream_each("<p>a<b>b</b>c</p>", event => {
    match event {
      StreamText(_) => text_events = text_events + 1
      _ => ()
    }
  })
  assert_eq(text_events, 3)
}
```
