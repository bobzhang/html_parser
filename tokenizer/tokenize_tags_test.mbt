// Blackbox snapshot tests for `tokenize` on tag-shaped input.
//
// Each snapshot doubles as documentation: read the `content=` to see exactly
// what the public `tokenize` API returns for a given HTML string. Regenerate
// with `moon test tokenizer --update` after intentional behavior changes.

///|
test "tokenize start tag with class attribute" {
  let result = @tokenizer.tokenize("<p class='x'>")
  debug_inspect(
    result.tokens,
    content=(
      #|[
      #|  Tag(
      #|    {
      #|      kind: StartTag,
      #|      name: "p",
      #|      attrs: { "class": Some("x") },
      #|      self_closing: false,
      #|    },
      #|  ),
      #|  Eof,
      #|]
    ),
  )
}

///|
test "tokenize void-like start tag without trailing slash" {
  let result = @tokenizer.tokenize("<br>")
  debug_inspect(
    result.tokens,
    content=(
      #|[
      #|  Tag({ kind: StartTag, name: "br", attrs: {}, self_closing: false }),
      #|  Eof,
      #|]
    ),
  )
}

///|
test "tokenize self-closing tag with explicit slash" {
  let result = @tokenizer.tokenize("<img/>")
  debug_inspect(
    result.tokens,
    content=(
      #|[
      #|  Tag({ kind: StartTag, name: "img", attrs: {}, self_closing: true }),
      #|  Eof,
      #|]
    ),
  )
}

///|
test "tokenize end tag" {
  let result = @tokenizer.tokenize("</p>")
  debug_inspect(
    result.tokens,
    content=(
      #|[
      #|  Tag({ kind: EndTag, name: "p", attrs: {}, self_closing: false }),
      #|  Eof,
      #|]
    ),
  )
}

///|
test "tokenize start and end tag pair" {
  let result = @tokenizer.tokenize("<p>hi</p>")
  debug_inspect(
    result.tokens,
    content=(
      #|[
      #|  Tag({ kind: StartTag, name: "p", attrs: {}, self_closing: false }),
      #|  Characters("hi"),
      #|  Tag({ kind: EndTag, name: "p", attrs: {}, self_closing: false }),
      #|  Eof,
      #|]
    ),
  )
}

///|
test "tokenize empty attribute value forms" {
  // Three equivalent ways to write an empty id attribute.
  let bare = @tokenizer.tokenize("<title id>")
  let space = @tokenizer.tokenize("<title id >")
  let equals = @tokenizer.tokenize("<title id=>", collect_errors=true)
  debug_inspect(
    (bare.tokens, space.tokens, equals.tokens),
    content=(
      #|(
      #|  [
      #|    Tag(
      #|      {
      #|        kind: StartTag,
      #|        name: "title",
      #|        attrs: { "id": Some("") },
      #|        self_closing: false,
      #|      },
      #|    ),
      #|    Eof,
      #|  ],
      #|  [
      #|    Tag(
      #|      {
      #|        kind: StartTag,
      #|        name: "title",
      #|        attrs: { "id": Some("") },
      #|        self_closing: false,
      #|      },
      #|    ),
      #|    Eof,
      #|  ],
      #|  [
      #|    Tag(
      #|      {
      #|        kind: StartTag,
      #|        name: "title",
      #|        attrs: { "id": Some("") },
      #|        self_closing: false,
      #|      },
      #|    ),
      #|    Eof,
      #|  ],
      #|)
    ),
  )
}

///|
test "tokenize multiple attributes with quoted and unquoted values" {
  let result = @tokenizer.tokenize("<a href=/x class=\"y z\" data-id='3'>")
  debug_inspect(
    result.tokens,
    content=(
      #|[
      #|  Tag(
      #|    {
      #|      kind: StartTag,
      #|      name: "a",
      #|      attrs: { "href": Some("/x"), "class": Some("y z"), "data-id": Some("3") },
      #|      self_closing: false,
      #|    },
      #|  ),
      #|  Eof,
      #|]
    ),
  )
}

///|
test "tokenize keeps quote and backslash inside attribute name" {
  // Tokenization is lenient about attribute names: a backslash or stray quote
  // becomes part of the name rather than triggering a parse error.
  let result = @tokenizer.tokenize("<title id\\\">")
  debug_inspect(
    result.tokens,
    content=(
      #|[
      #|  Tag(
      #|    {
      #|      kind: StartTag,
      #|      name: "title",
      #|      attrs: { "id\\\"": Some("") },
      #|      self_closing: false,
      #|    },
      #|  ),
      #|  Eof,
      #|]
    ),
  )
}

///|
test "tokenize raw end tag before tree recovery" {
  // The tokenizer emits the tag verbatim; the tree builder is what decides
  // whether it is balanced.
  let result = @tokenizer.tokenize("<p>open</span>")
  debug_inspect(
    result.tokens,
    content=(
      #|[
      #|  Tag({ kind: StartTag, name: "p", attrs: {}, self_closing: false }),
      #|  Characters("open"),
      #|  Tag({ kind: EndTag, name: "span", attrs: {}, self_closing: false }),
      #|  Eof,
      #|]
    ),
  )
}
