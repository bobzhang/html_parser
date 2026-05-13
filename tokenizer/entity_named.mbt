///|
fn entity_without_semicolon_error(
  input : StringView,
  start : Int,
) -> EntityDecodeError {
  {
    code: "missing-semicolon-after-character-reference",
    offset: named_entity_missing_semicolon_error_offset(input, start),
  }
}

///|
fn named_entity_missing_semicolon_error_offset(
  input : StringView,
  start : Int,
) -> Int {
  let mut pos = start + 1
  let mut last = start
  while pos < input.length() {
    match input.get_char(pos) {
      Some(ch) if ch.is_ascii_alphabetic() || (ch >= '0' && ch <= '9') => {
        last = pos
        pos += ch.utf16_len()
      }
      Some(';') => return pos
      _ => return last
    }
  }
  last
}

///|
fn named_entity_name_end(input : StringView, start : Int) -> Int {
  let mut pos = start + 1
  while pos < input.length() {
    match input.get_char(pos) {
      Some(ch) if ch.is_ascii_alphabetic() || (ch >= '0' && ch <= '9') =>
        pos += ch.utf16_len()
      _ => break
    }
  }
  pos
}

///|
fn longest_legacy_named_entity(
  input : StringView,
  name_start : Int,
  name_end : Int,
) -> (String, Int)? {
  let mut end = name_end
  while end > name_start {
    let name = input[name_start:end]
    match legacy_named_entity_value(name) {
      Some(value) => return Some((value, end))
      None => ()
    }
    end -= 1
  }
  None
}

///|
pub fn consume_named_entity_with_errors(
  input : StringView,
  start : Int,
  in_attribute~ : Bool,
) -> EntityConsumeResult? {
  let name_start = start + 1
  let name_end = named_entity_name_end(input, start)
  if name_end == name_start {
    return None
  }
  let has_semicolon = input.get_char(name_end) is Some(';')
  let name = input[name_start:name_end]
  if has_semicolon {
    match semicolon_named_entity_value(name) {
      Some(value) => return Some({ value, next: name_end + 1, errors: [] })
      None => ()
    }
    if !in_attribute {
      match longest_legacy_named_entity(input, name_start, name_end) {
        Some((value, next)) =>
          return Some({
            value,
            next,
            errors: [entity_without_semicolon_error(input, start)],
          })
        None => ()
      }
    }
    None
  } else {
    match legacy_named_entity_value(name) {
      Some(value) =>
        if legacy_entity_blocked_in_attribute(input, name_end, in_attribute~) {
          return None
        } else {
          return Some({
            value,
            next: name_end,
            errors: [entity_without_semicolon_error(input, start)],
          })
        }
      None => ()
    }
    if in_attribute {
      return None
    }
    match longest_legacy_named_entity(input, name_start, name_end) {
      Some((value, next)) =>
        Some({
          value,
          next,
          errors: [entity_without_semicolon_error(input, start)],
        })
      None => None
    }
  }
}

///|
pub fn legacy_entity_blocked_in_attribute(
  input : StringView,
  next : Int,
  in_attribute~ : Bool,
) -> Bool {
  if !in_attribute {
    return false
  }
  match input.get_char(next) {
    Some(ch) if ch.is_ascii_alphabetic() || (ch >= '0' && ch <= '9') => true
    Some('=') => true
    _ => false
  }
}
