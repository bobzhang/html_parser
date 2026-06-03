///|
fn has_utf16le_bom(input : BytesView) -> Bool {
  input is [0xff, 0xfe, ..]
}

///|
fn has_utf16be_bom(input : BytesView) -> Bool {
  input is [0xfe, 0xff, ..]
}

///|
fn has_utf8_bom(input : BytesView) -> Bool {
  input is [0xef, 0xbb, 0xbf, ..]
}

///|
fn decode_utf16le_lossy(input : BytesView) -> String {
  @utf16.decode_lossy(input, ignore_bom=true)
}

///|
fn decode_utf16be_lossy(input : BytesView) -> String {
  @utf16.decode_lossy(input, ignore_bom=true, endianness=Big)
}

///|
fn decode_utf16_lossy(input : BytesView) -> String {
  if has_utf16be_bom(input) {
    decode_utf16be_lossy(input)
  } else {
    decode_utf16le_lossy(input)
  }
}

///|
fn decode_windows1252_lossy(input : BytesView) -> String {
  let out = StringBuilder(size_hint=input.length())
  for index in 0..<input.length() {
    let value = input[index].to_int()
    let code = if value >= 0x80 && value <= 0x9F {
      @tok.html_numeric_entity_replacement(value)
    } else {
      value
    }
    out.write_char(code.to_char().unwrap())
  }
  out.to_string()
}

///|
fn iso88592_code_point(value : Int) -> Int {
  match value {
    0xA0 => 0x00A0
    0xA1 => 0x0104
    0xA2 => 0x02D8
    0xA3 => 0x0141
    0xA4 => 0x00A4
    0xA5 => 0x013D
    0xA6 => 0x015A
    0xA7 => 0x00A7
    0xA8 => 0x00A8
    0xA9 => 0x0160
    0xAA => 0x015E
    0xAB => 0x0164
    0xAC => 0x0179
    0xAD => 0x00AD
    0xAE => 0x017D
    0xAF => 0x017B
    0xB0 => 0x00B0
    0xB1 => 0x0105
    0xB2 => 0x02DB
    0xB3 => 0x0142
    0xB4 => 0x00B4
    0xB5 => 0x013E
    0xB6 => 0x015B
    0xB7 => 0x02C7
    0xB8 => 0x00B8
    0xB9 => 0x0161
    0xBA => 0x015F
    0xBB => 0x0165
    0xBC => 0x017A
    0xBD => 0x02DD
    0xBE => 0x017E
    0xBF => 0x017C
    0xC0 => 0x0154
    0xC1 => 0x00C1
    0xC2 => 0x00C2
    0xC3 => 0x0102
    0xC4 => 0x00C4
    0xC5 => 0x0139
    0xC6 => 0x0106
    0xC7 => 0x00C7
    0xC8 => 0x010C
    0xC9 => 0x00C9
    0xCA => 0x0118
    0xCB => 0x00CB
    0xCC => 0x011A
    0xCD => 0x00CD
    0xCE => 0x00CE
    0xCF => 0x010E
    0xD0 => 0x0110
    0xD1 => 0x0143
    0xD2 => 0x0147
    0xD3 => 0x00D3
    0xD4 => 0x00D4
    0xD5 => 0x0150
    0xD6 => 0x00D6
    0xD7 => 0x00D7
    0xD8 => 0x0158
    0xD9 => 0x016E
    0xDA => 0x00DA
    0xDB => 0x0170
    0xDC => 0x00DC
    0xDD => 0x00DD
    0xDE => 0x0162
    0xDF => 0x00DF
    0xE0 => 0x0155
    0xE1 => 0x00E1
    0xE2 => 0x00E2
    0xE3 => 0x0103
    0xE4 => 0x00E4
    0xE5 => 0x013A
    0xE6 => 0x0107
    0xE7 => 0x00E7
    0xE8 => 0x010D
    0xE9 => 0x00E9
    0xEA => 0x0119
    0xEB => 0x00EB
    0xEC => 0x011B
    0xED => 0x00ED
    0xEE => 0x00EE
    0xEF => 0x010F
    0xF0 => 0x0111
    0xF1 => 0x0144
    0xF2 => 0x0148
    0xF3 => 0x00F3
    0xF4 => 0x00F4
    0xF5 => 0x0151
    0xF6 => 0x00F6
    0xF7 => 0x00F7
    0xF8 => 0x0159
    0xF9 => 0x016F
    0xFA => 0x00FA
    0xFB => 0x0171
    0xFC => 0x00FC
    0xFD => 0x00FD
    0xFE => 0x0163
    0xFF => 0x02D9
    _ => value
  }
}

///|
fn decode_iso88592_lossy(input : BytesView) -> String {
  let out = StringBuilder(size_hint=input.length())
  for index in 0..<input.length() {
    out.write_char(
      iso88592_code_point(input[index].to_int()).to_char().unwrap(),
    )
  }
  out.to_string()
}

///|
fn is_ascii_whitespace_byte(byte : Byte) -> Bool {
  match byte.to_int() {
    0x09 | 0x0A | 0x0C | 0x0D | 0x20 => true
    _ => false
  }
}

///|
fn ascii_lower_value(value : Int) -> Int {
  if value >= 0x41 && value <= 0x5A {
    value + 0x20
  } else {
    value
  }
}

///|
fn is_ascii_alpha_byte(byte : Byte) -> Bool {
  let value = ascii_lower_value(byte.to_int())
  value >= 0x61 && value <= 0x7A
}

///|
fn skip_ascii_whitespace_bytes(input : BytesView, pos : Int) -> Int {
  let mut pos = pos
  while pos < input.length() && is_ascii_whitespace_byte(input[pos]) {
    pos += 1
  }
  pos
}

///|
fn ascii_lower_bytes(input : BytesView, start : Int, end : Int) -> String {
  let out = StringBuilder(size_hint=end - start)
  for index in start..<end {
    let value = input[index].to_int()
    if value < 0x80 {
      out.write_char(ascii_lower_value(value).to_char().unwrap())
    }
  }
  out.to_string()
}

///|
fn strip_ascii_whitespace_bytes(
  input : BytesView,
  start : Int,
  end : Int,
) -> (Int, Int) {
  let mut start = start
  let mut end = end
  while start < end && is_ascii_whitespace_byte(input[start]) {
    start += 1
  }
  while end > start && is_ascii_whitespace_byte(input[end - 1]) {
    end -= 1
  }
  (start, end)
}

///|
fn ascii_lower_content_bytes(
  input : BytesView,
  start : Int,
  end : Int,
) -> String {
  let out = StringBuilder(size_hint=end - start)
  for index in start..<end {
    let value = if is_ascii_whitespace_byte(input[index]) {
      0x20
    } else {
      ascii_lower_value(input[index].to_int())
    }
    if value < 0x80 {
      out.write_char(value.to_char().unwrap())
    }
  }
  out.to_string()
}

///|
fn byte_range_ascii_lower_eq(
  input : BytesView,
  start : Int,
  end : Int,
  expected : StringView,
) -> Bool {
  ascii_lower_bytes(input, start, end)[:] == expected
}

///|
fn normalize_supported_html_encoding_label(label : StringView) -> String? {
  let label = label.trim().to_lower()
  if label.is_empty() {
    return None
  }
  match label {
    "utf-8" | "utf8" => Some("utf-8")
    "utf-7" | "utf7" | "x-utf-7" => Some("windows-1252")
    "iso-8859-1"
    | "iso8859-1"
    | "latin1"
    | "latin-1"
    | "l1"
    | "cp819"
    | "ibm819" => Some("windows-1252")
    "windows-1252" | "windows1252" | "cp1252" | "x-cp1252" =>
      Some("windows-1252")
    "iso-8859-2" | "iso8859-2" | "latin2" | "latin-2" => Some("iso-8859-2")
    "utf-16" | "utf16" => Some("utf-16")
    "utf-16le" | "utf16le" => Some("utf-16le")
    "utf-16be" | "utf16be" => Some("utf-16be")
    _ => None
  }
}

///|
fn normalize_meta_html_encoding_label(label : StringView) -> String? {
  match normalize_supported_html_encoding_label(label) {
    Some("utf-16") | Some("utf-16le") | Some("utf-16be") => Some("utf-8")
    other => other
  }
}

///|
fn extract_charset_from_content_bytes(
  input : BytesView,
  start : Int,
  end : Int,
) -> String? {
  let content = ascii_lower_content_bytes(input, start, end)
  guard content.find("charset") is Some(found) else { return None }
  let mut pos = found + "charset".length()
  while pos < content.length() {
    guard content.get_char(pos) is Some(ch) else { return None }
    if !ch.is_ascii_whitespace() {
      break
    }
    pos += ch.utf16_len()
  }
  guard content.get_char(pos) is Some('=') else { return None }
  pos += 1
  while pos < content.length() {
    guard content.get_char(pos) is Some(ch) else { return None }
    if !ch.is_ascii_whitespace() {
      break
    }
    pos += ch.utf16_len()
  }
  if pos >= content.length() {
    return None
  }
  let mut quote : Char? = None
  match content.get_char(pos) {
    Some('"') => {
      quote = Some('"')
      pos += 1
    }
    Some('\'') => {
      quote = Some('\'')
      pos += 1
    }
    _ => ()
  }
  let value_start = pos
  while pos < content.length() {
    guard content.get_char(pos) is Some(ch) else { return None }
    match quote {
      Some(expected) =>
        if ch == expected {
          let label = content[value_start:pos]
          return normalize_meta_html_encoding_label(label)
        }
      None =>
        if ch.is_ascii_whitespace() || ch == ';' {
          let label = content[value_start:pos]
          return normalize_meta_html_encoding_label(label)
        }
    }
    pos += ch.utf16_len()
  }
  match quote {
    Some(_) => None
    None => {
      let label = content[value_start:pos]
      normalize_meta_html_encoding_label(label)
    }
  }
}

///|
fn decode_supported_html_encoding(
  input : BytesView,
  encoding : String,
) -> (String, String) {
  match encoding {
    "utf-8" => (@utf8.decode_lossy(input, ignore_bom=true), "utf-8")
    "windows-1252" => (decode_windows1252_lossy(input), "windows-1252")
    "iso-8859-2" => (decode_iso88592_lossy(input), "iso-8859-2")
    "utf-16" => (decode_utf16_lossy(input), "utf-16")
    "utf-16le" => (decode_utf16le_lossy(input), "utf-16le")
    "utf-16be" => (decode_utf16be_lossy(input), "utf-16be")
    _ => (decode_windows1252_lossy(input), "windows-1252")
  }
}

///|
fn starts_html_comment_at(input : BytesView, pos : Int) -> Bool {
  pos + 3 < input.length() && input[pos:] is [.. b"<!--", ..]
}

///|
fn find_html_comment_end(input : BytesView, pos : Int, limit : Int) -> Int? {
  let mut pos = pos
  while pos + 2 < limit {
    if input[pos:] is [.. b"-->", ..] {
      return Some(pos + 3)
    }
    pos += 1
  }
  None
}

///|
fn skip_byte_tag(input : BytesView, pos : Int, limit : Int) -> Int {
  let mut pos = pos
  let mut quote : Byte? = None
  while pos < limit {
    let byte = input[pos]
    match quote {
      Some(expected) => if byte == expected { quote = None }
      None =>
        if byte == b'"' || byte == b'\'' {
          quote = Some(byte)
        } else if byte == b'>' {
          return pos + 1
        }
    }
    pos += 1
  }
  limit
}

///|
fn parse_meta_tag_declared_encoding(
  input : BytesView,
  tag_start : Int,
  pos : Int,
  limit : Int,
) -> (String?, Int) {
  let mut pos = pos
  let mut charset : (Int, Int)? = None
  let mut http_equiv : (Int, Int)? = None
  let mut content : (Int, Int)? = None
  while pos < limit {
    let byte = input[pos]
    if byte == b'>' {
      match charset {
        Some((start, end)) => {
          let label = ascii_lower_bytes(input, start, end)
          match normalize_meta_html_encoding_label(label) {
            Some(encoding) => return (Some(encoding), pos + 1)
            None => ()
          }
        }
        None => ()
      }
      match (http_equiv, content) {
        (Some((http_start, http_end)), Some((content_start, content_end))) => {
          if byte_range_ascii_lower_eq(
              input, http_start, http_end, "content-type",
            ) {
            return (
              extract_charset_from_content_bytes(
                input, content_start, content_end,
              ),
              pos + 1,
            )
          }
          return (None, pos + 1)
        }
        _ => return (None, pos + 1)
      }
    }
    if byte == b'<' {
      return (None, tag_start + 1)
    }
    if is_ascii_whitespace_byte(byte) || byte == b'/' {
      pos += 1
      continue
    }
    let name_start = pos
    while pos < limit {
      let value = input[pos].to_int()
      if is_ascii_whitespace_byte(input[pos]) ||
        value == 0x3D ||
        value == 0x3E ||
        value == 0x2F ||
        value == 0x3C {
        break
      }
      pos += 1
    }
    let attr_name = ascii_lower_bytes(input, name_start, pos)
    pos = skip_ascii_whitespace_bytes(input, pos)
    let mut value_range : (Int, Int)? = None
    if pos < limit && input[pos] == b'=' {
      pos += 1
      pos = skip_ascii_whitespace_bytes(input, pos)
      if pos >= limit {
        return (None, tag_start + 1)
      }
      if input[pos] == b'"' || input[pos] == b'\'' {
        let quote = input[pos]
        pos += 1
        let value_start = pos
        while pos < limit && input[pos] != quote {
          pos += 1
        }
        if pos >= limit {
          return (None, tag_start + 1)
        }
        value_range = Some((value_start, pos))
        pos += 1
      } else {
        let value_start = pos
        while pos < limit {
          let value = input[pos].to_int()
          if is_ascii_whitespace_byte(input[pos]) ||
            value == 0x3E ||
            value == 0x3C {
            break
          }
          pos += 1
        }
        value_range = Some((value_start, pos))
      }
    }
    if attr_name == "charset" {
      match value_range {
        Some((start, end)) => {
          let (start, end) = strip_ascii_whitespace_bytes(input, start, end)
          if start < end {
            charset = Some((start, end))
          }
        }
        None => ()
      }
    } else if attr_name == "http-equiv" {
      match value_range {
        Some((start, end)) => {
          let (start, end) = strip_ascii_whitespace_bytes(input, start, end)
          if start < end {
            http_equiv = Some((start, end))
          }
        }
        None => ()
      }
    } else if attr_name == "content" {
      match value_range {
        Some((start, end)) => {
          let (start, end) = strip_ascii_whitespace_bytes(input, start, end)
          if start < end {
            content = Some((start, end))
          }
        }
        None => ()
      }
    }
  }
  (None, tag_start + 1)
}

///|
fn prescan_meta_charset(input : BytesView) -> String? {
  let scan_limit = if input.length() < 65536 { input.length() } else { 65536 }
  let mut pos = 0
  let mut non_comment = 0
  while pos < scan_limit && non_comment < 1024 {
    if input[pos] != b'<' {
      pos += 1
      non_comment += 1
      continue
    }
    if starts_html_comment_at(input, pos) {
      match find_html_comment_end(input, pos + 4, scan_limit) {
        Some(next) => {
          pos = next
          continue
        }
        None => return None
      }
    }
    let mut tag_pos = pos + 1
    if tag_pos < scan_limit && input[tag_pos] == b'/' {
      let next = skip_byte_tag(input, pos, scan_limit)
      non_comment += next - pos
      pos = next
      continue
    }
    if tag_pos >= scan_limit || !is_ascii_alpha_byte(input[tag_pos]) {
      pos += 1
      non_comment += 1
      continue
    }
    let name_start = tag_pos
    while tag_pos < scan_limit && is_ascii_alpha_byte(input[tag_pos]) {
      tag_pos += 1
    }
    let tag_name = ascii_lower_bytes(input, name_start, tag_pos)
    if tag_name != "meta" {
      let next = skip_byte_tag(input, pos, scan_limit)
      non_comment += next - pos
      pos = next
      continue
    }
    let (encoding, next) = parse_meta_tag_declared_encoding(
      input, pos, tag_pos, scan_limit,
    )
    match encoding {
      Some(_) => return encoding
      None => {
        non_comment += next - pos
        pos = next
      }
    }
  }
  None
}

///|
/// Decode HTML bytes using optional caller-supplied encoding or HTML sniffing.
///
/// When `encoding` is absent, BOMs and `<meta charset>` declarations are
/// sniffed before falling back to Windows-1252.
pub fn decode_html_bytes(
  input : BytesView,
  encoding : String?,
) -> (String, String) {
  match encoding {
    Some(label) => {
      let trimmed = label[:].trim()
      if trimmed.is_empty() {
        decode_html_bytes(input, None)
      } else {
        match normalize_supported_html_encoding_label(trimmed) {
          Some(encoding) => decode_supported_html_encoding(input, encoding)
          None => decode_html_bytes(input, None)
        }
      }
    }
    None =>
      if has_utf16le_bom(input) {
        (decode_utf16le_lossy(input), "utf-16le")
      } else if has_utf16be_bom(input) {
        (decode_utf16be_lossy(input), "utf-16be")
      } else if has_utf8_bom(input) {
        (@utf8.decode_lossy(input, ignore_bom=true), "utf-8")
      } else {
        match prescan_meta_charset(input) {
          Some(encoding) => decode_supported_html_encoding(input, encoding)
          None => (decode_windows1252_lossy(input), "windows-1252")
        }
      }
  }
}
