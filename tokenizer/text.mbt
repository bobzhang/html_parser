///|
fn SourceTokenizer::parse_characters(self : SourceTokenizer) -> Unit {
  let start = self.pos
  while !self.is_eof() && !self.starts_with("<") {
    match self.current() {
      Some('\u{0000}') => self.error_at("unexpected-null-character", self.pos)
      Some(ch) if @syn.is_xml_noncharacter(ch) =>
        self.error_at("noncharacter-in-input-stream", self.pos)
      _ => ()
    }
    ignore(self.advance_char())
  }
  let view = self.input[start:self.pos]
  if !view.is_empty() {
    let decoded = @impl.decode_entities_with_errors(view, in_attribute=false)
    for error in decoded.errors {
      self.error_at(error.code, start + error.offset)
    }
    let data = if self.xml_coercion {
      @syn.coerce_text_for_xml(decoded.data)
    } else {
      decoded.data.to_owned()
    }
    self.tokens.push(Characters(data))
  }
}

///|
fn SourceTokenizer::parse_invalid_tag_open_as_text(
  self : SourceTokenizer,
  start : Int,
) -> Unit {
  self.error_at("invalid-first-character-of-tag-name", self.pos)
  while !self.is_eof() && !self.starts_with("<") {
    match self.current() {
      Some('\u{0000}') => self.error_at("unexpected-null-character", self.pos)
      Some(ch) if @syn.is_xml_noncharacter(ch) =>
        self.error_at("noncharacter-in-input-stream", self.pos)
      _ => ()
    }
    ignore(self.advance_char())
  }
  let view = self.input[start:self.pos]
  if !view.is_empty() {
    let decoded = @impl.decode_entities_with_errors(view, in_attribute=false)
    for error in decoded.errors {
      self.error_at(error.code, start + error.offset)
    }
    let data = if self.xml_coercion {
      @syn.coerce_text_for_xml(decoded.data)
    } else {
      decoded.data.to_owned()
    }
    self.tokens.push(Characters(data))
  }
}
