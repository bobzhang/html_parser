///|
/// Whether a tag token opens an element or closes one.
///
/// `StartTag` represents tags such as `<p>` and `EndTag` represents tags such
/// as `</p>`.
pub(all) enum TagKind {
  StartTag
  EndTag
} derive(Debug, Eq)

///|
/// A start or end tag emitted by `tokenize`.
///
/// `name` is lower-cased for HTML tag tokens. `attrs` maps attribute names to
/// optional values; a value of `None` represents a minimized or missing-value
/// attribute. `self_closing` records the solidus marker on start tags.
pub(all) struct TagToken {
  kind : TagKind
  name : String
  attrs : Map[String, String?]
  self_closing : Bool
} derive(Debug, Eq)

///|
/// Doctype data emitted by the tokenizer.
///
/// `force_quirks` is set when the tokenizer sees a malformed or legacy doctype
/// form that should place a parsed document into quirks mode.
pub(all) struct DoctypeInfo {
  name : String
  public_id : String?
  system_id : String?
  force_quirks : Bool
} derive(Debug, Eq)

///|
/// Token variants produced by the HTML tokenizer.
///
/// `Eof` is appended as the final token. Character data and comments are stored
/// as already-normalized MoonBit strings; parse diagnostics are returned through
/// `TokenizedHtml.errors` when error collection is enabled.
pub(all) enum HtmlToken {
  Tag(TagToken)
  Characters(String)
  CommentToken(String)
  DoctypeToken(DoctypeInfo)
  Eof
} derive(Debug, Eq)

///|
/// Result returned by `tokenize`.
///
/// `tokens` always ends with `HtmlToken::Eof`. `errors` is empty unless
/// `collect_errors=true` was passed.
pub(all) struct TokenizedHtml {
  tokens : Array[HtmlToken]
  errors : Array[ParseError]
} derive(Debug)

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
priv struct SourceTokenizer {
  input : StringView
  collect_errors : Bool
  xml_coercion : Bool
  mut pos : Int
  tokens : Array[HtmlToken]
  errors : Array[ParseError]
}

///|
fn SourceTokenizer::new(
  input : StringView,
  collect_errors~ : Bool,
  xml_coercion~ : Bool,
) -> SourceTokenizer {
  let input = strip_leading_bom(input)
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
    let (line, column) = line_col_at(self.input, pos)
    self.errors.push(
      ParseError::new(code, line~, column~, category="tokenizer"),
    )
  }
}

///|
fn SourceTokenizer::error_at_eof(self : SourceTokenizer, code : String) -> Unit {
  if self.collect_errors {
    if self.input.is_empty() {
      self.errors.push(
        ParseError::new(code, line=1, column=0, category="tokenizer"),
      )
    } else {
      self.error_at(code, eof_error_pos(self.input))
    }
  }
}

///|
fn SourceTokenizer::report_current_noncharacter(self : SourceTokenizer) -> Unit {
  match self.current() {
    Some(ch) if is_xml_noncharacter(ch) =>
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
  } else if starts_with_case_insensitive(self.input, self.pos, "<!doctype") {
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
fn SourceTokenizer::parse_characters(self : SourceTokenizer) -> Unit {
  let start = self.pos
  while !self.is_eof() && !self.starts_with("<") {
    match self.current() {
      Some('\u{0000}') => self.error_at("unexpected-null-character", self.pos)
      Some(ch) if is_xml_noncharacter(ch) =>
        self.error_at("noncharacter-in-input-stream", self.pos)
      _ => ()
    }
    ignore(self.advance_char())
  }
  let view = self.input[start:self.pos]
  if !view.is_empty() {
    let decoded = decode_entities_with_errors(view, in_attribute=false)
    for error in decoded.errors {
      self.error_at(error.code, start + error.offset)
    }
    let data = decoded.data
    let data = if self.xml_coercion { coerce_text_for_xml(data) } else { data }
    self.tokens.push(Characters(data))
  }
}

///|
fn SourceTokenizer::parse_comment(self : SourceTokenizer) -> Unit {
  self.pos += 4
  let scan = scan_comment_data(self.input, self.pos)
  for error in scan.errors {
    self.error_at(error.code, error.offset)
  }
  self.pos = scan.end
  let data = if self.xml_coercion {
    coerce_comment_for_xml(scan.data)
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

///|
fn SourceTokenizer::parse_invalid_tag_open_as_text(
  self : SourceTokenizer,
  start : Int,
) -> Unit {
  self.error_at("invalid-first-character-of-tag-name", self.pos)
  while !self.is_eof() && !self.starts_with("<") {
    match self.current() {
      Some('\u{0000}') => self.error_at("unexpected-null-character", self.pos)
      Some(ch) if is_xml_noncharacter(ch) =>
        self.error_at("noncharacter-in-input-stream", self.pos)
      _ => ()
    }
    ignore(self.advance_char())
  }
  let view = self.input[start:self.pos]
  if !view.is_empty() {
    let decoded = decode_entities_with_errors(view, in_attribute=false)
    for error in decoded.errors {
      self.error_at(error.code, start + error.offset)
    }
    let data = decoded.data
    let data = if self.xml_coercion { coerce_text_for_xml(data) } else { data }
    self.tokens.push(Characters(data))
  }
}

///|
fn SourceTokenizer::parse_bogus_comment(self : SourceTokenizer) -> Unit {
  let data_start = self.pos
  while !self.is_eof() && self.current() != Some('>') {
    ignore(self.advance_char())
  }
  let data = normalize_bogus_comment_data(self.input[data_start:self.pos])
  let data = if self.xml_coercion { coerce_comment_for_xml(data) } else { data }
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
  if self.current() == Some('=') {
    self.error_at("unexpected-equals-sign-before-attribute-name", self.pos)
    ignore(self.advance_char())
  }
  while !self.is_eof() {
    match self.current().unwrap() {
      ch if ch.is_ascii_whitespace() || ch == '=' || ch == '/' || ch == '>' =>
        break
      '<' | '"' | '\'' => {
        self.error_at("unexpected-character-in-attribute-name", self.pos)
        ignore(self.advance_char())
      }
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
  if name == "" {
    ignore(self.advance_char())
    return
  }
  let duplicate = attrs.contains(name)
  if duplicate {
    self.error_at("duplicate-attribute", name_start)
  }
  self.skip_ascii_whitespace()
  if self.current() != Some('=') {
    if !duplicate {
      attrs[name] = Some("")
    }
    return
  }
  ignore(self.advance_char())
  self.skip_ascii_whitespace()
  if self.current() == Some('>') {
    self.error_at("missing-attribute-value", self.pos)
  }
  let value = self.parse_attribute_value()
  if !duplicate {
    attrs[name] = Some(value)
  }
}

///|
fn SourceTokenizer::parse_attribute_value(self : SourceTokenizer) -> String {
  match self.current() {
    Some('"') => self.parse_quoted_attribute_value('"')
    Some('\'') => self.parse_quoted_attribute_value('\'')
    _ => {
      let start = self.pos
      while !self.is_eof() {
        match self.current().unwrap() {
          ch if ch.is_ascii_whitespace() || ch == '>' => break
          '\u{0000}' => {
            self.error_at("unexpected-null-character", self.pos)
            ignore(self.advance_char())
          }
          '"' | '\'' | '<' | '=' | '`' => {
            self.error_at(
              "unexpected-character-in-unquoted-attribute-value",
              self.pos,
            )
            ignore(self.advance_char())
          }
          _ => ignore(self.advance_char())
        }
      }
      let view = self.input[start:self.pos]
      let decoded = decode_attribute_value_with_errors(view)
      for error in decoded.errors {
        self.error_at(error.code, self.pos)
      }
      decoded.data
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
  let raw = self.input[start:self.pos]
  if self.current() == Some(quote) {
    ignore(self.advance_char())
    match self.current() {
      Some(ch) if !ch.is_ascii_whitespace() && ch != '>' && ch != '/' =>
        self.error_at("missing-whitespace-between-attributes", self.pos)
      _ => ()
    }
  }
  let decoded = decode_attribute_value_with_errors(raw)
  for error in decoded.errors {
    self.error_at(error.code, self.pos)
  }
  decoded.data
}

///|
fn SourceTokenizer::decoded_special_text(
  self : SourceTokenizer,
  name : StringView,
  raw : StringView,
  start : Int,
  error_pos : Int,
) -> String {
  let raw = self.replace_special_text_nulls(raw, start)
  let data = if special_text_decodes_entities(name) {
    let decoded = decode_entities_with_errors(raw, in_attribute=false)
    for error in decoded.errors {
      self.error_at(error.code, error_pos)
    }
    decoded.data
  } else {
    normalize_newlines(raw)
  }
  if self.xml_coercion {
    coerce_text_for_xml(data)
  } else {
    data
  }
}

///|
fn SourceTokenizer::replace_special_text_nulls(
  self : SourceTokenizer,
  raw : StringView,
  start : Int,
) -> String {
  let out = StringBuilder::new(size_hint=raw.length())
  let mut pos = 0
  for ch in raw {
    if ch == '\u{0000}' {
      self.error_at("unexpected-null-character", start + pos)
      out.write_char('\u{FFFD}')
    } else {
      out.write_char(ch)
    }
    pos += ch.utf16_len()
  }
  out.to_string()
}

///|
fn SourceTokenizer::consume_special_text_tokens(
  self : SourceTokenizer,
  name : String,
) -> Unit {
  let content_start = self.pos
  if name == "plaintext" {
    match self.input.get_view(start=content_start, end=self.input.length()) {
      Some(view) if !view.is_empty() =>
        self.tokens.push(
          Characters(
            self.decoded_special_text(
              name,
              view,
              content_start,
              eof_error_pos(self.input),
            ),
          ),
        )
      _ => ()
    }
    self.pos = self.input.length()
    return
  }
  if name == "script" {
    let scan = scan_script_text(self.input, self.pos)
    for error in scan.errors {
      self.error_at(error.code, error.offset)
    }
    if !scan.data.is_empty() {
      let data = if self.xml_coercion {
        coerce_text_for_xml(scan.data)
      } else {
        scan.data
      }
      self.tokens.push(Characters(data))
    }
    match scan.end_start {
      Some(end_start) => {
        self.pos = end_start
        self.parse_end_tag()
      }
      None => self.pos = self.input.length()
    }
    return
  }
  match find_matching_end_tag(self.input, self.pos, name) {
    Some(end_start) => {
      let error_pos = matching_end_tag_error_pos(self.input, end_start)
      match self.input.get_view(start=content_start, end=end_start) {
        Some(view) if !view.is_empty() =>
          self.tokens.push(
            Characters(
              self.decoded_special_text(name, view, content_start, error_pos),
            ),
          )
        _ => ()
      }
      self.pos = end_start
      self.parse_end_tag()
    }
    None => {
      let error_pos = eof_error_pos(self.input)
      match self.input.get_view(start=content_start, end=self.input.length()) {
        Some(view) if !view.is_empty() =>
          self.tokens.push(
            Characters(
              self.decoded_special_text(name, view, content_start, error_pos),
            ),
          )
        _ => ()
      }
      self.pos = self.input.length()
    }
  }
}
