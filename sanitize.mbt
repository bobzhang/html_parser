///|
pub(all) enum DisallowedTagHandling {
  Unwrap
  Drop
} derive(Debug, Eq)

///|
pub struct SanitizationPolicy {
  priv allowed_tags : Set[String]
  priv allowed_attributes : Map[String, Set[String]]
  priv drop_comments : Bool
  priv drop_doctype : Bool
  priv drop_foreign_namespaces : Bool
  priv drop_content_tags : Set[String]
  priv disallowed_tag_handling : DisallowedTagHandling
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
pub fn SanitizationPolicy::new(
  allowed_tags : Array[String],
  allowed_attributes? : Map[String, Array[String]] = {},
  drop_comments? : Bool = true,
  drop_doctype? : Bool = true,
  drop_foreign_namespaces? : Bool = true,
  drop_content_tags? : Array[String] = ["script", "style"],
  disallowed_tag_handling? : DisallowedTagHandling = Unwrap,
) -> SanitizationPolicy {
  {
    allowed_tags: sanitized_string_set(allowed_tags),
    allowed_attributes: sanitize_allowed_attributes(allowed_attributes),
    drop_comments,
    drop_doctype,
    drop_foreign_namespaces,
    drop_content_tags: sanitized_string_set(drop_content_tags),
    disallowed_tag_handling,
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
fn sanitize_url_attribute_value(
  tag_name : String,
  attr_name : String,
  value : String,
) -> String? {
  let trimmed = value[:].trim().to_owned()
  if trimmed == "" {
    return None
  }
  if tag_name == "a" && attr_name == "href" {
    if trimmed.has_prefix("#") {
      return Some(trimmed)
    }
    if trimmed.has_prefix("//") {
      return Some("https:" + trimmed)
    }
    match extract_url_scheme(trimmed) {
      Some("http") | Some("https") | Some("mailto") | Some("tel") =>
        Some(trimmed)
      Some(_) => None
      None => Some(trimmed)
    }
  } else if tag_name == "img" && attr_name == "src" {
    if trimmed.has_prefix("#") || trimmed.has_prefix("//") {
      return None
    }
    match extract_url_scheme(trimmed) {
      Some(_) => None
      None => Some(trimmed)
    }
  } else {
    Some(value)
  }
}

///|
fn sanitize_element_attributes(
  node : Node,
  policy : SanitizationPolicy,
) -> Unit {
  let tag_name = sanitize_node_name(node)
  let keys = node.attrs.keys().to_array()
  for key in keys {
    let attr_name = lower_ascii(key[:])
    if !policy_allows_attribute(policy, tag_name, attr_name) {
      node.attrs.remove(key)
    } else {
      match node.attrs.get(key) {
        Some(Some(value)) =>
          match sanitize_url_attribute_value(tag_name, attr_name, value) {
            Some(cleaned) =>
              if cleaned != value || attr_name != key {
                node.attrs.remove(key)
                node.attrs[attr_name] = Some(cleaned)
              }
            None => node.attrs.remove(key)
          }
        Some(None) if attr_name == "href" || attr_name == "src" =>
          node.attrs.remove(key)
        Some(value) =>
          if attr_name != key {
            node.attrs.remove(key)
            node.attrs[attr_name] = value
          }
        None => ()
      }
    }
  }
}

///|
fn sanitize_container_children(
  parent : Node,
  policy : SanitizationPolicy,
) -> Unit {
  let mut index = 0
  while index < parent.children.length() {
    let child = parent.children[index]
    match child.kind {
      Text => index += 1
      Comment =>
        if policy.drop_comments {
          remove_child_at(parent, index)
        } else {
          index += 1
        }
      Doctype =>
        if policy.drop_doctype {
          remove_child_at(parent, index)
        } else {
          index += 1
        }
      Element => {
        let tag_name = sanitize_node_name(child)
        if policy.drop_foreign_namespaces &&
          sanitize_namespace_is_foreign(child) {
          remove_child_at(parent, index)
        } else if policy.drop_content_tags.contains(tag_name) {
          remove_child_at(parent, index)
        } else if !policy.allowed_tags.contains(tag_name) {
          match policy.disallowed_tag_handling {
            Drop => remove_child_at(parent, index)
            Unwrap => {
              sanitize_container_children(child, policy)
              let inserted = unwrap_child_at(parent, index)
              index += inserted
            }
          }
        } else {
          sanitize_element_attributes(child, policy)
          sanitize_container_children(child, policy)
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
pub fn sanitize_dom(node : Node, policy? : SanitizationPolicy) -> Node {
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
