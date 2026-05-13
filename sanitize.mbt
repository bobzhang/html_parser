///|
/// Return the default fragment sanitization policy.
pub fn default_sanitization_policy() -> SanitizationPolicy {
  @san.default_sanitization_policy()
}

///|
/// Return the default document sanitization policy.
pub fn default_document_sanitization_policy() -> SanitizationPolicy {
  @san.default_document_sanitization_policy()
}

///|
/// Return the conservative CSS property allowlist for text styling.
pub fn css_preset_text() -> Array[String] {
  @san.css_preset_text()
}

///|
/// Sanitize a DOM node in place and return the sanitized root.
///
/// When no policy is supplied, document roots use the document policy and other
/// roots use the fragment policy.
pub fn sanitize_dom(
  node : Node,
  policy? : SanitizationPolicy,
) -> Node raise HtmlError {
  match policy {
    Some(policy) => @san.sanitize_dom(node, policy~)
    None => @san.sanitize_dom(node)
  }
}
