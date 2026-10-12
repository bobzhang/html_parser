///|
fn push_comment_scan_error(
  errors : Array[CommentScanError],
  code : String,
  offset : Int32,
) -> Unit {
  errors.push({ code, offset, })
}
