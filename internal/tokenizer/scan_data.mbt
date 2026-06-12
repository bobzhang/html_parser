///|
/// Materialize scanned raw data from its source slice.
///
/// The comment and script scanners keep every character verbatim except for
/// the input-stream preprocessing (CRLF and bare CR normalize to LF, NUL
/// becomes U+FFFD), so they only locate the end of the data and let this
/// helper produce it: the common clean slice is one exact-size copy, and a
/// slice containing CR or NUL gets a single normalization pass. This
/// replaces per-character builder writes behind a rest-of-the-document
/// size hint, which preallocated far too much for every comment (#16).
fn scanned_data_slice(input : StringView, start : Int, end : Int) -> String {
  // Empty data never slices: the scanners fail closed on surrogate-split
  // offsets (get_char yields None there), where slicing would abort.
  if start >= end {
    return ""
  }
  let raw = input[start:end]
  if !raw.contains_char('\r') && !raw.contains_char('\u{0000}') {
    return raw.to_owned()
  }
  let out = StringBuilder(size_hint=raw.length())
  let mut last_was_cr = false
  for ch in raw {
    match ch {
      '\r' => {
        out.write_char('\n')
        last_was_cr = true
      }
      '\n' => {
        if !last_was_cr {
          out.write_char('\n')
        }
        last_was_cr = false
      }
      '\u{0000}' => {
        out.write_char('\u{FFFD}')
        last_was_cr = false
      }
      _ => {
        out.write_char(ch)
        last_was_cr = false
      }
    }
  }
  out.to_string()
}
