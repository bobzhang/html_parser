# `@tokenizer`

Low-level HTML5 tokenizer. Drives the higher-level tree builder in
`@parser`, but is also useful on its own when you only need a flat stream
of tags, text, comments, and doctypes — for example to count tag usage,
strip a specific element, or build a custom syntax highlighter.

The examples below are `mbt check` blocks and run as part of
`moon test tokenizer`.

## A first token stream

`tokenize` returns a `TokenizedHtml` with a list of tokens. Every token
stream ends with an explicit `Eof`.

```mbt check
///|
test "readme tokenize hello" {
  let result = @tokenizer.tokenize("<p class='hi'>Hello</p>")
  debug_inspect(
    result.tokens,
    content=(
      #|[
      #|  Tag(
      #|    {
      #|      kind: StartTag,
      #|      name: "p",
      #|      attrs: { "class": Some("hi") },
      #|      self_closing: false,
      #|    },
      #|  ),
      #|  Characters("Hello"),
      #|  Tag({ kind: EndTag, name: "p", attrs: {}, self_closing: false }),
      #|  Eof,
      #|]
    ),
  )
}
```

## Token shape at a glance

```mbt nocheck
///|
pub(all) enum HtmlToken {
  Tag(TagToken)
  Characters(String)
  CommentToken(String)
  DoctypeToken(DoctypeInfo)
  Eof
}
```

- `Tag` carries `kind` (`StartTag` or `EndTag`), `name`, an attribute
  map, and the `self_closing` flag.
- `Characters` is the decoded text — entities like `&amp;` are already
  expanded.
- `CommentToken` holds the comment data without the `<!--`/`-->`
  delimiters.
- `DoctypeToken` holds the name, optional public/system identifiers, and
  the `force_quirks` flag.

## Collecting errors

By default the tokenizer recovers silently. Pass `collect_errors=true`
to get structured diagnostics alongside the recovered tokens.

```mbt check
///|
test "readme tokenize collect errors" {
  let result = @tokenizer.tokenize("<div a=>", collect_errors=true)
  debug_inspect(
    result,
    content=(
      #|{
      #|  tokens: [
      #|    Tag(
      #|      {
      #|        kind: StartTag,
      #|        name: "div",
      #|        attrs: { "a": Some("") },
      #|        self_closing: false,
      #|      },
      #|    ),
      #|    Eof,
      #|  ],
      #|  errors: [
      #|    {
      #|      code: "missing-attribute-value",
      #|      line: Some(1),
      #|      column: Some(8),
      #|      category: "tokenizer",
      #|      message: "missing-attribute-value",
      #|    },
      #|  ],
      #|}
    ),
  )
}
```

## Decoding character references

`decode_entities` exposes the same decoder the tokenizer uses on text
nodes and attribute values, in case you already have the raw string.

```mbt check
///|
test "readme decode entities" {
  let decoded = @tokenizer.decode_entities(
    "Tom &amp; Jerry &#x26; friends",
    in_attribute=false,
  )
  debug_inspect(
    decoded,
    content=(
      #|"Tom & Jerry & friends"
    ),
  )
}
```

## Streaming callback variant

When you do not want the intermediate array, `tokenize_each` invokes a
callback per token:

```mbt check
///|
test "readme tokenize_each counts tags" {
  let mut start_tags = 0
  @tokenizer.tokenize_each("<p>one</p><p>two</p>", token => {
    match token {
      Tag({ kind: StartTag, .. }) => start_tags = start_tags + 1
      _ => ()
    }
  })
  assert_eq(start_tags, 2)
}
```

## When to reach for `@parser` instead

The tokenizer is intentionally context-free: it does not insert implicit
`<html>` / `<head>` / `<body>` elements, balance mismatched tags, or
foster-parent table contents. For a real DOM with HTML5 recovery
semantics, call `@parser.parse` (or the convenience wrappers at the
crate root). Use `@tokenizer` directly when you want the raw token
stream without that machinery.
