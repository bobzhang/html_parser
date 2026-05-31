///|
fn SourceTokenizer::parse_attribute(
  self : SourceTokenizer,
  attrs : Map[String, String?],
) -> Unit {
  let name_start = self.pos
  if self.current() == Some('=') {
    self.error_at("unexpected-equals-sign-before-attribute-name", self.pos)
    ignore(self.advance_char())
  }
  while !self.is_eof() {
    match self.current().unwrap() {
      ch if ch.is_ascii_whitespace() || ch == '=' || ch == '/' || ch == '>' =>
        break
      '<' | '"' | '\'' => {
        self.error_at("unexpected-character-in-attribute-name", self.pos)
        ignore(self.advance_char())
      }
      _ => ignore(self.advance_char())
    }
  }
  let (name, name_errors) = parse_lower_name_value_replacing_nulls(
    self.input,
    name_start,
    self.pos,
  )
  for error in name_errors {
    self.error_at(error.code, error.offset)
  }
  if name == "" {
    ignore(self.advance_char())
    return
  }
  let duplicate = attrs.contains(name)
  if duplicate {
    self.error_at("duplicate-attribute", name_start)
  }
  self.skip_ascii_whitespace()
  if self.current() != Some('=') {
    if !duplicate {
      attrs[name] = Some("")
    }
    return
  }
  ignore(self.advance_char())
  self.skip_ascii_whitespace()
  if self.current() == Some('>') {
    self.error_at("missing-attribute-value", self.pos)
  }
  let value = self.parse_attribute_value()
  if !duplicate {
    attrs[name] = Some(value)
  }
}

///|
fn SourceTokenizer::parse_attribute_value(self : SourceTokenizer) -> String {
  match self.current() {
    Some('"') => self.parse_quoted_attribute_value('"')
    Some('\'') => self.parse_quoted_attribute_value('\'')
    _ => {
      let start = self.pos
      while !self.is_eof() {
        match self.current().unwrap() {
          ch if ch.is_ascii_whitespace() || ch == '>' => break
          '\u{0000}' => {
            self.error_at("unexpected-null-character", self.pos)
            ignore(self.advance_char())
          }
          '"' | '\'' | '<' | '=' | '`' => {
            self.error_at(
              "unexpected-character-in-unquoted-attribute-value",
              self.pos,
            )
            ignore(self.advance_char())
          }
          _ => ignore(self.advance_char())
        }
      }
      let view = self.input[start:self.pos]
      let decoded = decode_attribute_value_with_errors(view)
      for error in decoded.errors {
        self.error_at(error.code, self.pos)
      }
      decoded.data
    }
  }
}

///|
fn SourceTokenizer::parse_quoted_attribute_value(
  self : SourceTokenizer,
  quote : Char,
) -> String {
  ignore(self.advance_char())
  let start = self.pos
  while !self.is_eof() && self.current() != Some(quote) {
    if self.current() == Some('\u{0000}') {
      self.error_at("unexpected-null-character", self.pos)
    }
    ignore(self.advance_char())
  }
  let raw = self.input[start:self.pos]
  if self.current() == Some(quote) {
    ignore(self.advance_char())
    match self.current() {
      Some(ch) if !ch.is_ascii_whitespace() && ch != '>' && ch != '/' =>
        self.error_at("missing-whitespace-between-attributes", self.pos)
      _ => ()
    }
  }
  let decoded = decode_attribute_value_with_errors(raw)
  for error in decoded.errors {
    self.error_at(error.code, self.pos)
  }
  decoded.data
}
