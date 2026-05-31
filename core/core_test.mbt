// Blackbox snapshot tests for the small but central `@core` package:
// `ParseError`, `HtmlError`, and the `parser_error_category` helper.

///|
test "ParseError::new defaults derive category and message from code" {
  // With only `code` supplied, `category` and `message` default to the
  // code itself; `line`/`column` default to None.
  let err = @core.ParseError::new("unexpected-null-character")
  debug_inspect(
    err,
    content=(
      #|{
      #|  code: "unexpected-null-character",
      #|  line: None,
      #|  column: None,
      #|  category: "parse",
      #|  message: "unexpected-null-character",
      #|}
    ),
  )
}

///|
test "ParseError::new accepts explicit position and category" {
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

///|
test "parser_error_category categorizes tokenizer codes as tokenizer" {
  // The helper is the single source of truth for which category a
  // given parser-error code belongs to.
  let tokenizer = @core.parser_error_category("unexpected-null-character")
  let treebuilder = @core.parser_error_category("unexpected-end-tag")
  let unknown = @core.parser_error_category("nonexistent-code")
  debug_inspect(
    (tokenizer, treebuilder, unknown),
    content=(
      #|("tokenizer", "treebuilder", "treebuilder")
    ),
  )
}

///|
test "HtmlError variants carry their own payload" {
  // HtmlError is the umbrella raised by parse / sanitize / serialize.
  // The snapshot shows the shape callers see when catching it.
  let strict = @core.HtmlError::StrictMode(@core.ParseError::new("oops"))
  let unsafe_ = @core.HtmlError::UnsafeHtml("blocked: <script>")
  let bad_sel = @core.HtmlError::SelectorError("invalid pseudo")
  let bad_ser = @core.HtmlError::InvalidSerialization("orphan node")
  debug_inspect(
    (strict, unsafe_, bad_sel, bad_ser),
    content=(
      #|(
      #|  StrictMode(
      #|    {
      #|      code: "oops",
      #|      line: None,
      #|      column: None,
      #|      category: "parse",
      #|      message: "oops",
      #|    },
      #|  ),
      #|  UnsafeHtml("blocked: <script>"),
      #|  SelectorError("invalid pseudo"),
      #|  InvalidSerialization("orphan node"),
      #|)
    ),
  )
}
