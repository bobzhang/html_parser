///|
/// How sanitizer handles elements whose tag names are not allowlisted.
pub(all) enum DisallowedTagHandling {
  Unwrap
  Escape
  Drop
} derive(Debug, Eq)

///|
/// How sanitizer reports unsafe input that it strips or rewrites.
pub(all) enum UnsafeHandling {
  Strip
  Raise
  Collect
} derive(Debug, Eq)

///|
/// Action used after a URL value passes the configured URL checks.
pub(all) enum UrlHandling {
  UrlAllow
  UrlStrip
  UrlProxy
} derive(Debug, Eq)

///|
/// Callback wrapper used to rewrite or reject URL values before validation.
///
/// The callback receives normalized tag name, normalized attribute name, and the
/// raw attribute value. Returning `None` drops the URL.
pub struct UrlFilter {
  priv callback : (String, String, String) -> String?
}

///|
pub impl Debug for UrlFilter with to_repr(_) {
  Repr::opaque_("UrlFilter", Repr::unit())
}

///|
/// Proxy endpoint used when a URL rule selects `UrlProxy`.
///
/// Sanitized URLs are emitted as `url?param=<encoded-url>` or
/// `url&param=<encoded-url>` depending on whether the proxy URL already has a
/// query string.
pub struct UrlProxy {
  priv url : String
  priv param : String
} derive(Debug)

///|
/// Per-attribute URL validation rule.
///
/// Rules can restrict schemes and hosts, disallow fragments, normalize
/// protocol-relative URLs, override relative-URL handling, or route accepted
/// URLs through a proxy.
pub struct UrlRule {
  priv allow_fragment : Bool
  priv resolve_protocol_relative : String?
  priv allowed_schemes : Set[String]
  priv allowed_hosts : Set[String]
  priv handling : UrlHandling?
  priv allow_relative : Bool?
  priv proxy : UrlProxy?
} derive(Debug)

///|
/// URL rule bound to a tag and attribute name.
pub struct UrlPolicyRule {
  priv tag : String
  priv attr : String
  priv rule : UrlRule
} derive(Debug)

///|
/// URL sanitization policy shared by URL-bearing attributes.
///
/// Exact `(tag, attr)` rules take precedence. Unmatched URL-like attributes use
/// the default handling and relative-URL behavior.
pub struct UrlPolicy {
  priv default_handling : UrlHandling
  priv default_allow_relative : Bool
  priv allow_rules : Map[String, UrlRule]
  priv proxy : UrlProxy?
  priv url_filter : UrlFilter?
} derive(Debug)

///|
/// DOM sanitization policy.
///
/// A policy controls allowed tags and attributes, URL filtering, comment and
/// doctype handling, foreign-content hardening, CSS style allowlists, selector
/// limits used by transform hooks, and unsafe-input reporting.
pub struct SanitizationPolicy {
  priv allowed_tags : Set[String]
  priv allowed_attributes : Map[String, Set[String]]
  priv url_policy : UrlPolicy
  priv drop_comments : Bool
  priv drop_doctype : Bool
  priv drop_foreign_namespaces : Bool
  priv drop_content_tags : Set[String]
  priv disallowed_tag_handling : DisallowedTagHandling
  priv force_link_rel : Array[String]
  priv allowed_css_properties : Set[String]
  priv strip_invisible_unicode : Bool
  priv selector_limits : SelectorLimits
  priv unsafe_handling : UnsafeHandling
  priv security_errors : Array[ParseError]
} derive(Debug)

///|
fn sanitized_string_set(values : Array[String]) -> Set[String] {
  let set : Set[String] = Set::default()
  for value in values {
    let normalized = lower_ascii(value[:].trim())
    if normalized != "" {
      set.add(normalized)
    }
  }
  set
}

///|
fn string_array_contains(values : Array[String], needle : String) -> Bool {
  for value in values {
    if value == needle {
      return true
    }
  }
  false
}

///|
fn push_unique_string(values : Array[String], value : String) -> Unit {
  if value != "" && !string_array_contains(values, value) {
    values.push(value)
  }
}

///|
fn sanitized_string_list(values : Array[String]) -> Array[String] {
  let out : Array[String] = []
  for value in values {
    push_unique_string(out, lower_ascii(value[:].trim()))
  }
  out
}

///|
fn sanitize_allowed_attributes(
  attrs : Map[String, Array[String]],
) -> Map[String, Set[String]] {
  let normalized : Map[String, Set[String]] = {}
  for tag, values in attrs {
    let tag_name = lower_ascii(tag[:].trim())
    if tag_name != "" {
      normalized[tag_name] = sanitized_string_set(values)
    }
  }
  normalized
}

///|
/// Construct a URL filter from a callback.
pub fn UrlFilter::new(
  callback : (String, String, String) -> String?,
) -> UrlFilter {
  { callback, }
}

///|
/// Construct a URL proxy descriptor.
pub fn UrlProxy::new(url : StringView, param? : String = "url") -> UrlProxy {
  { url: url.to_owned(), param }
}

///|
/// Construct a per-attribute URL validation rule.
///
/// Schemes and hosts are normalized to lowercase. `resolve_protocol_relative`
/// rewrites protocol-relative URLs such as `//example.com` before validation.
pub fn UrlRule::new(
  allowed_schemes? : Array[String] = [],
  allowed_hosts? : Array[String] = [],
  allow_fragment? : Bool = true,
  resolve_protocol_relative? : String? = Some("https"),
  handling? : UrlHandling,
  allow_relative? : Bool,
  proxy? : UrlProxy,
) -> UrlRule {
  {
    allow_fragment,
    resolve_protocol_relative: resolve_protocol_relative.map(fn(scheme) {
      lower_ascii(scheme[:].trim())
    }),
    allowed_schemes: sanitized_string_set(allowed_schemes),
    allowed_hosts: sanitized_string_set(allowed_hosts),
    handling,
    allow_relative,
    proxy,
  }
}

///|
/// Construct a URL policy rule for one tag and attribute.
pub fn UrlPolicyRule::new(
  tag : StringView,
  attr : StringView,
  rule : UrlRule,
) -> UrlPolicyRule {
  { tag: lower_ascii(tag.trim()), attr: lower_ascii(attr.trim()), rule }
}

///|
fn url_policy_rule_key(tag : String, attr : String) -> String {
  tag + "\u{0000}" + attr
}

///|
fn sanitize_url_policy_rules(
  rules : Array[UrlPolicyRule],
) -> Map[String, UrlRule] {
  let out : Map[String, UrlRule] = {}
  for rule in rules {
    if rule.tag != "" && rule.attr != "" {
      out[url_policy_rule_key(rule.tag, rule.attr)] = rule.rule
    }
  }
  out
}

///|
/// Construct a URL policy.
///
/// `allow_rules` are exact tag/attribute bindings. `url_filter` runs before
/// rule validation and can rewrite or drop the URL value.
pub fn UrlPolicy::new(
  default_handling? : UrlHandling = UrlAllow,
  default_allow_relative? : Bool = true,
  allow_rules? : Array[UrlPolicyRule] = [],
  proxy? : UrlProxy,
  url_filter? : UrlFilter,
) -> UrlPolicy {
  {
    default_handling,
    default_allow_relative,
    allow_rules: sanitize_url_policy_rules(allow_rules),
    proxy,
    url_filter,
  }
}

///|
fn default_url_policy() -> UrlPolicy {
  UrlPolicy::new(default_handling=UrlStrip, allow_rules=[
    UrlPolicyRule::new(
      "a",
      "href",
      UrlRule::new(
        allowed_schemes=["http", "https", "mailto", "tel"],
        handling=UrlAllow,
      ),
    ),
    UrlPolicyRule::new(
      "img",
      "src",
      UrlRule::new(
        allow_fragment=false,
        resolve_protocol_relative=None,
        handling=UrlAllow,
      ),
    ),
  ])
}

///|
/// Construct a DOM sanitization policy.
///
/// Tag and attribute names are normalized to lowercase. By default comments,
/// doctypes, foreign namespaces, script/style content, and invisible Unicode
/// controls are removed. Unsafe findings are stripped unless `unsafe_handling`
/// is set to `Raise` or `Collect`.
pub fn SanitizationPolicy::new(
  allowed_tags : Array[String],
  allowed_attributes? : Map[String, Array[String]] = {},
  url_policy? : UrlPolicy,
  drop_comments? : Bool = true,
  drop_doctype? : Bool = true,
  drop_foreign_namespaces? : Bool = true,
  drop_content_tags? : Array[String] = ["script", "style"],
  disallowed_tag_handling? : DisallowedTagHandling = Unwrap,
  force_link_rel? : Array[String] = [],
  allowed_css_properties? : Array[String] = [],
  strip_invisible_unicode? : Bool = true,
  selector_limits? : SelectorLimits,
  unsafe_handling? : UnsafeHandling = Strip,
) -> SanitizationPolicy {
  {
    allowed_tags: sanitized_string_set(allowed_tags),
    allowed_attributes: sanitize_allowed_attributes(allowed_attributes),
    url_policy: url_policy.unwrap_or(default_url_policy()),
    drop_comments,
    drop_doctype,
    drop_foreign_namespaces,
    drop_content_tags: sanitized_string_set(drop_content_tags),
    disallowed_tag_handling,
    force_link_rel: sanitized_string_list(force_link_rel),
    allowed_css_properties: sanitized_string_set(allowed_css_properties),
    strip_invisible_unicode,
    selector_limits: selector_limits.unwrap_or(default_selector_limits()),
    unsafe_handling,
    security_errors: [],
  }
}

///|
/// Clear unsafe findings accumulated in `Collect` mode.
pub fn SanitizationPolicy::reset_collected_security_errors(
  self : SanitizationPolicy,
) -> Unit {
  self.security_errors.clear()
}

///|
/// Return a copy of unsafe findings accumulated in `Collect` mode.
pub fn SanitizationPolicy::collected_security_errors(
  self : SanitizationPolicy,
) -> Array[ParseError] {
  self.security_errors.copy()
}

///|
fn SanitizationPolicy::handle_unsafe(
  self : SanitizationPolicy,
  message : String,
) -> Unit raise HtmlError {
  match self.unsafe_handling {
    Strip => ()
    Raise => raise UnsafeHtml(message)
    Collect =>
      self.security_errors.push(
        ParseError::new("unsafe-html", category="security", message~),
      )
  }
}

///|
priv struct SanitizeTransformObserver {
  hook : TransformNodeCallback?
  report_callback : TransformReportCallback?
}

///|
fn sanitize_observer_event(
  observer : SanitizeTransformObserver?,
  message : String,
  node : Node?,
) -> Unit {
  match observer {
    Some(observer) => {
      match (node, observer.hook) {
        (Some(node), Some(hook)) => (hook.callback)(node)
        _ => ()
      }
      match observer.report_callback {
        Some(report) => (report.callback)(message, node)
        None => ()
      }
    }
    None => ()
  }
}

///|
fn sanitize_report_unsafe(
  policy : SanitizationPolicy,
  observer : SanitizeTransformObserver?,
  message : String,
  node : Node?,
) -> Unit raise HtmlError {
  policy.handle_unsafe(message)
  sanitize_observer_event(observer, message, node)
}

///|
fn default_allowed_tags() -> Array[String] {
  [
    "p", "br", "div", "span", "blockquote", "pre", "code", "h1", "h2", "h3", "h4",
    "h5", "h6", "ul", "ol", "li", "table", "caption", "thead", "tbody", "tfoot",
    "tr", "th", "td", "b", "strong", "i", "em", "u", "s", "sub", "sup", "small",
    "mark", "hr", "a", "img",
  ]
}

///|
fn default_allowed_attributes() -> Map[String, Array[String]] {
  {
    "*": ["class", "id", "title", "lang", "dir"],
    "a": ["href", "title"],
    "img": ["src", "alt", "title", "width", "height", "loading", "decoding"],
    "th": ["colspan", "rowspan"],
    "td": ["colspan", "rowspan"],
  }
}

///|
/// Return the default fragment sanitizer policy.
pub fn default_sanitization_policy() -> SanitizationPolicy {
  SanitizationPolicy::new(
    default_allowed_tags(),
    allowed_attributes=default_allowed_attributes(),
  )
}

///|
/// Return the default document sanitizer policy.
///
/// This extends the fragment policy with document shell tags and preserves the
/// doctype.
pub fn default_document_sanitization_policy() -> SanitizationPolicy {
  let tags = default_allowed_tags()
  tags.push("html")
  tags.push("head")
  tags.push("body")
  tags.push("title")
  SanitizationPolicy::new(
    tags,
    allowed_attributes=default_allowed_attributes(),
    drop_doctype=false,
  )
}

///|
/// Return the conservative text-style CSS property allowlist.
pub fn css_preset_text() -> Array[String] {
  [
    "background-color", "color", "font-size", "font-style", "font-weight", "letter-spacing",
    "line-height", "text-align", "text-decoration", "text-transform", "white-space",
    "word-break", "word-spacing", "word-wrap",
  ]
}

///|
fn node_is_sanitize_container(node : Node) -> Bool {
  match node.kind {
    Document | Fragment => true
    _ => false
  }
}

///|
fn remove_child_at(parent : Node, index : Int) -> Unit {
  let child = parent.children[index]
  ignore(parent.children.remove(index))
  if child.parent is Some(current_parent) &&
    physical_equal(parent, current_parent) {
    child.parent = None
  }
}

///|
fn unwrap_child_at(parent : Node, index : Int) -> Int {
  let child = parent.children[index]
  ignore(parent.children.remove(index))
  if child.parent is Some(current_parent) &&
    physical_equal(parent, current_parent) {
    child.parent = None
  }
  let mut inserted = 0
  while !child.children.is_empty() {
    let grandchild = child.children[0]
    ignore(child.children.remove(0))
    grandchild.parent = Some(parent)
    parent.children.insert(index + inserted, grandchild)
    inserted += 1
  }
  inserted
}

///|
fn escaped_end_tag_for(node : Node) -> String? {
  if is_void_element(node.name) {
    None
  } else {
    Some("</" + node.name + ">")
  }
}

///|
fn sanitizer_escaped_end_tag_for(node : Node) -> String? {
  match node.source_end_tag {
    Some(raw) => Some(raw)
    None =>
      if node.parsed_from_source || is_void_element(node.name) {
        None
      } else {
        Some("</" + node.name + ">")
      }
  }
}

///|
fn sanitizer_escaped_start_tag_for(node : Node) -> String {
  node.source_start_tag.unwrap_or(serialize_start_tag_unchecked(node, '"'))
}

///|
fn insert_sanitized_escape_text(
  parent : Node,
  index : Int,
  value : String,
) -> Unit {
  let escaped = text(value)
  escaped.parent = Some(parent)
  parent.children.insert(index, escaped)
}

///|
fn escape_child_at(
  parent : Node,
  index : Int,
  policy : SanitizationPolicy,
  observer : SanitizeTransformObserver?,
) -> Int raise HtmlError {
  let child = parent.children[index]
  let start_tag = sanitizer_escaped_start_tag_for(child)
  let end_tag = sanitizer_escaped_end_tag_for(child)
  sanitize_container_children(child, policy, observer)
  ignore(parent.children.remove(index))
  if child.parent is Some(current_parent) &&
    physical_equal(parent, current_parent) {
    child.parent = None
  }
  let mut inserted = 0
  insert_sanitized_escape_text(parent, index + inserted, start_tag)
  inserted += 1
  while !child.children.is_empty() {
    let grandchild = child.children[0]
    ignore(child.children.remove(0))
    grandchild.parent = Some(parent)
    parent.children.insert(index + inserted, grandchild)
    inserted += 1
  }
  match end_tag {
    Some(value) => {
      insert_sanitized_escape_text(parent, index + inserted, value)
      inserted += 1
    }
    None => ()
  }
  inserted
}

///|
fn sanitize_node_name(node : Node) -> String {
  lower_ascii(node.name)
}

///|
fn sanitize_namespace_is_foreign(node : Node) -> Bool {
  match node.ns {
    Some(ns) => ns != "html"
    None => false
  }
}

///|
fn node_is_effectively_foreign(node : Node) -> Bool {
  let mut current = Some(node)
  while current is Some(current_node) {
    if sanitize_namespace_is_foreign(current_node) {
      return true
    }
    match current_node.kind {
      Element =>
        match sanitize_node_name(current_node) {
          "math" | "svg" => return true
          _ => ()
        }
      _ => ()
    }
    current = current_node.parent
  }
  false
}

///|
fn is_active_foreign_mutation_tag(name : String) -> Bool {
  match name {
    "animate" | "annotation-xml" | "foreignobject" | "set" => true
    _ => false
  }
}

///|
fn sanitize_node_is_active_foreign_content(node : Node) -> Bool {
  is_active_foreign_mutation_tag(sanitize_node_name(node)) &&
  node_is_effectively_foreign(node)
}

///|
fn attr_name_is_dangerous(name : StringView) -> Bool {
  let normalized = lower_ascii(name)
  normalized.has_prefix("on") ||
  normalized == "srcdoc" ||
  string_contains_char(normalized, ':')
}

///|
fn policy_allows_attribute(
  policy : SanitizationPolicy,
  tag_name : String,
  attr_name : String,
) -> Bool {
  if attr_name_is_dangerous(attr_name) {
    return false
  }
  if tag_name == "a" && attr_name == "rel" && !policy.force_link_rel.is_empty() {
    return true
  }
  match policy.allowed_attributes.get(tag_name) {
    Some(attrs) if attrs.contains(attr_name) => true
    _ =>
      match policy.allowed_attributes.get("*") {
        Some(attrs) => attrs.contains(attr_name)
        None => false
      }
  }
}

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
    match value.get_char(pos) {
      Some(ch) if is_ascii_url_boundary(ch) => return None
      Some(':') =>
        if saw_scheme_char {
          return Some(out.to_string())
        } else {
          return None
        }
      Some(ch) if is_url_ignored_scheme_char(ch) => pos += ch.utf16_len()
      Some(ch) => {
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
      None => return None
    }
  }
  None
}

///|
fn url_scheme_prefix_is_valid(value : StringView, end : Int) -> Bool {
  let mut pos = 0
  let mut saw_scheme_char = false
  while pos < end {
    match value.get_char(pos) {
      Some(ch) if is_url_ignored_scheme_char(ch) => pos += ch.utf16_len()
      Some(ch) => {
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
      None => return false
    }
  }
  saw_scheme_char
}

///|
fn has_invalid_scheme_like_prefix(value : StringView) -> Bool {
  let mut pos = 0
  while pos < value.length() {
    match value.get_char(pos) {
      Some(':') =>
        if pos == 0 {
          return false
        } else {
          return !url_scheme_prefix_is_valid(value, pos)
        }
      Some(ch) if is_ascii_url_boundary(ch) => return false
      Some(ch) => pos += ch.utf16_len()
      None => break
    }
  }
  false
}

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
        guard value.get_view(start=start + 1, end=pos) is Some(host) else {
          return None
        }
        return Some(lower_ascii(host))
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
        return Some(lower_ascii(host))
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
    Some(lower_ascii(host))
  }
}

///|
fn extract_absolute_url_host(value : StringView) -> String? {
  guard extract_url_scheme(value) is Some(_) else { return None }
  let mut pos = 0
  while pos < value.length() {
    match value.get_char(pos) {
      Some(':') => {
        let after_colon = pos + 1
        if !(value.get_char(after_colon) is Some('/')) ||
          !(value.get_char(after_colon + 1) is Some('/')) {
          return None
        }
        let authority_start = after_colon + 2
        let authority_end = url_authority_end(value, authority_start)
        return extract_authority_host(value, authority_start, authority_end)
      }
      Some(ch) => pos += ch.utf16_len()
      None => break
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
  let out = StringBuilder::new(size_hint=bytes.length())
  for index in 0..<bytes.length() {
    let byte = bytes[index]
    if url_proxy_query_byte_is_safe(byte) {
      out.write_char(byte.to_char())
    } else {
      write_percent_encoded_byte(out, byte)
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
    if normalized == "" {
      return None
    }
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
fn split_srcset_candidate(candidate : StringView) -> (StringView, StringView) {
  let mut pos = 0
  while pos < candidate.length() {
    match candidate.get_char(pos) {
      Some(ch) if is_html_whitespace_char(ch) => {
        let url = candidate.get_view(start=0, end=pos).unwrap_or(candidate)
        let descriptor = candidate
          .get_view(start=pos, end=candidate.length())
          .map(fn(view) { view.trim() })
          .unwrap_or("")
        return (url, descriptor)
      }
      Some(ch) => pos += ch.utf16_len()
      None => break
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
    match view.get_char(pos) {
      Some(',') => {
        match view.get_view(start~, end=pos) {
          Some(candidate) =>
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
          None => ()
        }
        pos += 1
        start = pos
      }
      Some(ch) => pos += ch.utf16_len()
      None => break
    }
  }
  match view.get_view(start~, end=view.length()) {
    Some(candidate) =>
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
    None => ()
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
    match view.get_char(pos) {
      Some(ch) if is_html_whitespace_char(ch) => {
        match view.get_view(start~, end=pos) {
          Some(token) =>
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
          None => ()
        }
        pos += ch.utf16_len()
        start = pos
      }
      Some(ch) => pos += ch.utf16_len()
      None => break
    }
  }
  match view.get_view(start~, end=view.length()) {
    Some(token) =>
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
    None => ()
  }
  if out.is_empty() {
    None
  } else {
    Some(out.join(" "))
  }
}

///|
fn is_srcset_like_attr(name : String) -> Bool {
  name == "srcset" || name == "imagesrcset"
}

///|
fn is_space_separated_url_list_attr(name : String) -> Bool {
  name == "ping" || name == "attributionsrc"
}

///|
fn is_single_url_like_attr(name : String) -> Bool {
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
fn is_foreign_url_function_like_attr(name : String) -> Bool {
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

///|
fn is_invisible_unicode_char(ch : Char) -> Bool {
  let code = ch.to_int()
  code == 0x061C ||
  (code >= 0x200B && code <= 0x200F) ||
  (code >= 0x202A && code <= 0x202E) ||
  (code >= 0x2060 && code <= 0x2069) ||
  (code >= 0xFE00 && code <= 0xFE0F) ||
  code == 0xFEFF ||
  (code >= 0xE000 && code <= 0xF8FF) ||
  (code >= 0xE0100 && code <= 0xE01EF) ||
  (code >= 0xF0000 && code <= 0xFFFFD) ||
  (code >= 0x100000 && code <= 0x10FFFD)
}

///|
fn strip_invisible_unicode(value : String) -> String {
  let out = StringBuilder::new(size_hint=value.length())
  let mut changed = false
  for ch in value {
    if is_invisible_unicode_char(ch) {
      changed = true
    } else {
      out.write_char(ch)
    }
  }
  if changed {
    out.to_string()
  } else {
    value
  }
}

///|
fn sanitized_text_node_data(
  node : Node,
  policy : SanitizationPolicy,
) -> String? {
  if policy.strip_invisible_unicode && node.data != "" {
    let stripped = strip_invisible_unicode(node.data)
    if stripped != node.data {
      Some(stripped)
    } else {
      None
    }
  } else {
    None
  }
}

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
    match value.get_char(pos) {
      Some('\\') => return None
      Some('/') if value.get_char(pos + 1) is Some('*') => {
        pos += 2
        let mut closed = false
        while pos < value.length() {
          if value.get_char(pos) is Some('*') &&
            value.get_char(pos + 1) is Some('/') {
            pos += 2
            closed = true
            break
          }
          match value.get_char(pos) {
            Some(ch) => pos += ch.utf16_len()
            None => break
          }
        }
        if !closed {
          return None
        }
      }
      Some(ch) if is_url_ignored_scheme_char(ch) => pos += ch.utf16_len()
      Some(ch) => {
        if ch.is_ascii_uppercase() {
          out.write_char(ch.to_ascii_lowercase())
        } else {
          out.write_char(ch)
        }
        pos += ch.utf16_len()
      }
      None => break
    }
  }
  Some(out.to_string())
}

///|
fn css_value_may_load_external_resource(value : StringView) -> Bool {
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
    match value.get_char(pos) {
      Some(ch) if ch == needle => return Some(pos)
      Some(ch) => pos += ch.utf16_len()
      None => break
    }
  }
  None
}

///|
fn css_next_url_function(value : StringView, start : Int) -> Int? {
  let mut pos = start
  while pos < value.length() {
    if starts_with_case_insensitive(value, pos, "url(") {
      return Some(pos)
    }
    match value.get_char(pos) {
      Some(ch) => pos += ch.utf16_len()
      None => break
    }
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
        match value.get_view(start=pos, end=url_start) {
          Some(prefix) => write_string_view(out, prefix)
          None => return None
        }
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
            guard value.get_view(start=url_start, end=url_end) is Some(raw) else {
              return None
            }
            raw
          }
          _ => {
            let url_start = cursor
            guard css_find_char(value, cursor, ')') is Some(url_end) else {
              return None
            }
            cursor = url_end
            guard value.get_view(start=url_start, end=url_end) is Some(raw) else {
              return None
            }
            let raw = raw.trim()
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
        match value.get_view(start=pos, end=value.length()) {
          Some(rest) => write_string_view(out, rest)
          None => return None
        }
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
    match declaration.get_char(pos) {
      Some(':') => return Some(pos)
      Some(ch) => pos += ch.utf16_len()
      None => break
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
  guard declaration.get_view(start=0, end=colon) is Some(prop_view) else {
    return None
  }
  let prop = lower_ascii(prop_view.trim())
  if !is_valid_css_property_name(prop) ||
    !policy.allowed_css_properties.contains(prop) {
    return None
  }
  guard declaration.get_view(start=colon + 1, end=declaration.length())
    is Some(value_view) else {
    return None
  }
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
    match view.get_char(pos) {
      Some(';') => {
        match view.get_view(start~, end=pos) {
          Some(declaration) =>
            match sanitize_style_declaration(declaration, policy, tag_name) {
              Some(part) => parts.push(part)
              None => ()
            }
          None => ()
        }
        pos += 1
        start = pos
      }
      Some(ch) => pos += ch.utf16_len()
      None => break
    }
  }
  match view.get_view(start~, end=view.length()) {
    Some(declaration) =>
      match sanitize_style_declaration(declaration, policy, tag_name) {
        Some(part) => parts.push(part)
        None => ()
      }
    None => ()
  }
  if parts.is_empty() {
    None
  } else {
    Some(parts.join("; "))
  }
}

///|
fn sanitize_attribute_value(
  policy : SanitizationPolicy,
  tag_name : String,
  attr_name : String,
  value : String,
  effectively_foreign? : Bool = false,
) -> String? {
  if effectively_foreign &&
    is_foreign_url_function_like_attr(attr_name) &&
    css_value_may_load_external_resource(value) {
    sanitize_foreign_url_function_attribute_value(
      policy, tag_name, attr_name, value,
    )
  } else if is_srcset_like_attr(attr_name) {
    sanitize_srcset_attribute_value(policy, tag_name, attr_name, value)
  } else if is_space_separated_url_list_attr(attr_name) {
    sanitize_space_separated_url_list_attribute_value(
      policy, tag_name, attr_name, value,
    )
  } else if is_single_url_like_attr(attr_name) {
    sanitize_single_url_attribute_value(policy, tag_name, attr_name, value)
  } else if attr_name == "style" {
    sanitize_inline_style_value(policy, tag_name, value)
  } else {
    Some(value)
  }
}

///|
fn push_html_whitespace_tokens(
  tokens : Array[String],
  value : StringView,
) -> Unit {
  let mut token_start = 0
  let mut pos = 0
  while pos < value.length() {
    match value.get_char(pos) {
      Some(ch) if is_html_whitespace_char(ch) => {
        if token_start < pos {
          match value.get_view(start=token_start, end=pos) {
            Some(token) => push_unique_string(tokens, lower_ascii(token.trim()))
            None => ()
          }
        }
        pos += ch.utf16_len()
        token_start = pos
      }
      Some(ch) => pos += ch.utf16_len()
      None => break
    }
  }
  if token_start < value.length() {
    match value.get_view(start=token_start, end=value.length()) {
      Some(token) => push_unique_string(tokens, lower_ascii(token.trim()))
      None => ()
    }
  }
}

///|
fn merge_forced_link_rel(
  node : Node,
  policy : SanitizationPolicy,
  observer : SanitizeTransformObserver?,
) -> Unit {
  if policy.force_link_rel.is_empty() {
    return
  }
  let tokens : Array[String] = []
  match node.attrs.get("rel") {
    Some(Some(value)) => push_html_whitespace_tokens(tokens, value)
    _ => ()
  }
  for token in policy.force_link_rel {
    push_unique_string(tokens, token)
  }
  let normalized = tokens.join(" ")
  if node.attrs.get("rel") != Some(Some(normalized)) {
    sanitize_observer_event(
      observer,
      "Merged tokens into attribute 'rel' on <a>",
      Some(node),
    )
  }
  node.attrs["rel"] = Some(normalized)
}

///|
fn sanitize_meta_refresh_content(
  node : Node,
  policy : SanitizationPolicy,
  observer : SanitizeTransformObserver?,
) -> Unit raise HtmlError {
  match node.attrs.get("http-equiv") {
    Some(Some(value)) if lower_ascii(value[:].trim()) == "refresh" &&
      node.attrs.contains("content") => {
      sanitize_report_unsafe(
        policy,
        observer,
        "Unsafe URL in attribute 'content' (meta refresh)",
        Some(node),
      )
      node.attrs.remove("content")
    }
    _ => ()
  }
}

///|
fn sanitize_forbidden_attr_pattern(attr_name : String) -> String? {
  if attr_name == "srcdoc" {
    Some("srcdoc")
  } else if string_view_contains_char(attr_name, ':') {
    Some("*:*")
  } else if attr_name.has_prefix("on") {
    Some("on*")
  } else {
    None
  }
}

///|
fn sanitize_url_like_attr_for_report(
  attr_name : String,
  raw_value : String?,
  effectively_foreign : Bool,
) -> Bool {
  let foreign_url_function_loads = match raw_value {
    Some(value) => css_value_may_load_external_resource(value)
    None => false
  }
  is_single_url_like_attr(attr_name) ||
  is_srcset_like_attr(attr_name) ||
  is_space_separated_url_list_attr(attr_name) ||
  (
    effectively_foreign &&
    is_foreign_url_function_like_attr(attr_name) &&
    foreign_url_function_loads
  )
}

///|
fn sanitize_dropped_attr_report_message(
  policy : SanitizationPolicy,
  tag_name : String,
  attr_name : String,
  raw_value : String?,
  effectively_foreign : Bool,
) -> String {
  if attr_name == "style" {
    "Unsafe inline style in attribute 'style'"
  } else if tag_name == "base" && attr_name == "href" {
    "Unsafe URL in attribute 'href' (base tag)"
  } else if sanitize_url_like_attr_for_report(
      attr_name, raw_value, effectively_foreign,
    ) {
    let suffix = match raw_value {
      Some(_) =>
        match policy.url_policy.lookup_rule(tag_name, attr_name) {
          None => " (no rule)"
          Some(_) => ""
        }
      None => ""
    }
    "Unsafe URL in attribute '" + attr_name + "'" + suffix
  } else {
    "Unsafe attribute '" + attr_name + "' on <" + tag_name + "> was dropped"
  }
}

///|
fn sanitize_element_attributes(
  node : Node,
  policy : SanitizationPolicy,
  observer : SanitizeTransformObserver?,
) -> Unit raise HtmlError {
  let tag_name = sanitize_node_name(node)
  let effectively_foreign = node_is_effectively_foreign(node)
  if policy.strip_invisible_unicode {
    let stripped_attr_names : Array[String] = []
    for key in node.attrs.keys() {
      match node.attrs.get(key) {
        Some(Some(raw_value)) => {
          let stripped = strip_invisible_unicode(raw_value)
          if stripped != raw_value {
            node.attrs[key] = Some(stripped)
            stripped_attr_names.push(key)
          }
        }
        _ => ()
      }
    }
    if !stripped_attr_names.is_empty() {
      sanitize_report_unsafe(
        policy,
        observer,
        "Stripped invisible Unicode from attribute(s): " +
        stripped_attr_names.join(", "),
        Some(node),
      )
    }
  }
  let keys = node.attrs.keys().to_array()
  for key in keys {
    let attr_name = lower_ascii(key)
    match sanitize_forbidden_attr_pattern(attr_name) {
      Some(pattern) => {
        sanitize_report_unsafe(
          policy,
          observer,
          "Unsafe attribute '" +
          attr_name +
          "' (matched forbidden pattern '" +
          pattern +
          "')",
          Some(node),
        )
        node.attrs.remove(key)
        continue
      }
      None => ()
    }
    if !policy_allows_attribute(policy, tag_name, attr_name) {
      sanitize_report_unsafe(
        policy,
        observer,
        "Unsafe attribute '" + attr_name + "' (not allowed)",
        Some(node),
      )
      node.attrs.remove(key)
    } else {
      match node.attrs.get(key) {
        Some(Some(raw_value)) => {
          let value = raw_value
          match
            sanitize_attribute_value(
              policy,
              tag_name,
              attr_name,
              value,
              effectively_foreign~,
            ) {
            Some(cleaned) =>
              if cleaned != raw_value || attr_name != key {
                node.attrs.remove(key)
                node.attrs[attr_name] = Some(cleaned)
              }
            None => {
              sanitize_report_unsafe(
                policy,
                observer,
                sanitize_dropped_attr_report_message(
                  policy,
                  tag_name,
                  attr_name,
                  Some(raw_value),
                  effectively_foreign,
                ),
                Some(node),
              )
              node.attrs.remove(key)
            }
          }
        }
        Some(None) if attr_name == "href" ||
          attr_name == "src" ||
          attr_name == "style" ||
          is_single_url_like_attr(attr_name) ||
          is_srcset_like_attr(attr_name) ||
          is_space_separated_url_list_attr(attr_name) => {
          sanitize_report_unsafe(
            policy,
            observer,
            sanitize_dropped_attr_report_message(
              policy,
              tag_name,
              attr_name,
              None,
              effectively_foreign,
            ),
            Some(node),
          )
          node.attrs.remove(key)
        }
        Some(value) =>
          if attr_name != key {
            node.attrs.remove(key)
            node.attrs[attr_name] = value
          }
        None => ()
      }
    }
  }
  if tag_name == "meta" {
    sanitize_meta_refresh_content(node, policy, observer)
  }
  if tag_name == "a" {
    merge_forced_link_rel(node, policy, observer)
  }
}

///|
fn rawtext_serialization_element_name(node : Node) -> String? {
  let name = sanitize_node_name(node)
  match name {
    "script" | "style" => Some(name)
    _ => None
  }
}

///|
fn is_math_text_integration_child_exception(node : Node) -> Bool {
  if node.kind != Element {
    false
  } else {
    match node.ns {
      Some("math") =>
        match sanitize_node_name(node) {
          "mglyph" | "malignmark" => true
          _ => false
        }
      _ => false
    }
  }
}

///|
fn foreign_text_integration_namespace(node : Node) -> String? {
  let name = sanitize_node_name(node)
  match node.ns {
    Some("svg") =>
      match name {
        "desc" | "title" => Some("svg")
        _ => None
      }
    Some("math") =>
      match name {
        "mi" | "mn" | "mo" | "ms" | "mtext" => Some("math")
        _ => None
      }
    _ => None
  }
}

///|
fn sanitize_foreign_text_integration_children(
  node : Node,
  policy : SanitizationPolicy,
  observer : SanitizeTransformObserver?,
) -> Bool raise HtmlError {
  guard foreign_text_integration_namespace(node) is Some(ns) else {
    return false
  }
  let original = node.children.copy()
  node.children.clear()
  for child in original {
    if child.parent is Some(parent) && physical_equal(parent, node) {
      child.parent = None
    }
    match child.kind {
      Text =>
        match sanitized_text_node_data(child, policy) {
          Some(stripped) => {
            sanitize_observer_event(
              observer,
              "Stripped invisible Unicode from text node",
              Some(child),
            )
            node.append_child(text(stripped))
          }
          None => node.append_child(child)
        }
      Element if ns == "math" && is_math_text_integration_child_exception(child) => {
        let child_name = sanitize_node_name(child)
        if policy.allowed_tags.contains(child_name) &&
          !policy.drop_content_tags.contains(child_name) {
          sanitize_element_attributes(child, policy, observer)
          node.append_child(child)
        }
      }
      _ =>
        sanitize_report_unsafe(
          policy,
          observer,
          "Unsafe HTML child inside foreign integration point <" +
          sanitize_node_name(node) +
          "> was dropped",
          Some(child),
        )
    }
  }
  true
}

///|
fn sanitize_rawtext_element_children(
  node : Node,
  policy : SanitizationPolicy,
  observer : SanitizeTransformObserver?,
) -> Bool raise HtmlError {
  guard rawtext_serialization_element_name(node) is Some(tag_name) else {
    return false
  }
  let original = node.children.copy()
  node.children.clear()
  let text_children : Array[Node] = []
  let text_parts : Array[String] = []
  let mut text_changed = false
  for child in original {
    if child.parent is Some(parent) && physical_equal(parent, node) {
      child.parent = None
    }
    match child.kind {
      Text => {
        let data = if policy.strip_invisible_unicode {
          let stripped = strip_invisible_unicode(child.data)
          if stripped != child.data {
            text_changed = true
            sanitize_observer_event(
              observer,
              "Stripped invisible Unicode from text node",
              Some(child),
            )
          }
          stripped
        } else {
          child.data
        }
        text_children.push(child)
        text_parts.push(data)
      }
      _ =>
        sanitize_report_unsafe(
          policy,
          observer,
          "Unsafe non-text child inside <" + tag_name + "> was dropped",
          Some(child),
        )
    }
  }
  if text_children.is_empty() {
    return true
  }
  let combined_text = text_parts.join("")
  let sanitized_text = neutralize_rawtext_end_tag_sequences(
    combined_text, tag_name,
  )
  if sanitized_text != combined_text {
    sanitize_report_unsafe(
      policy,
      observer,
      "Unsafe raw text inside <" +
      tag_name +
      "> contains a closing tag sequence",
      Some(node),
    )
  }
  if tag_name == "style" &&
    sanitized_text != "" &&
    css_value_may_load_external_resource(sanitized_text) {
    sanitize_report_unsafe(
      policy,
      observer,
      "Unsafe CSS inside <style> contains resource-loading constructs",
      Some(node),
    )
    return true
  }
  if sanitized_text == combined_text && !text_changed {
    for child in text_children {
      node.append_child(child)
    }
  } else if sanitized_text != "" {
    node.append_child(text(sanitized_text))
  }
  true
}

///|
fn sanitize_container_children(
  parent : Node,
  policy : SanitizationPolicy,
  observer : SanitizeTransformObserver?,
) -> Unit raise HtmlError {
  let mut index = 0
  while index < parent.children.length() {
    let child = parent.children[index]
    match child.kind {
      Text if child.sanitize_escape_only =>
        if policy.disallowed_tag_handling == Escape {
          child.clear_sanitize_escape_only()
          index += 1
        } else {
          remove_child_at(parent, index)
        }
      Text => {
        match sanitized_text_node_data(child, policy) {
          Some(stripped) => {
            sanitize_observer_event(
              observer,
              "Stripped invisible Unicode from text node",
              Some(child),
            )
            ignore(parent.replace_child(text(stripped), child))
          }
          None => ()
        }
        index += 1
      }
      Comment =>
        if policy.drop_comments {
          sanitize_observer_event(observer, "Dropped comment", Some(child))
          remove_child_at(parent, index)
        } else {
          index += 1
        }
      Doctype =>
        if policy.drop_doctype {
          sanitize_observer_event(observer, "Dropped doctype", Some(child))
          remove_child_at(parent, index)
        } else {
          index += 1
        }
      Element => {
        let tag_name = sanitize_node_name(child)
        if policy.drop_foreign_namespaces && node_is_effectively_foreign(child) {
          sanitize_report_unsafe(
            policy,
            observer,
            "Unsafe tag '" + tag_name + "' (foreign namespace)",
            Some(child),
          )
          remove_child_at(parent, index)
        } else if !policy.drop_foreign_namespaces &&
          sanitize_node_is_active_foreign_content(child) {
          sanitize_report_unsafe(
            policy,
            observer,
            "Unsafe tag '" + tag_name + "' (active foreign content)",
            Some(child),
          )
          remove_child_at(parent, index)
        } else if policy.drop_content_tags.contains(tag_name) {
          sanitize_report_unsafe(
            policy,
            observer,
            "Unsafe tag '" + tag_name + "' (dropped content)",
            Some(child),
          )
          remove_child_at(parent, index)
        } else if !policy.allowed_tags.contains(tag_name) {
          sanitize_report_unsafe(
            policy,
            observer,
            "Unsafe tag '" + tag_name + "' (not allowed)",
            Some(child),
          )
          match policy.disallowed_tag_handling {
            Drop => remove_child_at(parent, index)
            Escape => {
              let inserted = escape_child_at(parent, index, policy, observer)
              index += inserted
            }
            Unwrap => {
              sanitize_container_children(child, policy, observer)
              let inserted = unwrap_child_at(parent, index)
              index += inserted
            }
          }
        } else {
          sanitize_element_attributes(child, policy, observer)
          if sanitize_foreign_text_integration_children(child, policy, observer) {
            ()
          } else if !sanitize_rawtext_element_children(child, policy, observer) {
            sanitize_container_children(child, policy, observer)
          }
          index += 1
        }
      }
      Document | Fragment => {
        sanitize_container_children(child, policy, observer)
        index += 1
      }
    }
  }
}

///|
/// Sanitize a DOM node in place and return the sanitized root.
///
/// When no policy is supplied, document roots use the document policy and other
/// roots use the fragment policy.
pub fn sanitize_dom(
  node : Node,
  policy? : SanitizationPolicy,
) -> Node raise HtmlError {
  sanitize_dom_with_observer(node, policy, None)
}

///|
fn sanitize_dom_with_observer(
  node : Node,
  policy : SanitizationPolicy?,
  observer : SanitizeTransformObserver?,
) -> Node raise HtmlError {
  let policy = match policy {
    Some(value) => value
    None =>
      if node.kind == Document {
        default_document_sanitization_policy()
      } else {
        default_sanitization_policy()
      }
  }
  if node_is_sanitize_container(node) {
    sanitize_container_children(node, policy, observer)
    node
  } else {
    let wrapper = fragment(children=[node])
    sanitize_container_children(wrapper, policy, observer)
    if wrapper.children.length() == 1 {
      let only = wrapper.children[0]
      ignore(wrapper.children.remove(0))
      only.parent = None
      only
    } else {
      wrapper
    }
  }
}
