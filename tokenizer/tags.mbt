///|
fn SourceTokenizer::parse_end_tag(self : SourceTokenizer) -> Unit {
  self.pos += 2
  match self.current() {
    Some('>') => {
      self.error_at("empty-end-tag", self.pos)
      ignore(self.advance_char())
      return
    }
    Some(ch) if !@impl.is_tag_name_start(ch) => {
      self.error_at("invalid-first-character-of-tag-name", self.pos)
      self.parse_bogus_comment()
      return
    }
    None => {
      self.error_at_eof("eof-before-tag-name")
      self.tokens.push(Characters("</"))
      return
    }
    _ => ()
  }
  let name_start = self.pos
  while !self.is_eof() {
    match self.current().unwrap() {
      '>' => break
      '/' => break
      ch if ch.is_ascii_whitespace() => break
      _ => ignore(self.advance_char())
    }
  }
  let (name, name_errors) = @impl.parse_lower_name_value_replacing_nulls(
    self.input,
    name_start,
    self.pos,
  )
  for error in name_errors {
    self.error_at(error.code, error.offset)
  }
  let tail = self.parse_tag_tail()
  if !tail.closed {
    self.error_at_eof("eof-in-tag")
    return
  }
  self.tokens.push(
    Tag({
      kind: EndTag,
      name,
      attrs: tail.attrs,
      self_closing: tail.self_closing,
    }),
  )
}

///|
fn SourceTokenizer::parse_start_tag_or_text(self : SourceTokenizer) -> Unit {
  let start = self.pos
  self.pos += 1
  match self.current() {
    Some(ch) if @impl.is_tag_name_start(ch) => {
      let name_start = self.pos
      while !self.is_eof() {
        match self.current() {
          Some(ch) if !@impl.is_tag_name_end(ch) => ignore(self.advance_char())
          _ => break
        }
      }
      let (name, name_errors) = @impl.parse_lower_name_value_replacing_nulls(
        self.input,
        name_start,
        self.pos,
      )
      for error in name_errors {
        self.error_at(error.code, error.offset)
      }
      let tail = self.parse_tag_tail()
      if !tail.closed {
        self.error_at_eof("eof-in-tag")
        return
      }
      self.tokens.push(
        Tag({
          kind: StartTag,
          name,
          attrs: tail.attrs,
          self_closing: tail.self_closing,
        }),
      )
      if !tail.self_closing && @impl.is_special_text_element(name) {
        self.consume_special_text_tokens(name)
      }
    }
    _ =>
      if self.current() is None {
        self.error_at_eof("eof-before-tag-name")
        self.tokens.push(Characters("<"))
      } else if self.current() is Some('?') {
        self.error_at("unexpected-question-mark-instead-of-tag-name", self.pos)
        self.parse_bogus_comment()
      } else {
        self.report_current_noncharacter()
        self.parse_invalid_tag_open_as_text(start)
      }
  }
}
