///|
fn escape_text(value : StringView) -> String {
  let out = StringBuilder(size_hint=value.length())
  for ch in value {
    match ch {
      '&' => out.write_string("&amp;")
      '<' => out.write_string("&lt;")
      '>' => out.write_string("&gt;")
      _ => out.write_char(ch)
    }
  }
  out.to_string()
}

///|
/// Escape text for a quoted HTML attribute value.
///
/// This always escapes `&`, `<`, and `>`. It also escapes only the delimiter
/// selected by `quote`, so callers can choose the shorter safe quote style when
/// serializing attributes.
pub fn escape_attr_value(value : StringView, quote : Char) -> String {
  let out = StringBuilder(size_hint=value.length())
  for ch in value {
    match ch {
      '&' => out.write_string("&amp;")
      '<' => out.write_string("&lt;")
      '>' => out.write_string("&gt;")
      '"' if quote == '"' => out.write_string("&quot;")
      '\'' if quote == '\'' => out.write_string("&#39;")
      _ => out.write_char(ch)
    }
  }
  out.to_string()
}

///|
/// Escape text for a JavaScript string literal using `quote` as the delimiter.
///
/// The result is not wrapped in quotes. It escapes backslashes, line breaks,
/// the selected quote character, `<`/`>`, and Unicode line separators so HTML
/// embedded in script contexts cannot terminate the string or the script tag.
pub fn escape_js_string(value : StringView, quote : Char) -> String {
  let out = StringBuilder(size_hint=value.length())
  for ch in value {
    match ch {
      '\\' => out.write_string("\\\\")
      '\n' => out.write_string("\\n")
      '\r' => out.write_string("\\r")
      '\t' => out.write_string("\\t")
      '\u{0008}' => out.write_string("\\b")
      '\u{000C}' => out.write_string("\\f")
      '"' if quote == '"' => out.write_string("\\\"")
      '\'' if quote == '\'' => out.write_string("\\'")
      '<' => out.write_string("\\u003c")
      '>' => out.write_string("\\u003e")
      '\u{2028}' => out.write_string("\\u2028")
      '\u{2029}' => out.write_string("\\u2029")
      _ => out.write_char(ch)
    }
  }
  out.to_string()
}

///|
/// Percent-encode a URL-ish string using UTF-8 bytes.
///
/// ASCII letters, digits, and common URL delimiters such as `/`, `?`, `#`, and
/// `&` are left readable; every other byte is emitted as an uppercase `%HH`
/// triplet.
pub fn percent_encode_url(value : StringView) -> String {
  let bytes = @utf8.encode(value)
  let out = StringBuilder(size_hint=bytes.length())
  for index in 0..<bytes.length() {
    let byte = bytes[index]
    if is_url_safe_byte(byte) {
      out.write_char(byte.to_char())
    } else {
      write_percent_encoded_byte(out, byte)
    }
  }
  out.to_string()
}

///|
fn is_url_safe_byte(byte : Byte) -> Bool {
  let value = byte.to_int()
  (value >= 0x41 && value <= 0x5A) ||
  (value >= 0x61 && value <= 0x7A) ||
  (value >= 0x30 && value <= 0x39) ||
  value == 0x2F ||
  value == 0x3A ||
  value == 0x40 ||
  value == 0x3F ||
  value == 0x26 ||
  value == 0x3D ||
  value == 0x23 ||
  value == 0x2B ||
  value == 0x2D ||
  value == 0x2E ||
  value == 0x5F ||
  value == 0x7E
}

///|
/// Append one byte as an uppercase percent-encoded triplet.
///
/// The output form is `%HH`, using hexadecimal digits `0`-`9` and `A`-`F`.
pub fn write_percent_encoded_byte(out : StringBuilder, byte : Byte) -> Unit {
  let value = byte.to_int()
  out.write_char('%')
  out.write_char(hex_digit_upper(value / 16))
  out.write_char(hex_digit_upper(value % 16))
}

///|
fn hex_digit_upper(value : Int) -> Char {
  match value {
    0 => '0'
    1 => '1'
    2 => '2'
    3 => '3'
    4 => '4'
    5 => '5'
    6 => '6'
    7 => '7'
    8 => '8'
    9 => '9'
    10 => 'A'
    11 => 'B'
    12 => 'C'
    13 => 'D'
    14 => 'E'
    15 => 'F'
    _ => '0'
  }
}

///|
/// Return whether `value` contains `needle`.
///
/// This scans by `Char`, so non-BMP characters are treated as single
/// characters even though MoonBit string offsets are UTF-16 code units.
pub fn string_contains_char(value : StringView, needle : Char) -> Bool {
  for ch in value {
    if ch == needle {
      return true
    }
  }
  false
}
