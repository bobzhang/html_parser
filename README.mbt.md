# bobzhang/html_parser

MoonBit port of the JustHTML parser. This is being ported incrementally from
the Python reference implementation in `.repos/justhtml`.

The current slice provides:

- Public DOM node builders.
- Compact and simple pretty HTML serialization.
- Text extraction.
- A tolerant parser for basic documents/fragments.
- Basic tag, class, id, and `tag.class` queries.

```mbt check
///|
test "readme parse fragment example" {
  let doc = parse_fragment("<p class='intro'>Hello <b>MoonBit</b></p>")
  assert_eq(
    doc.to_html(pretty=false),
    "<p class=\"intro\">Hello <b>MoonBit</b></p>",
  )
  assert_eq(doc.to_text(separator="", strip=false), "Hello MoonBit")
  assert_eq(doc.query("p.intro").length(), 1)
}
```

Full HTML5 tree construction, sanitization, transforms, selectors, linkify,
encoding sniffing, streaming, Markdown, and CLI compatibility are planned as
separate passing slices.
