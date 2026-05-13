///|
/// Parse a full HTML document.
pub fn parse(
  html : StringView,
  sanitize? : Bool = false,
  collect_errors? : Bool = false,
  strict? : Bool = false,
  scripting_enabled? : Bool = true,
  xml_coercion? : Bool = false,
  track_node_locations? : Bool = false,
) -> ParsedHtml raise HtmlError {
  @p.parse(
    html,
    sanitize~,
    collect_errors~,
    strict~,
    scripting_enabled~,
    xml_coercion~,
    track_node_locations~,
  )
}

///|
/// Parse an HTML fragment.
pub fn parse_fragment(
  html : StringView,
  context? : FragmentContext,
  sanitize? : Bool = false,
  collect_errors? : Bool = false,
  strict? : Bool = false,
  scripting_enabled? : Bool = true,
  xml_coercion? : Bool = false,
  track_node_locations? : Bool = false,
) -> ParsedHtml raise HtmlError {
  match context {
    Some(context) =>
      @p.parse_fragment(
        html,
        context~,
        sanitize~,
        collect_errors~,
        strict~,
        scripting_enabled~,
        xml_coercion~,
        track_node_locations~,
      )
    None =>
      @p.parse_fragment(
        html,
        sanitize~,
        collect_errors~,
        strict~,
        scripting_enabled~,
        xml_coercion~,
        track_node_locations~,
      )
  }
}

///|
/// Decode bytes and parse a full HTML document.
pub fn parse_bytes(
  input : BytesView,
  encoding? : String,
  sanitize? : Bool = false,
  collect_errors? : Bool = false,
  strict? : Bool = false,
  scripting_enabled? : Bool = true,
  xml_coercion? : Bool = false,
  track_node_locations? : Bool = false,
) -> ParsedHtml raise HtmlError {
  match encoding {
    Some(encoding) =>
      @p.parse_bytes(
        input,
        encoding~,
        sanitize~,
        collect_errors~,
        strict~,
        scripting_enabled~,
        xml_coercion~,
        track_node_locations~,
      )
    None =>
      @p.parse_bytes(
        input,
        sanitize~,
        collect_errors~,
        strict~,
        scripting_enabled~,
        xml_coercion~,
        track_node_locations~,
      )
  }
}
