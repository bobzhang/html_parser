///|
fn linkify_host_view(value : StringView) -> StringView? {
  let mut pos = 0
  for ch in value {
    match ch {
      '/' | '?' | '#' => return value.get_view(start=0, end=pos)
      _ => pos += ch.utf16_len()
    }
  }
  value.get_view(start=0, end=value.length())
}

///|
fn linkify_host_without_userinfo_port(hostport : StringView) -> StringView {
  let host = linkify_strip_userinfo(hostport)
  linkify_split_host_port(host).0
}

///|
fn linkify_strip_userinfo(hostport : StringView) -> StringView {
  match linkify_last_char_index(hostport, '@') {
    Some(at) => hostport[at + 1:hostport.length()]
    None => hostport
  }
}

///|
fn linkify_split_host_port(hostport : StringView) -> (StringView, String) {
  if hostport.has_prefix("[") {
    return (hostport, "")
  }
  match linkify_last_char_index(hostport, ':') {
    Some(colon) =>
      (hostport[0:colon], hostport[colon + 1:hostport.length()].to_owned())
    None => (hostport, "")
  }
}

///|
fn linkify_after_url_scheme(candidate : StringView) -> StringView? {
  let start = if @syn.starts_with_case_insensitive(candidate, 0, "http://") {
    7
  } else if @syn.starts_with_case_insensitive(candidate, 0, "https://") {
    8
  } else if @syn.starts_with_case_insensitive(candidate, 0, "ftp://") {
    6
  } else {
    return None
  }
  candidate.get_view(start~, end=candidate.length())
}

///|
fn linkify_valid_ipv4(host : StringView) -> Bool {
  let mut parts = 0
  let mut pos = 0
  let mut part_start = 0
  for ch in host {
    if ch == '.' {
      if !linkify_valid_ipv4_part(host[part_start:pos]) {
        return false
      }
      parts += 1
      part_start = pos + 1
    }
    pos += ch.utf16_len()
  }
  if !linkify_valid_ipv4_part(host[part_start:host.length()]) {
    return false
  }
  parts += 1
  parts == 4
}

///|
fn linkify_valid_ipv4_part(part : StringView) -> Bool {
  guard linkify_parse_uint(part) is Some(value) else { return false }
  !part.is_empty() && part.length() <= 3 && value <= 255
}
