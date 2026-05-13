///|
fn SourceTokenizer::decoded_special_text(
  self : SourceTokenizer,
  name : StringView,
  raw : StringView,
  start : Int,
  error_pos : Int,
) -> String {
  let raw = self.replace_special_text_nulls(raw, start)
  let data = if special_text_decodes_entities(name) {
    let decoded = decode_entities_with_errors(raw, in_attribute=false)
    for error in decoded.errors {
      self.error_at(error.code, error_pos)
    }
    decoded.data
  } else {
    @syn.normalize_newlines(raw)
  }
  if self.xml_coercion {
    @syn.coerce_text_for_xml(data)
  } else {
    data
  }
}

///|
fn SourceTokenizer::replace_special_text_nulls(
  self : SourceTokenizer,
  raw : StringView,
  start : Int,
) -> String {
  let out = StringBuilder::new(size_hint=raw.length())
  let mut pos = 0
  for ch in raw {
    if ch == '\u{0000}' {
      self.error_at("unexpected-null-character", start + pos)
      out.write_char('\u{FFFD}')
    } else {
      out.write_char(ch)
    }
    pos += ch.utf16_len()
  }
  out.to_string()
}

///|
fn SourceTokenizer::consume_special_text_tokens(
  self : SourceTokenizer,
  name : String,
) -> Unit {
  let content_start = self.pos
  if name == "plaintext" {
    match self.input.get_view(start=content_start, end=self.input.length()) {
      Some(view) if !view.is_empty() =>
        self.tokens.push(
          Characters(
            self.decoded_special_text(
              name,
              view,
              content_start,
              @syn.eof_error_pos(self.input),
            ),
          ),
        )
      _ => ()
    }
    self.pos = self.input.length()
    return
  }
  if name == "script" {
    let scan = scan_script_text(self.input, self.pos)
    for error in scan.errors {
      self.error_at(error.code, error.offset)
    }
    if !scan.data.is_empty() {
      let data = if self.xml_coercion {
        @syn.coerce_text_for_xml(scan.data)
      } else {
        scan.data
      }
      self.tokens.push(Characters(data))
    }
    match scan.end_start {
      Some(end_start) => {
        self.pos = end_start
        self.parse_end_tag()
      }
      None => self.pos = self.input.length()
    }
    return
  }
  match find_matching_end_tag(self.input, self.pos, name) {
    Some(end_start) => {
      let error_pos = matching_end_tag_error_pos(self.input, end_start)
      match self.input.get_view(start=content_start, end=end_start) {
        Some(view) if !view.is_empty() =>
          self.tokens.push(
            Characters(
              self.decoded_special_text(name, view, content_start, error_pos),
            ),
          )
        _ => ()
      }
      self.pos = end_start
      self.parse_end_tag()
    }
    None => {
      let error_pos = @syn.eof_error_pos(self.input)
      match self.input.get_view(start=content_start, end=self.input.length()) {
        Some(view) if !view.is_empty() =>
          self.tokens.push(
            Characters(
              self.decoded_special_text(name, view, content_start, error_pos),
            ),
          )
        _ => ()
      }
      self.pos = self.input.length()
    }
  }
}
