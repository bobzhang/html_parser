///|
pub(all) enum DisallowedTagHandling {
  Unwrap
  Escape
  Drop
} derive(Debug, Eq)

///|
pub(all) enum UnsafeHandling {
  Strip
  Raise
  Collect
} derive(Debug, Eq)

///|
pub(all) enum UrlHandling {
  UrlAllow
  UrlStrip
} derive(Debug, Eq)

///|
pub struct UrlRule {
  priv allow_fragment : Bool
  priv resolve_protocol_relative : String?
  priv allowed_schemes : Set[String]
  priv handling : UrlHandling?
  priv allow_relative : Bool?
} derive(Debug)

///|
pub struct UrlPolicyRule {
  priv tag : String
  priv attr : String
  priv rule : UrlRule
} derive(Debug)

///|
pub struct UrlPolicy {
  priv default_handling : UrlHandling
  priv default_allow_relative : Bool
  priv allow_rules : Map[String, UrlRule]
} derive(Debug)

///|
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
  priv unsafe_handling : UnsafeHandling
  priv security_errors : Array[ParseError]
} derive(Debug)

///|
fn sanitized_string_set(values : Array[String]) -> Set[String] {
  let set : Set[String] = Set::new(capacity=values.length())
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
pub fn UrlRule::new(
  allowed_schemes? : Array[String] = [],
  allow_fragment? : Bool = true,
  resolve_protocol_relative? : String? = Some("https"),
  handling? : UrlHandling,
  allow_relative? : Bool,
) -> UrlRule {
  {
    allow_fragment,
    resolve_protocol_relative: resolve_protocol_relative.map(fn(scheme) {
      lower_ascii(scheme[:].trim())
    }),
    allowed_schemes: sanitized_string_set(allowed_schemes),
    handling,
    allow_relative,
  }
}

///|
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
pub fn UrlPolicy::new(
  default_handling? : UrlHandling = UrlAllow,
  default_allow_relative? : Bool = true,
  allow_rules? : Array[UrlPolicyRule] = [],
) -> UrlPolicy {
  {
    default_handling,
    default_allow_relative,
    allow_rules: sanitize_url_policy_rules(allow_rules),
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
    unsafe_handling,
    security_errors: [],
  }
}

///|
pub fn SanitizationPolicy::reset_collected_security_errors(
  self : SanitizationPolicy,
) -> Unit {
  self.security_errors.clear()
}

///|
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
pub fn default_sanitization_policy() -> SanitizationPolicy {
  SanitizationPolicy::new(
    default_allowed_tags(),
    allowed_attributes=default_allowed_attributes(),
  )
}

///|
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
) -> Int raise HtmlError {
  let child = parent.children[index]
  let start_tag = serialize_start_tag(child, '"')
  let end_tag = escaped_end_tag_for(child)
  sanitize_container_children(child, policy)
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
  lower_ascii(node.name[:])
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
fn string_contains_url_control(value : StringView) -> Bool {
  for ch in value {
    let code = ch.to_int()
    if code < 0x20 || code == 0x7F {
      return true
    }
  }
  false
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
  value : String,
) -> String? {
  let trimmed = value[:].trim().to_owned()
  if trimmed == "" {
    return None
  } else if string_contains_url_control(trimmed) {
    return None
  } else {
    let handling = rule.handling.unwrap_or(policy.default_handling)
    let allow_relative = rule.allow_relative.unwrap_or(
      policy.default_allow_relative,
    )
    if trimmed.has_prefix("#") {
      if rule.allow_fragment && handling == UrlAllow {
        Some(trimmed)
      } else {
        None
      }
    } else if trimmed.has_prefix("//") {
      match rule.resolve_protocol_relative {
        Some(scheme) if rule.allowed_schemes.contains(scheme) =>
          if handling == UrlAllow {
            Some(scheme + ":" + trimmed)
          } else {
            None
          }
        _ => None
      }
    } else {
      match extract_url_scheme(trimmed) {
        Some(scheme) =>
          if rule.allowed_schemes.contains(scheme) && handling == UrlAllow {
            Some(trimmed)
          } else {
            None
          }
        None =>
          if allow_relative && handling == UrlAllow {
            Some(trimmed)
          } else {
            None
          }
      }
    }
  }
}

///|
fn sanitize_url_attribute_value(
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
        sanitize_url_attribute_value_with_rule(policy.url_policy, rule, value)
      None => Some(value)
    }
  }
}

///|
fn is_unsupported_url_like_attr(name : String) -> Bool {
  match name {
    "srcset"
    | "imagesrcset"
    | "poster"
    | "action"
    | "formaction"
    | "data"
    | "cite"
    | "background"
    | "ping"
    | "attributionsrc" => true
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
      Some('/') if value.get_char(pos + 1) == Some('*') => {
        pos += 2
        let mut closed = false
        while pos < value.length() {
          if value.get_char(pos) == Some('*') &&
            value.get_char(pos + 1) == Some('/') {
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
      string_view_contains(normalized[:], "@import") ||
      string_view_contains(normalized[:], "url(") ||
      string_view_contains(normalized[:], "image-set(") ||
      string_view_contains(normalized[:], "expression(") ||
      string_view_contains(normalized[:], "progid:") ||
      string_view_contains(normalized[:], "alphaimageloader") ||
      string_view_contains(normalized[:], "behavior:") ||
      string_view_contains(normalized[:], "-moz-binding")
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
  if value.is_empty() || css_value_may_load_external_resource(value) {
    return None
  }
  Some(prop + ": " + value.to_owned())
}

///|
fn sanitize_inline_style_value(
  policy : SanitizationPolicy,
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
            match sanitize_style_declaration(declaration, policy) {
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
      match sanitize_style_declaration(declaration, policy) {
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
    None
  } else if is_unsupported_url_like_attr(attr_name) {
    None
  } else if attr_name == "style" {
    sanitize_inline_style_value(policy, value)
  } else {
    sanitize_url_attribute_value(policy, tag_name, attr_name, value)
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
fn merge_forced_link_rel(node : Node, policy : SanitizationPolicy) -> Unit {
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
  node.attrs["rel"] = Some(tokens.join(" "))
}

///|
fn sanitize_meta_refresh_content(
  node : Node,
  policy : SanitizationPolicy,
) -> Unit raise HtmlError {
  match node.attrs.get("http-equiv") {
    Some(Some(value)) if lower_ascii(value[:].trim()) == "refresh" &&
      node.attrs.contains("content") => {
      policy.handle_unsafe(
        "Unsafe URL in attribute 'content' on <meta> refresh was dropped",
      )
      node.attrs.remove("content")
    }
    _ => ()
  }
}

///|
fn sanitize_element_attributes(
  node : Node,
  policy : SanitizationPolicy,
) -> Unit raise HtmlError {
  let tag_name = sanitize_node_name(node)
  let effectively_foreign = node_is_effectively_foreign(node)
  let keys = node.attrs.keys().to_array()
  for key in keys {
    let attr_name = lower_ascii(key[:])
    if !policy_allows_attribute(policy, tag_name, attr_name) {
      policy.handle_unsafe(
        "Unsafe attribute '" +
        attr_name +
        "' on <" +
        tag_name +
        "> was dropped because it is not allowed",
      )
      node.attrs.remove(key)
    } else {
      match node.attrs.get(key) {
        Some(Some(raw_value)) => {
          let value = if policy.strip_invisible_unicode {
            strip_invisible_unicode(raw_value)
          } else {
            raw_value
          }
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
              policy.handle_unsafe(
                "Unsafe attribute '" +
                attr_name +
                "' on <" +
                tag_name +
                "> was dropped",
              )
              node.attrs.remove(key)
            }
          }
        }
        Some(None) if attr_name == "href" ||
          attr_name == "src" ||
          attr_name == "style" ||
          is_unsupported_url_like_attr(attr_name) => {
          policy.handle_unsafe(
            "Unsafe attribute '" +
            attr_name +
            "' on <" +
            tag_name +
            "> was dropped",
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
    sanitize_meta_refresh_content(node, policy)
  }
  if tag_name == "a" {
    merge_forced_link_rel(node, policy)
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
          Some(stripped) => node.append_child(text(stripped))
          None => node.append_child(child)
        }
      Element if ns == "math" && is_math_text_integration_child_exception(child) => {
        let child_name = sanitize_node_name(child)
        if policy.allowed_tags.contains(child_name) &&
          !policy.drop_content_tags.contains(child_name) {
          sanitize_element_attributes(child, policy)
          node.append_child(child)
        }
      }
      _ =>
        policy.handle_unsafe(
          "Unsafe HTML child inside foreign integration point <" +
          sanitize_node_name(node) +
          "> was dropped",
        )
    }
  }
  true
}

///|
fn sanitize_rawtext_element_children(
  node : Node,
  policy : SanitizationPolicy,
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
          }
          stripped
        } else {
          child.data
        }
        text_children.push(child)
        text_parts.push(data)
      }
      _ =>
        policy.handle_unsafe(
          "Unsafe non-text child inside <" + tag_name + "> was dropped",
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
    policy.handle_unsafe(
      "Unsafe raw text inside <" +
      tag_name +
      "> contains a closing tag sequence",
    )
  }
  if tag_name == "style" &&
    sanitized_text != "" &&
    css_value_may_load_external_resource(sanitized_text) {
    policy.handle_unsafe(
      "Unsafe CSS inside <style> contains resource-loading constructs",
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
) -> Unit raise HtmlError {
  let mut index = 0
  while index < parent.children.length() {
    let child = parent.children[index]
    match child.kind {
      Text => {
        match sanitized_text_node_data(child, policy) {
          Some(stripped) => ignore(parent.replace_child(text(stripped), child))
          None => ()
        }
        index += 1
      }
      Comment =>
        if policy.drop_comments {
          policy.handle_unsafe("Unsafe comment was dropped")
          remove_child_at(parent, index)
        } else {
          index += 1
        }
      Doctype =>
        if policy.drop_doctype {
          policy.handle_unsafe("Unsafe doctype was dropped")
          remove_child_at(parent, index)
        } else {
          index += 1
        }
      Element => {
        let tag_name = sanitize_node_name(child)
        if policy.drop_foreign_namespaces && node_is_effectively_foreign(child) {
          policy.handle_unsafe(
            "Unsafe tag '" +
            tag_name +
            "' was dropped because it is in a foreign namespace",
          )
          remove_child_at(parent, index)
        } else if !policy.drop_foreign_namespaces &&
          sanitize_node_is_active_foreign_content(child) {
          policy.handle_unsafe(
            "Unsafe tag '" +
            tag_name +
            "' was dropped because it can mutate foreign content",
          )
          remove_child_at(parent, index)
        } else if policy.drop_content_tags.contains(tag_name) {
          policy.handle_unsafe(
            "Unsafe tag '" + tag_name + "' was dropped with its content",
          )
          remove_child_at(parent, index)
        } else if !policy.allowed_tags.contains(tag_name) {
          policy.handle_unsafe(
            "Unsafe tag '" +
            tag_name +
            "' was dropped because it is not allowed",
          )
          match policy.disallowed_tag_handling {
            Drop => remove_child_at(parent, index)
            Escape => {
              let inserted = escape_child_at(parent, index, policy)
              index += inserted
            }
            Unwrap => {
              sanitize_container_children(child, policy)
              let inserted = unwrap_child_at(parent, index)
              index += inserted
            }
          }
        } else {
          sanitize_element_attributes(child, policy)
          if sanitize_foreign_text_integration_children(child, policy) {
            ()
          } else if !sanitize_rawtext_element_children(child, policy) {
            sanitize_container_children(child, policy)
          }
          index += 1
        }
      }
      Document | Fragment => {
        sanitize_container_children(child, policy)
        index += 1
      }
    }
  }
}

///|
pub fn sanitize_dom(
  node : Node,
  policy? : SanitizationPolicy,
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
    sanitize_container_children(node, policy)
    node
  } else {
    let wrapper = fragment(children=[node])
    sanitize_container_children(wrapper, policy)
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
