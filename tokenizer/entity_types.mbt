///|
pub(all) struct EntityDecodeError {
  code : String
  offset : Int
}

///|
pub(all) struct EntityDecodeResult {
  data : String
  errors : Array[EntityDecodeError]
}

///|
pub(all) struct EntityConsumeResult {
  value : String
  next : Int
  errors : Array[EntityDecodeError]
}
