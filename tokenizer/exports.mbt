///|
/// Decode HTML character references in `input`.
pub fn decode_entities(input : StringView, in_attribute~ : Bool) -> String {
  // The internal decoder borrows the input when the decode is the
  // identity; to_owned is free when the decode built a fresh string.
  @impl.decode_entities(input, in_attribute~).to_owned()
}
