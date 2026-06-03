# `@parser`

HTML5 document and fragment parser. Builds a DOM tree from a string or
a byte slice, with implicit `html`/`head`/`body` scaffolding, error
recovery for malformed input, table foster-parenting, foreign-content
handling, and structured parse diagnostics.

Most callers reach the parser through the crate-root convenience
wrappers (`@html_parser.parse`, `@html_parser.parse_fragment`,
`@html_parser.parse_bytes`). This package is what those forward to.

The examples below are `mbt check` blocks and run as part of
`moon test parser`.

## A first document parse

`parse` always returns a `ParsedHtml { root, errors, encoding }`. The
root is a real DOM tree with implicit `<html>` and `<body>` inserted
even when the input only contains a body fragment.

```mbt check
///|
test "readme parse hello" {
  let doc = @parser.parse("<p>hi</p>")
  inspect(
    @ser.to_html(doc.root, pretty=true),
    content=(
      #|<html>
      #|  <head></head>
      #|  <body>
      #|    <p>hi</p>
      #|  </body>
      #|</html>
    ),
  )
}
```

## Head vs body routing

`<meta>`, `<title>`, `<style>`, and `<script>` get routed into the
implicit `<head>`; everything else falls into the `<body>`.

```mbt check
///|
test "readme parse head routing" {
  let doc = @parser.parse("<meta charset=utf-8><title>T</title><p>x</p>")
  inspect(
    @ser.to_html(doc.root, pretty=true),
    content=(
      #|<html>
      #|  <head>
      #|    <meta charset="utf-8">
      #|    <title>T</title>
      #|  </head>
      #|  <body>
      #|    <p>x</p>
      #|  </body>
      #|</html>
    ),
  )
}
```

## Parsing a fragment instead of a document

`parse_fragment` is the right entry point for snippets that should
not be wrapped in implicit scaffolding — e.g. a `<p>` you intend to
inject into an existing page.

```mbt check
///|
test "readme parse_fragment basic" {
  let doc = @parser.parse_fragment("<p>hello <b>world</b></p>")
  inspect(
    @ser.to_html(doc.root, pretty=false),
    content=(
      #|<p>hello <b>world</b></p>
    ),
  )
}
```

Passing a `FragmentContext` tells the parser which container the
fragment will live inside. In `table` context, bare `<tr>` is wrapped
in an implicit `<tbody>` exactly like the document parser does.

```mbt check
///|

///|
test "readme parse_fragment table context" {
  let doc = @parser.parse_fragment(
    "<tr><td>x</td></tr>",
    context=FragmentContext("table"),
  )
  inspect(
    @ser.to_html(doc.root, pretty=true),
    content=(
      #|<tbody>
      #|  <tr>
      #|    <td>x</td>
      #|  </tr>
      #|</tbody>
    ),
  )
}
```

## Byte input with encoding detection

`parse_bytes` runs BOM sniffing and meta-charset prescan and exposes
the resolved encoding on the result. With no signal, naked high bytes
fall back to windows-1252.

```mbt check
///|
test "readme parse_bytes fallback" {
  let doc = @parser.parse_bytes(b"<p>\x80</p>")
  debug_inspect(
    (doc.encoding, @ser.to_html(doc.root, pretty=false)),
    content=(
      #|(
      #|  Some("windows-1252"),
      #|  "<html><head></head><body><p>€</p></body></html>",
      #|)
    ),
  )
}
```

## Collecting parse errors

By default the parser recovers silently. `collect_errors=true` returns
a structured diagnostic list with code, category, and source position.

```mbt check
///|
test "readme parse collect_errors" {
  let doc = @parser.parse_fragment("<p>hi</span></p>", collect_errors=true)
  debug_inspect(
    doc.errors,
    content=(
      #|[
      #|  {
      #|    code: "unexpected-end-tag",
      #|    line: Some(1),
      #|    column: Some(12),
      #|    category: "treebuilder",
      #|    message: "unexpected-end-tag",
      #|  },
      #|]
    ),
  )
}
```

## Querying and converting the parsed tree

`ParsedHtml` carries convenience methods for the common
post-processing steps: CSS-style queries, plain-text extraction, and
Markdown rendering.

```mbt check
///|
test "readme parsed query and to_markdown" {
  let doc = @parser.parse_fragment(
    "<h1>Title</h1><p class='lede'>Hello <b>MoonBit</b></p>",
  )
  inspect(
    doc.query(".lede").length(),
    content=(
      #|1
    ),
  )
  inspect(
    doc.to_markdown(),
    content=(
      #|# Title
      #|
      #|Hello **MoonBit**
    ),
  )
}
```
