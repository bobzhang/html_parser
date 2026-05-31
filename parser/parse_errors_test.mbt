// Blackbox snapshot tests for `collect_errors=true` on the parser.
//
// The error list is structured: code, line/column position, category,
// and message. Snapshots show the exact diagnostic shape callers
// receive.

///|
test "parse collects unexpected null character error" {
  let doc = @parser.parse("<div a\u{0000}b='c'>hi</div>", collect_errors=true)
  debug_inspect(
    doc.errors,
    content=(
      #|[
      #|  {
      #|    code: "expected-doctype-but-got-start-tag",
      #|    line: Some(1),
      #|    column: Some(13),
      #|    category: "treebuilder",
      #|    message: "expected-doctype-but-got-start-tag",
      #|  },
      #|  {
      #|    code: "unexpected-null-character",
      #|    line: Some(1),
      #|    column: Some(7),
      #|    category: "tokenizer",
      #|    message: "unexpected-null-character",
      #|  },
      #|]
    ),
  )
}

///|
test "parse collects missing attribute value error" {
  let doc = @parser.parse("<div a=>hi</div>", collect_errors=true)
  debug_inspect(
    doc.errors,
    content=(
      #|[
      #|  {
      #|    code: "expected-doctype-but-got-start-tag",
      #|    line: Some(1),
      #|    column: Some(8),
      #|    category: "treebuilder",
      #|    message: "expected-doctype-but-got-start-tag",
      #|  },
      #|  {
      #|    code: "missing-attribute-value",
      #|    line: Some(1),
      #|    column: Some(8),
      #|    category: "tokenizer",
      #|    message: "missing-attribute-value",
      #|  },
      #|]
    ),
  )
}

///|
test "parse without collect_errors returns an empty error list" {
  let doc = @parser.parse("<div a=>hi</div>")
  debug_inspect(
    doc.errors.length(),
    content=(
      #|0
    ),
  )
}

///|
test "parse_fragment collects unexpected end tag error" {
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
