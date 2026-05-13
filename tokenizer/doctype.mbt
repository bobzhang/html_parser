///|
pub(all) struct DoctypeExternalError {
  code : String
  offset : Int
}

///|
pub(all) struct DoctypeExternalParse {
  public_id : String?
  system_id : String?
  errors : Array[DoctypeExternalError]
  force_quirks : Bool
}

///|
pub fn parse_doctype_external(
  input : StringView,
  closed : Bool,
) -> DoctypeExternalParse {
  let errors : Array[DoctypeExternalError] = []
  let mut public_id : String? = None
  let mut system_id : String? = None
  let mut force_quirks = false
  match input.get_char(0) {
    Some(ch) if ch.is_ascii_whitespace() => {
      let start = ch.utf16_len()
      if view_has_prefix_case_insensitive_at(input, start, "public") {
        let (parsed_public, parsed_system, force) = parse_doctype_public_after_keyword(
          input,
          start + 6,
          closed,
          errors,
        )
        public_id = parsed_public
        system_id = parsed_system
        force_quirks = force
      } else if view_has_prefix_case_insensitive_at(input, start, "system") {
        let (parsed_system, force) = parse_doctype_system_after_keyword(
          input,
          start + 6,
          closed,
          errors,
        )
        system_id = parsed_system
        force_quirks = force
      } else {
        let unexpected = skip_ascii_whitespace_in_view(input, start)
        if unexpected < input.length() {
          push_doctype_external_error(
            errors, "missing-whitespace-after-doctype-name", unexpected,
          )
          force_quirks = true
        }
      }
    }
    _ => ()
  }
  { public_id, system_id, errors, force_quirks }
}
