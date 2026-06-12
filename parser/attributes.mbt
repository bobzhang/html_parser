///|
fn Parser::parse_attribute(self : Parser, attrs : Map[String, String?]) -> Unit {
  let name_start = self.pos
  if self.current() == Some('=') {
    self.error_at("unexpected-equals-sign-before-attribute-name", self.pos)
    ignore(self.advance_char())
  }
  // Scan with direct code-unit indexing: the delimiters are ASCII, which
  // never matches inside a surrogate pair, so stepping one unit at a
  // time is safe and avoids the Char? boxing of get_char per character.
  let input = self.input
  let input_length = input.length()
  while self.pos < input_length {
    match input[self.pos] {
      '=' | '/' | '>' => break
      ' ' | '\t' | '\n' | '\u{000B}' | '\u{000C}' | '\r' => break
      '<' | '"' | '\'' => {
        self.error_at("unexpected-character-in-attribute-name", self.pos)
        self.pos += 1
      }
      _ => self.pos += 1
    }
  }
  let (name, name_errors) = @tok.parse_lower_name_value_replacing_nulls(
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
      attrs[name] = None
    }
    return
  }
  ignore(self.advance_char())
  self.skip_ascii_whitespace()
  let missing_value = self.current() == Some('>')
  if missing_value {
    self.error_at("missing-attribute-value", self.pos)
  }
  let value = match self.current() {
    Some('"') => self.parse_quoted_attribute_value('"')
    Some('\'') => self.parse_quoted_attribute_value('\'')
    _ => {
      let start = self.pos
      // Direct code-unit scan; see the attribute-name loop above.
      while self.pos < input_length {
        match input[self.pos] {
          '>' => break
          ' ' | '\t' | '\n' | '\u{000B}' | '\u{000C}' | '\r' => break
          '\u{0000}' => {
            self.error_at("unexpected-null-character", self.pos)
            self.pos += 1
          }
          '"' | '\'' | '<' | '=' | '`' => {
            self.error_at(
              "unexpected-character-in-unquoted-attribute-value",
              self.pos,
            )
            self.pos += 1
          }
          _ => self.pos += 1
        }
      }
      let view = self.input[start:self.pos]
      let decoded = @tok.decode_attribute_value_with_errors(view)
      for error in decoded.errors {
        self.error_at(error.code, self.pos)
      }
      decoded.data.to_owned()
    }
  }
  if !duplicate {
    attrs[name] = if missing_value { None } else { Some(value) }
  }
}

///|
fn Parser::parse_quoted_attribute_value(self : Parser, quote : Char) -> String {
  ignore(self.advance_char())
  let start = self.pos
  // Direct code-unit scan: the quote and NUL are ASCII, which never
  // matches inside a surrogate pair, so stepping one unit at a time is
  // safe and avoids the Char? boxing of get_char per character.
  let input = self.input
  let input_length = input.length()
  let quote_unit = quote.to_int()
  while self.pos < input_length {
    let ch = input[self.pos]
    if ch.to_int() == quote_unit {
      break
    }
    if ch is '\u{0000}' {
      self.error_at("unexpected-null-character", self.pos)
    }
    self.pos += 1
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
  let decoded = @tok.decode_attribute_value_with_errors(raw)
  for error in decoded.errors {
    self.error_at(error.code, self.pos)
  }
  decoded.data.to_owned()
}
