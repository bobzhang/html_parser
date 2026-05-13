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
pub fn parse_quoted_doctype_value_at(
  input : StringView,
  start : Int,
  errors : Array[DoctypeExternalError],
) -> (String?, Int, Bool) {
  match input.get_char(start) {
    Some('"') | Some('\'') as quote_opt => {
      guard quote_opt is Some(quote)
      let mut pos = start + quote.utf16_len()
      let value_start = pos
      while pos < input.length() && input.get_char(pos) != Some(quote) {
        let ch = input.get_char(pos).unwrap()
        pos += ch.utf16_len()
      }
      let mut closed = false
      let value = Some(normalize_doctype_value(input, value_start, pos, errors))
      if input.get_char(pos) == Some(quote) {
        pos += quote.utf16_len()
        closed = true
      }
      (value, pos, closed)
    }
    _ => (None, start, false)
  }
}

///|
fn skip_ascii_whitespace_in_view(input : StringView, start : Int) -> Int {
  let mut pos = start
  while pos < input.length() {
    match input.get_char(pos) {
      Some(ch) if ch.is_ascii_whitespace() => pos += ch.utf16_len()
      _ => break
    }
  }
  pos
}

///|
fn view_has_prefix_case_insensitive_at(
  input : StringView,
  start : Int,
  prefix : StringView,
) -> Bool {
  let end = start + prefix.length()
  if end > input.length() {
    false
  } else {
    input[start:end].compare_ignore_ascii_case(prefix) == 0
  }
}

///|
pub fn normalize_doctype_value(
  input : StringView,
  start : Int,
  end : Int,
  errors : Array[DoctypeExternalError],
) -> String {
  let out = StringBuilder::new(size_hint=end - start)
  let mut pos = start
  while pos < end {
    match input.get_char(pos) {
      Some('\u{0000}') => {
        push_doctype_external_error(errors, "unexpected-null-character", pos)
        out.write_char('\u{FFFD}')
        pos += 1
      }
      Some('\r') => {
        out.write_char('\n')
        pos += 1
        if pos < end && input.get_char(pos) is Some('\n') {
          pos += 1
        }
      }
      Some(ch) => {
        out.write_char(ch)
        pos += ch.utf16_len()
      }
      None => break
    }
  }
  out.to_string()
}

///|
pub fn parse_lower_name_value_replacing_nulls(
  input : StringView,
  start : Int,
  end : Int,
) -> (String, Array[DoctypeExternalError]) {
  let errors : Array[DoctypeExternalError] = []
  if start >= end {
    return ("", errors)
  }
  let out = StringBuilder::new(size_hint=end - start)
  let mut pos = start
  while pos < end {
    match input.get_char(pos) {
      Some('\u{0000}') => {
        push_doctype_external_error(errors, "unexpected-null-character", pos)
        out.write_char('\u{FFFD}')
        pos += 1
      }
      Some(ch) => {
        if ch.is_ascii_uppercase() {
          out.write_char(ch.to_ascii_lowercase())
        } else {
          out.write_char(ch)
        }
        pos += ch.utf16_len()
      }
      None => break
    }
  }
  (out.to_string(), errors)
}

///|
fn view_last_char_offset(input : StringView) -> Int {
  let mut last = 0
  let mut pos = 0
  while pos < input.length() {
    last = pos
    let ch = input.get_char(pos).unwrap()
    pos += ch.utf16_len()
  }
  last
}

///|
pub fn doctype_eof_error_offset(input : StringView) -> Int {
  if @syn.input_ends_with_newline(input) {
    input.length()
  } else {
    view_last_char_offset(input)
  }
}

///|
fn push_doctype_external_error(
  errors : Array[DoctypeExternalError],
  code : String,
  offset : Int,
) -> Unit {
  errors.push({ code, offset })
}

///|
fn doctype_after_system_identifier(
  input : StringView,
  after_system : Int,
  closed : Bool,
  errors : Array[DoctypeExternalError],
) -> Bool {
  let next = skip_ascii_whitespace_in_view(input, after_system)
  if next >= input.length() {
    if closed {
      false
    } else {
      push_doctype_external_error(
        errors,
        "eof-in-doctype",
        doctype_eof_error_offset(input),
      )
      true
    }
  } else {
    push_doctype_external_error(
      errors, "unexpected-character-after-doctype-system-identifier", next,
    )
    false
  }
}

///|
fn parse_doctype_system_identifier_at(
  input : StringView,
  quote_pos : Int,
  closed : Bool,
  errors : Array[DoctypeExternalError],
) -> (String?, Bool) {
  let (system_id, after_system, system_closed) = parse_quoted_doctype_value_at(
    input, quote_pos, errors,
  )
  if !system_closed {
    if closed {
      push_doctype_external_error(
        errors,
        "abrupt-doctype-system-identifier",
        input.length(),
      )
    } else {
      push_doctype_external_error(
        errors,
        "eof-in-doctype-system-identifier",
        doctype_eof_error_offset(input),
      )
    }
    (system_id, true)
  } else {
    (
      system_id,
      doctype_after_system_identifier(input, after_system, closed, errors),
    )
  }
}

///|
fn parse_doctype_system_after_keyword(
  input : StringView,
  after_keyword : Int,
  closed : Bool,
  errors : Array[DoctypeExternalError],
) -> (String?, Bool) {
  match input.get_char(after_keyword) {
    None =>
      if closed {
        push_doctype_external_error(
          errors,
          "missing-doctype-system-identifier",
          input.length(),
        )
        (None, true)
      } else {
        push_doctype_external_error(
          errors,
          "missing-quote-before-doctype-system-identifier",
          after_keyword - 1,
        )
        (None, true)
      }
    Some(ch) if ch.is_ascii_whitespace() => {
      let id_pos = skip_ascii_whitespace_in_view(input, after_keyword)
      if id_pos >= input.length() {
        push_doctype_external_error(
          errors,
          "missing-doctype-system-identifier",
          if closed {
            input.length()
          } else {
            doctype_eof_error_offset(input)
          },
        )
        (None, true)
      } else {
        match input.get_char(id_pos) {
          Some('"') | Some('\'') =>
            parse_doctype_system_identifier_at(input, id_pos, closed, errors)
          _ => {
            push_doctype_external_error(
              errors, "missing-quote-before-doctype-system-identifier", id_pos,
            )
            (None, true)
          }
        }
      }
    }
    Some('"') | Some('\'') => {
      push_doctype_external_error(
        errors, "missing-whitespace-after-doctype-public-identifier", after_keyword,
      )
      parse_doctype_system_identifier_at(input, after_keyword, closed, errors)
    }
    _ => {
      push_doctype_external_error(
        errors, "unexpected-character-after-doctype-system-keyword", after_keyword,
      )
      (None, true)
    }
  }
}

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
