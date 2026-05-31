///|
fn sanitized_string_set(values : Array[String]) -> Set[String] {
  let set : Set[String] = Set::default()
  for value in values {
    let normalized = @syn.lower_ascii(value[:].trim())
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
/// Append `value` to `values` if it is non-empty and absent.
///
/// Existing order is preserved, making this suitable for normalized allowlists
/// and token merges where duplicate entries should be ignored.
fn push_unique_string(values : Array[String], value : String) -> Unit {
  if value != "" && !string_array_contains(values, value) {
    values.push(value)
  }
}

///|
fn sanitized_string_list(values : Array[String]) -> Array[String] {
  let out : Array[String] = []
  for value in values {
    push_unique_string(out, @syn.lower_ascii(value[:].trim()))
  }
  out
}

///|
fn sanitize_allowed_attributes(
  attrs : Map[String, Array[String]],
) -> Map[String, Set[String]] {
  let normalized : Map[String, Set[String]] = {}
  for tag, values in attrs {
    let tag_name = @syn.lower_ascii(tag[:].trim())
    if tag_name != "" {
      normalized[tag_name] = sanitized_string_set(values)
    }
  }
  normalized
}

///|
/// Construct a URL filter from a callback.
pub fn UrlFilter::UrlFilter(
  callback : (String, String, String) -> String?,
) -> UrlFilter {
  { callback, }
}

///|
/// Construct a URL proxy descriptor.
pub fn UrlProxy::UrlProxy(
  url : StringView,
  param? : String = "url",
) -> UrlProxy {
  { url: url.to_owned(), param }
}

///|
/// Construct a per-attribute URL validation rule.
///
/// Schemes and hosts are normalized to lowercase. `resolve_protocol_relative`
/// rewrites protocol-relative URLs such as `//example.com` before validation.
pub fn UrlRule::UrlRule(
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
      @syn.lower_ascii(scheme[:].trim())
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
pub fn UrlPolicyRule::UrlPolicyRule(
  tag : StringView,
  attr : StringView,
  rule : UrlRule,
) -> UrlPolicyRule {
  {
    tag: @syn.lower_ascii(tag.trim()),
    attr: @syn.lower_ascii(attr.trim()),
    rule,
  }
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
pub fn UrlPolicy::UrlPolicy(
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
  UrlPolicy(default_handling=UrlStrip, allow_rules=[
    UrlPolicyRule(
      "a",
      "href",
      UrlRule(
        allowed_schemes=["http", "https", "mailto", "tel"],
        handling=UrlAllow,
      ),
    ),
    UrlPolicyRule(
      "img",
      "src",
      UrlRule(
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
pub fn SanitizationPolicy::SanitizationPolicy(
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
  selector_limits? : @sel.SelectorLimits,
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
    selector_limits: selector_limits.unwrap_or(SelectorLimits()),
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
) -> Array[@core.ParseError] {
  self.security_errors.copy()
}

///|
/// Return the selector limits used by this policy.
///
/// Sanitizer transforms use these limits when selector-based hooks are
/// evaluated during sanitization.
pub fn SanitizationPolicy::selector_limits(
  self : SanitizationPolicy,
) -> @sel.SelectorLimits {
  self.selector_limits
}

///|
fn sanitize_allowed_attributes_to_arrays(
  attrs : Map[String, Set[String]],
) -> Map[String, Array[String]] {
  let out : Map[String, Array[String]] = {}
  for tag, values in attrs {
    out[tag] = values.to_array()
  }
  out
}

///|
/// Return a copy of this policy with additional allowed tag names.
///
/// Extra tags are trimmed, ASCII-lowercased, deduplicated, and merged with the
/// existing allowlist. Other policy settings, including URL rules and unsafe
/// handling, are preserved.
pub fn SanitizationPolicy::with_extra_allowed_tags(
  self : SanitizationPolicy,
  extra_tags : Array[String],
) -> SanitizationPolicy {
  let tags = self.allowed_tags.to_array()
  for tag in extra_tags {
    push_unique_string(tags, @syn.lower_ascii(tag[:].trim()))
  }
  SanitizationPolicy(
    tags,
    allowed_attributes=sanitize_allowed_attributes_to_arrays(
      self.allowed_attributes,
    ),
    url_policy=self.url_policy,
    drop_comments=self.drop_comments,
    drop_doctype=self.drop_doctype,
    drop_foreign_namespaces=self.drop_foreign_namespaces,
    drop_content_tags=self.drop_content_tags.to_array(),
    disallowed_tag_handling=self.disallowed_tag_handling,
    force_link_rel=self.force_link_rel.copy(),
    allowed_css_properties=self.allowed_css_properties.to_array(),
    strip_invisible_unicode=self.strip_invisible_unicode,
    selector_limits=self.selector_limits,
    unsafe_handling=self.unsafe_handling,
  )
}

///|
/// Return whether this policy has an exact URL rule for a tag and attribute.
///
/// `tag_name` and `attr_name` should be normalized lowercase names. The default
/// URL handling is not considered a rule; this checks only explicit
/// tag/attribute bindings.
pub fn SanitizationPolicy::has_url_rule(
  self : SanitizationPolicy,
  tag_name : String,
  attr_name : String,
) -> Bool {
  self.url_policy.lookup_rule(tag_name, attr_name) is Some(_)
}

///|
fn SanitizationPolicy::handle_unsafe(
  self : SanitizationPolicy,
  message : String,
) -> Unit raise @core.HtmlError {
  match self.unsafe_handling {
    Strip => ()
    Raise => raise UnsafeHtml(message)
    Collect =>
      self.security_errors.push(
        ParseError("unsafe-html", category="security", message~),
      )
  }
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
  SanitizationPolicy(
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
  SanitizationPolicy(
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
