///|
/// Find URL and email-like spans in plain text using the default configuration.
pub fn find_links(text : StringView) -> Array[LinkMatch] {
  find_links_with_config(text, LinkifyConfig::new())
}

///|
/// Find URL and email-like spans in plain text using an explicit configuration.
pub fn find_links_with_config(
  text : StringView,
  config : LinkifyConfig,
) -> Array[LinkMatch] {
  let out : Array[LinkMatch] = []
  let mut pos = 0
  let mut last_end = -1
  while pos < text.length() {
    if linkify_left_boundary(text, pos) &&
      linkify_candidate_can_start(text, pos) {
      let raw_end = if linkify_broad_candidate_start(text, pos) {
        linkify_candidate_end(text, pos)
      } else {
        linkify_fuzzy_candidate_end(text, pos)
      }
      match linkify_match_candidate(text, pos, raw_end, config) {
        Some(link) => {
          if link.start >= last_end {
            out.push(link)
            last_end = link.end
          }
          pos = raw_end
          continue
        }
        None =>
          match linkify_embedded_scheme_start(text, pos, raw_end) {
            Some(next) => {
              pos = next
              continue
            }
            None =>
              if raw_end > pos {
                pos = raw_end
                continue
              }
          }
      }
    }
    pos += text.get_char(pos).unwrap().utf16_len()
  }
  out
}

///|
fn linkify_left_boundary(text : StringView, pos : Int) -> Bool {
  if pos <= 0 {
    return true
  }
  match text.get_char(pos - 1) {
    Some(ch) => !(linkify_ascii_alnum(ch) || ch == '_')
    None => true
  }
}

///|
fn linkify_candidate_can_start(text : StringView, pos : Int) -> Bool {
  linkify_broad_candidate_start(text, pos) ||
  linkify_fuzzy_start_char(text.get_char(pos).unwrap())
}

///|
fn linkify_broad_candidate_start(text : StringView, pos : Int) -> Bool {
  @syn.starts_with_case_insensitive(text, pos, "http://") ||
  @syn.starts_with_case_insensitive(text, pos, "https://") ||
  @syn.starts_with_case_insensitive(text, pos, "ftp://") ||
  @syn.starts_with_case_insensitive(text, pos, "mailto:") ||
  @syn.starts_with_case_insensitive(text, pos, "www.") ||
  (text.get_char(pos) is Some('/') && text.get_char(pos + 1) is Some('/'))
}

///|
fn linkify_candidate_end(text : StringView, start : Int) -> Int {
  let mut pos = start
  for ch in text[start:text.length()] {
    if linkify_candidate_delimiter(ch) {
      return pos
    }
    pos += ch.utf16_len()
  }
  text.length()
}

///|
fn linkify_fuzzy_candidate_end(text : StringView, start : Int) -> Int {
  let mut pos = start
  for ch in text[start:text.length()] {
    if linkify_candidate_delimiter(ch) ||
      ch == '(' ||
      ch == ')' ||
      ch == '[' ||
      ch == ']' {
      return pos
    }
    pos += ch.utf16_len()
  }
  text.length()
}

///|
fn linkify_candidate_delimiter(ch : Char) -> Bool {
  ch.is_ascii_whitespace() || ch == '<' || ch == '>' || ch == '\u{FF5C}'
}

///|
fn linkify_match_candidate(
  text : StringView,
  start : Int,
  raw_end : Int,
  config : LinkifyConfig,
) -> LinkMatch? {
  let mut end = linkify_trim_trailing_end(text, start, raw_end)
  if end <= start {
    return None
  }
  guard text.get_view(start~, end~) is Some(candidate) else { return None }
  if linkify_is_scheme_url(candidate) {
    match linkify_find_substring(candidate, ")[") {
      Some(offset) =>
        end = linkify_trim_trailing_end(text, start, start + offset)
      None => ()
    }
  }
  guard text.get_view(start~, end~) is Some(candidate) else { return None }
  if !linkify_validate_candidate(candidate, text, start, config) {
    return None
  }
  let match_text = candidate.to_owned()
  let (href, kind) = linkify_href_for(candidate)
  Some({ start, end, text: match_text, href, kind })
}

///|
fn linkify_trim_trailing_end(text : StringView, start : Int, end : Int) -> Int {
  let mut end = end
  while end > start {
    match text.get_char(end - 1) {
      Some(ch) if ch == '.' ||
        ch == ',' ||
        ch == ';' ||
        ch == ':' ||
        ch == '!' ||
        ch == '?' => end -= 1
      _ => break
    }
  }
  while end > start {
    match text.get_char(end - 1) {
      Some('"') if linkify_count_char(text, start, end, '"') % 2 == 1 =>
        end -= 1
      Some('\'') if linkify_count_char(text, start, end, '\'') % 2 == 1 =>
        end -= 1
      _ => break
    }
  }
  while end > start {
    match text.get_char(end - 1) {
      Some(')') if linkify_count_char(text, start, end, ')') >
        linkify_count_char(text, start, end, '(') => end -= 1
      Some(']') if linkify_count_char(text, start, end, ']') >
        linkify_count_char(text, start, end, '[') => end -= 1
      Some('}') if linkify_count_char(text, start, end, '}') >
        linkify_count_char(text, start, end, '{') => end -= 1
      Some('>') if linkify_count_char(text, start, end, '>') >
        linkify_count_char(text, start, end, '<') => end -= 1
      _ => break
    }
  }
  end
}

///|
fn linkify_embedded_scheme_start(
  text : StringView,
  start : Int,
  end : Int,
) -> Int? {
  let mut pos = start
  for ch in text[start:end] {
    let next = pos + ch.utf16_len()
    if next < end &&
      (
        @syn.starts_with_case_insensitive(text, next, "http://") ||
        @syn.starts_with_case_insensitive(text, next, "https://") ||
        @syn.starts_with_case_insensitive(text, next, "ftp://") ||
        @syn.starts_with_case_insensitive(text, next, "mailto:")
      ) {
      return Some(next)
    }
    pos = next
  }
  None
}

///|
fn linkify_validate_candidate(
  candidate : StringView,
  source : StringView,
  start : Int,
  config : LinkifyConfig,
) -> Bool {
  let is_scheme = linkify_is_scheme(candidate)
  let is_scheme_url = linkify_is_scheme_url(candidate)
  let is_www = @syn.starts_with_case_insensitive(candidate, 0, "www.")
  let is_proto_rel = @syn.starts_with_case_insensitive(candidate, 0, "//")
  let has_at = string_view_contains(candidate, "@")
  if @syn.starts_with_case_insensitive(candidate, 0, "mailto:") {
    let address = candidate[7:candidate.length()]
    return linkify_validate_email_address(address, config, true)
  }
  if !is_scheme && !is_proto_rel && !is_www && !has_at {
    if linkify_broken_schema_context(source, start) {
      return false
    }
  }
  if linkify_starts_with_digit(candidate) &&
    string_view_contains(candidate, ".") &&
    !is_scheme_url &&
    !is_proto_rel {
    guard linkify_host_view(candidate) is Some(host) else { return false }
    if linkify_all_digits_or_dots(host) &&
      linkify_valid_ipv4(host) &&
      !config.fuzzy_ip {
      return false
    }
  }
  if is_proto_rel &&
    !linkify_validate_protocol_relative(candidate, source, start) {
    return false
  }
  if !is_scheme && !is_proto_rel && !is_www && !has_at {
    guard linkify_host_view(candidate) is Some(host) else { return false }
    if string_view_contains(host, "_") {
      return false
    }
    if string_view_contains(host, ":") {
      return false
    }
    if string_view_contains(host, ".") &&
      linkify_all_digits_or_dots(host) &&
      linkify_valid_ipv4(host) {
      return true
    }
    guard linkify_split_domain_for_tld(host) is Some((_base, tld)) else {
      return false
    }
    if !linkify_valid_tld(tld, config.extra_tlds) {
      return false
    }
  }
  if has_at &&
    !is_scheme_url &&
    !is_proto_rel &&
    !@syn.starts_with_case_insensitive(candidate, 0, "mailto:") {
    if !linkify_validate_email_address(candidate, config, false) {
      return false
    }
  }
  if is_scheme_url && !linkify_validate_scheme_url(candidate) {
    return false
  }
  true
}

///|
fn linkify_validate_email_address(
  address : StringView,
  config : LinkifyConfig,
  allow_tldless_domain : Bool,
) -> Bool {
  guard linkify_last_char_index(address, '@') is Some(at) else { return false }
  if at == 0 || at + 1 >= address.length() {
    return false
  }
  let domain = address[at + 1:address.length()]
  guard linkify_host_view(domain) is Some(host) else { return false }
  if string_view_contains(host, "_") {
    return false
  }
  match linkify_split_domain_for_tld(host) {
    Some((_base, tld)) => linkify_valid_tld(tld, config.extra_tlds)
    None => allow_tldless_domain && !host.is_empty()
  }
}

///|
fn linkify_broken_schema_context(source : StringView, start : Int) -> Bool {
  if start >= 3 {
    match source.get_view(start=start - 3, end=start) {
      Some("://") => return true
      _ => ()
    }
  }
  if start > 0 {
    match source.get_char(start - 1) {
      Some('/') | Some(':') | Some('@') => return true
      _ => ()
    }
  }
  false
}

///|
fn linkify_validate_protocol_relative(
  candidate : StringView,
  source : StringView,
  start : Int,
) -> Bool {
  if start > 0 {
    match source.get_char(start - 1) {
      Some(':') | Some('/') => return false
      _ => ()
    }
  }
  let after = candidate[2:candidate.length()]
  guard linkify_host_view(after) is Some(hostport) else { return false }
  if hostport.is_empty() || hostport.has_prefix("[") {
    return false
  }
  let host = linkify_host_without_userinfo_port(hostport)
  if host.is_empty() {
    return false
  }
  if @syn.lower_ascii(host) != "localhost" && !string_view_contains(host, ".") {
    return false
  }
  !string_view_contains(host, "_")
}

///|
fn linkify_validate_scheme_url(candidate : StringView) -> Bool {
  guard linkify_after_url_scheme(candidate) is Some(after) else { return false }
  guard linkify_host_view(after) is Some(hostport) else { return false }
  if hostport.is_empty() {
    return false
  }
  let hostport = linkify_strip_userinfo(hostport)
  let (host, port) = linkify_split_host_port(hostport)
  if port != "" {
    guard linkify_parse_uint(port) is Some(port_value) else { return false }
    if port_value > 65535 {
      return false
    }
  }
  if host.is_empty() ||
    host.has_prefix("-") ||
    host.has_prefix(".") ||
    host.has_suffix("-") ||
    host.has_suffix(".") ||
    string_view_contains(host, "..") ||
    string_view_contains(host, "_") {
    return false
  }
  if string_view_contains(host, ".") &&
    linkify_all_digits_or_dots(host) &&
    !linkify_valid_ipv4(host) {
    return false
  }
  true
}

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

///|
fn linkify_href_for(candidate : StringView) -> (String, String) {
  let text = candidate.to_owned()
  if @syn.starts_with_case_insensitive(candidate, 0, "mailto:") {
    return (text, "email")
  }
  if string_view_contains(candidate, "@") &&
    !linkify_is_scheme_url(candidate) &&
    !@syn.starts_with_case_insensitive(candidate, 0, "//") &&
    !@syn.starts_with_case_insensitive(candidate, 0, "www.") {
    return ("mailto:" + text, "email")
  }
  if linkify_is_scheme_url(candidate) ||
    @syn.starts_with_case_insensitive(candidate, 0, "//") {
    return (linkify_punycode_href(text), "url")
  }
  (linkify_punycode_href("http://" + text), "url")
}

///|
fn linkify_is_scheme(candidate : StringView) -> Bool {
  @syn.starts_with_case_insensitive(candidate, 0, "http://") ||
  @syn.starts_with_case_insensitive(candidate, 0, "https://") ||
  @syn.starts_with_case_insensitive(candidate, 0, "ftp://") ||
  @syn.starts_with_case_insensitive(candidate, 0, "mailto:")
}

///|
fn linkify_is_scheme_url(candidate : StringView) -> Bool {
  @syn.starts_with_case_insensitive(candidate, 0, "http://") ||
  @syn.starts_with_case_insensitive(candidate, 0, "https://") ||
  @syn.starts_with_case_insensitive(candidate, 0, "ftp://")
}
