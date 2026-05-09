///|
pub(all) enum TagKind {
  StartTag
  EndTag
} derive(Debug, Eq)

///|
pub(all) struct TagToken {
  kind : TagKind
  name : String
  attrs : Map[String, String?]
  self_closing : Bool
} derive(Debug, Eq)

///|
pub(all) struct DoctypeInfo {
  name : String
  public_id : String?
  system_id : String?
  force_quirks : Bool
} derive(Debug, Eq)

///|
pub(all) enum HtmlToken {
  Tag(TagToken)
  Characters(String)
  CommentToken(String)
  DoctypeToken(DoctypeInfo)
  Eof
} derive(Debug, Eq)

///|
pub(all) struct TokenizedHtml {
  tokens : Array[HtmlToken]
  errors : Array[ParseError]
} derive(Debug)

///|
pub fn tokenize(
  html : StringView,
  collect_errors? : Bool = false,
) -> TokenizedHtml {
  let tokenizer = SourceTokenizer::new(html, collect_errors~)
  tokenizer.run()
  tokenizer.tokens.push(Eof)
  TokenizedHtml::{ tokens: tokenizer.tokens, errors: tokenizer.errors }
}

///|
priv struct SourceTokenizer {
  input : StringView
  collect_errors : Bool
  mut pos : Int
  tokens : Array[HtmlToken]
  errors : Array[ParseError]
}

///|
fn SourceTokenizer::new(
  input : StringView,
  collect_errors~ : Bool,
) -> SourceTokenizer {
  let input = strip_leading_bom(input)
  SourceTokenizer::{ input, collect_errors, pos: 0, tokens: [], errors: [] }
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
    let (line, column) = line_col_at(self.input, pos)
    self.errors.push(ParseError::new(code, line~, column~))
  }
}

///|
fn SourceTokenizer::run(self : SourceTokenizer) -> Unit {
  while !self.is_eof() {
    if self.starts_with("<!--") {
      self.parse_comment()
    } else if self.starts_with("</") {
      self.parse_end_tag()
    } else if starts_with_case_insensitive(self.input, self.pos, "<!doctype") {
      self.parse_doctype()
    } else if self.starts_with("<") {
      self.parse_start_tag_or_text()
    } else {
      self.parse_characters()
    }
  }
}

///|
fn SourceTokenizer::parse_characters(self : SourceTokenizer) -> Unit {
  let start = self.pos
  while !self.is_eof() && !self.starts_with("<") {
    if self.current() == Some('\u{0000}') {
      self.error_at("unexpected-null-character", self.pos)
    }
    ignore(self.advance_char())
  }
  match self.input.get_view(start~, end=self.pos) {
    Some(view) if !view.is_empty() =>
      self.tokens.push(Characters(decode_entities(view, in_attribute=false)))
    _ => ()
  }
}

///|
fn SourceTokenizer::parse_comment(self : SourceTokenizer) -> Unit {
  let start = self.pos
  self.pos += 4
  let data_start = self.pos
  while !self.is_eof() && !self.starts_with("-->") {
    ignore(self.advance_char())
  }
  let data = match self.input.get_view(start=data_start, end=self.pos) {
    Some(view) => normalize_newlines(view)
    None => ""
  }
  if self.starts_with("-->") {
    self.pos += 3
  } else {
    self.error_at("eof-in-comment", start)
  }
  self.tokens.push(CommentToken(data))
}

///|
fn SourceTokenizer::parse_doctype(self : SourceTokenizer) -> Unit {
  let start = self.pos
  self.pos += "<!doctype".length()
  self.skip_ascii_whitespace()
  let name_start = self.pos
  while !self.is_eof() {
    match self.current() {
      Some('>') => break
      Some(ch) if ch.is_ascii_whitespace() => break
      Some(_) => ignore(self.advance_char())
      None => ()
    }
  }
  let name = match self.input.get_view(start=name_start, end=self.pos) {
    Some(view) if !view.is_empty() => lower_ascii(view)
    _ => {
      self.error_at("missing-doctype-name", start)
      ""
    }
  }
  while !self.is_eof() && !self.starts_with(">") {
    ignore(self.advance_char())
  }
  if self.starts_with(">") {
    self.pos += 1
  } else {
    self.error_at("eof-in-doctype", start)
  }
  self.tokens.push(
    DoctypeToken(DoctypeInfo::{
      name,
      public_id: None,
      system_id: None,
      force_quirks: name == "",
    }),
  )
}

///|
fn SourceTokenizer::parse_end_tag(self : SourceTokenizer) -> Unit {
  let start = self.pos
  self.pos += 2
  self.skip_ascii_whitespace()
  match self.current() {
    Some('>') => {
      self.error_at("missing-end-tag-name", self.pos)
      ignore(self.advance_char())
      return
    }
    Some(ch) if !is_tag_name_start(ch) => {
      self.error_at("invalid-first-character-of-tag-name", self.pos)
      self.parse_bogus_comment()
      return
    }
    None => {
      self.error_at("eof-before-tag-name", self.pos)
      self.tokens.push(Characters("</"))
      return
    }
    _ => ()
  }
  let name_start = self.pos
  while !self.is_eof() {
    match self.current() {
      Some('>') => break
      Some(ch) if ch.is_ascii_whitespace() => break
      Some(_) => ignore(self.advance_char())
      None => ()
    }
  }
  let name = match self.input.get_view(start=name_start, end=self.pos) {
    Some(view) => lower_ascii(view)
    None => ""
  }
  if name == "" {
    self.error_at("missing-end-tag-name", start)
  }
  while !self.is_eof() && !self.starts_with(">") {
    ignore(self.advance_char())
  }
  if self.starts_with(">") {
    self.pos += 1
  } else {
    self.error_at("eof-in-tag", start)
  }
  if name != "" {
    self.tokens.push(
      Tag(TagToken::{ kind: EndTag, name, attrs: {}, self_closing: false }),
    )
  }
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
          Some(ch) if is_tag_name_char(ch) => ignore(self.advance_char())
          _ => break
        }
      }
      let name = match self.input.get_view(start=name_start, end=self.pos) {
        Some(view) => lower_ascii(view)
        None => ""
      }
      let attrs : Map[String, String?] = {}
      let mut self_closing = false
      let mut closed = false
      while !self.is_eof() {
        self.skip_ascii_whitespace()
        match self.current() {
          Some('>') => {
            ignore(self.advance_char())
            closed = true
            break
          }
          Some('/') => {
            ignore(self.advance_char())
            self.skip_ascii_whitespace()
            if self.current() == Some('>') {
              ignore(self.advance_char())
              self_closing = true
              closed = true
              break
            } else {
              self.error_at("unexpected-solidus-in-tag", self.pos)
            }
          }
          Some(_) => self.parse_attribute(attrs)
          None => ()
        }
      }
      if !closed {
        self.error_at("eof-in-tag", start)
      }
      self.tokens.push(
        Tag(TagToken::{ kind: StartTag, name, attrs, self_closing }),
      )
      if !self_closing && is_special_text_element(name) {
        self.consume_special_text_tokens(name)
      }
    }
    _ =>
      if self.current() is None {
        self.error_at("eof-before-tag-name", self.pos)
        self.tokens.push(Characters("<"))
      } else if self.current() == Some('?') {
        self.parse_bogus_comment()
      } else {
        self.error_at("invalid-first-character-of-tag-name", start)
        self.tokens.push(Characters("<"))
      }
  }
}

///|
fn SourceTokenizer::parse_bogus_comment(self : SourceTokenizer) -> Unit {
  let data_start = self.pos
  while !self.is_eof() && self.current() != Some('>') {
    ignore(self.advance_char())
  }
  let data = match self.input.get_view(start=data_start, end=self.pos) {
    Some(view) => normalize_newlines(view)
    None => ""
  }
  if self.current() == Some('>') {
    ignore(self.advance_char())
  }
  self.tokens.push(CommentToken(data))
}

///|
fn SourceTokenizer::parse_attribute(
  self : SourceTokenizer,
  attrs : Map[String, String?],
) -> Unit {
  let name_start = self.pos
  while !self.is_eof() {
    match self.current() {
      Some(ch) if ch.is_ascii_whitespace() ||
        ch == '=' ||
        ch == '/' ||
        ch == '>' => break
      Some(_) => ignore(self.advance_char())
      None => ()
    }
  }
  let name = match self.input.get_view(start=name_start, end=self.pos) {
    Some(view) => lower_ascii(view)
    None => ""
  }
  if name == "" {
    ignore(self.advance_char())
    return
  }
  self.skip_ascii_whitespace()
  if self.current() != Some('=') {
    attrs[name] = Some("")
    return
  }
  ignore(self.advance_char())
  self.skip_ascii_whitespace()
  attrs[name] = Some(self.parse_attribute_value())
}

///|
fn SourceTokenizer::parse_attribute_value(self : SourceTokenizer) -> String {
  match self.current() {
    Some('"') => self.parse_quoted_attribute_value('"')
    Some('\'') => self.parse_quoted_attribute_value('\'')
    _ => {
      let start = self.pos
      while !self.is_eof() {
        match self.current() {
          Some(ch) if ch.is_ascii_whitespace() || ch == '>' => break
          Some('\u{0000}') => {
            self.error_at("unexpected-null-character", self.pos)
            ignore(self.advance_char())
          }
          Some(_) => ignore(self.advance_char())
          None => ()
        }
      }
      match self.input.get_view(start~, end=self.pos) {
        Some(view) => decode_attribute_value(view)
        None => ""
      }
    }
  }
}

///|
fn SourceTokenizer::parse_quoted_attribute_value(
  self : SourceTokenizer,
  quote : Char,
) -> String {
  ignore(self.advance_char())
  let start = self.pos
  while !self.is_eof() && self.current() != Some(quote) {
    if self.current() == Some('\u{0000}') {
      self.error_at("unexpected-null-character", self.pos)
    }
    ignore(self.advance_char())
  }
  let raw = match self.input.get_view(start~, end=self.pos) {
    Some(view) => decode_attribute_value(view)
    None => ""
  }
  if self.current() == Some(quote) {
    ignore(self.advance_char())
  }
  raw
}

///|
fn SourceTokenizer::consume_special_text_tokens(
  self : SourceTokenizer,
  name : String,
) -> Unit {
  let content_start = self.pos
  match find_matching_end_tag(self.input, self.pos, name) {
    Some(end_start) => {
      match self.input.get_view(start=content_start, end=end_start) {
        Some(view) if !view.is_empty() =>
          self.tokens.push(Characters(decoded_special_text(name, view)))
        _ => ()
      }
      self.pos = end_start
      self.parse_end_tag()
    }
    None => {
      match self.input.get_view(start=content_start, end=self.input.length()) {
        Some(view) if !view.is_empty() =>
          self.tokens.push(Characters(decoded_special_text(name, view)))
        _ => ()
      }
      self.error_at("eof-in-text-element", content_start)
      self.pos = self.input.length()
    }
  }
}
