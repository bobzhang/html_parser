///|
pub(all) struct CommentScanError {
  code : String
  offset : Int
}

///|
pub(all) struct CommentScan {
  data : String
  end : Int
  eof : Bool
  errors : Array[CommentScanError]
}
