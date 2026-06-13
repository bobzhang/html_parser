///|
fn SourceTokenizer::parse_comment(self : SourceTokenizer) -> Unit {
  self.pos += 4
  let scan = @impl.scan_comment_data(self.input, self.pos)
  for error in scan.errors {
    self.error_at(error.code, error.offset)
  }
  self.pos = scan.end
  let data = if self.xml_coercion {
    @syn.coerce_comment_for_xml(scan.data)
  } else {
    scan.data
  }
  self.tokens.push(CommentToken(data))
}

///|
fn SourceTokenizer::parse_markup_declaration(self : SourceTokenizer) -> Unit {
  self.pos += 2
  if self.starts_with("[CDATA[") {
    self.error_at("cdata-in-html-content", self.pos + "[CDATA[".length() - 1)
  } else {
    self.error_at("incorrectly-opened-comment", self.pos - 1)
  }
  self.parse_bogus_comment()
}

///|
fn SourceTokenizer::parse_bogus_comment(self : SourceTokenizer) -> Unit {
  let data_start = self.pos
  while self.current() is Some(ch) && ch != '>' {
    self.pos += ch.utf16_len()
  }
  let data = @syn.normalize_bogus_comment_data(self.input[data_start:self.pos])
  let data = if self.xml_coercion {
    @syn.coerce_comment_for_xml(data)
  } else {
    data
  }
  if self.current() is Some('>') {
    ignore(self.advance_char())
  }
  self.tokens.push(CommentToken(data))
}
