///|
fn UrlPolicy::apply_url_filter(
  self : UrlPolicy,
  tag_name : String,
  attr_name : String,
  value : String,
) -> String? {
  match self.url_filter {
    Some(filter) => (filter.callback)(tag_name, attr_name, value)
    None => Some(value)
  }
}

///|
fn UrlPolicy::lookup_rule(
  self : UrlPolicy,
  tag_name : String,
  attr_name : String,
) -> UrlRule? {
  self.allow_rules.get(url_policy_rule_key(tag_name, attr_name))
}

///|
fn sanitize_url_attribute_value_with_rule(
  policy : UrlPolicy,
  rule : UrlRule,
  tag_name : String,
  attr_name : String,
  value : String,
  apply_filter? : Bool = true,
) -> String? {
  let value = if apply_filter {
    match policy.apply_url_filter(tag_name, attr_name, value) {
      Some(filtered) => filtered
      None => return None
    }
  } else {
    value
  }
  let trimmed = value[:].trim().to_owned()
  if trimmed == "" {
    return None
  } else if string_contains_forbidden_url_char(trimmed) {
    return None
  } else {
    let normalized = normalize_url_for_checking(trimmed)
    let handling = rule.handling.unwrap_or(policy.default_handling)
    let allow_relative = rule.allow_relative.unwrap_or(
      policy.default_allow_relative,
    )
    if normalized.has_prefix("#") {
      if rule.allow_fragment {
        apply_url_handling(policy, rule, handling, trimmed)
      } else {
        None
      }
    } else if handling == UrlProxy && has_invalid_scheme_like_prefix(normalized) {
      None
    } else if normalized.has_prefix("//") {
      match rule.resolve_protocol_relative {
        Some(scheme) if rule.allowed_schemes.contains(scheme) => {
          let resolved = scheme + ":" + normalized
          if url_rule_allows_host(rule, resolved) {
            apply_url_handling(policy, rule, handling, resolved)
          } else {
            None
          }
        }
        _ => None
      }
    } else {
      match extract_url_scheme(normalized) {
        Some(scheme) =>
          if rule.allowed_schemes.contains(scheme) &&
            url_rule_allows_host(rule, normalized) {
            apply_url_handling(policy, rule, handling, trimmed)
          } else {
            None
          }
        None =>
          if allow_relative {
            apply_url_handling(policy, rule, handling, trimmed)
          } else {
            None
          }
      }
    }
  }
}

///|
fn sanitize_single_url_attribute_value(
  policy : SanitizationPolicy,
  tag_name : String,
  attr_name : String,
  value : String,
) -> String? {
  if tag_name == "base" && attr_name == "href" {
    None
  } else {
    match policy.url_policy.lookup_rule(tag_name, attr_name) {
      Some(rule) =>
        sanitize_url_attribute_value_with_rule(
          policy.url_policy,
          rule,
          tag_name,
          attr_name,
          value,
        )
      None => None
    }
  }
}

///|
pub fn is_srcset_like_attr(name : String) -> Bool {
  name == "srcset" || name == "imagesrcset"
}

///|
pub fn is_space_separated_url_list_attr(name : String) -> Bool {
  name == "ping" || name == "attributionsrc"
}

///|
pub fn is_single_url_like_attr(name : String) -> Bool {
  match name {
    "href"
    | "src"
    | "poster"
    | "action"
    | "formaction"
    | "data"
    | "cite"
    | "background" => true
    _ => false
  }
}

///|
pub fn is_foreign_url_function_like_attr(name : String) -> Bool {
  match name {
    "clip-path"
    | "cursor"
    | "filter"
    | "fill"
    | "marker-end"
    | "marker-mid"
    | "marker-start"
    | "mask"
    | "stroke" => true
    _ => false
  }
}
