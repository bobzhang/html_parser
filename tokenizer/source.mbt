///|
/// Tokenize an HTML string without building a DOM tree.
///
/// Set `collect_errors=true` to collect tokenizer diagnostics in the returned
/// `TokenizedHtml`. Set `xml_coercion=true` to replace XML-invalid text and
/// comment characters during tokenization.
pub fn tokenize(
  html : StringView,
  collect_errors? : Bool = false,
  xml_coercion? : Bool = false,
) -> TokenizedHtml {
  let tokenizer = SourceTokenizer::new(html, collect_errors~, xml_coercion~)
  tokenizer.run()
  tokenizer.tokens.push(Eof)
  { tokens: tokenizer.tokens, errors: tokenizer.errors }
}

///|
/// Tokenize an HTML string and emit tokens incrementally.
///
/// The callback receives tokenizer output in source order, without an explicit
/// `Eof` token.
pub fn tokenize_each(
  html : StringView,
  emit : (HtmlToken) -> Unit,
  xml_coercion? : Bool = false,
) -> Unit {
  let tokenizer = SourceTokenizer::new(
    html,
    collect_errors=false,
    xml_coercion~,
  )
  while !tokenizer.is_eof() {
    tokenizer.tokens.clear()
    ignore(tokenizer.step())
    for token in tokenizer.tokens {
      emit(token)
    }
  }
}

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

///|
fn SourceTokenizer::parse_doctype(self : SourceTokenizer) -> Unit {
  self.pos += "<!doctype".length()
  let missing_before_name = match self.current() {
    Some('>') | None => None
    Some(ch) if ch.is_ascii_whitespace() => {
      self.skip_ascii_whitespace()
      None
    }
    _ => Some(self.pos)
  }
  let name_start = self.pos
  while !self.is_eof() {
    match self.current().unwrap() {
      '>' => break
      ch if ch.is_ascii_whitespace() => break
      _ => ignore(self.advance_char())
    }
  }
  let (name, name_errors) = parse_lower_name_value_replacing_nulls(
    self.input,
    name_start,
    self.pos,
  )
  let ids_start = self.pos
  while !self.is_eof() && !self.starts_with(">") {
    ignore(self.advance_char())
  }
  let external = parse_doctype_external(
    self.input[ids_start:self.pos],
    self.starts_with(">"),
  )
  let public_id = external.public_id
  let system_id = external.system_id
  let has_external_error = !external.errors.is_empty()
  let eof_doctype = name != "" && !has_external_error && !self.starts_with(">")
  match missing_before_name {
    Some(pos) => self.error_at("missing-whitespace-before-doctype-name", pos)
    None => ()
  }
  for error in name_errors {
    self.error_at(error.code, error.offset)
  }
  if name == "" {
    if self.starts_with(">") {
      self.error_at("expected-doctype-name-but-got-right-bracket", self.pos)
    } else {
      self.error_at_eof("eof-in-doctype")
    }
  } else {
    for error in external.errors {
      self.error_at(error.code, ids_start + error.offset)
    }
  }
  if eof_doctype {
    self.error_at_eof("eof-in-doctype")
  }
  if self.starts_with(">") {
    self.pos += 1
  }
  let force_quirks = name == "" || external.force_quirks || eof_doctype
  self.tokens.push(DoctypeToken({ name, public_id, system_id, force_quirks }))
}

///|
fn SourceTokenizer::parse_end_tag(self : SourceTokenizer) -> Unit {
  self.pos += 2
  match self.current() {
    Some('>') => {
      self.error_at("empty-end-tag", self.pos)
      ignore(self.advance_char())
      return
    }
    Some(ch) if !is_tag_name_start(ch) => {
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
  let (name, name_errors) = parse_lower_name_value_replacing_nulls(
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
        if self.current() == Some('>') {
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
  if !closed {
    self.error_at_eof("eof-in-tag")
    return
  }
  self.tokens.push(Tag({ kind: EndTag, name, attrs, self_closing }))
}

///|
fn SourceTokenizer::parse_start_tag_or_text(self : SourceTokenizer) -> Unit {
  let start = self.pos
  self.pos += 1
  match self.current() {
    Some(ch) if is_tag_name_start(ch) => {
      let name_start = self.pos
      while !self.is_eof() {
        match self.current() {
          Some(ch) if !is_tag_name_end(ch) => ignore(self.advance_char())
          _ => break
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
        return
      }
      self.tokens.push(Tag({ kind: StartTag, name, attrs, self_closing }))
      if !self_closing && is_special_text_element(name) {
        self.consume_special_text_tokens(name)
      }
    }
    _ =>
      if self.current() is None {
        self.error_at_eof("eof-before-tag-name")
        self.tokens.push(Characters("<"))
      } else if self.current() == Some('?') {
        self.error_at("unexpected-question-mark-instead-of-tag-name", self.pos)
        self.parse_bogus_comment()
      } else {
        self.report_current_noncharacter()
        self.parse_invalid_tag_open_as_text(start)
      }
  }
}
