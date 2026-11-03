///|
/// Diagnostic produced while decoding a character reference.
///
/// `offset` is a UTF-16 code-unit offset relative to the string passed to the
/// entity decoder.
#derive(Debug, Eq)
pub(all) struct EntityDecodeError {
  code : String
  offset : Int32
}

///|
/// Result of decoding character references in a string.
///
/// `data` is the decoded text; when the decode was the identity it borrows
/// the input, so callers that need an owned `String` call `to_owned` (free
/// for full-string views). `errors` contains parse diagnostics such as
/// missing semicolons, control references, and noncharacter references.
#derive(Debug, Eq)
pub(all) struct EntityDecodeResult {
  data : StringView
  errors : Array[EntityDecodeError]
}

///|
/// Result of consuming one character reference.
///
/// `value` is the decoded replacement text. `next` is the UTF-16 offset where
/// scanning should resume. `errors` contains diagnostics for the consumed
/// reference.
#derive(Debug, Eq)
pub(all) struct EntityConsumeResult {
  value : String
  next : Int32
  errors : Array[EntityDecodeError]
}
