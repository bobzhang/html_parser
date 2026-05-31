// Blackbox snapshot tests for raw-text and special-text element contexts.
//
// Inside <script>/<style>/<textarea>/<title>, the tokenizer follows distinct
// rules: tags inside are usually treated as text, and entity decoding may or
// may not apply.

///|
test "tokenize script element keeps body as raw text" {
  let result = @tokenizer.tokenize("<script>if (a < b) { f(); }</script>")
  debug_inspect(
    result.tokens,
    content=(
      #|[
      #|  Tag({ kind: StartTag, name: "script", attrs: {}, self_closing: false }),
      #|  Characters("if (a < b) { f(); }"),
      #|  Tag({ kind: EndTag, name: "script", attrs: {}, self_closing: false }),
      #|  Eof,
      #|]
    ),
  )
}

///|
test "tokenize style element keeps body as raw text" {
  let result = @tokenizer.tokenize("<style>p > a { color: red }</style>")
  debug_inspect(
    result.tokens,
    content=(
      #|[
      #|  Tag({ kind: StartTag, name: "style", attrs: {}, self_closing: false }),
      #|  Characters("p > a { color: red }"),
      #|  Tag({ kind: EndTag, name: "style", attrs: {}, self_closing: false }),
      #|  Eof,
      #|]
    ),
  )
}

///|
test "tokenize textarea decodes entities in body" {
  let result = @tokenizer.tokenize("<textarea>&amp; &lt;</textarea>")
  debug_inspect(
    result.tokens,
    content=(
      #|[
      #|  Tag({ kind: StartTag, name: "textarea", attrs: {}, self_closing: false }),
      #|  Characters("& <"),
      #|  Tag({ kind: EndTag, name: "textarea", attrs: {}, self_closing: false }),
      #|  Eof,
      #|]
    ),
  )
}

///|
test "tokenize title decodes entities in body" {
  let result = @tokenizer.tokenize("<title>Tom &amp; Jerry</title>")
  debug_inspect(
    result.tokens,
    content=(
      #|[
      #|  Tag({ kind: StartTag, name: "title", attrs: {}, self_closing: false }),
      #|  Characters("Tom & Jerry"),
      #|  Tag({ kind: EndTag, name: "title", attrs: {}, self_closing: false }),
      #|  Eof,
      #|]
    ),
  )
}
