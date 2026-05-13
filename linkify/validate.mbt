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
