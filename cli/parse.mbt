///|
fn cli_parse_document(
  input : BytesView,
  options : CliOptions,
) -> @p.ParsedHtml raise @core.HtmlError {
  if options.fragment {
    let (decoded, _) = @enc.decode_html_bytes(input, None)
    @p.parse_fragment(
      decoded,
      context=FragmentContext("div"),
      sanitize=false,
      strict=options.strict,
    )
  } else {
    @p.parse_bytes(input, sanitize=false, strict=options.strict)
  }
}
