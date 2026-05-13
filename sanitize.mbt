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

///|
fn sanitize_dom_with_observer(
  node : Node,
  policy : SanitizationPolicy?,
  observer : SanitizeTransformObserver?,
) -> Node raise HtmlError {
  @san.sanitize_dom_with_observer(node, policy, observer)
}

///|
fn escaped_end_tag_for(node : Node) -> String? {
  @san.escaped_end_tag_for(node)
}

///|
fn remove_child_at(parent : Node, index : Int) -> Unit {
  @san.remove_child_at(parent, index)
}

///|
fn unwrap_child_at(parent : Node, index : Int) -> Int {
  @san.unwrap_child_at(parent, index)
}

///|
fn push_unique_string(values : Array[String], value : String) -> Unit {
  @san.push_unique_string(values, value)
}

///|
fn push_html_whitespace_tokens(
  tokens : Array[String],
  value : StringView,
) -> Unit {
  @san.push_html_whitespace_tokens(tokens, value)
}

///|
fn css_value_may_load_external_resource(value : StringView) -> Bool {
  @san.css_value_may_load_external_resource(value)
}

///|
fn is_single_url_like_attr(name : String) -> Bool {
  @san.is_single_url_like_attr(name)
}

///|
fn is_srcset_like_attr(name : String) -> Bool {
  @san.is_srcset_like_attr(name)
}

///|
fn is_space_separated_url_list_attr(name : String) -> Bool {
  @san.is_space_separated_url_list_attr(name)
}

///|
fn is_foreign_url_function_like_attr(name : String) -> Bool {
  @san.is_foreign_url_function_like_attr(name)
}

///|
fn node_is_effectively_foreign(node : Node) -> Bool {
  @san.node_is_effectively_foreign(node)
}
