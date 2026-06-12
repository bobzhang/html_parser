///|
fn Parser::parse_start_tag_or_text(self : Parser) -> Unit {
  let start = self.pos
  self.pos += 1
  match self.current() {
    Some(ch) if @tok.is_tag_name_start(ch) => {
      let name_start = self.pos
      // Direct code-unit scan: the name-ending delimiters are ASCII,
      // which never matches inside a surrogate pair, so stepping one
      // unit at a time is safe and avoids the Char? boxing of get_char.
      let input = self.input
      let input_length = input.length()
      while self.pos < input_length {
        match input[self.pos] {
          '>' | '/' | ' ' | '\t' | '\n' | '\u{000B}' | '\u{000C}' | '\r' =>
            break
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
      let attrs : Map[String, String?] = {}
      let mut self_closing = false
      let mut closed = false
      while !self.is_eof() {
        self.skip_ascii_whitespace()
        let ch = self.current().unwrap()
        match ch {
          '>' => {
            ignore(self.advance_char())
            closed = true
            break
          }
          '/' => {
            ignore(self.advance_char())
            if self.current() == Some('>') {
              ignore(self.advance_char())
              self_closing = true
              closed = true
              break
            } else {
              self.error_at(
                "unexpected-character-after-solidus-in-tag",
                self.pos,
              )
            }
          }
          _ => self.parse_attribute(attrs)
        }
      }
      if !closed {
        self.error_at_eof("eof-in-tag")
        self.append_sanitize_escape_source_text(start, self.pos)
        return
      }
      let tag_close_pos = self.pos - 1
      let was_after_body = self.document_after_body
      self.handle_parsed_start_tag(
        name, attrs, self_closing, start, tag_close_pos,
      )
      // Any start tag in the after-body modes is the "anything else" case:
      // the mode switches to in-body before reprocessing, even when the
      // token is then ignored (a late <head> or <frame>). Cleared after
      // processing so insertion-time marking still sees the state.
      if was_after_body {
        self.leave_after_body_for_token(name)
      }
    }
    _ =>
      if self.current() is None {
        self.error_at_eof("eof-before-tag-name")
        self.flush_deferred_initial_doctype_error()
        self.current_node().append_child(self.text_at("<", start))
      } else if self.current() == Some('?') {
        self.error_at("unexpected-question-mark-instead-of-tag-name", self.pos)
        self.parse_bogus_comment(start)
        self.append_sanitize_escape_source_text(start, self.pos)
      } else {
        self.report_current_noncharacter()
        self.parse_invalid_tag_open_as_text(start)
      }
  }
}

///|
fn Parser::parse_invalid_tag_open_as_text(self : Parser, start : Int) -> Unit {
  self.error_at("invalid-first-character-of-tag-name", self.pos)
  while !self.is_eof() && !self.starts_with("<") {
    self.report_current_noncharacter()
    ignore(self.advance_char())
  }
  let view = self.input[start:self.pos]
  self.flush_deferred_initial_doctype_error()
  self.append_text(view, start)
}
