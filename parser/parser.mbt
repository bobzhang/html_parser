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
      while !self.is_eof() && !self.starts_with("<") {
        self.report_current_noncharacter()
        ignore(self.advance_char())
      }
      let view = self.input[start:self.pos]
      self.flush_deferred_initial_doctype_error()
      self.append_text(view, start)
    }
  }
}
