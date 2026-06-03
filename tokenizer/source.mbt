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
  let tokenizer = SourceTokenizer(html, collect_errors~, xml_coercion~)
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
  let tokenizer = SourceTokenizer(html, collect_errors=false, xml_coercion~)
  while !tokenizer.is_eof() {
    tokenizer.tokens.clear()
    ignore(tokenizer.step())
    for token in tokenizer.tokens {
      emit(token)
    }
  }
}
