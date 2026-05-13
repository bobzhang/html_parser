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
