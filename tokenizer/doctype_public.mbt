///|
fn parse_doctype_after_public_identifier(
  input : StringView,
  after_public : Int,
  closed : Bool,
  errors : Array[DoctypeExternalError],
) -> (String?, Bool) {
  match input.get_char(after_public) {
    None =>
      if closed {
        (None, false)
      } else {
        push_doctype_external_error(
          errors,
          "missing-whitespace-between-doctype-public-and-system-identifiers",
          doctype_eof_error_offset(input),
        )
        (None, true)
      }
    Some(ch) if ch.is_ascii_whitespace() => {
      let system_pos = skip_ascii_whitespace_in_view(input, after_public)
      if system_pos >= input.length() {
        if closed {
          (None, false)
        } else {
          push_doctype_external_error(
            errors,
            "missing-quote-before-doctype-system-identifier",
            doctype_eof_error_offset(input),
          )
          (None, true)
        }
      } else {
        match input.get_char(system_pos) {
          Some('"') | Some('\'') =>
            parse_doctype_system_identifier_at(
              input, system_pos, closed, errors,
            )
          _ => {
            push_doctype_external_error(
              errors, "missing-quote-before-doctype-system-identifier", system_pos,
            )
            (None, true)
          }
        }
      }
    }
    Some('"') | Some('\'') => {
      push_doctype_external_error(
        errors, "missing-whitespace-between-doctype-public-and-system-identifiers",
        after_public,
      )
      parse_doctype_system_identifier_at(input, after_public, closed, errors)
    }
    _ => {
      push_doctype_external_error(
        errors, "unexpected-character-after-doctype-public-identifier", after_public,
      )
      (None, true)
    }
  }
}

///|
fn parse_doctype_public_after_keyword(
  input : StringView,
  after_keyword : Int,
  closed : Bool,
  errors : Array[DoctypeExternalError],
) -> (String?, String?, Bool) {
  let mut force_quirks = false
  let public_pos = match input.get_char(after_keyword) {
    None =>
      if closed {
        push_doctype_external_error(
          errors,
          "missing-doctype-public-identifier",
          input.length(),
        )
        force_quirks = true
        None
      } else {
        push_doctype_external_error(
          errors,
          "missing-quote-before-doctype-public-identifier",
          after_keyword - 1,
        )
        force_quirks = true
        None
      }
    Some(ch) if ch.is_ascii_whitespace() => {
      let id_pos = skip_ascii_whitespace_in_view(input, after_keyword)
      if id_pos >= input.length() {
        push_doctype_external_error(
          errors,
          "missing-doctype-public-identifier",
          if closed {
            input.length()
          } else {
            doctype_eof_error_offset(input)
          },
        )
        force_quirks = true
        None
      } else {
        match input.get_char(id_pos) {
          Some('"') | Some('\'') => Some(id_pos)
          _ => {
            push_doctype_external_error(
              errors, "missing-quote-before-doctype-public-identifier", id_pos,
            )
            force_quirks = true
            None
          }
        }
      }
    }
    Some('"') | Some('\'') => {
      push_doctype_external_error(
        errors, "missing-whitespace-before-doctype-public-identifier", after_keyword,
      )
      Some(after_keyword)
    }
    _ => {
      push_doctype_external_error(
        errors, "unexpected-character-after-doctype-public-keyword", after_keyword,
      )
      force_quirks = true
      None
    }
  }
  match public_pos {
    None => (None, None, force_quirks)
    Some(pos) => {
      let (public_id, after_public, public_closed) = parse_quoted_doctype_value_at(
        input, pos, errors,
      )
      if !public_closed {
        if closed {
          push_doctype_external_error(
            errors,
            "abrupt-doctype-public-identifier",
            input.length(),
          )
        } else {
          push_doctype_external_error(
            errors,
            "eof-in-doctype-public-identifier",
            doctype_eof_error_offset(input),
          )
        }
        (public_id, None, true)
      } else {
        let (system_id, system_force_quirks) = parse_doctype_after_public_identifier(
          input, after_public, closed, errors,
        )
        (public_id, system_id, force_quirks || system_force_quirks)
      }
    }
  }
}
