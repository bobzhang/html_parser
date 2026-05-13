///|
pub fn decode_entities(input : StringView, in_attribute~ : Bool) -> String {
  decode_entities_with_errors(input, in_attribute~).data
}

///|
pub fn decode_entities_with_errors(
  input : StringView,
  in_attribute~ : Bool,
) -> EntityDecodeResult {
  let out = StringBuilder::new(size_hint=input.length())
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
pub fn decode_attribute_value_with_errors(
  input : StringView,
) -> EntityDecodeResult {
  let decoded = decode_entities_with_errors(input, in_attribute=true)
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
