///|
priv struct SourceTokenizer {
  input : StringView
  collect_errors : Bool
  xml_coercion : Bool
  mut pos : Int
  tokens : Array[HtmlToken]
  errors : Array[@core.ParseError]
}

///|
fn SourceTokenizer::new(
  input : StringView,
  collect_errors~ : Bool,
  xml_coercion~ : Bool,
) -> SourceTokenizer {
  let input = @syn.strip_leading_bom(input)
  { input, collect_errors, xml_coercion, pos: 0, tokens: [], errors: [] }
}

///|
fn SourceTokenizer::current(self : SourceTokenizer) -> Char? {
  self.input.get_char(self.pos)
}

///|
fn SourceTokenizer::is_eof(self : SourceTokenizer) -> Bool {
  self.pos >= self.input.length()
}

///|
fn SourceTokenizer::advance_char(self : SourceTokenizer) -> Char? {
  match self.current() {
    Some(ch) => {
      self.pos += ch.utf16_len()
      Some(ch)
    }
    None => None
  }
}

///|
fn SourceTokenizer::starts_with(
  self : SourceTokenizer,
  prefix : StringView,
) -> Bool {
  let end = self.pos + prefix.length()
  match self.input.get_view(start=self.pos, end~) {
    Some(view) => view == prefix
    None => false
  }
}

///|
fn SourceTokenizer::skip_ascii_whitespace(self : SourceTokenizer) -> Unit {
  while !self.is_eof() {
    match self.current() {
      Some(ch) if ch.is_ascii_whitespace() => ignore(self.advance_char())
      _ => return
    }
  }
}

///|
fn SourceTokenizer::error_at(
  self : SourceTokenizer,
  code : String,
  pos : Int,
) -> Unit {
  if self.collect_errors {
    let (line, column) = @syn.line_col_at(self.input, pos)
    self.errors.push(
      @core.ParseError::new(code, line~, column~, category="tokenizer"),
    )
  }
}

///|
fn SourceTokenizer::error_at_eof(self : SourceTokenizer, code : String) -> Unit {
  if self.collect_errors {
    if self.input.is_empty() {
      self.errors.push(
        @core.ParseError::new(code, line=1, column=0, category="tokenizer"),
      )
    } else {
      self.error_at(code, @syn.eof_error_pos(self.input))
    }
  }
}

///|
fn SourceTokenizer::report_current_noncharacter(self : SourceTokenizer) -> Unit {
  match self.current() {
    Some(ch) if @syn.is_xml_noncharacter(ch) =>
      self.error_at("noncharacter-in-input-stream", self.pos)
    _ => ()
  }
}
