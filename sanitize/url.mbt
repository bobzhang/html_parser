///|
fn is_ascii_url_boundary(ch : Char) -> Bool {
  ch == '/' || ch == '?' || ch == '#'
}

///|
fn is_url_scheme_start(ch : Char) -> Bool {
  ch.is_ascii_alphabetic()
}

///|
fn is_url_scheme_char(ch : Char) -> Bool {
  ch.is_ascii_alphabetic() ||
  (ch >= '0' && ch <= '9') ||
  ch == '+' ||
  ch == '-' ||
  ch == '.'
}

///|
fn is_url_ignored_scheme_char(ch : Char) -> Bool {
  let code = ch.to_int()
  code <= 0x20 || code == 0x7F
}

///|
fn string_contains_forbidden_url_char(value : StringView) -> Bool {
  for ch in value {
    let code = ch.to_int()
    if code < 0x20 || code == 0x7F || ch == '\\' {
      return true
    }
  }
  false
}

///|
fn normalize_url_for_checking(value : StringView) -> String {
  let out = StringBuilder::new(size_hint=value.length())
  for ch in value {
    if !is_url_ignored_scheme_char(ch) {
      out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn extract_url_scheme(value : StringView) -> String? {
  let out = StringBuilder::new()
  let mut pos = 0
  let mut saw_scheme_char = false
  while pos < value.length() {
    let ch = value.get_char(pos).unwrap()
    if is_ascii_url_boundary(ch) {
      return None
    } else if ch == ':' {
      if saw_scheme_char {
        return Some(out.to_string())
      } else {
        return None
      }
    } else if is_url_ignored_scheme_char(ch) {
      pos += ch.utf16_len()
    } else {
      if !saw_scheme_char {
        if !is_url_scheme_start(ch) {
          return None
        }
        saw_scheme_char = true
      } else if !is_url_scheme_char(ch) {
        return None
      }
      if ch.is_ascii_uppercase() {
        out.write_char(ch.to_ascii_lowercase())
      } else {
        out.write_char(ch)
      }
      pos += ch.utf16_len()
    }
  }
  None
}

///|
fn url_scheme_prefix_is_valid(value : StringView, end : Int) -> Bool {
  let mut pos = 0
  let mut saw_scheme_char = false
  while pos < end {
    let ch = value.get_char(pos).unwrap()
    if is_url_ignored_scheme_char(ch) {
      pos += ch.utf16_len()
    } else {
      if !saw_scheme_char {
        if !is_url_scheme_start(ch) {
          return false
        }
        saw_scheme_char = true
      } else if !is_url_scheme_char(ch) {
        return false
      }
      pos += ch.utf16_len()
    }
  }
  saw_scheme_char
}

///|
fn has_invalid_scheme_like_prefix(value : StringView) -> Bool {
  let mut pos = 0
  while pos < value.length() {
    let ch = value.get_char(pos).unwrap()
    match ch {
      ':' =>
        if pos == 0 {
          return false
        } else {
          return !url_scheme_prefix_is_valid(value, pos)
        }
      _ if is_ascii_url_boundary(ch) => return false
      _ => pos += ch.utf16_len()
    }
  }
  false
}

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
