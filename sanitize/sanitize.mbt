///|
fn is_html_whitespace_char(ch : Char) -> Bool {
  match ch {
    ' ' | '\t' | '\n' | '\r' | '\u{000C}' => true
    _ => false
  }
}

///|
fn string_view_contains(haystack : StringView, needle : StringView) -> Bool {
  if needle.is_empty() || needle.length() > haystack.length() {
    return false
  }
  let mut pos = 0
  while pos + needle.length() <= haystack.length() {
    match haystack.get_view(start=pos, end=pos + needle.length()) {
      Some(part) if part == needle => return true
      _ => ()
    }
    pos += haystack.get_char(pos).unwrap().utf16_len()
  }
  false
}

///|
pub struct SanitizeTransformObserver {
  priv hook : ((@dom.Node) -> Unit)?
  priv report_callback : ((String, @dom.Node?) -> Unit)?
}

///|
pub fn SanitizeTransformObserver::new(
  hook : ((@dom.Node) -> Unit)?,
  report_callback : ((String, @dom.Node?) -> Unit)?,
) -> SanitizeTransformObserver {
  { hook, report_callback }
}

///|
fn sanitize_observer_event(
  observer : SanitizeTransformObserver?,
  message : String,
  node : @dom.Node?,
) -> Unit {
  match observer {
    Some(observer) => {
      match (node, observer.hook) {
        (Some(node), Some(hook)) => hook(node)
        _ => ()
      }
      match observer.report_callback {
        Some(report) => report(message, node)
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
  node : @dom.Node?,
) -> Unit raise @core.HtmlError {
  policy.handle_unsafe(message)
  sanitize_observer_event(observer, message, node)
}

///|
fn node_is_sanitize_container(node : @dom.Node) -> Bool {
  match node.kind {
    Document | Fragment => true
    _ => false
  }
}

///|
pub fn remove_child_at(parent : @dom.Node, index : Int) -> Unit {
  let child = parent.children[index]
  ignore(parent.children.remove(index))
  if child.parent is Some(current_parent) &&
    physical_equal(parent, current_parent) {
    child.parent = None
  }
}

///|
pub fn unwrap_child_at(parent : @dom.Node, index : Int) -> Int {
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
pub fn escaped_end_tag_for(node : @dom.Node) -> String? {
  if @ser.is_void_element(node.name) {
    None
  } else {
    Some("</" + node.name + ">")
  }
}

///|
fn sanitizer_escaped_end_tag_for(node : @dom.Node) -> String? {
  match node.source_end_tag {
    Some(raw) => Some(raw)
    None =>
      if node.parsed_from_source || @ser.is_void_element(node.name) {
        None
      } else {
        Some("</" + node.name + ">")
      }
  }
}

///|
fn sanitizer_escaped_start_tag_for(node : @dom.Node) -> String {
  node.source_start_tag.unwrap_or(@ser.serialize_start_tag_unchecked(node, '"'))
}

///|
fn insert_sanitized_escape_text(
  parent : @dom.Node,
  index : Int,
  value : String,
) -> Unit {
  let escaped = @dom.text(value)
  escaped.parent = Some(parent)
  parent.children.insert(index, escaped)
}

///|
fn escape_child_at(
  parent : @dom.Node,
  index : Int,
  policy : SanitizationPolicy,
  observer : SanitizeTransformObserver?,
) -> Int raise @core.HtmlError {
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
fn sanitize_node_name(node : @dom.Node) -> String {
  @syn.lower_ascii(node.name)
}

///|
fn sanitize_namespace_is_foreign(node : @dom.Node) -> Bool {
  match node.ns {
    Some(ns) => ns != "html"
    None => false
  }
}

///|
pub fn node_is_effectively_foreign(node : @dom.Node) -> Bool {
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
fn sanitize_node_is_active_foreign_content(node : @dom.Node) -> Bool {
  is_active_foreign_mutation_tag(sanitize_node_name(node)) &&
  node_is_effectively_foreign(node)
}

///|
fn attr_name_is_dangerous(name : StringView) -> Bool {
  let normalized = @syn.lower_ascii(name)
  normalized.has_prefix("on") ||
  normalized == "srcdoc" ||
  @ser.string_contains_char(normalized, ':')
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
  node : @dom.Node,
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
pub fn SanitizationPolicy::sanitize_attribute_value(
  self : SanitizationPolicy,
  tag_name : String,
  attr_name : String,
  value : String,
  effectively_foreign? : Bool = false,
) -> String? {
  sanitize_attribute_value(
    self,
    tag_name,
    attr_name,
    value,
    effectively_foreign~,
  )
}

///|
pub fn SanitizationPolicy::sanitize_inline_style_value(
  self : SanitizationPolicy,
  tag_name : String,
  value : String,
) -> String? {
  sanitize_inline_style_value(self, tag_name, value)
}

///|
pub fn push_html_whitespace_tokens(
  tokens : Array[String],
  value : StringView,
) -> Unit {
  let mut token_start = 0
  let mut pos = 0
  while pos < value.length() {
    let ch = value.get_char(pos).unwrap()
    if is_html_whitespace_char(ch) {
      if token_start < pos {
        let token = value[token_start:pos]
        push_unique_string(tokens, @syn.lower_ascii(token.trim()))
      }
      pos += ch.utf16_len()
      token_start = pos
    } else {
      pos += ch.utf16_len()
    }
  }
  if token_start < value.length() {
    let token = value[token_start:value.length()]
    push_unique_string(tokens, @syn.lower_ascii(token.trim()))
  }
}

///|
fn merge_forced_link_rel(
  node : @dom.Node,
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
  node : @dom.Node,
  policy : SanitizationPolicy,
  observer : SanitizeTransformObserver?,
) -> Unit raise @core.HtmlError {
  match node.attrs.get("http-equiv") {
    Some(Some(value)) if @syn.lower_ascii(value[:].trim()) == "refresh" &&
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
  } else if @ser.string_contains_char(attr_name, ':') {
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
  node : @dom.Node,
  policy : SanitizationPolicy,
  observer : SanitizeTransformObserver?,
) -> Unit raise @core.HtmlError {
  let tag_name = sanitize_node_name(node)
  let effectively_foreign = node_is_effectively_foreign(node)
  if policy.strip_invisible_unicode {
    let stripped_attr_names : Array[String] = []
    for key in node.attrs.keys() {
      match node.attrs.get(key).unwrap() {
        Some(raw_value) => {
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
    let attr_name = @syn.lower_ascii(key)
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
      match node.attrs.get(key).unwrap() {
        Some(raw_value) => {
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
        None if attr_name == "href" ||
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
        value =>
          if attr_name != key {
            node.attrs.remove(key)
            node.attrs[attr_name] = value
          }
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
fn rawtext_serialization_element_name(node : @dom.Node) -> String? {
  let name = sanitize_node_name(node)
  match name {
    "script" | "style" => Some(name)
    _ => None
  }
}

///|
fn is_math_text_integration_child_exception(node : @dom.Node) -> Bool {
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
fn foreign_text_integration_namespace(node : @dom.Node) -> String? {
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
  node : @dom.Node,
  policy : SanitizationPolicy,
  observer : SanitizeTransformObserver?,
) -> Bool raise @core.HtmlError {
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
            node.append_child(@dom.text(stripped))
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
  node : @dom.Node,
  policy : SanitizationPolicy,
  observer : SanitizeTransformObserver?,
) -> Bool raise @core.HtmlError {
  guard rawtext_serialization_element_name(node) is Some(tag_name) else {
    return false
  }
  let original = node.children.copy()
  node.children.clear()
  let text_children : Array[@dom.Node] = []
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
  let sanitized_text = @ser.neutralize_rawtext_end_tag_sequences(
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
    node.append_child(@dom.text(sanitized_text))
  }
  true
}

///|
fn sanitize_container_children(
  parent : @dom.Node,
  policy : SanitizationPolicy,
  observer : SanitizeTransformObserver?,
) -> Unit raise @core.HtmlError {
  let mut index = 0
  while index < parent.children.length() {
    let child = parent.children[index]
    match child.kind {
      Text if child.sanitize_escape_only =>
        if policy.disallowed_tag_handling == Escape {
          child.sanitize_escape_only = false
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
            ignore(parent.replace_child(@dom.text(stripped), child))
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
  node : @dom.Node,
  policy? : SanitizationPolicy,
) -> @dom.Node raise @core.HtmlError {
  sanitize_dom_with_observer(node, policy, None)
}

///|
pub fn sanitize_dom_with_observer(
  node : @dom.Node,
  policy : SanitizationPolicy?,
  observer : SanitizeTransformObserver?,
) -> @dom.Node raise @core.HtmlError {
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
    let wrapper = @dom.fragment(children=[node])
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
