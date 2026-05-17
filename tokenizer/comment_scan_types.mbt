///|
/// Diagnostic collected while scanning an HTML comment body.
///
/// `code` is the HTML parse-error code. `offset` is a UTF-16 code-unit offset
/// in the original scanned input.
pub(all) struct CommentScanError {
  code : String
  offset : Int
}

///|
/// Result of scanning an HTML comment body.
///
/// `data` is the normalized comment text. `end` is the offset where tokenization
/// should resume. `eof` is `true` when no comment closer was found. `errors`
/// contains non-fatal parse diagnostics discovered during the scan.
pub(all) struct CommentScan {
  data : String
  end : Int
  eof : Bool
  errors : Array[CommentScanError]
}
