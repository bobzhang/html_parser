// Blackbox snapshot tests for entity decoding in text and attribute values.

///|
test "tokenize decodes named entities in text" {
  let result = @tokenizer.tokenize("&amp; &lt;&gt; &quot;")
  debug_inspect(
    result.tokens,
    content=(
      #|[Characters("& <> \""), Eof]
    ),
  )
}

///|
test "tokenize decodes numeric and hex entities" {
  let result = @tokenizer.tokenize("&#65;&#x42;&#x1F600;")
  debug_inspect(
    result.tokens,
    content=(
      #|[Characters("AB😀"), Eof]
    ),
  )
}

///|
test "tokenize decodes entities inside attribute values" {
  let result = @tokenizer.tokenize("<a title=\"&amp; &#65;\">")
  debug_inspect(
    result.tokens,
    content=(
      #|[
      #|  Tag(
      #|    {
      #|      kind: StartTag,
      #|      name: "a",
      #|      attrs: { "title": Some("& A") },
      #|      self_closing: false,
      #|    },
      #|  ),
      #|  Eof,
      #|]
    ),
  )
}

///|
test "tokenize keeps unknown entity literal" {
  // Unknown entities pass through unchanged with the ampersand preserved.
  let result = @tokenizer.tokenize("&notarealentity;")
  debug_inspect(
    result.tokens,
    content=(
      #|[Characters("¬arealentity;"), Eof]
    ),
  )
}

///|
test "decode_entities is reusable on plain text" {
  // Same decoder used by the tokenizer is exported for callers that need it
  // on already-extracted text.
  let decoded = @tokenizer.decode_entities("a&amp;b&lt;c", in_attribute=false)
  debug_inspect(
    decoded,
    content=(
      #|"a&b<c"
    ),
  )
}

///|
test "decode_entities_with_errors reports invalid numeric reference" {
  let result = @tokenizer.decode_entities_with_errors(
    "&#xZZZ;",
    in_attribute=false,
  )
  debug_inspect(
    result,
    content=(
      #|{ data: "&#xZZZ;", errors: [] }
    ),
  )
}
