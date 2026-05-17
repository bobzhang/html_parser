///|
/// Diagnostic collected while scanning special raw-text content.
///
/// Offsets are UTF-16 code-unit positions in the original source input.
pub(all) struct SpecialTextError {
  code : String
  offset : Int
}

///|
/// Result of scanning `<script>` raw text.
///
/// `data` is the normalized script text. `end_start` is the offset of the
/// matching end tag's `<`, or `None` when EOF is reached first. `errors`
/// contains non-fatal parse diagnostics collected during the scan.
pub(all) struct ScriptTextScan {
  data : String
  end_start : Int?
  errors : Array[SpecialTextError]
}

///|
priv enum ScriptTextState {
  ScriptRawText
  ScriptEscaped
  ScriptEscapedDash
  ScriptEscapedDashDash
  ScriptEscapedLessThan
  ScriptDoubleEscapeStart
  ScriptDoubleEscaped
  ScriptDoubleEscapedDash
  ScriptDoubleEscapedDashDash
  ScriptDoubleEscapedLessThan
  ScriptDoubleEscapeEnd
}
