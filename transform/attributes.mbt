///|
fn apply_edit_attrs_transform(
  node : @dom.Node,
  transform : TransformSpec,
) -> Bool {
  match transform.attrs_callback {
    Some(callback) =>
      match (callback.callback)(node) {
        Some(attrs) => {
          attrs_replace_with(node, attrs)
          true
        }
        None => false
      }
    None => false
  }
}

///|
fn apply_set_attrs_transform(
  node : @dom.Node,
  transform : TransformSpec,
) -> Bool {
  match transform.attr_patch {
    Some(attrs) => {
      let mut changed = false
      for name, value in attrs {
        if node.attrs.get(name) != Some(value) {
          changed = true
        }
        node.attrs[name] = value
      }
      changed
    }
    None => false
  }
}

///|
fn attrs_replace_with(node : @dom.Node, attrs : Map[String, String?]) -> Unit {
  node.attrs.clear()
  for name, value in attrs {
    node.attrs[name] = value
  }
}

///|
fn transform_glob_match(pattern : StringView, value : StringView) -> Bool {
  transform_glob_match_at(pattern, 0, value, 0)
}

///|
fn transform_glob_match_at(
  pattern : StringView,
  pattern_pos : Int,
  value : StringView,
  value_pos : Int,
) -> Bool {
  if pattern_pos >= pattern.length() {
    return value_pos >= value.length()
  }
  match pattern.get_char(pattern_pos).unwrap() {
    '*' => {
      let mut next_pattern_pos = pattern_pos + 1
      while next_pattern_pos < pattern.length() &&
            pattern.get_char(next_pattern_pos) is Some('*') {
        next_pattern_pos += 1
      }
      if next_pattern_pos >= pattern.length() {
        return true
      }
      let mut scan = value_pos
      while scan <= value.length() {
        if transform_glob_match_at(pattern, next_pattern_pos, value, scan) {
          return true
        }
        if scan >= value.length() {
          break
        }
        scan += value.get_char(scan).unwrap().utf16_len()
      }
      false
    }
    pattern_ch =>
      match value.get_char(value_pos) {
        Some(value_ch) if value_ch == pattern_ch =>
          transform_glob_match_at(
            pattern,
            pattern_pos + pattern_ch.utf16_len(),
            value,
            value_pos + value_ch.utf16_len(),
          )
        _ => false
      }
  }
}

///|
fn attr_matches_any_pattern(
  name : StringView,
  patterns : Array[String],
) -> Bool {
  for pattern in patterns {
    if transform_glob_match(pattern, name) {
      return true
    }
  }
  false
}

///|
fn string_view_contains_char(value : StringView, target : Char) -> Bool {
  for ch in value {
    if ch == target {
      return true
    }
  }
  false
}

///|
fn drop_attrs_report_pattern(
  name : StringView,
  patterns : Array[String],
  hot_path : Bool,
) -> String {
  if hot_path {
    if name == "srcdoc" {
      "srcdoc"
    } else if string_view_contains_char(name, ':') {
      "*:*"
    } else {
      "on*"
    }
  } else {
    for pattern in patterns {
      if transform_glob_match(pattern, name) {
        return pattern
      }
    }
    "?"
  }
}

///|
fn report_dropped_attr_pattern(
  node : @dom.Node,
  transform : TransformSpec,
  name : StringView,
  pattern : String,
) -> Unit {
  let attr = name.to_owned()
  transform_report(
    transform,
    "Unsafe attribute '\{attr}' (matched forbidden pattern '\{pattern}')",
    Some(node),
  )
}

///|
fn transform_drop_attrs_hot_path(patterns : Array[String]) -> Bool {
  patterns.length() == 3 &&
  patterns.contains("*:*") &&
  patterns.contains("on*") &&
  patterns.contains("srcdoc")
}

///|
fn apply_drop_attrs_transform(
  node : @dom.Node,
  transform : TransformSpec,
) -> Bool {
  if transform.attr_patterns.is_empty() || node.attrs.length() == 0 {
    return false
  }
  let preserve_safe_key_case = transform_drop_attrs_hot_path(
    transform.attr_patterns,
  )
  let mut found = false
  for raw_name, _ in node.attrs {
    let name = @syn.lower_ascii(raw_name[:].trim())
    if name != "" && attr_matches_any_pattern(name, transform.attr_patterns) {
      found = true
      break
    }
  }
  if !found {
    return false
  }
  let out : Map[String, String?] = {}
  for raw_name, value in node.attrs {
    let name = @syn.lower_ascii(raw_name[:].trim())
    if name != "" && attr_matches_any_pattern(name, transform.attr_patterns) {
      report_dropped_attr_pattern(
        node,
        transform,
        name,
        drop_attrs_report_pattern(
          name,
          transform.attr_patterns,
          preserve_safe_key_case,
        ),
      )
    } else if name != "" {
      if preserve_safe_key_case {
        out[raw_name] = value
      } else {
        out[name] = value
      }
    }
  }
  transform_call_hook(node, transform)
  attrs_replace_with(node, out)
  true
}

///|
fn allowed_attrs_for_node(
  node : @dom.Node,
  allowed : Map[String, Array[String]],
) -> Array[String] {
  let tag = @syn.lower_ascii(node.name)
  let global = allowed.get("*").unwrap_or([])
  match allowed.get(tag) {
    Some(tag_attrs) => {
      let out = global.copy()
      for attr in tag_attrs {
        if !out.contains(attr) {
          out.push(attr)
        }
      }
      out
    }
    None => global.copy()
  }
}

///|
fn apply_allowlist_attrs_transform(
  node : @dom.Node,
  transform : TransformSpec,
) -> Bool {
  guard transform.allowed_attrs is Some(allowed) else { return false }
  if node.attrs.length() == 0 {
    return false
  }
  let allowed_for_node = allowed_attrs_for_node(node, allowed)
  let out : Map[String, String?] = {}
  let mut changed = false
  for raw_name, value in node.attrs {
    let trimmed = raw_name[:].trim()
    if trimmed.is_empty() {
      changed = true
      continue
    }
    if allowed_for_node.contains(raw_name) {
      out[raw_name] = value
    } else {
      let normalized = @syn.lower_ascii(trimmed)
      if allowed_for_node.contains(normalized) {
        out[normalized] = value
        if normalized != raw_name {
          changed = true
        }
      } else {
        changed = true
        transform_report(
          transform,
          "Unsafe attribute '\{normalized}' (not allowed)",
          Some(node),
        )
      }
    }
  }
  if changed {
    transform_call_hook(node, transform)
    attrs_replace_with(node, out)
  }
  changed
}

///|
fn apply_merge_attrs_transform(
  node : @dom.Node,
  transform : TransformSpec,
) -> Bool {
  if transform.merge_attr == "" || transform.merge_tokens.is_empty() {
    return false
  }
  let matched_keys : Array[String] = []
  let existing : Array[String] = []
  for raw_name, value in node.attrs {
    if @syn.lower_ascii(raw_name[:].trim()) == transform.merge_attr {
      matched_keys.push(raw_name)
      match value {
        Some(raw_value) =>
          transform_push_html_whitespace_tokens(existing, raw_value)
        None => ()
      }
    }
  }
  let had_exact_key = matched_keys.length() == 1 &&
    matched_keys[0] == transform.merge_attr
  let original_value = node.attrs.get(transform.merge_attr)
  for token in transform.merge_tokens {
    if !existing.contains(token) {
      existing.push(token)
    }
  }
  let normalized = existing.join(" ")
  if !had_exact_key || original_value != Some(Some(normalized)) {
    for key in matched_keys {
      node.attrs.remove(key)
    }
    node.attrs[transform.merge_attr] = Some(normalized)
    true
  } else {
    false
  }
}
