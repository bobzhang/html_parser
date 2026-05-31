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
  let result = @impl.tokenize(html, collect_errors~, xml_coercion~)
  { tokens: result.tokens.map(internal_token_to_public), errors: result.errors }
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
  @impl.tokenize_each(
    html,
    token => emit(internal_token_to_public(token)),
    xml_coercion~,
  )
}

///|
pub using @impl {decode_entities}

///|
fn internal_kind_to_public(kind : @impl.TagKind) -> TagKind {
  match kind {
    StartTag => StartTag
    EndTag => EndTag
  }
}

///|
fn internal_tag_to_public(tag : @impl.TagToken) -> TagToken {
  {
    kind: internal_kind_to_public(tag.kind),
    name: tag.name,
    attrs: tag.attrs,
    self_closing: tag.self_closing,
  }
}

///|
fn internal_doctype_to_public(info : @impl.DoctypeInfo) -> DoctypeInfo {
  {
    name: info.name,
    public_id: info.public_id,
    system_id: info.system_id,
    force_quirks: info.force_quirks,
  }
}

///|
fn internal_token_to_public(token : @impl.HtmlToken) -> HtmlToken {
  match token {
    Tag(tag) => Tag(internal_tag_to_public(tag))
    Characters(data) => Characters(data)
    CommentToken(data) => CommentToken(data)
    DoctypeToken(info) => DoctypeToken(internal_doctype_to_public(info))
    Eof => Eof
  }
}
