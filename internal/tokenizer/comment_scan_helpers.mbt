///|
fn push_comment_scan_error(
  errors : Array[CommentScanError],
  code : String,
  offset : Int,
) -> Unit {
  errors.push({ code, offset })
}

///|
fn write_comment_hyphens(out : StringBuilder, count : Int) -> Unit {
  if count > 0 {
    out.write_string("-".repeat(count))
  }
}

///|
fn write_comment_char(
  out : StringBuilder,
  input : StringView,
  pos : Int,
  ch : Char,
) -> Int {
  if ch == '\r' {
    out.write_char('\n')
    let next = pos + 1
    if input.get_char(next) is Some('\n') {
      next + 1
    } else {
      next
    }
  } else {
    out.write_char(ch)
    pos + ch.utf16_len()
  }
}
