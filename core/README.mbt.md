# `@core`

Shared error types used across the parser pipeline. Most callers see
these through `parse(...).errors` or by catching `@core.HtmlError`
from a sanitize/serialize call.

The examples below are `mbt check` blocks and run as part of
`moon test core`.

## `ParseError`

A single parse diagnostic. `code` is the spec-style identifier;
`category` distinguishes tokenizer from tree-builder issues;
`line`/`column` are UTF-16 1-based positions when known.

```mbt check
///|
test "readme ParseError" {
  let err = @core.ParseError::new(
    "unexpected-null-character",
    line=3,
    column=14,
    category="tokenizer",
  )
  debug_inspect(
    err,
    content=(
      #|{
      #|  code: "unexpected-null-character",
      #|  line: Some(3),
      #|  column: Some(14),
      #|  category: "tokenizer",
      #|  message: "unexpected-null-character",
      #|}
    ),
  )
}
```

When `category` and `message` are omitted, they default to the code
itself; positions default to `None`.

## `parser_error_category`

Maps a parser-error code to its canonical category. Useful when you
want to bucket diagnostics without writing a per-code switch.

```mbt check
///|
test "readme parser_error_category" {
  debug_inspect(
    (
      @core.parser_error_category("unexpected-null-character"),
      @core.parser_error_category("unexpected-end-tag"),
    ),
    content=(
      #|("tokenizer", "treebuilder")
    ),
  )
}
```

## `HtmlError`

The error type raised by `parse`, `sanitize_dom`, and `to_html` when
something goes wrong end-to-end. Match on the variant to recover the
specific failure mode.

```mbt nocheck
///|
pub(all) suberror HtmlError {
  StrictMode(ParseError) // strict=true and parser found a diagnostic
  InvalidSerialization(String) // tree could not be serialized
  UnsafeHtml(String) // sanitizer found content it refused
  SelectorError(String) // CSS selector failed to compile
}
```
