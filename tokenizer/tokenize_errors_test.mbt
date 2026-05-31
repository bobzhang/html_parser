// Blackbox snapshot tests for error reporting via `collect_errors=true`.
//
// These snapshots show both the recovered token stream AND the structured
// error list so callers can see what gets reported and at what position.

///|
test "null byte in attribute name becomes replacement char and reports error" {
  let result = @tokenizer.tokenize("<div a\u{0000}b='c'>", collect_errors=true)
  debug_inspect(
    result,
    content=(
      #|{
      #|  tokens: [
      #|    Tag(
      #|      {
      #|        kind: StartTag,
      #|        name: "div",
      #|        attrs: { "a�b": Some("c") },
      #|        self_closing: false,
      #|      },
      #|    ),
      #|    Eof,
      #|  ],
      #|  errors: [
      #|    {
      #|      code: "unexpected-null-character",
      #|      line: Some(1),
      #|      column: Some(7),
      #|      category: "tokenizer",
      #|      message: "unexpected-null-character",
      #|    },
      #|  ],
      #|}
    ),
  )
}

///|
test "null byte in double-quoted attribute value becomes replacement char" {
  let result = @tokenizer.tokenize(
    "<div a=\"b\u{0000}c\">",
    collect_errors=true,
  )
  debug_inspect(
    result,
    content=(
      #|{
      #|  tokens: [
      #|    Tag(
      #|      {
      #|        kind: StartTag,
      #|        name: "div",
      #|        attrs: { "a": Some("b�c") },
      #|        self_closing: false,
      #|      },
      #|    ),
      #|    Eof,
      #|  ],
      #|  errors: [
      #|    {
      #|      code: "unexpected-null-character",
      #|      line: Some(1),
      #|      column: Some(10),
      #|      category: "tokenizer",
      #|      message: "unexpected-null-character",
      #|    },
      #|  ],
      #|}
    ),
  )
}

///|
test "null byte in single-quoted attribute value becomes replacement char" {
  let result = @tokenizer.tokenize("<div a='b\u{0000}c'>", collect_errors=true)
  debug_inspect(
    result,
    content=(
      #|{
      #|  tokens: [
      #|    Tag(
      #|      {
      #|        kind: StartTag,
      #|        name: "div",
      #|        attrs: { "a": Some("b�c") },
      #|        self_closing: false,
      #|      },
      #|    ),
      #|    Eof,
      #|  ],
      #|  errors: [
      #|    {
      #|      code: "unexpected-null-character",
      #|      line: Some(1),
      #|      column: Some(10),
      #|      category: "tokenizer",
      #|      message: "unexpected-null-character",
      #|    },
      #|  ],
      #|}
    ),
  )
}

///|
test "missing attribute value at tag close is reported" {
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

///|
test "unexpected character in tag name is reported" {
  let result = @tokenizer.tokenize("<p<", collect_errors=true)
  debug_inspect(
    result,
    content=(
      #|{
      #|  tokens: [Eof],
      #|  errors: [
      #|    {
      #|      code: "eof-in-tag",
      #|      line: Some(1),
      #|      column: Some(3),
      #|      category: "tokenizer",
      #|      message: "eof-in-tag",
      #|    },
      #|  ],
      #|}
    ),
  )
}

///|
test "without collect_errors the errors list is empty" {
  // Recovery still happens, but no diagnostics are stored.
  let result = @tokenizer.tokenize("<div a=>")
  debug_inspect(
    result.errors.length(),
    content=(
      #|0
    ),
  )
}
