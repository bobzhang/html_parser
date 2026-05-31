///|
/// Scan HTML comment data starting immediately after a `<!--` opener.
///
/// `start` is a UTF-16 code-unit offset in `input`. The returned `data`
/// normalizes CRLF and bare CR to LF and replaces null characters with U+FFFD.
/// `end` is the offset after the consumed comment closer, or `input.length()`
/// when the scan reaches EOF. Parse errors use offsets in the original input.
pub fn scan_comment_data(input : StringView, start : Int) -> CommentScan {
  let out = StringBuilder::StringBuilder(size_hint=input.length() - start)
  let errors : Array[CommentScanError] = []
  if start >= input.length() {
    push_comment_scan_error(errors, "eof-in-comment", @syn.eof_error_pos(input))
    return { data: "", end: input.length(), eof: true, errors }
  }
  if input.get_char(start) is Some('>') {
    push_comment_scan_error(errors, "abrupt-closing-of-empty-comment", start)
    return { data: "", end: start + 1, eof: false, errors }
  }
  if @syn.view_starts_with_at(input, start, "->") {
    push_comment_scan_error(
      errors,
      "abrupt-closing-of-empty-comment",
      start + 1,
    )
    return { data: "", end: start + 2, eof: false, errors }
  }
  let mut pos = start
  while pos < input.length() {
    match input.get_char(pos) {
      Some('-') => {
        let dash_start = pos
        while input.get_char(pos) is Some('-') {
          pos += 1
        }
        let dash_count = pos - dash_start
        if dash_count >= 2 {
          match input.get_char(pos) {
            Some('>') => {
              write_comment_hyphens(out, dash_count - 2)
              return { data: out.to_string(), end: pos + 1, eof: false, errors }
            }
            Some('!') =>
              match input.get_char(pos + 1) {
                Some('>') => {
                  write_comment_hyphens(out, dash_count - 2)
                  push_comment_scan_error(
                    errors,
                    "incorrectly-closed-comment",
                    pos + 1,
                  )
                  return {
                    data: out.to_string(),
                    end: pos + 2,
                    eof: false,
                    errors,
                  }
                }
                Some('\u{0000}') => {
                  write_comment_hyphens(out, dash_count)
                  out.write_char('!')
                  push_comment_scan_error(
                    errors,
                    "unexpected-null-character",
                    pos + 1,
                  )
                  out.write_char('\u{FFFD}')
                  pos += 2
                }
                Some(ch) => {
                  write_comment_hyphens(out, dash_count)
                  out.write_char('!')
                  pos = write_comment_char(out, input, pos + 1, ch)
                }
                None => {
                  write_comment_hyphens(out, dash_count - 2)
                  push_comment_scan_error(
                    errors,
                    "eof-in-comment",
                    @syn.eof_error_pos(input),
                  )
                  return {
                    data: out.to_string(),
                    end: input.length(),
                    eof: true,
                    errors,
                  }
                }
              }
            Some('\u{0000}') => {
              write_comment_hyphens(out, dash_count - 2)
              out.write_string("--")
              push_comment_scan_error(errors, "unexpected-null-character", pos)
              out.write_char('\u{FFFD}')
              pos += 1
            }
            Some(ch) => {
              write_comment_hyphens(out, dash_count - 2)
              push_comment_scan_error(errors, "incorrectly-closed-comment", pos)
              out.write_string("--")
              pos = write_comment_char(out, input, pos, ch)
            }
            None => {
              write_comment_hyphens(out, dash_count - 2)
              push_comment_scan_error(
                errors,
                "eof-in-comment",
                @syn.eof_error_pos(input),
              )
              return {
                data: out.to_string(),
                end: input.length(),
                eof: true,
                errors,
              }
            }
          }
        } else {
          out.write_char('-')
        }
      }
      Some('\u{0000}') => {
        push_comment_scan_error(errors, "unexpected-null-character", pos)
        out.write_char('\u{FFFD}')
        pos += 1
      }
      Some(ch) => pos = write_comment_char(out, input, pos, ch)
      None => break
    }
  }
  push_comment_scan_error(errors, "eof-in-comment", @syn.eof_error_pos(input))
  { data: out.to_string(), end: input.length(), eof: true, errors }
}
