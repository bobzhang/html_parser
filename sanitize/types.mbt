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
  priv selector_limits : @sel.SelectorLimits
  priv unsafe_handling : UnsafeHandling
  priv security_errors : Array[@core.ParseError]
} derive(Debug)
