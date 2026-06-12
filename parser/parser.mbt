///|
fn Parser::parse_all(self : Parser) -> Unit {
  while !self.is_eof() {
    let start = self.pos
    if self.current().unwrap() == '<' {
      if self.starts_with("<!--") {
        self.parse_comment()
      } else if self.starts_with("</") {
        self.parse_end_tag()
      } else if starts_with_case_insensitive(self.input, self.pos, "<!doctype") {
        self.parse_doctype()
      } else if self.starts_with("<!") {
        self.parse_markup_declaration()
      } else {
        self.parse_start_tag_or_text()
      }
    } else {
      // Direct code-unit scan for the next '<'. Units below the
      // surrogate range cannot be noncharacters (those all sit at
      // U+FDD0..U+FDEF and U+xFFFE/U+xFFFF); surrogates and high BMP
      // units take the decoded per-character path so astral and BMP
      // noncharacters are still reported.
      let input = self.input
      let input_length = input.length()
      while self.pos < input_length {
        let unit = input[self.pos]
        if unit is '<' {
          break
        }
        if unit.to_int() < 0xD800 {
          self.pos += 1
        } else {
          self.report_current_noncharacter()
          ignore(self.advance_char())
        }
      }
      let view = self.input[start:self.pos]
      self.flush_deferred_initial_doctype_error()
      self.append_text(view, start)
    }
  }
  self.flush_pending_text()
}
