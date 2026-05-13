///|
pub(all) struct DoctypeExternalError {
  code : String
  offset : Int
}

///|
pub(all) struct DoctypeExternalParse {
  public_id : String?
  system_id : String?
  errors : Array[DoctypeExternalError]
  force_quirks : Bool
}
