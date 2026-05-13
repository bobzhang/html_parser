///|
fn find_attr_key_case_insensitive(node : @dom.Node, target : String) -> String? {
  for key, _ in node.attrs {
    if @syn.lower_ascii(key) == target {
      return Some(key)
    }
  }
  None
}

///|
fn attr_value_is_refresh(value : String?) -> Bool {
  match value {
    Some(raw) => @syn.lower_ascii(raw[:].trim()) == "refresh"
    None => false
  }
}

///|
fn transform_attr_is_url_like(
  attr_name : String,
  raw_value : String?,
  effectively_foreign : Bool,
) -> Bool {
  let foreign_url_function_loads = match raw_value {
    Some(value) => @san.css_value_may_load_external_resource(value)
    None => false
  }
  @san.is_single_url_like_attr(attr_name) ||
  @san.is_srcset_like_attr(attr_name) ||
  @san.is_space_separated_url_list_attr(attr_name) ||
  (
    effectively_foreign &&
    @san.is_foreign_url_function_like_attr(attr_name) &&
    foreign_url_function_loads
  )
}

///|
fn transform_report_unsafe_url_attr(
  node : @dom.Node,
  transform : TransformSpec,
  attr_name : String,
  reason? : String,
) -> Unit {
  let suffix = match reason {
    Some(value) => " (" + value + ")"
    None => ""
  }
  transform_report(
    transform,
    "Unsafe URL in attribute '" + attr_name + "'" + suffix,
    Some(node),
  )
}

///|
fn apply_drop_url_attrs_transform(
  node : @dom.Node,
  transform : TransformSpec,
) -> Bool {
  guard transform.sanitize_policy is Some(policy) else { return false }
  if node.attrs.length() == 0 {
    return false
  }
  let to_drop : Array[String] = []
  let to_set : Map[String, String?] = {}
  let tag_name = @syn.lower_ascii(node.name)
  match
    (
      find_attr_key_case_insensitive(node, "http-equiv"),
      find_attr_key_case_insensitive(node, "content"),
    ) {
    (Some(http_equiv_key), Some(content_key)) => {
      let http_equiv_value = node.attrs.get(http_equiv_key).unwrap()
      if attr_value_is_refresh(http_equiv_value) {
        transform_report_unsafe_url_attr(
          node,
          transform,
          "content",
          reason="meta refresh",
        )
        @san.push_unique_string(to_drop, content_key)
      }
    }
    _ => ()
  }
  let effectively_foreign = @san.node_is_effectively_foreign(node)
  let keys = node.attrs.keys().to_array()
  for key in keys {
    let attr_name = @syn.lower_ascii(key)
    let current_value = node.attrs.get(key).unwrap()
    if !transform_attr_is_url_like(
        attr_name, current_value, effectively_foreign,
      ) {
      continue
    }
    if tag_name == "base" && attr_name == "href" {
      transform_report_unsafe_url_attr(
        node,
        transform,
        "href",
        reason="base tag",
      )
      @san.push_unique_string(to_drop, key)
      continue
    }
    match current_value {
      Some(raw_value) =>
        if !policy.has_url_rule(tag_name, attr_name) {
          transform_report_unsafe_url_attr(
            node,
            transform,
            attr_name,
            reason="no rule",
          )
          @san.push_unique_string(to_drop, key)
        } else {
          match
            policy.sanitize_attribute_value(
              tag_name,
              attr_name,
              raw_value,
              effectively_foreign~,
            ) {
            Some(cleaned) =>
              if cleaned != raw_value || attr_name != key {
                @san.push_unique_string(to_drop, key)
                to_set[attr_name] = Some(cleaned)
              }
            None => {
              transform_report_unsafe_url_attr(node, transform, attr_name)
              @san.push_unique_string(to_drop, key)
            }
          }
        }
      None => {
        transform_report_unsafe_url_attr(node, transform, attr_name)
        @san.push_unique_string(to_drop, key)
      }
    }
  }
  if to_drop.is_empty() && to_set.is_empty() {
    false
  } else {
    transform_call_hook(node, transform)
    let out = node.attrs.copy()
    for key in to_drop {
      out.remove(key)
    }
    for key, value in to_set {
      out[key] = value
    }
    attrs_replace_with(node, out)
    true
  }
}

///|
fn apply_allow_style_attrs_transform(
  node : @dom.Node,
  transform : TransformSpec,
) -> Bool {
  guard transform.sanitize_policy is Some(policy) else { return false }
  guard find_attr_key_case_insensitive(node, "style") is Some(style_key) else {
    return false
  }
  let tag_name = @syn.lower_ascii(node.name)
  match node.attrs.get(style_key).unwrap() {
    Some(raw_value) =>
      match policy.sanitize_inline_style_value(tag_name, raw_value) {
        Some(cleaned) =>
          if cleaned != raw_value || style_key != "style" {
            transform_call_hook(node, transform)
            node.attrs.remove(style_key)
            node.attrs["style"] = Some(cleaned)
            true
          } else {
            false
          }
        None => {
          transform_report(
            transform,
            "Unsafe inline style in attribute 'style'",
            Some(node),
          )
          transform_call_hook(node, transform)
          node.attrs.remove(style_key)
          true
        }
      }
    None => {
      transform_report(
        transform,
        "Unsafe inline style in attribute 'style'",
        Some(node),
      )
      transform_call_hook(node, transform)
      node.attrs.remove(style_key)
      true
    }
  }
}
