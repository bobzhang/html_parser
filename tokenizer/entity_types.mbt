///|
/// Diagnostic produced while decoding a character reference.
///
/// `offset` is a UTF-16 code-unit offset relative to the string passed to the
/// entity decoder.
pub(all) struct EntityDecodeError {
  code : String
  offset : Int
}

///|
/// Result of decoding character references in a string.
///
/// `data` is the decoded text. `errors` contains parse diagnostics such as
/// missing semicolons, control references, and noncharacter references.
pub(all) struct EntityDecodeResult {
  data : String
  errors : Array[EntityDecodeError]
}

///|
/// Result of consuming one character reference.
///
/// `value` is the decoded replacement text. `next` is the UTF-16 offset where
/// scanning should resume. `errors` contains diagnostics for the consumed
/// reference.
pub(all) struct EntityConsumeResult {
  value : String
  next : Int
  errors : Array[EntityDecodeError]
}
