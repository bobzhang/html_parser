///|
fn url_proxy_query_byte_is_safe(byte : Byte) -> Bool {
  let value = byte.to_int()
  (value >= 0x41 && value <= 0x5A) ||
  (value >= 0x61 && value <= 0x7A) ||
  (value >= 0x30 && value <= 0x39) ||
  value == 0x2D ||
  value == 0x2E ||
  value == 0x5F ||
  value == 0x7E
}

///|
fn percent_encode_url_proxy_param(value : StringView) -> String {
  let bytes = @utf8.encode(value)
  let out = StringBuilder::StringBuilder(size_hint=bytes.length())
  for index in 0..<bytes.length() {
    let byte = bytes[index]
    if url_proxy_query_byte_is_safe(byte) {
      out.write_char(byte.to_char())
    } else {
      @seri.write_percent_encoded_byte(out, byte)
    }
  }
  out.to_string()
}

///|
fn UrlPolicy::effective_proxy(self : UrlPolicy, rule : UrlRule) -> UrlProxy? {
  match rule.proxy {
    Some(proxy) => Some(proxy)
    None => self.proxy
  }
}

///|
fn proxy_url_value(proxy : UrlProxy, value : String) -> String? {
  if proxy.url == "" {
    None
  } else {
    let sep = if string_view_contains(proxy.url, "?") { "&" } else { "?" }
    Some(
      proxy.url +
      sep +
      proxy.param +
      "=" +
      percent_encode_url_proxy_param(value),
    )
  }
}

///|
fn apply_url_handling(
  policy : UrlPolicy,
  rule : UrlRule,
  handling : UrlHandling,
  value : String,
) -> String? {
  match handling {
    UrlAllow => Some(value)
    UrlStrip => None
    UrlProxy =>
      match policy.effective_proxy(rule) {
        Some(proxy) => proxy_url_value(proxy, value)
        None => None
      }
  }
}
