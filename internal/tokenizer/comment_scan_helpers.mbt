///|
fn push_comment_scan_error(
  errors : Array[CommentScanError],
  code : String,
  offset : Int,
) -> Unit {
  errors.push({ code, offset })
}
