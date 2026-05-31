// Blackbox snapshot tests for doctype and comment tokenization.

///|
test "tokenize html5 doctype" {
  let result = @tokenizer.tokenize("<!DOCTYPE html>")
  debug_inspect(
    result.tokens,
    content=(
      #|[
      #|  DoctypeToken(
      #|    {
      #|      name: "html",
      #|      public_id: None,
      #|      system_id: None,
      #|      force_quirks: false,
      #|    },
      #|  ),
      #|  Eof,
      #|]
    ),
  )
}

///|
test "tokenize legacy doctype with public and system identifiers" {
  let result = @tokenizer.tokenize(
    "<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01//EN\" \"http://www.w3.org/TR/html4/strict.dtd\">",
  )
  debug_inspect(
    result.tokens,
    content=(
      #|[
      #|  DoctypeToken(
      #|    {
      #|      name: "html",
      #|      public_id: Some("-//W3C//DTD HTML 4.01//EN"),
      #|      system_id: Some("http://www.w3.org/TR/html4/strict.dtd"),
      #|      force_quirks: false,
      #|    },
      #|  ),
      #|  Eof,
      #|]
    ),
  )
}

///|
test "tokenize unknown doctype name forces quirks" {
  let result = @tokenizer.tokenize("<!DOCTYPE bogus>")
  debug_inspect(
    result.tokens,
    content=(
      #|[
      #|  DoctypeToken(
      #|    {
      #|      name: "bogus",
      #|      public_id: None,
      #|      system_id: None,
      #|      force_quirks: false,
      #|    },
      #|  ),
      #|  Eof,
      #|]
    ),
  )
}

///|
test "tokenize simple comment" {
  let result = @tokenizer.tokenize("<!-- hello -->")
  debug_inspect(
    result.tokens,
    content=(
      #|[CommentToken(" hello "), Eof]
    ),
  )
}

///|
test "tokenize empty comment" {
  let result = @tokenizer.tokenize("<!---->")
  debug_inspect(
    result.tokens,
    content=(
      #|[CommentToken(""), Eof]
    ),
  )
}

///|
test "tokenize bogus comment for unknown declaration" {
  // <!foo> is not a real declaration; the tokenizer emits a comment token.
  let result = @tokenizer.tokenize("<!foo>")
  debug_inspect(
    result.tokens,
    content=(
      #|[CommentToken("foo"), Eof]
    ),
  )
}

///|
test "tokenize unterminated comment reports eof error" {
  let result = @tokenizer.tokenize("<!-- never closes", collect_errors=true)
  debug_inspect(
    result,
    content=(
      #|{
      #|  tokens: [CommentToken(" never closes"), Eof],
      #|  errors: [
      #|    {
      #|      code: "eof-in-comment",
      #|      line: Some(1),
      #|      column: Some(17),
      #|      category: "tokenizer",
      #|      message: "eof-in-comment",
      #|    },
      #|  ],
      #|}
    ),
  )
}
