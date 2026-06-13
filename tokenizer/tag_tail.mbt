///|
priv struct TagTailScan {
  attrs : Map[String, String?]
  self_closing : Bool
  closed : Bool
}

///|
fn SourceTokenizer::parse_tag_tail(self : SourceTokenizer) -> TagTailScan {
  let attrs : Map[String, String?] = {}
  let mut self_closing = false
  let mut closed = false
  while !self.is_eof() {
    self.skip_ascii_whitespace()
    if self.is_eof() {
      break
    }
    match self.current().unwrap() {
      '>' => {
        ignore(self.advance_char())
        closed = true
        break
      }
      '/' => {
        ignore(self.advance_char())
        if self.current() is Some('>') {
          ignore(self.advance_char())
          self_closing = true
          closed = true
          break
        } else {
          self.error_at("unexpected-character-after-solidus-in-tag", self.pos)
        }
      }
      _ => self.parse_attribute(attrs)
    }
  }
  { attrs, self_closing, closed }
}
