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
- Default-policy DOM sanitization with tag/attribute allowlists, comment and
  doctype handling, unsafe attribute filtering, basic URL checks, and explicit
  parse-time sanitization via `sanitize=true`. Custom policies can unwrap,
  drop, or escape disallowed tags, force hardened anchor `rel` tokens, and
  allowlist simple inline CSS properties while stripping invisible Unicode and
  hardening allowed raw-text, foreign text-integration, active foreign contents,
  foreign URL-function attributes, meta refresh contents, and base URL rewrites.
  URL-like attributes require exact URL policy rules. Policies can keep the
  default strip behavior, collect security findings, or raise on the first
  unsafe construct, and can define exact tag/attribute URL rules for schemes,
  hosts, fragments, relative URLs, protocol-relative rewrites, and allow/strip
  handling while rejecting malformed host values and backslashes. URL handling
  can also proxy validated URLs through a policy-level or per-rule
  `UrlProxy`, including single URL attributes, simple `srcset`/`imagesrcset`
  candidate lists, `ping`/`attributionsrc` URL-token lists, and plain CSS
  `url(...)` values on allowlisted inline-style properties. Use
  `css_preset_text()` for the
  conservative text-style property allowlist from the reference sanitizer.
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

```mbt check
///|
test "readme sanitize dom example" {
  let doc = parse(
    "<!DOCTYPE html><!--x--><p onclick=alert(1)>ok</p><script>alert(1)</script>",
    sanitize=false,
  )
  let clean = sanitize_dom(doc.root, policy=default_sanitization_policy())
  assert_eq(clean.to_html(pretty=false), "<p>ok</p>")
  let fragment = parse_fragment(
    "<p onclick=alert(1)>ok</p><script>alert(1)</script>",
    sanitize=true,
  )
  assert_eq(fragment.to_html(pretty=false), "<p>ok</p>")
}
```

Full HTML5 tree construction, full sanitizer transform parity, linkify,
streaming, full Markdown parity, and CLI compatibility are planned as separate
passing slices.
