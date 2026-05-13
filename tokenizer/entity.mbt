///|
pub(all) struct EntityDecodeError {
  code : String
  offset : Int
}

///|
pub(all) struct EntityDecodeResult {
  data : String
  errors : Array[EntityDecodeError]
}

///|
pub(all) struct EntityConsumeResult {
  value : String
  next : Int
  errors : Array[EntityDecodeError]
}

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
fn legacy_named_entity_value(name : StringView) -> String? {
  match name {
    "gt" => Some(">")
    "lt" => Some("<")
    "amp" => Some("&")
    "quot" => Some("\"")
    "nbsp" => Some("\u{00A0}")
    "AMP" => Some("&")
    "QUOT" => Some("\"")
    "GT" => Some(">")
    "LT" => Some("<")
    "COPY" => Some("\u{00A9}")
    "REG" => Some("\u{00AE}")
    "AElig" => Some("\u{00C6}")
    "Aacute" => Some("\u{00C1}")
    "Acirc" => Some("\u{00C2}")
    "Agrave" => Some("\u{00C0}")
    "Aring" => Some("\u{00C5}")
    "Atilde" => Some("\u{00C3}")
    "Auml" => Some("\u{00C4}")
    "Ccedil" => Some("\u{00C7}")
    "ETH" => Some("\u{00D0}")
    "Eacute" => Some("\u{00C9}")
    "Ecirc" => Some("\u{00CA}")
    "Egrave" => Some("\u{00C8}")
    "Euml" => Some("\u{00CB}")
    "Iacute" => Some("\u{00CD}")
    "Icirc" => Some("\u{00CE}")
    "Igrave" => Some("\u{00CC}")
    "Iuml" => Some("\u{00CF}")
    "Ntilde" => Some("\u{00D1}")
    "Oacute" => Some("\u{00D3}")
    "Ocirc" => Some("\u{00D4}")
    "Ograve" => Some("\u{00D2}")
    "Oslash" => Some("\u{00D8}")
    "Otilde" => Some("\u{00D5}")
    "Ouml" => Some("\u{00D6}")
    "THORN" => Some("\u{00DE}")
    "Uacute" => Some("\u{00DA}")
    "Ucirc" => Some("\u{00DB}")
    "Ugrave" => Some("\u{00D9}")
    "Uuml" => Some("\u{00DC}")
    "Yacute" => Some("\u{00DD}")
    "aacute" => Some("\u{00E1}")
    "acirc" => Some("\u{00E2}")
    "acute" => Some("\u{00B4}")
    "aelig" => Some("\u{00E6}")
    "agrave" => Some("\u{00E0}")
    "aring" => Some("\u{00E5}")
    "atilde" => Some("\u{00E3}")
    "auml" => Some("\u{00E4}")
    "brvbar" => Some("\u{00A6}")
    "ccedil" => Some("\u{00E7}")
    "cedil" => Some("\u{00B8}")
    "cent" => Some("\u{00A2}")
    "copy" => Some("\u{00A9}")
    "curren" => Some("\u{00A4}")
    "deg" => Some("\u{00B0}")
    "divide" => Some("\u{00F7}")
    "eacute" => Some("\u{00E9}")
    "ecirc" => Some("\u{00EA}")
    "egrave" => Some("\u{00E8}")
    "eth" => Some("\u{00F0}")
    "euml" => Some("\u{00EB}")
    "frac12" => Some("\u{00BD}")
    "frac14" => Some("\u{00BC}")
    "frac34" => Some("\u{00BE}")
    "iacute" => Some("\u{00ED}")
    "icirc" => Some("\u{00EE}")
    "iexcl" => Some("\u{00A1}")
    "igrave" => Some("\u{00EC}")
    "iquest" => Some("\u{00BF}")
    "iuml" => Some("\u{00EF}")
    "laquo" => Some("\u{00AB}")
    "macr" => Some("\u{00AF}")
    "micro" => Some("\u{00B5}")
    "middot" => Some("\u{00B7}")
    "not" => Some("\u{00AC}")
    "ntilde" => Some("\u{00F1}")
    "oacute" => Some("\u{00F3}")
    "ocirc" => Some("\u{00F4}")
    "ograve" => Some("\u{00F2}")
    "ordf" => Some("\u{00AA}")
    "ordm" => Some("\u{00BA}")
    "oslash" => Some("\u{00F8}")
    "otilde" => Some("\u{00F5}")
    "ouml" => Some("\u{00F6}")
    "para" => Some("\u{00B6}")
    "plusmn" => Some("\u{00B1}")
    "pound" => Some("\u{00A3}")
    "raquo" => Some("\u{00BB}")
    "reg" => Some("\u{00AE}")
    "sect" => Some("\u{00A7}")
    "shy" => Some("\u{00AD}")
    "sup1" => Some("\u{00B9}")
    "sup2" => Some("\u{00B2}")
    "sup3" => Some("\u{00B3}")
    "szlig" => Some("\u{00DF}")
    "thorn" => Some("\u{00FE}")
    "times" => Some("\u{00D7}")
    "uacute" => Some("\u{00FA}")
    "ucirc" => Some("\u{00FB}")
    "ugrave" => Some("\u{00F9}")
    "uml" => Some("\u{00A8}")
    "uuml" => Some("\u{00FC}")
    "yacute" => Some("\u{00FD}")
    "yen" => Some("\u{00A5}")
    "yuml" => Some("\u{00FF}")
    _ => None
  }
}

///|
fn semicolon_named_entity_value(name : StringView) -> String? {
  match name {
    "apos" => Some("'")
    "euro" => Some("\u{20AC}")
    "hellip" => Some("\u{2026}")
    "larr" => Some("\u{2190}")
    "rarr" => Some("\u{2192}")
    "ldquo" => Some("\u{201C}")
    "rdquo" => Some("\u{201D}")
    "lsquo" => Some("\u{2018}")
    "rsquo" => Some("\u{2019}")
    "mdash" => Some("\u{2014}")
    "ndash" => Some("\u{2013}")
    "trade" => Some("\u{2122}")
    "notin" => Some("\u{2209}")
    "le" => Some("\u{2264}")
    "ge" => Some("\u{2265}")
    "ne" => Some("\u{2260}")
    _ => legacy_named_entity_value(name)
  }
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

///|
fn consume_numeric_entity(
  input : StringView,
  start : Int,
) -> EntityConsumeResult? {
  let mut pos = start + 2
  let mut base = 10
  if pos < input.length() {
    match input.get_char(pos) {
      Some('x') | Some('X') => {
        base = 16
        pos += 1
      }
      _ => ()
    }
  }
  let digits_start = pos
  let mut value = 0
  while pos < input.length() {
    let ch = input.get_char(pos).unwrap()
    let digit = digit_value(ch)
    if digit < 0 || digit >= base {
      break
    }
    value = value * base + digit
    pos += ch.utf16_len()
  }
  if pos == digits_start {
    return None
  }
  let errors : Array[EntityDecodeError] = []
  let mut error_offset = pos - 1
  if input.get_char(pos) is Some(';') {
    pos += 1
    error_offset = pos - 1
  } else {
    errors.push({
      code: "missing-semicolon-after-character-reference",
      offset: error_offset,
    })
  }
  if numeric_reference_can_report_character_error(value) {
    if is_character_reference_control(value) {
      errors.push({ code: "control-character-reference", offset: error_offset })
    }
    if @syn.is_xml_noncharacter_code(value) {
      errors.push({
        code: "noncharacter-character-reference",
        offset: error_offset,
      })
    }
  }
  match html_numeric_entity_replacement(value).to_char() {
    Some(ch) => Some({ value: ch.to_string(), next: pos, errors })
    None => Some({ value: "\u{FFFD}", next: pos, errors })
  }
}

///|
fn numeric_reference_can_report_character_error(value : Int) -> Bool {
  value >= 0 && value <= 0x10FFFF && !(value >= 0xD800 && value <= 0xDFFF)
}

///|
fn is_character_reference_control(value : Int) -> Bool {
  (value >= 0x00 && value <= 0x1F) || (value >= 0x7F && value <= 0x9F)
}

///|
pub fn html_numeric_entity_replacement(value : Int) -> Int {
  match value {
    0 => 0xFFFD
    0x80 => 0x20AC
    0x82 => 0x201A
    0x83 => 0x0192
    0x84 => 0x201E
    0x85 => 0x2026
    0x86 => 0x2020
    0x87 => 0x2021
    0x88 => 0x02C6
    0x89 => 0x2030
    0x8A => 0x0160
    0x8B => 0x2039
    0x8C => 0x0152
    0x8E => 0x017D
    0x91 => 0x2018
    0x92 => 0x2019
    0x93 => 0x201C
    0x94 => 0x201D
    0x95 => 0x2022
    0x96 => 0x2013
    0x97 => 0x2014
    0x98 => 0x02DC
    0x99 => 0x2122
    0x9A => 0x0161
    0x9B => 0x203A
    0x9C => 0x0153
    0x9E => 0x017E
    0x9F => 0x0178
    _ => value
  }
}

///|
fn digit_value(ch : Char) -> Int {
  if ch >= '0' && ch <= '9' {
    ch.to_int() - ('0' : Int)
  } else if ch >= 'a' && ch <= 'f' {
    ch.to_int() - ('a' : Int) + 10
  } else if ch >= 'A' && ch <= 'F' {
    ch.to_int() - ('A' : Int) + 10
  } else {
    -1
  }
}
