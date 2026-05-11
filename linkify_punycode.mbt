///|
let linkify_punycode_base = 36

///|
let linkify_punycode_tmin = 1

///|
let linkify_punycode_tmax = 26

///|
let linkify_punycode_skew = 38

///|
let linkify_punycode_damp = 700

///|
let linkify_punycode_initial_bias = 72

///|
let linkify_punycode_initial_n = 128

///|
fn linkify_punycode_href(href : StringView) -> String {
  if starts_with_case_insensitive(href, 0, "mailto:") {
    return href.to_owned()
  }
  let (prefix, rest_start) = if starts_with_case_insensitive(href, 0, "http://") {
    ("http://", 7)
  } else if starts_with_case_insensitive(href, 0, "https://") {
    ("https://", 8)
  } else if starts_with_case_insensitive(href, 0, "ftp://") {
    ("ftp://", 6)
  } else if starts_with_case_insensitive(href, 0, "//") {
    ("//", 2)
  } else {
    ("", 0)
  }
  guard href.get_view(start=rest_start, end=href.length()) is Some(rest) else {
    return href.to_owned()
  }
  let (hostport, tail) = linkify_split_host_and_tail(rest)
  let mut userinfo = ""
  let mut hostport_without_userinfo = hostport
  match linkify_last_char_index(hostport, '@') {
    Some(at) => {
      userinfo = match hostport.get_view(start=0, end=at) {
        Some(view) => view.to_owned()
        None => ""
      }
      hostport_without_userinfo = match
        hostport.get_view(start=at + 1, end=hostport.length()) {
        Some(view) => view
        None => hostport
      }
    }
    None => ()
  }
  if hostport_without_userinfo.has_prefix("[") {
    return href.to_owned()
  }
  let (host, port) = linkify_split_host_port(hostport_without_userinfo)
  let host = linkify_punycode_host(host)
  let out = StringBuilder::new(size_hint=href.length() + 16)
  out.write_string(prefix)
  if userinfo != "" {
    out.write_string(userinfo)
    out.write_char('@')
  }
  out.write_string(host)
  if port != "" {
    out.write_char(':')
    out.write_string(port)
  }
  out.write_stringview(tail)
  out.to_string()
}

///|
fn linkify_split_host_and_tail(raw : StringView) -> (StringView, StringView) {
  let mut pos = 0
  while pos < raw.length() {
    match raw.get_char(pos) {
      Some('/') | Some('?') | Some('#') =>
        return (
          raw.get_view(start=0, end=pos).unwrap_or(raw),
          raw.get_view(start=pos, end=raw.length()).unwrap_or(""),
        )
      Some(ch) => pos += ch.utf16_len()
      None => break
    }
  }
  (raw, "")
}

///|
fn linkify_punycode_host(host : StringView) -> String {
  if !linkify_has_non_ascii(host) {
    return host.to_owned()
  }
  let labels : Array[String] = []
  let mut start = 0
  let mut pos = 0
  while pos <= host.length() {
    if pos == host.length() || host.get_char(pos) is Some('.') {
      guard host.get_view(start~, end=pos) is Some(label) else {
        return host.to_owned()
      }
      match linkify_punycode_label(label) {
        Some(encoded) => labels.push(encoded)
        None => return host.to_owned()
      }
      start = pos + 1
    }
    if pos < host.length() {
      match host.get_char(pos) {
        Some(ch) => pos += ch.utf16_len()
        None => break
      }
    } else {
      pos += 1
    }
  }
  labels.join(".")
}

///|
fn linkify_punycode_label(label : StringView) -> String? {
  if !linkify_has_non_ascii(label) {
    return Some(label.to_owned())
  }
  guard linkify_idna_codepoints(label) is Some(codepoints) else { return None }
  let encoded = linkify_punycode_encode(codepoints)
  if encoded == "" {
    None
  } else {
    Some("xn--" + encoded)
  }
}

///|
fn linkify_has_non_ascii(value : StringView) -> Bool {
  for ch in value {
    if ch.to_int() >= 128 {
      return true
    }
  }
  false
}

///|
fn linkify_idna_codepoints(label : StringView) -> Array[Int]? {
  let out : Array[Int] = []
  for ch in label {
    let code = ch.to_int()
    if code >= 0xD800 && code <= 0xDFFF {
      return None
    }
    if code >= 0x41 && code <= 0x5A {
      out.push(code + 0x20)
    } else if (code >= 0xC0 && code <= 0xD6) || (code >= 0xD8 && code <= 0xDE) {
      out.push(code + 0x20)
    } else {
      linkify_push_idna_mapped_codepoint(out, code)
    }
  }
  Some(out)
}

///|
fn linkify_push_idna_mapped_codepoint(out : Array[Int], code : Int) -> Unit {
  match code {
    0x00DF => {
      out.push(0x73)
      out.push(0x73)
    }
    0xFE8D => out.push(0x0627)
    0xFE93 => out.push(0x0629)
    0xFE97 | 0xFE98 => out.push(0x062A)
    0xFEAD => out.push(0x0631)
    0xFEAF => out.push(0x0632)
    0xFEBB => out.push(0x0635)
    0xFECB => out.push(0x0639)
    0xFED8 => out.push(0x0642)
    0xFEE1 | 0xFEE2 => out.push(0x0645)
    0xFEED | 0xFEEE => out.push(0x0648)
    0xFEFC => {
      out.push(0x0644)
      out.push(0x0627)
    }
    _ => out.push(code)
  }
}

///|
fn linkify_punycode_encode(input : Array[Int]) -> String {
  let out = StringBuilder::new()
  let input_len = input.length()
  let mut basic_count = 0
  for code in input {
    if code < 0x80 {
      out.write_char(code.unsafe_to_char())
      basic_count += 1
    }
  }
  let mut handled = basic_count
  if basic_count > 0 && handled < input_len {
    out.write_char('-')
  }
  let mut n = linkify_punycode_initial_n
  let mut delta = 0
  let mut bias = linkify_punycode_initial_bias
  while handled < input_len {
    let mut m = 0x110000
    for code in input {
      if code >= n && code < m {
        m = code
      }
    }
    if m == 0x110000 {
      return ""
    }
    delta += (m - n) * (handled + 1)
    n = m
    for code in input {
      if code < n {
        delta += 1
      } else if code == n {
        let mut q = delta
        let mut k = linkify_punycode_base
        let mut done = false
        while !done {
          let t = if k <= bias {
            linkify_punycode_tmin
          } else if k >= bias + linkify_punycode_tmax {
            linkify_punycode_tmax
          } else {
            k - bias
          }
          if q < t {
            out.write_char(linkify_punycode_digit(q))
            done = true
          } else {
            out.write_char(
              linkify_punycode_digit(t + (q - t) % (linkify_punycode_base - t)),
            )
            q = (q - t) / (linkify_punycode_base - t)
            k += linkify_punycode_base
          }
        }
        bias = linkify_punycode_adapt(
          delta,
          handled + 1,
          handled == basic_count,
        )
        delta = 0
        handled += 1
      }
    }
    delta += 1
    n += 1
  }
  out.to_string()
}

///|
fn linkify_punycode_digit(value : Int) -> Char {
  if value < 26 {
    (0x61 + value).unsafe_to_char()
  } else {
    (0x30 + value - 26).unsafe_to_char()
  }
}

///|
fn linkify_punycode_adapt(delta : Int, numpoints : Int, first : Bool) -> Int {
  let mut delta = if first { delta / linkify_punycode_damp } else { delta / 2 }
  delta += delta / numpoints
  let mut k = 0
  while delta >
        (linkify_punycode_base - linkify_punycode_tmin) *
        linkify_punycode_tmax /
        2 {
    delta /= linkify_punycode_base - linkify_punycode_tmin
    k += linkify_punycode_base
  }
  k +
  (linkify_punycode_base - linkify_punycode_tmin + 1) *
  delta /
  (delta + linkify_punycode_skew)
}
