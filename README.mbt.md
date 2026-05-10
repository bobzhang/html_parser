# bobzhang/html_parser

MoonBit port of the JustHTML parser. This is being ported incrementally from
the Python reference implementation in `.repos/justhtml`.

The current slice provides:

- Public DOM node builders.
- Compact and simple pretty HTML serialization.
- Text extraction.
- A tolerant parser for basic documents/fragments.
- Basic document-mode scaffolding with `html/head/body`.
- Stable token data structures for early tokenizer harness work.
- CSS-style DOM queries for tag, class, id, attributes, combinators, selector
  lists, and common pseudo selectors.
- Byte input parsing with supported transport labels, BOM sniffing, and
  meta-charset prescan.
- Initial Markdown conversion for text, paragraphs, headings, inline
  formatting, links, code, lists, blockquotes, and raw HTML passthrough.

```mbt check
///|
test "readme parse fragment example" {
  let doc = parse_fragment("<p class='intro'>Hello <b>MoonBit</b></p>")
  assert_eq(
    doc.to_html(pretty=false),
    "<p class=\"intro\">Hello <b>MoonBit</b></p>",
  )
  assert_eq(doc.to_text(separator="", strip=false), "Hello MoonBit")
  assert_eq(doc.to_markdown(), "Hello **MoonBit**")
  assert_eq(doc.query("p.intro").length(), 1)
  let tokens = tokenize("<p>Hello</p>").tokens
  assert_eq(tokens.length(), 4)
}
```

```mbt check
///|
test "readme parse bytes example" {
  let bytes = @utf8.encode("<meta charset=utf-8><p>\u{20AC}</p>")
  let doc = parse_bytes(bytes)
  guard doc.encoding is Some("utf-8") else { fail("expected utf-8 encoding") }
  assert_eq(doc.to_text(separator="", strip=false), "\u{20AC}")
}
```

Full HTML5 tree construction, sanitization, transforms, linkify, streaming,
full Markdown parity, and CLI compatibility are planned as separate passing
slices.
