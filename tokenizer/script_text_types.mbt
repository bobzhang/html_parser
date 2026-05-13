///|
pub(all) struct SpecialTextError {
  code : String
  offset : Int
}

///|
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
