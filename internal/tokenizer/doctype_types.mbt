///|
/// Diagnostic collected while parsing doctype external identifiers.
///
/// `code` is the HTML parse-error code. `offset` is relative to the doctype
/// tail slice passed to `parse_doctype_external`, or to the full input passed
/// to lower-level helper functions.
pub(all) struct DoctypeExternalError {
  code : String
  offset : Int
}

///|
/// Parsed PUBLIC/SYSTEM identifiers from a doctype tail.
///
/// `force_quirks` records whether the malformed external identifier syntax
/// requires the emitted doctype token to force quirks mode.
pub(all) struct DoctypeExternalParse {
  public_id : String?
  system_id : String?
  errors : Array[DoctypeExternalError]
  force_quirks : Bool
}
