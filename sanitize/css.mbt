///|
fn is_valid_css_property_name(name : StringView) -> Bool {
  if name.is_empty() {
    return false
  }
  for ch in name {
    if ch.is_ascii_alphabetic() || (ch >= '0' && ch <= '9') || ch == '-' {
      continue
    }
    return false
  }
  true
}

///|
fn css_safety_normalize(value : StringView) -> String? {
  let out = StringBuilder::new(size_hint=value.length())
  let mut pos = 0
  while pos < value.length() {
    let ch = value.get_char(pos).unwrap()
    match ch {
      '\\' => return None
      '/' if value.get_char(pos + 1) is Some('*') => {
        pos += 2
        let mut closed = false
        while pos < value.length() {
          if value.get_char(pos) is Some('*') &&
            value.get_char(pos + 1) is Some('/') {
            pos += 2
            closed = true
            break
          }
          let ch = value.get_char(pos).unwrap()
          pos += ch.utf16_len()
        }
        if !closed {
          return None
        }
      }
      _ if is_url_ignored_scheme_char(ch) => pos += ch.utf16_len()
      _ => {
        if ch.is_ascii_uppercase() {
          out.write_char(ch.to_ascii_lowercase())
        } else {
          out.write_char(ch)
        }
        pos += ch.utf16_len()
      }
    }
  }
  Some(out.to_string())
}

///|
pub fn css_value_may_load_external_resource(value : StringView) -> Bool {
  match css_safety_normalize(value) {
    None => true
    Some(normalized) =>
      string_view_contains(normalized, "@import") ||
      string_view_contains(normalized, "url(") ||
      string_view_contains(normalized, "image-set(") ||
      string_view_contains(normalized, "expression(") ||
      string_view_contains(normalized, "progid:") ||
      string_view_contains(normalized, "alphaimageloader") ||
      string_view_contains(normalized, "behavior:") ||
      string_view_contains(normalized, "-moz-binding")
  }
}

///|
fn css_value_has_disallowed_resource_functions(value : StringView) -> Bool {
  match css_safety_normalize(value) {
    None => true
    Some(normalized) =>
      string_view_contains(normalized, "@import") ||
      string_view_contains(normalized, "image-set(") ||
      string_view_contains(normalized, "expression(") ||
      string_view_contains(normalized, "progid:") ||
      string_view_contains(normalized, "alphaimageloader") ||
      string_view_contains(normalized, "behavior:") ||
      string_view_contains(normalized, "-moz-binding")
  }
}

///|
fn UrlPolicy::lookup_css_rule(
  self : UrlPolicy,
  tag_name : String,
  prop : String,
) -> UrlRule? {
  let key = "style:" + prop
  match self.lookup_rule(tag_name, key) {
    Some(rule) => Some(rule)
    None => self.lookup_rule("*", key)
  }
}

///|
fn css_url_skip_whitespace(value : StringView, start : Int) -> Int {
  let mut pos = start
  while pos < value.length() {
    match value.get_char(pos) {
      Some(ch) if is_url_ignored_scheme_char(ch) => pos += ch.utf16_len()
      _ => return pos
    }
  }
  pos
}

///|
fn css_find_char(value : StringView, start : Int, needle : Char) -> Int? {
  let mut pos = start
  while pos < value.length() {
    let ch = value.get_char(pos).unwrap()
    if ch == needle {
      return Some(pos)
    } else {
      pos += ch.utf16_len()
    }
  }
  None
}

///|
fn css_next_url_function(value : StringView, start : Int) -> Int? {
  let mut pos = start
  while pos < value.length() {
    if @syn.starts_with_case_insensitive(value, pos, "url(") {
      return Some(pos)
    }
    let ch = value.get_char(pos).unwrap()
    pos += ch.utf16_len()
  }
  None
}

///|
fn css_url_value_is_safe_to_quote(value : StringView) -> Bool {
  for ch in value {
    let code = ch.to_int()
    if code <= 0x20 ||
      code == 0x7F ||
      ch == '\'' ||
      ch == '"' ||
      ch == '(' ||
      ch == ')' ||
      ch == '\\' {
      return false
    }
  }
  true
}

///|
fn write_string_view(out : StringBuilder, value : StringView) -> Unit {
  for ch in value {
    out.write_char(ch)
  }
}

///|
fn sanitize_css_url_functions(
  policy : SanitizationPolicy,
  tag_name : String,
  prop : String,
  value : StringView,
) -> String? {
  guard policy.url_policy.lookup_css_rule(tag_name, prop) is Some(rule) else {
    return None
  }
  let attr_name = "style:" + prop
  sanitize_url_function_value(
    policy.url_policy,
    rule,
    tag_name,
    attr_name,
    value,
  )
}

///|
fn sanitize_url_function_value(
  url_policy : UrlPolicy,
  rule : UrlRule,
  tag_name : String,
  attr_name : String,
  value : StringView,
) -> String? {
  if css_value_has_disallowed_resource_functions(value) ||
    string_view_contains(value, "/*") {
    return None
  }
  let out = StringBuilder::new(size_hint=value.length())
  let mut pos = 0
  let mut replaced_any = false
  while true {
    match css_next_url_function(value, pos) {
      Some(url_start) => {
        let prefix = value[pos:url_start]
        write_string_view(out, prefix)
        let mut cursor = css_url_skip_whitespace(value, url_start + 4)
        guard value.get_char(cursor) is Some(first) else { return None }
        let url_raw = match first {
          '\'' | '"' => {
            let quote = first
            cursor += quote.utf16_len()
            let url_start = cursor
            guard css_find_char(value, cursor, quote) is Some(url_end) else {
              return None
            }
            cursor = css_url_skip_whitespace(value, url_end + quote.utf16_len())
            if !(value.get_char(cursor) is Some(')')) {
              return None
            }
            value[url_start:url_end]
          }
          _ => {
            let url_start = cursor
            guard css_find_char(value, cursor, ')') is Some(url_end) else {
              return None
            }
            cursor = url_end
            let raw = value[url_start:url_end].trim()
            if raw.is_empty() || string_contains_forbidden_url_char(raw) {
              return None
            }
            raw
          }
        }
        let after_paren = cursor + 1
        if after_paren < value.length() {
          match value.get_char(after_paren) {
            Some(ch) if is_url_ignored_scheme_char(ch) || ch == ',' || ch == '/' =>
              ()
            _ => return None
          }
        }
        match
          sanitize_url_attribute_value_with_rule(
            url_policy,
            rule,
            tag_name,
            attr_name,
            url_raw.to_owned(),
          ) {
          Some(sanitized_url) if css_url_value_is_safe_to_quote(sanitized_url) => {
            out.write_string("url('")
            out.write_string(sanitized_url)
            out.write_string("')")
          }
          _ => return None
        }
        replaced_any = true
        pos = after_paren
      }
      None => {
        let rest = value[pos:value.length()]
        write_string_view(out, rest)
        break
      }
    }
  }
  if replaced_any {
    Some(out.to_string())
  } else {
    None
  }
}

///|
fn sanitize_foreign_url_function_attribute_value(
  policy : SanitizationPolicy,
  tag_name : String,
  attr_name : String,
  value : String,
) -> String? {
  match policy.url_policy.lookup_rule(tag_name, attr_name) {
    Some(rule) =>
      sanitize_url_function_value(
        policy.url_policy,
        rule,
        tag_name,
        attr_name,
        value,
      )
    None => None
  }
}

///|
fn style_declaration_colon(declaration : StringView) -> Int? {
  let mut pos = 0
  while pos < declaration.length() {
    let ch = declaration.get_char(pos).unwrap()
    if ch == ':' {
      return Some(pos)
    } else {
      pos += ch.utf16_len()
    }
  }
  None
}

///|
fn sanitize_style_declaration(
  declaration : StringView,
  policy : SanitizationPolicy,
  tag_name : String,
) -> String? {
  let declaration = declaration.trim()
  if declaration.is_empty() {
    return None
  }
  guard style_declaration_colon(declaration) is Some(colon) else { return None }
  let prop_view = declaration[0:colon]
  let prop = @syn.lower_ascii(prop_view.trim())
  if !is_valid_css_property_name(prop) ||
    !policy.allowed_css_properties.contains(prop) {
    return None
  }
  let value_view = declaration[colon + 1:declaration.length()]
  let value = value_view.trim()
  if value.is_empty() {
    return None
  }
  if css_value_may_load_external_resource(value) {
    match sanitize_css_url_functions(policy, tag_name, prop, value) {
      Some(sanitized) => Some(prop + ": " + sanitized)
      None => None
    }
  } else {
    Some(prop + ": " + value.to_owned())
  }
}

///|
fn sanitize_inline_style_value(
  policy : SanitizationPolicy,
  tag_name : String,
  value : String,
) -> String? {
  if policy.allowed_css_properties.is_empty() || value == "" {
    return None
  }
  let view = value[:]
  let parts : Array[String] = []
  let mut start = 0
  let mut pos = 0
  while pos < view.length() {
    let ch = view.get_char(pos).unwrap()
    if ch == ';' {
      let declaration = view[start:pos]
      match sanitize_style_declaration(declaration, policy, tag_name) {
        Some(part) => parts.push(part)
        None => ()
      }
      pos += 1
      start = pos
    } else {
      pos += ch.utf16_len()
    }
  }
  let declaration = view[start:view.length()]
  match sanitize_style_declaration(declaration, policy, tag_name) {
    Some(part) => parts.push(part)
    None => ()
  }
  if parts.is_empty() {
    None
  } else {
    Some(parts.join("; "))
  }
}
