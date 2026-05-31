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
  let sanitized_text = @seri.neutralize_rawtext_end_tag_sequences(
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
