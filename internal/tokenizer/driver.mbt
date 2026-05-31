///|
fn SourceTokenizer::run(self : SourceTokenizer) -> Unit {
  while !self.step() {
    ()
  }
}

///|
fn SourceTokenizer::step(self : SourceTokenizer) -> Bool {
  if self.is_eof() {
    return true
  }
  if self.starts_with("<!--") {
    self.parse_comment()
  } else if self.starts_with("</") {
    self.parse_end_tag()
  } else if @syn.starts_with_case_insensitive(self.input, self.pos, "<!doctype") {
    self.parse_doctype()
  } else if self.starts_with("<!") {
    self.parse_markup_declaration()
  } else if self.starts_with("<") {
    self.parse_start_tag_or_text()
  } else {
    self.parse_characters()
  }
  self.is_eof()
}
