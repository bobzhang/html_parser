///|
/// Scan HTML comment data starting immediately after a `<!--` opener.
///
/// `start` is a UTF-16 code-unit offset in `input`. The returned `data`
/// normalizes CRLF and bare CR to LF and replaces null characters with U+FFFD.
/// `end` is the offset after the consumed comment closer, or `input.length()`
/// when the scan reaches EOF. Parse errors use offsets in the original input.
///
/// The scan writes nothing while running: kept characters are the input
/// verbatim (trailing closer dashes excluded), so each exit materializes the
/// data from its source slice via scanned_data_slice.
pub fn scan_comment_data(input : StringView, start : Int) -> CommentScan {
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
            Some('>') =>
              // The final two dashes belong to the closer, not the data.
              return {
                data: scanned_data_slice(input, start, pos - 2),
                end: pos + 1,
                eof: false,
                errors,
              }
            Some('!') =>
              match input.get_char(pos + 1) {
                Some('>') => {
                  push_comment_scan_error(
                    errors,
                    "incorrectly-closed-comment",
                    pos + 1,
                  )
                  return {
                    data: scanned_data_slice(input, start, pos - 2),
                    end: pos + 2,
                    eof: false,
                    errors,
                  }
                }
                Some('\u{0000}') => {
                  push_comment_scan_error(
                    errors,
                    "unexpected-null-character",
                    pos + 1,
                  )
                  pos += 2
                }
                Some(ch) =>
                  // The bang and the character after it are plain data;
                  // that character never starts a closer of its own.
                  pos = pos + 1 + ch.utf16_len()
                None => {
                  push_comment_scan_error(
                    errors,
                    "eof-in-comment",
                    @syn.eof_error_pos(input),
                  )
                  return {
                    data: scanned_data_slice(input, start, pos - 2),
                    end: input.length(),
                    eof: true,
                    errors,
                  }
                }
              }
            Some('\u{0000}') => {
              push_comment_scan_error(errors, "unexpected-null-character", pos)
              pos += 1
            }
            Some(ch) => {
              push_comment_scan_error(errors, "incorrectly-closed-comment", pos)
              pos += ch.utf16_len()
            }
            None => {
              push_comment_scan_error(
                errors,
                "eof-in-comment",
                @syn.eof_error_pos(input),
              )
              return {
                data: scanned_data_slice(input, start, pos - 2),
                end: input.length(),
                eof: true,
                errors,
              }
            }
          }
        }
      }
      Some('\u{0000}') => {
        push_comment_scan_error(errors, "unexpected-null-character", pos)
        pos += 1
      }
      Some(ch) => pos += ch.utf16_len()
      None => break
    }
  }
  push_comment_scan_error(errors, "eof-in-comment", @syn.eof_error_pos(input))
  // pos equals input.length() at a normal EOF; on a get_char fail-closed
  // break it marks where the consumed data stopped.
  {
    data: scanned_data_slice(input, start, pos),
    end: input.length(),
    eof: true,
    errors,
  }
}
