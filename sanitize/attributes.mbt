///|
fn attr_name_is_dangerous(name : StringView) -> Bool {
  let normalized = @syn.lower_ascii(name)
  normalized.has_prefix("on") ||
  normalized == "srcdoc" ||
  @ser.string_contains_char(normalized, ':')
}

///|
fn policy_allows_attribute(
  policy : SanitizationPolicy,
  tag_name : String,
  attr_name : String,
) -> Bool {
  if attr_name_is_dangerous(attr_name) {
    return false
  }
  if tag_name == "a" && attr_name == "rel" && !policy.force_link_rel.is_empty() {
    return true
  }
  match policy.allowed_attributes.get(tag_name) {
    Some(attrs) if attrs.contains(attr_name) => true
    _ =>
      match policy.allowed_attributes.get("*") {
        Some(attrs) => attrs.contains(attr_name)
        None => false
      }
  }
}

///|
fn sanitize_attribute_value(
  policy : SanitizationPolicy,
  tag_name : String,
  attr_name : String,
  value : String,
  effectively_foreign? : Bool = false,
) -> String? {
  if effectively_foreign &&
    is_foreign_url_function_like_attr(attr_name) &&
    css_value_may_load_external_resource(value) {
    sanitize_foreign_url_function_attribute_value(
      policy, tag_name, attr_name, value,
    )
  } else if is_srcset_like_attr(attr_name) {
    sanitize_srcset_attribute_value(policy, tag_name, attr_name, value)
  } else if is_space_separated_url_list_attr(attr_name) {
    sanitize_space_separated_url_list_attribute_value(
      policy, tag_name, attr_name, value,
    )
  } else if is_single_url_like_attr(attr_name) {
    sanitize_single_url_attribute_value(policy, tag_name, attr_name, value)
  } else if attr_name == "style" {
    sanitize_inline_style_value(policy, tag_name, value)
  } else {
    Some(value)
  }
}

///|
/// Sanitize a single attribute value with this policy.
///
/// `tag_name` and `attr_name` should already be normalized to lowercase. URL
/// attributes, URL lists, foreign SVG-like URL function attributes, and inline
/// style values are validated through the policy. Returns `None` when the
/// attribute value should be dropped.
pub fn SanitizationPolicy::sanitize_attribute_value(
  self : SanitizationPolicy,
  tag_name : String,
  attr_name : String,
  value : String,
  effectively_foreign? : Bool = false,
) -> String? {
  sanitize_attribute_value(
    self,
    tag_name,
    attr_name,
    value,
    effectively_foreign~,
  )
}

///|
/// Sanitize the value of an inline `style` attribute.
///
/// Only declarations whose property names are in `allowed_css_properties` are
/// kept. Declarations that may load external resources are kept only when their
/// `url(...)` values pass the policy's URL rules. Returns `None` when no safe
/// declaration remains.
pub fn SanitizationPolicy::sanitize_inline_style_value(
  self : SanitizationPolicy,
  tag_name : String,
  value : String,
) -> String? {
  sanitize_inline_style_value(self, tag_name, value)
}

///|
/// Split HTML whitespace-separated tokens into a unique normalized list.
///
/// Tokens are trimmed, ASCII-lowercased, and appended to `tokens` only when
/// non-empty and not already present. Existing token order is preserved.
pub fn push_html_whitespace_tokens(
  tokens : Array[String],
  value : StringView,
) -> Unit {
  let mut token_start = 0
  let mut pos = 0
  while pos < value.length() {
    let ch = value.get_char(pos).unwrap()
    if is_html_whitespace_char(ch) {
      if token_start < pos {
        let token = value[token_start:pos]
        push_unique_string(tokens, @syn.lower_ascii(token.trim()))
      }
      pos += ch.utf16_len()
      token_start = pos
    } else {
      pos += ch.utf16_len()
    }
  }
  if token_start < value.length() {
    let token = value[token_start:value.length()]
    push_unique_string(tokens, @syn.lower_ascii(token.trim()))
  }
}

///|
fn merge_forced_link_rel(
  node : @dom.Node,
  policy : SanitizationPolicy,
  observer : SanitizeTransformObserver?,
) -> Unit {
  if policy.force_link_rel.is_empty() {
    return
  }
  let tokens : Array[String] = []
  match node.attrs.get("rel") {
    Some(Some(value)) => push_html_whitespace_tokens(tokens, value)
    _ => ()
  }
  for token in policy.force_link_rel {
    push_unique_string(tokens, token)
  }
  let normalized = tokens.join(" ")
  if node.attrs.get("rel") != Some(Some(normalized)) {
    sanitize_observer_event(
      observer,
      "Merged tokens into attribute 'rel' on <a>",
      Some(node),
    )
  }
  node.attrs["rel"] = Some(normalized)
}

///|
fn sanitize_meta_refresh_content(
  node : @dom.Node,
  policy : SanitizationPolicy,
  observer : SanitizeTransformObserver?,
) -> Unit raise @core.HtmlError {
  match node.attrs.get("http-equiv") {
    Some(Some(value)) if @syn.lower_ascii(value[:].trim()) == "refresh" &&
      node.attrs.contains("content") => {
      sanitize_report_unsafe(
        policy,
        observer,
        "Unsafe URL in attribute 'content' (meta refresh)",
        Some(node),
      )
      node.attrs.remove("content")
    }
    _ => ()
  }
}

///|
fn sanitize_forbidden_attr_pattern(attr_name : String) -> String? {
  if attr_name == "srcdoc" {
    Some("srcdoc")
  } else if @ser.string_contains_char(attr_name, ':') {
    Some("*:*")
  } else if attr_name.has_prefix("on") {
    Some("on*")
  } else {
    None
  }
}

///|
fn sanitize_url_like_attr_for_report(
  attr_name : String,
  raw_value : String?,
  effectively_foreign : Bool,
) -> Bool {
  let foreign_url_function_loads = match raw_value {
    Some(value) => css_value_may_load_external_resource(value)
    None => false
  }
  is_single_url_like_attr(attr_name) ||
  is_srcset_like_attr(attr_name) ||
  is_space_separated_url_list_attr(attr_name) ||
  (
    effectively_foreign &&
    is_foreign_url_function_like_attr(attr_name) &&
    foreign_url_function_loads
  )
}

///|
fn sanitize_dropped_attr_report_message(
  policy : SanitizationPolicy,
  tag_name : String,
  attr_name : String,
  raw_value : String?,
  effectively_foreign : Bool,
) -> String {
  if attr_name == "style" {
    "Unsafe inline style in attribute 'style'"
  } else if tag_name == "base" && attr_name == "href" {
    "Unsafe URL in attribute 'href' (base tag)"
  } else if sanitize_url_like_attr_for_report(
      attr_name, raw_value, effectively_foreign,
    ) {
    let suffix = match raw_value {
      Some(_) =>
        match policy.url_policy.lookup_rule(tag_name, attr_name) {
          None => " (no rule)"
          Some(_) => ""
        }
      None => ""
    }
    "Unsafe URL in attribute '" + attr_name + "'" + suffix
  } else {
    "Unsafe attribute '" + attr_name + "' on <" + tag_name + "> was dropped"
  }
}

///|
fn sanitize_element_attributes(
  node : @dom.Node,
  policy : SanitizationPolicy,
  observer : SanitizeTransformObserver?,
) -> Unit raise @core.HtmlError {
  let tag_name = sanitize_node_name(node)
  let effectively_foreign = node_is_effectively_foreign(node)
  if policy.strip_invisible_unicode {
    let stripped_attr_names : Array[String] = []
    for key in node.attrs.keys() {
      match node.attrs.get(key).unwrap() {
        Some(raw_value) => {
          let stripped = strip_invisible_unicode(raw_value)
          if stripped != raw_value {
            node.attrs[key] = Some(stripped)
            stripped_attr_names.push(key)
          }
        }
        _ => ()
      }
    }
    if !stripped_attr_names.is_empty() {
      sanitize_report_unsafe(
        policy,
        observer,
        "Stripped invisible Unicode from attribute(s): " +
        stripped_attr_names.join(", "),
        Some(node),
      )
    }
  }
  let keys = node.attrs.keys().to_array()
  for key in keys {
    let attr_name = @syn.lower_ascii(key)
    match sanitize_forbidden_attr_pattern(attr_name) {
      Some(pattern) => {
        sanitize_report_unsafe(
          policy,
          observer,
          "Unsafe attribute '" +
          attr_name +
          "' (matched forbidden pattern '" +
          pattern +
          "')",
          Some(node),
        )
        node.attrs.remove(key)
        continue
      }
      None => ()
    }
    if !policy_allows_attribute(policy, tag_name, attr_name) {
      sanitize_report_unsafe(
        policy,
        observer,
        "Unsafe attribute '" + attr_name + "' (not allowed)",
        Some(node),
      )
      node.attrs.remove(key)
    } else {
      match node.attrs.get(key).unwrap() {
        Some(raw_value) => {
          let value = raw_value
          match
            sanitize_attribute_value(
              policy,
              tag_name,
              attr_name,
              value,
              effectively_foreign~,
            ) {
            Some(cleaned) =>
              if cleaned != raw_value || attr_name != key {
                node.attrs.remove(key)
                node.attrs[attr_name] = Some(cleaned)
              }
            None => {
              sanitize_report_unsafe(
                policy,
                observer,
                sanitize_dropped_attr_report_message(
                  policy,
                  tag_name,
                  attr_name,
                  Some(raw_value),
                  effectively_foreign,
                ),
                Some(node),
              )
              node.attrs.remove(key)
            }
          }
        }
        None if attr_name == "href" ||
          attr_name == "src" ||
          attr_name == "style" ||
          is_single_url_like_attr(attr_name) ||
          is_srcset_like_attr(attr_name) ||
          is_space_separated_url_list_attr(attr_name) => {
          sanitize_report_unsafe(
            policy,
            observer,
            sanitize_dropped_attr_report_message(
              policy,
              tag_name,
              attr_name,
              None,
              effectively_foreign,
            ),
            Some(node),
          )
          node.attrs.remove(key)
        }
        value =>
          if attr_name != key {
            node.attrs.remove(key)
            node.attrs[attr_name] = value
          }
      }
    }
  }
  if tag_name == "meta" {
    sanitize_meta_refresh_content(node, policy, observer)
  }
  if tag_name == "a" {
    merge_forced_link_rel(node, policy, observer)
  }
}
