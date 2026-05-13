///|
fn split_srcset_candidate(candidate : StringView) -> (StringView, StringView) {
  let mut pos = 0
  while pos < candidate.length() {
    let ch = candidate.get_char(pos).unwrap()
    if is_html_whitespace_char(ch) {
      let url = candidate[0:pos]
      let descriptor = candidate[pos:candidate.length()].trim()
      return (url, descriptor)
    } else {
      pos += ch.utf16_len()
    }
  }
  (candidate, "")
}

///|
fn push_sanitized_srcset_candidate(
  out : Array[String],
  url_policy : UrlPolicy,
  rule : UrlRule,
  tag_name : String,
  attr_name : String,
  candidate : StringView,
) -> Bool {
  let candidate = candidate.trim()
  if candidate.is_empty() {
    return true
  }
  let (url_token, descriptor) = split_srcset_candidate(candidate)
  match
    sanitize_url_attribute_value_with_rule(
      url_policy,
      rule,
      tag_name,
      attr_name,
      url_token.to_owned(),
      apply_filter=false,
    ) {
    Some(cleaned_url) => {
      if descriptor.is_empty() {
        out.push(cleaned_url)
      } else {
        out.push(cleaned_url + " " + descriptor.to_owned())
      }
      true
    }
    None => false
  }
}

///|
fn sanitize_srcset_attribute_value(
  policy : SanitizationPolicy,
  tag_name : String,
  attr_name : String,
  value : String,
) -> String? {
  guard policy.url_policy.lookup_rule(tag_name, attr_name) is Some(rule) else {
    return None
  }
  let value = match
    policy.url_policy.apply_url_filter(tag_name, attr_name, value) {
    Some(filtered) => filtered
    None => return None
  }
  let view = value[:].trim()
  if view.is_empty() {
    return None
  }
  let out : Array[String] = []
  let mut start = 0
  let mut pos = 0
  while pos < view.length() {
    let ch = view.get_char(pos).unwrap()
    if ch == ',' {
      let candidate = view[start:pos]
      if !push_sanitized_srcset_candidate(
          out,
          policy.url_policy,
          rule,
          tag_name,
          attr_name,
          candidate,
        ) {
        return None
      }
      pos += 1
      start = pos
    } else {
      pos += ch.utf16_len()
    }
  }
  let candidate = view[start:view.length()]
  if !push_sanitized_srcset_candidate(
      out,
      policy.url_policy,
      rule,
      tag_name,
      attr_name,
      candidate,
    ) {
    return None
  }
  if out.is_empty() {
    None
  } else {
    Some(out.join(", "))
  }
}

///|
fn push_sanitized_url_list_token(
  out : Array[String],
  url_policy : UrlPolicy,
  rule : UrlRule,
  tag_name : String,
  attr_name : String,
  token : StringView,
) -> Bool {
  let token = token.trim()
  if token.is_empty() {
    return true
  }
  match
    sanitize_url_attribute_value_with_rule(
      url_policy,
      rule,
      tag_name,
      attr_name,
      token.to_owned(),
      apply_filter=false,
    ) {
    Some(cleaned) => {
      out.push(cleaned)
      true
    }
    None => false
  }
}

///|
fn sanitize_space_separated_url_list_attribute_value(
  policy : SanitizationPolicy,
  tag_name : String,
  attr_name : String,
  value : String,
) -> String? {
  guard policy.url_policy.lookup_rule(tag_name, attr_name) is Some(rule) else {
    return None
  }
  let value = match
    policy.url_policy.apply_url_filter(tag_name, attr_name, value) {
    Some(filtered) => filtered
    None => return None
  }
  let view = value[:].trim()
  if view.is_empty() {
    return None
  }
  let out : Array[String] = []
  let mut start = 0
  let mut pos = 0
  while pos < view.length() {
    let ch = view.get_char(pos).unwrap()
    if is_html_whitespace_char(ch) {
      let token = view[start:pos]
      if !push_sanitized_url_list_token(
          out,
          policy.url_policy,
          rule,
          tag_name,
          attr_name,
          token,
        ) {
        return None
      }
      pos += ch.utf16_len()
      start = pos
    } else {
      pos += ch.utf16_len()
    }
  }
  let token = view[start:view.length()]
  if !push_sanitized_url_list_token(
      out,
      policy.url_policy,
      rule,
      tag_name,
      attr_name,
      token,
    ) {
    return None
  }
  if out.is_empty() {
    None
  } else {
    Some(out.join(" "))
  }
}
