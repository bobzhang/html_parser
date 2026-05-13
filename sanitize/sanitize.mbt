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
fn node_is_sanitize_container(node : @dom.Node) -> Bool {
  match node.kind {
    Document | Fragment => true
    _ => false
  }
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
