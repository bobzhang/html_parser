///|
/// Parse a full HTML document from a string.
///
/// The returned root is a document node with the usual `html`, `head`, and
/// `body` scaffolding. Set `sanitize=true` to apply the default document
/// sanitizer after parsing, `collect_errors=true` to keep parse diagnostics, and
/// `strict=true` to raise `@core.HtmlError::StrictMode` on the first parse error.
pub fn parse(
  html : StringView,
  sanitize? : Bool = false,
  collect_errors? : Bool = false,
  strict? : Bool = false,
  scripting_enabled? : Bool = true,
  xml_coercion? : Bool = false,
  track_node_locations? : Bool = false,
) -> ParsedHtml raise @core.HtmlError {
  let root = @dom.document()
  let parser = Parser::new(
    html,
    root,
    scripting_enabled~,
    xml_coercion~,
    collect_errors=collect_errors || strict,
    track_node_locations~,
  )
  parser.deferred_initial_doctype_error = parser.report_initial_doctype_error()
  parser.parse_all()
  parser.flush_deferred_initial_doctype_error()
  parser.report_eof_tree_errors()
  scaffold_document(root)
  parser.apply_pending_document_html_attrs()
  append_post_body_html_children(root, parser.post_body_html_children)
  normalize_tables(root)
  populate_selectedcontent(root)
  let errors = if collect_errors || strict { parser.errors } else { [] }
  if strict && !parser.errors.is_empty() {
    raise StrictMode(parser.errors[0])
  }
  if sanitize {
    ignore(@san.sanitize_dom(root))
  }
  { root, errors, encoding: None }
}

///|
/// Parse an HTML fragment from a string.
///
/// `context` controls the fragment context element used by the tree builder.
/// Without a context, the fragment is parsed into a generic fragment root.
/// `sanitize`, `collect_errors`, `strict`, `scripting_enabled`, `xml_coercion`,
/// and `track_node_locations` have the same meaning as in `parse`.
pub fn parse_fragment(
  html : StringView,
  context? : FragmentContext,
  sanitize? : Bool = false,
  collect_errors? : Bool = false,
  strict? : Bool = false,
  scripting_enabled? : Bool = true,
  xml_coercion? : Bool = false,
  track_node_locations? : Bool = false,
) -> ParsedHtml raise @core.HtmlError {
  let root = @dom.fragment()
  let parser = Parser::new(
    html,
    root,
    scripting_enabled~,
    xml_coercion~,
    collect_errors=collect_errors || strict,
    track_node_locations~,
  )
  match context {
    Some(fragment_context) =>
      if !parser.parse_fragment_context(fragment_context) {
        parser.parse_all()
      }
    None => parser.parse_all()
  }
  parser.report_eof_tree_errors()
  normalize_tables(root)
  populate_selectedcontent(root)
  let errors = if collect_errors || strict { parser.errors } else { [] }
  if strict && !parser.errors.is_empty() {
    raise StrictMode(parser.errors[0])
  }
  if sanitize {
    ignore(@san.sanitize_dom(root))
  }
  { root, errors, encoding: None }
}

///|
/// Decode and parse an HTML byte stream.
///
/// When `encoding` is absent, BOMs and `<meta charset>` declarations are
/// sniffed before falling back to Windows-1252. The detected or requested
/// encoding is stored in `ParsedHtml.encoding`.
pub fn parse_bytes(
  input : BytesView,
  encoding? : String,
  sanitize? : Bool = false,
  collect_errors? : Bool = false,
  strict? : Bool = false,
  scripting_enabled? : Bool = true,
  xml_coercion? : Bool = false,
  track_node_locations? : Bool = false,
) -> ParsedHtml raise @core.HtmlError {
  let (decoded, detected_encoding) = @enc.decode_html_bytes(input, encoding)
  let parsed = parse(
    decoded,
    sanitize~,
    collect_errors~,
    strict~,
    scripting_enabled~,
    xml_coercion~,
    track_node_locations~,
  )
  {
    root: parsed.root,
    errors: parsed.errors,
    encoding: Some(detected_encoding),
  }
}

///|
/// Serialize the parsed root node back to HTML.
///
/// This forwards to `to_html` on `self.root`.
pub fn ParsedHtml::to_html(
  self : ParsedHtml,
  pretty? : Bool = true,
  indent_size? : Int = 2,
  context? : @ser.HtmlContext = Html,
  quote? : Char = '"',
) -> String raise @core.HtmlError {
  @ser.to_html(self.root, pretty~, indent_size~, context~, quote~)
}

///|
/// Extract text from the parsed root node.
///
/// This forwards to `to_text` on `self.root`.
pub fn ParsedHtml::to_text(
  self : ParsedHtml,
  separator? : String = " ",
  strip? : Bool = true,
  separator_blocks_only? : Bool = false,
) -> String {
  @ser.to_text(self.root, separator~, strip~, separator_blocks_only~)
}

///|
/// Render the parsed document or fragment root as Markdown.
///
/// This is equivalent to calling `to_markdown` on `self.root`.
pub fn ParsedHtml::to_markdown(
  self : ParsedHtml,
  html_passthrough? : Bool = false,
) -> String raise @core.HtmlError {
  @md.to_markdown(self.root, html_passthrough~)
}

///|
/// Return all descendants of the parsed root that match a CSS selector.
pub fn ParsedHtml::query(
  self : ParsedHtml,
  selector : StringView,
) -> Array[@dom.Node] {
  @sel.query(self.root, selector)
}

///|
/// Return the first descendant of the parsed root that matches a CSS selector.
pub fn ParsedHtml::query_one(
  self : ParsedHtml,
  selector : StringView,
) -> @dom.Node? {
  @sel.query_one(self.root, selector)
}
