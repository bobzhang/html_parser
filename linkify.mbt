///|
/// A URL or email-like span found in plain text.
///
/// `start` and `end` are UTF-16 offsets into the input `StringView`.
/// `kind` is `"url"` or `"email"`.
pub(all) struct LinkMatch {
  start : Int
  end : Int
  text : String
  href : String
  kind : String
} derive(Debug, Eq)

///|
/// Options for the plain-text link scanner.
pub struct LinkifyConfig {
  priv fuzzy_ip : Bool
  priv extra_tlds : Set[String]
} derive(Debug)

///|
/// Create a linkify scanner configuration.
///
/// `fuzzy_ip` enables bare IPv4 address matches such as `192.168.0.1`.
/// `extra_tlds` extends the default fuzzy domain and email TLD allowlist.
pub fn LinkifyConfig::new(
  fuzzy_ip? : Bool = false,
  extra_tlds? : Array[String] = [],
) -> LinkifyConfig {
  { fuzzy_ip, extra_tlds: linkify_tld_set(extra_tlds) }
}

///|
/// Create a linkify scanner configuration with additional fuzzy-link TLDs.
pub fn LinkifyConfig::with_extra_tlds(
  extra_tlds : Array[String],
) -> LinkifyConfig {
  LinkifyConfig::new(extra_tlds~)
}

///|
fn linkify_tld_set(values : Array[String]) -> Set[String] {
  let out : Set[String] = Set::default()
  for value in values {
    let tld = value[:].trim().to_lower().to_owned()
    if tld != "" {
      out.add(tld)
    }
  }
  out
}

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
    match text.get_char(pos) {
      Some(ch) => pos += ch.utf16_len()
      None => break
    }
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
  (match text.get_char(pos) {
    Some(ch) => linkify_fuzzy_start_char(ch)
    None => false
  })
}

///|
fn linkify_broad_candidate_start(text : StringView, pos : Int) -> Bool {
  starts_with_case_insensitive(text, pos, "http://") ||
  starts_with_case_insensitive(text, pos, "https://") ||
  starts_with_case_insensitive(text, pos, "ftp://") ||
  starts_with_case_insensitive(text, pos, "mailto:") ||
  starts_with_case_insensitive(text, pos, "www.") ||
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
      Some(offset) => {
        end = linkify_trim_trailing_end(text, start, start + offset)
        if end <= start {
          return None
        }
      }
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
fn linkify_count_char(
  text : StringView,
  start : Int,
  end : Int,
  needle : Char,
) -> Int {
  let mut count = 0
  for ch in text[start:end] {
    if ch == needle {
      count += 1
    }
  }
  count
}

///|
fn linkify_find_substring(haystack : StringView, needle : StringView) -> Int? {
  if needle.is_empty() || needle.length() > haystack.length() {
    return None
  }
  let mut pos = 0
  for ch in haystack {
    if pos + needle.length() > haystack.length() {
      break
    }
    match haystack.get_view(start=pos, end=pos + needle.length()) {
      Some(part) if part == needle => return Some(pos)
      _ => ()
    }
    pos += ch.utf16_len()
  }
  None
}

///|
fn linkify_embedded_scheme_start(
  text : StringView,
  start : Int,
  end : Int,
) -> Int? {
  let mut pos = start
  while pos < end {
    match text.get_char(pos) {
      Some(ch) => {
        let next = pos + ch.utf16_len()
        if next < end &&
          (
            starts_with_case_insensitive(text, next, "http://") ||
            starts_with_case_insensitive(text, next, "https://") ||
            starts_with_case_insensitive(text, next, "ftp://") ||
            starts_with_case_insensitive(text, next, "mailto:")
          ) {
          return Some(next)
        }
        pos = next
      }
      None => break
    }
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
  let is_www = starts_with_case_insensitive(candidate, 0, "www.")
  let is_proto_rel = starts_with_case_insensitive(candidate, 0, "//")
  let has_at = string_view_contains(candidate, "@")
  if starts_with_case_insensitive(candidate, 0, "mailto:") {
    guard candidate.get_view(start=7, end=candidate.length()) is Some(address) else {
      return false
    }
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
    !starts_with_case_insensitive(candidate, 0, "mailto:") {
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
  guard address.get_view(start=at + 1, end=address.length()) is Some(domain) else {
    return false
  }
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
  guard candidate.get_view(start=2, end=candidate.length()) is Some(after) else {
    return false
  }
  guard linkify_host_view(after) is Some(hostport) else { return false }
  if hostport.is_empty() || hostport.has_prefix("[") {
    return false
  }
  let host = linkify_host_without_userinfo_port(hostport)
  if host.is_empty() {
    return false
  }
  if lower_ascii(host) != "localhost" && !string_view_contains(host, ".") {
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
    Some(at) =>
      match hostport.get_view(start=at + 1, end=hostport.length()) {
        Some(host) => host
        None => hostport
      }
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
      match hostport.get_view(start=0, end=colon) {
        Some(host) => {
          let port = match
            hostport.get_view(start=colon + 1, end=hostport.length()) {
            Some(view) => view.to_owned()
            None => ""
          }
          (host, port)
        }
        None => (hostport, "")
      }
    None => (hostport, "")
  }
}

///|
fn linkify_after_url_scheme(candidate : StringView) -> StringView? {
  let start = if starts_with_case_insensitive(candidate, 0, "http://") {
    7
  } else if starts_with_case_insensitive(candidate, 0, "https://") {
    8
  } else if starts_with_case_insensitive(candidate, 0, "ftp://") {
    6
  } else {
    return None
  }
  candidate.get_view(start~, end=candidate.length())
}

///|
fn linkify_split_domain_for_tld(host : StringView) -> (String, String)? {
  let stripped = linkify_strip_edge_dots(host.trim())
  if stripped.is_empty() {
    return None
  }
  if stripped.compare_ignore_ascii_case("localhost") == 0 {
    return Some(("localhost", ""))
  }
  match linkify_last_char_index(stripped, '.') {
    Some(dot) => {
      guard stripped.get_view(start=0, end=dot) is Some(base) else {
        return None
      }
      guard stripped.get_view(start=dot + 1, end=stripped.length()) is Some(tld) else {
        return None
      }
      if base.is_empty() || tld.is_empty() {
        None
      } else {
        Some((base.to_owned(), tld.to_lower().to_owned()))
      }
    }
    None => None
  }
}

///|
fn linkify_strip_edge_dots(value : StringView) -> StringView {
  let mut start = 0
  let mut end = value.length()
  while start < end && value.get_char(start) is Some('.') {
    start += 1
  }
  while end > start && value.get_char(end - 1) is Some('.') {
    end -= 1
  }
  match value.get_view(start~, end~) {
    Some(view) => view
    None => value
  }
}

///|
fn linkify_valid_tld(tld : String, extra_tlds : Set[String]) -> Bool {
  let tld = tld.trim().to_lower().to_owned()
  if tld == "" {
    return false
  }
  if tld.has_prefix("xn--") {
    return true
  }
  linkify_default_tld(tld) ||
  linkify_common_cc_tld(tld) ||
  extra_tlds.contains(tld)
}

///|
fn linkify_default_tld(tld : StringView) -> Bool {
  match tld {
    "aero"
    | "asia"
    | "biz"
    | "com"
    | "coop"
    | "edu"
    | "gov"
    | "info"
    | "museum"
    | "name"
    | "net"
    | "org"
    | "pro"
    | "shop"
    | "web"
    | "xxx"
    | "рф" => true
    _ => false
  }
}

///|
fn linkify_common_cc_tld(tld : StringView) -> Bool {
  match tld {
    "ac"
    | "ad"
    | "ae"
    | "af"
    | "ag"
    | "ai"
    | "al"
    | "am"
    | "an"
    | "ao"
    | "aq"
    | "ar"
    | "as"
    | "at"
    | "au"
    | "aw"
    | "ax"
    | "az"
    | "ba"
    | "bb"
    | "bd"
    | "be"
    | "bf"
    | "bg"
    | "bh"
    | "bi"
    | "bj"
    | "bm"
    | "bn"
    | "bo"
    | "br"
    | "bs"
    | "bt"
    | "bv"
    | "bw"
    | "by"
    | "bz"
    | "ca"
    | "cc"
    | "cd"
    | "cf"
    | "cg"
    | "ch"
    | "ci"
    | "ck"
    | "cl"
    | "cm"
    | "cn"
    | "co"
    | "cr"
    | "cu"
    | "cv"
    | "cw"
    | "cx"
    | "cy"
    | "cz"
    | "de"
    | "dj"
    | "dk"
    | "dm"
    | "do"
    | "dz"
    | "ec"
    | "ee"
    | "eg"
    | "er"
    | "es"
    | "et"
    | "eu"
    | "fi"
    | "fj"
    | "fk"
    | "fm"
    | "fo"
    | "fr"
    | "ga"
    | "gb"
    | "gd"
    | "ge"
    | "gf"
    | "gg"
    | "gh"
    | "gi"
    | "gl"
    | "gm"
    | "gn"
    | "gp"
    | "gq"
    | "gr"
    | "gs"
    | "gt"
    | "gu"
    | "gw"
    | "gy"
    | "hk"
    | "hm"
    | "hn"
    | "hr"
    | "ht"
    | "hu"
    | "id"
    | "ie"
    | "il"
    | "im"
    | "in"
    | "io"
    | "iq"
    | "ir"
    | "is"
    | "it"
    | "je"
    | "jm"
    | "jo"
    | "jp"
    | "ke"
    | "kg"
    | "kh"
    | "ki"
    | "km"
    | "kn"
    | "kp"
    | "kr"
    | "kw"
    | "ky"
    | "kz"
    | "la"
    | "lb"
    | "lc"
    | "li"
    | "lk"
    | "lr"
    | "ls"
    | "lt"
    | "lu"
    | "lv"
    | "ly"
    | "ma"
    | "mc"
    | "md"
    | "me"
    | "mg"
    | "mh"
    | "mk"
    | "ml"
    | "mm"
    | "mn"
    | "mo"
    | "mp"
    | "mq"
    | "mr"
    | "ms"
    | "mt"
    | "mu"
    | "mv"
    | "mw"
    | "mx"
    | "my"
    | "mz"
    | "na"
    | "nc"
    | "ne"
    | "nf"
    | "ng"
    | "ni"
    | "nl"
    | "no"
    | "np"
    | "nr"
    | "nu"
    | "nz"
    | "om"
    | "pa"
    | "pe"
    | "pf"
    | "pg"
    | "ph"
    | "pk"
    | "pl"
    | "pm"
    | "pn"
    | "pr"
    | "ps"
    | "pt"
    | "pw"
    | "py"
    | "qa"
    | "re"
    | "ro"
    | "rs"
    | "ru"
    | "rw"
    | "sa"
    | "sb"
    | "sc"
    | "sd"
    | "se"
    | "sg"
    | "sh"
    | "si"
    | "sj"
    | "sk"
    | "sl"
    | "sm"
    | "sn"
    | "so"
    | "sr"
    | "st"
    | "su"
    | "sv"
    | "sx"
    | "sy"
    | "sz"
    | "tc"
    | "td"
    | "tf"
    | "tg"
    | "th"
    | "tj"
    | "tk"
    | "tl"
    | "tm"
    | "tn"
    | "to"
    | "tr"
    | "tt"
    | "tv"
    | "tw"
    | "tz"
    | "ua"
    | "ug"
    | "uk"
    | "us"
    | "uy"
    | "uz"
    | "va"
    | "vc"
    | "ve"
    | "vg"
    | "vi"
    | "vn"
    | "vu"
    | "wf"
    | "ws"
    | "ye"
    | "yt"
    | "za"
    | "zm"
    | "zw" => true
    _ => false
  }
}

///|
fn linkify_valid_ipv4(host : StringView) -> Bool {
  let mut parts = 0
  let mut pos = 0
  let mut part_start = 0
  while pos <= host.length() {
    if pos == host.length() || host.get_char(pos) is Some('.') {
      guard host.get_view(start=part_start, end=pos) is Some(part) else {
        return false
      }
      guard linkify_parse_uint(part) is Some(value) else { return false }
      if part.is_empty() || part.length() > 3 || value > 255 {
        return false
      }
      parts += 1
      part_start = pos + 1
    }
    if pos == host.length() {
      break
    }
    match host.get_char(pos) {
      Some(ch) => pos += ch.utf16_len()
      None => return false
    }
  }
  parts == 4
}

///|
fn linkify_parse_uint(value : StringView) -> Int? {
  if value.is_empty() {
    return None
  }
  let mut out = 0
  for ch in value {
    if !ch.is_digit(10) {
      return None
    }
    out = out * 10 + ch.to_int() - ('0' : Int)
  }
  Some(out)
}

///|
fn linkify_href_for(candidate : StringView) -> (String, String) {
  let text = candidate.to_owned()
  if starts_with_case_insensitive(candidate, 0, "mailto:") {
    return (text, "email")
  }
  if string_view_contains(candidate, "@") &&
    !linkify_is_scheme_url(candidate) &&
    !starts_with_case_insensitive(candidate, 0, "//") &&
    !starts_with_case_insensitive(candidate, 0, "www.") {
    return ("mailto:" + text, "email")
  }
  if linkify_is_scheme_url(candidate) ||
    starts_with_case_insensitive(candidate, 0, "//") {
    return (linkify_punycode_href(text), "url")
  }
  (linkify_punycode_href("http://" + text), "url")
}

///|
fn linkify_is_scheme(candidate : StringView) -> Bool {
  starts_with_case_insensitive(candidate, 0, "http://") ||
  starts_with_case_insensitive(candidate, 0, "https://") ||
  starts_with_case_insensitive(candidate, 0, "ftp://") ||
  starts_with_case_insensitive(candidate, 0, "mailto:")
}

///|
fn linkify_is_scheme_url(candidate : StringView) -> Bool {
  starts_with_case_insensitive(candidate, 0, "http://") ||
  starts_with_case_insensitive(candidate, 0, "https://") ||
  starts_with_case_insensitive(candidate, 0, "ftp://")
}

///|
fn linkify_last_char_index(value : StringView, needle : Char) -> Int? {
  let mut pos = 0
  let mut last : Int? = None
  for ch in value {
    if ch == needle {
      last = Some(pos)
    }
    pos += ch.utf16_len()
  }
  last
}

///|
fn linkify_starts_with_digit(value : StringView) -> Bool {
  match value.get_char(0) {
    Some(ch) => ch >= '0' && ch <= '9'
    None => false
  }
}

///|
fn linkify_all_digits_or_dots(value : StringView) -> Bool {
  if value.is_empty() {
    return false
  }
  for ch in value {
    if !(ch == '.' || (ch >= '0' && ch <= '9')) {
      return false
    }
  }
  true
}

///|
fn linkify_ascii_alnum(ch : Char) -> Bool {
  (ch >= '0' && ch <= '9') ||
  (ch >= 'A' && ch <= 'Z') ||
  (ch >= 'a' && ch <= 'z')
}

///|
fn linkify_fuzzy_start_char(ch : Char) -> Bool {
  linkify_ascii_alnum(ch) || ch.to_int() > 127
}
