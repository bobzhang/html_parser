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
