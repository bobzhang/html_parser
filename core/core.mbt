///|
/// Parser or tokenizer diagnostic with optional source location.
///
/// `category` identifies the source of the error, such as `tokenizer` or
/// `treebuilder`. `message` defaults to `code` when no custom message is given.
pub(all) struct ParseError {
  code : String
  line : Int?
  column : Int?
  category : String
  message : String
} derive(Debug, Eq)

///|
/// Construct a parse diagnostic.
pub fn ParseError::ParseError(
  code : String,
  line? : Int,
  column? : Int,
  category? : String = "parse",
  message? : String,
) -> ParseError {
  { code, line, column, category, message: message.unwrap_or(code) }
}

///|
fn is_tokenizer_error_code(code : StringView) -> Bool {
  match code {
    "abrupt-closing-of-empty-comment"
    | "abrupt-doctype-public-identifier"
    | "abrupt-doctype-system-identifier"
    | "cdata-in-html-content"
    | "control-character-reference"
    | "duplicate-attribute"
    | "eof-before-tag-name"
    | "eof-in-comment"
    | "eof-in-doctype"
    | "eof-in-doctype-name"
    | "eof-in-doctype-public-identifier"
    | "eof-in-doctype-system-identifier"
    | "eof-in-tag"
    | "expected-doctype-name-but-got-right-bracket"
    | "incorrectly-closed-comment"
    | "incorrectly-opened-comment"
    | "invalid-first-character-of-tag-name"
    | "missing-attribute-value"
    | "missing-doctype-public-identifier"
    | "missing-doctype-system-identifier"
    | "missing-end-tag-name"
    | "missing-quote-before-doctype-public-identifier"
    | "missing-quote-before-doctype-system-identifier"
    | "missing-semicolon-after-character-reference"
    | "missing-whitespace-after-doctype-name"
    | "missing-whitespace-after-doctype-public-identifier"
    | "missing-whitespace-before-doctype-name"
    | "missing-whitespace-before-doctype-public-identifier"
    | "missing-whitespace-between-attributes"
    | "missing-whitespace-between-doctype-public-and-system-identifiers"
    | "named-entity-without-semicolon"
    | "noncharacter-character-reference"
    | "noncharacter-in-input-stream"
    | "unexpected-character-after-doctype-public-identifier"
    | "unexpected-character-after-doctype-public-keyword"
    | "unexpected-character-after-doctype-system-identifier"
    | "unexpected-character-after-doctype-system-keyword"
    | "unexpected-character-after-solidus-in-tag"
    | "unexpected-character-in-attribute-name"
    | "unexpected-character-in-unquoted-attribute-value"
    | "unexpected-equals-sign-before-attribute-name"
    | "unexpected-null-character"
    | "unexpected-question-mark-instead-of-tag-name" => true
    _ => false
  }
}

///|
/// Classify a parse-error code by the subsystem that normally reports it.
///
/// Known tokenizer error codes return `"tokenizer"`. Other codes are treated
/// as tree-builder/parser diagnostics and return `"treebuilder"`.
pub fn parser_error_category(code : StringView) -> String {
  if is_tokenizer_error_code(code) {
    "tokenizer"
  } else {
    "treebuilder"
  }
}

///|
/// Error type raised by strict parsing, serialization, sanitizer, and selector
/// operations.
pub(all) suberror HtmlError {
  StrictMode(ParseError)
  InvalidSerialization(String)
  UnsafeHtml(String)
  SelectorError(String)
} derive(Debug, Eq)
