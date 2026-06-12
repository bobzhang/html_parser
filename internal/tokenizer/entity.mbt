///|
/// Decode HTML character references in text or attribute context.
///
/// This is the data-only form of `decode_entities_with_errors`: recognized
/// numeric and named references are decoded, CRLF and bare CR normalize to LF,
/// and diagnostics are discarded. Set `in_attribute=true` to apply HTML's
/// ambiguous-ampersand rule for legacy references in attribute values.
pub fn decode_entities(input : StringView, in_attribute~ : Bool) -> String {
  decode_entities_with_errors(input, in_attribute~).data
}

///|
/// Decode HTML character references and collect parse diagnostics.
///
/// Numeric references use the HTML replacement table, named references support
/// the legacy no-semicolon forms allowed by HTML, and non-reference ampersands
/// remain literal. Error offsets are relative to `input`.
pub fn decode_entities_with_errors(
  input : StringView,
  in_attribute~ : Bool,
) -> EntityDecodeResult {
  // The common case has no character references and no carriage returns:
  // the decode is the identity and a single plain copy suffices.
  let mut needs_decode = false
  for ch in input {
    if ch == '&' || ch == '\r' {
      needs_decode = true
      break
    }
  }
  if !needs_decode {
    return { data: input.to_owned(), errors: [] }
  }
  let out = StringBuilder(size_hint=input.length())
  let errors : Array[EntityDecodeError] = []
  let mut pos = 0
  while pos < input.length() {
    let ch = input.get_char(pos).unwrap()
    match ch {
      '&' =>
        match consume_entity_with_errors(input, pos, in_attribute~) {
          Some(consumed) => {
            out.write_string(consumed.value)
            for error in consumed.errors {
              errors.push(error)
            }
            pos = consumed.next
          }
          None => {
            out.write_char('&')
            pos += 1
          }
        }
      _ => pos = @syn.write_normalized_char(input, pos, out)
    }
  }
  { data: out.to_string(), errors }
}

///|
/// Decode an attribute value and collect character-reference diagnostics.
///
/// This uses attribute context for ambiguous ampersands, then replaces literal
/// null characters in the decoded value with U+FFFD. Null replacement here does
/// not add an extra entity-decoding diagnostic.
pub fn decode_attribute_value_with_errors(
  input : StringView,
) -> EntityDecodeResult {
  let decoded = decode_entities_with_errors(input, in_attribute=true)
  if !decoded.data.contains("\u{0000}") {
    return decoded
  }
  {
    data: decoded.data.replace_all(old="\u{0000}", new="\u{FFFD}"),
    errors: decoded.errors,
  }
}

///|
fn consume_entity_with_errors(
  input : StringView,
  start : Int,
  in_attribute~ : Bool,
) -> EntityConsumeResult? {
  let rest = input[start:]
  if rest.has_prefix("&#") {
    consume_numeric_entity(input, start)
  } else {
    consume_named_entity_with_errors(input, start, in_attribute~)
  }
}
