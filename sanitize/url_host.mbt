///|
fn url_authority_end(value : StringView, start : Int) -> Int {
  let mut pos = start
  while pos < value.length() {
    match value.get_char(pos) {
      Some('/') | Some('?') | Some('#') => return pos
      Some(ch) => pos += ch.utf16_len()
      None => break
    }
  }
  value.length()
}

///|
fn authority_host_start(value : StringView, start : Int, end : Int) -> Int {
  let mut host_start = start
  let mut pos = start
  while pos < end {
    match value.get_char(pos) {
      Some('@') => {
        pos += 1
        host_start = pos
      }
      Some(ch) => pos += ch.utf16_len()
      None => break
    }
  }
  host_start
}

///|
fn extract_authority_host(
  value : StringView,
  start : Int,
  end : Int,
) -> String? {
  let host_start = authority_host_start(value, start, end)
  if host_start >= end {
    return None
  }
  match value.get_char(host_start) {
    Some('[') => extract_bracketed_authority_host(value, host_start, end)
    Some(_) => extract_named_authority_host(value, host_start, end)
    None => None
  }
}

///|
fn extract_bracketed_authority_host(
  value : StringView,
  start : Int,
  end : Int,
) -> String? {
  let mut pos = start + 1
  while pos < end {
    match value.get_char(pos) {
      Some(']') => {
        if start + 1 >= pos {
          return None
        }
        let after_bracket = pos + 1
        if after_bracket < end && !(value.get_char(after_bracket) is Some(':')) {
          return None
        }
        let host = value[start + 1:pos]
        return Some(@syn.lower_ascii(host))
      }
      Some(ch) => pos += ch.utf16_len()
      None => return None
    }
  }
  None
}

///|
fn extract_named_authority_host(
  value : StringView,
  start : Int,
  end : Int,
) -> String? {
  let mut pos = start
  while pos < end {
    match value.get_char(pos) {
      Some(':') => {
        if start >= pos {
          return None
        }
        guard value.get_view(start~, end=pos) is Some(host) else { return None }
        return Some(@syn.lower_ascii(host))
      }
      Some('[') | Some(']') => return None
      Some(ch) => pos += ch.utf16_len()
      None => return None
    }
  }
  if start >= end {
    None
  } else {
    guard value.get_view(start~, end~) is Some(host) else { return None }
    Some(@syn.lower_ascii(host))
  }
}

///|
fn extract_absolute_url_host(value : StringView) -> String? {
  guard extract_url_scheme(value) is Some(_) else { return None }
  let mut pos = 0
  while pos < value.length() {
    let ch = value.get_char(pos).unwrap()
    match ch {
      ':' => {
        let after_colon = pos + 1
        if !(value.get_char(after_colon) is Some('/')) ||
          !(value.get_char(after_colon + 1) is Some('/')) {
          return None
        }
        let authority_start = after_colon + 2
        let authority_end = url_authority_end(value, authority_start)
        return extract_authority_host(value, authority_start, authority_end)
      }
      _ => pos += ch.utf16_len()
    }
  }
  None
}

///|
fn url_rule_allows_host(rule : UrlRule, value : String) -> Bool {
  if rule.allowed_hosts.is_empty() {
    true
  } else {
    match extract_absolute_url_host(value) {
      Some(host) => rule.allowed_hosts.contains(host)
      None => false
    }
  }
}
