///|
fn is_html_whitespace_char(ch : Char) -> Bool {
  match ch {
    ' ' | '\t' | '\n' | '\r' | '\u{000C}' => true
    _ => false
  }
}

///|
fn normalize_transform_strings(values : Array[String]) -> Array[String] {
  let out : Array[String] = []
  for value in values {
    let normalized = @syn.lower_ascii(value.trim())
    if normalized != "" && !out.contains(normalized) {
      out.push(normalized)
    }
  }
  out.sort()
  out
}

///|
fn copy_allowed_attrs_map(
  allowed : Map[String, Array[String]],
) -> Map[String, Array[String]] {
  let out : Map[String, Array[String]] = {}
  for tag, attrs in allowed {
    out[tag] = attrs.copy()
  }
  out
}

///|
fn normalize_allowed_attrs_map(
  allowed : Map[String, Array[String]],
) -> Map[String, Array[String]] {
  let out : Map[String, Array[String]] = {}
  for tag, attrs in allowed {
    let normalized_tag = @syn.lower_ascii(tag[:].trim())
    if normalized_tag != "" {
      out[normalized_tag] = normalize_transform_strings(attrs)
    }
  }
  out
}

///|
fn apply_selector_transform(
  root : @dom.Node,
  transform : TransformSpec,
  limits : @sel.SelectorLimits,
) -> Unit raise @core.HtmlError {
  match root.kind {
    Document | Fragment | Element => transform_children(root, transform, limits)
    _ => ()
  }
}

///|
fn transform_children(
  parent : @dom.Node,
  transform : TransformSpec,
  limits : @sel.SelectorLimits,
) -> Unit raise @core.HtmlError {
  let mut index = 0
  while index < parent.children.length() {
    let child = parent.children[index]
    if child.kind == Element &&
      transform_matches_element(child, transform, limits) {
      match transform.kind {
        DropElements => {
          transform_report_node_action(child, transform, "Dropped")
          @san.remove_child_at(parent, index)
        }
        UnwrapElements => {
          transform_report_node_action(child, transform, "Unwrapped")
          let inserted = @san.unwrap_child_at(parent, index)
          if inserted > 0 {
            transform_inserted_children_after_unwrap(
              parent, index, inserted, transform, limits,
            )
            index += inserted
          }
        }
        EscapeElements => {
          transform_report_node_action(child, transform, "Escaped")
          ignore(escape_transform_child_at(parent, index))
        }
        EmptyElements => {
          if empty_transform_node(child) {
            transform_report_node_action(child, transform, "Emptied")
          }
          index += 1
        }
        SetAttributes => {
          if apply_set_attrs_transform(child, transform) {
            transform_report_node_action(child, transform, "Set attributes on")
          }
          transform_children(child, transform, limits)
          index += 1
        }
        DropAttributes => {
          ignore(apply_drop_attrs_transform(child, transform))
          transform_children(child, transform, limits)
          index += 1
        }
        AllowlistAttributes => {
          ignore(apply_allowlist_attrs_transform(child, transform))
          transform_children(child, transform, limits)
          index += 1
        }
        MergeAttributeTokens => {
          if apply_merge_attrs_transform(child, transform) {
            transform_call_hook(child, transform)
            transform_report(
              transform,
              "Merged tokens into attribute '" +
              transform.merge_attr +
              "' on <" +
              transform.merge_tag +
              ">",
              Some(child),
            )
          }
          transform_children(child, transform, limits)
          index += 1
        }
        EditElement => {
          apply_edit_transform(child, transform)
          if index < parent.children.length() &&
            physical_equal(parent.children[index], child) {
            transform_children(child, transform, limits)
            index += 1
          }
        }
        EditAttributes => {
          if apply_edit_attrs_transform(child, transform) {
            transform_report_node_action(
              child, transform, "Edited attributes on",
            )
          }
          if index < parent.children.length() &&
            physical_equal(parent.children[index], child) {
            transform_children(child, transform, limits)
            index += 1
          }
        }
        DropUrlAttributes => {
          ignore(apply_drop_url_attrs_transform(child, transform))
          transform_children(child, transform, limits)
          index += 1
        }
        AllowStyleAttributes => {
          ignore(apply_allow_style_attrs_transform(child, transform))
          transform_children(child, transform, limits)
          index += 1
        }
        _ => index += 1
      }
    } else {
      match child.kind {
        Document | Fragment | Element =>
          transform_children(child, transform, limits)
        _ => ()
      }
      index += 1
    }
  }
}

///|
fn transform_inserted_children_after_unwrap(
  parent : @dom.Node,
  start : Int,
  count : Int,
  transform : TransformSpec,
  limits : @sel.SelectorLimits,
) -> Unit raise @core.HtmlError {
  let mut offset = 0
  while offset < count && start + offset < parent.children.length() {
    let child = parent.children[start + offset]
    match child.kind {
      Document | Fragment | Element =>
        transform_children(child, transform, limits)
      _ => ()
    }
    offset += 1
  }
}

///|
fn apply_decide_transform(
  root : @dom.Node,
  transform : TransformSpec,
  limits : @sel.SelectorLimits,
) -> Unit raise @core.HtmlError {
  match root.kind {
    Document | Fragment | Element =>
      decide_transform_children(root, transform, limits)
    _ => ()
  }
}

///|
fn decide_transform_all_nodes(transform : TransformSpec) -> Bool {
  transform.selector[:].trim() == "*"
}

///|
fn decide_action_label(action : DecideAction) -> String {
  match action {
    Keep => "keep"
    Drop => "drop"
    Unwrap => "unwrap"
    Empty => "empty"
    Escape => "escape"
  }
}

///|
fn decide_node_label(node : @dom.Node) -> String {
  if node.name.has_prefix("#") || node.name == "!doctype" {
    node.name
  } else {
    @syn.lower_ascii(node.name)
  }
}

///|
fn decide_transform_matches_node(
  node : @dom.Node,
  transform : TransformSpec,
  all_nodes : Bool,
  limits : @sel.SelectorLimits,
) -> Bool raise @core.HtmlError {
  if all_nodes {
    true
  } else {
    node.kind == Element && transform_matches_element(node, transform, limits)
  }
}

///|
fn decide_transform_action(
  node : @dom.Node,
  transform : TransformSpec,
) -> DecideAction {
  match transform.decide_callback {
    Some(callback) => {
      let action = (callback.callback)(node)
      if action != Keep {
        transform_call_hook(node, transform)
        transform_report(
          transform,
          "Decide -> " +
          decide_action_label(action) +
          " '" +
          decide_node_label(node) +
          "' (matched selector '" +
          transform.selector +
          "')",
          Some(node),
        )
      }
      action
    }
    None => Keep
  }
}

///|
fn decide_escape_child_at(parent : @dom.Node, index : Int) -> Unit {
  match parent.children[index].kind {
    Element => ignore(escape_transform_child_at(parent, index))
    Document | Fragment => ignore(@san.unwrap_child_at(parent, index))
    Text | Comment | Doctype => @san.remove_child_at(parent, index)
  }
}

///|
fn decide_transform_children(
  parent : @dom.Node,
  transform : TransformSpec,
  limits : @sel.SelectorLimits,
) -> Unit raise @core.HtmlError {
  let all_nodes = decide_transform_all_nodes(transform)
  let mut index = 0
  while index < parent.children.length() {
    let child = parent.children[index]
    if decide_transform_matches_node(child, transform, all_nodes, limits) {
      match decide_transform_action(child, transform) {
        Keep => {
          match child.kind {
            Document | Fragment | Element =>
              decide_transform_children(child, transform, limits)
            _ => ()
          }
          index += 1
        }
        Empty => {
          ignore(empty_transform_node(child))
          index += 1
        }
        Drop => @san.remove_child_at(parent, index)
        Unwrap => ignore(@san.unwrap_child_at(parent, index))
        Escape => decide_escape_child_at(parent, index)
      }
    } else {
      match child.kind {
        Document | Fragment | Element =>
          decide_transform_children(child, transform, limits)
        _ => ()
      }
      index += 1
    }
  }
}

///|
fn transform_matches_element(
  node : @dom.Node,
  transform : TransformSpec,
  limits : @sel.SelectorLimits,
) -> Bool raise @core.HtmlError {
  match transform.kind {
    MergeAttributeTokens => @syn.lower_ascii(node.name) == transform.merge_tag
    _ => @sel.matches_with_limits(node, transform.selector, limits)
  }
}

///|
fn empty_transform_node(node : @dom.Node) -> Bool {
  let had_children = !node.children.is_empty()
  while !node.children.is_empty() {
    let child = node.children[0]
    ignore(node.children.remove(0))
    if child.parent is Some(current_parent) &&
      physical_equal(current_parent, node) {
      child.parent = None
    }
  }
  had_children
}

///|
fn apply_edit_document_transform(
  node : @dom.Node,
  transform : TransformSpec,
) -> Unit {
  match transform.node_callback {
    Some(callback) => {
      transform_call_hook(node, transform)
      transform_report(transform, "Edited document root", Some(node))
      (callback.callback)(node)
    }
    None => ()
  }
}

///|
fn apply_edit_transform(node : @dom.Node, transform : TransformSpec) -> Unit {
  match transform.node_callback {
    Some(callback) => {
      transform_report_node_action(node, transform, "Edited")
      (callback.callback)(node)
    }
    None => ()
  }
}

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
  transform_report(
    transform,
    "Unsafe attribute '" +
    name.to_owned() +
    "' (matched forbidden pattern '" +
    pattern +
    "')",
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
          "Unsafe attribute '" + normalized + "' (not allowed)",
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
        Some(raw_value) => @san.push_html_whitespace_tokens(existing, raw_value)
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

///|
fn escape_transform_child_at(parent : @dom.Node, index : Int) -> Int {
  let child = parent.children[index]
  let start_tag = @ser.serialize_start_tag_unchecked(child, '"')
  let end_tag = @san.escaped_end_tag_for(child)
  ignore(parent.children.remove(index))
  if child.parent is Some(current_parent) &&
    physical_equal(parent, current_parent) {
    child.parent = None
  }
  let mut inserted = 0
  let start = @dom.text(start_tag)
  start.parent = Some(parent)
  parent.children.insert(index + inserted, start)
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
      let end = @dom.text(value)
      end.parent = Some(parent)
      parent.children.insert(index + inserted, end)
      inserted += 1
    }
    None => ()
  }
  inserted
}

///|
fn apply_drop_kind_transform(
  root : @dom.Node,
  kind : @dom.NodeKind,
  transform : TransformSpec,
) -> Unit {
  match root.kind {
    Document | Fragment | Element => {
      let mut index = 0
      while index < root.children.length() {
        let child = root.children[index]
        if child.kind == kind {
          transform_call_hook(child, transform)
          let label = match kind {
            Comment => "comment"
            Doctype => "doctype"
            _ => "node"
          }
          transform_report(transform, "Dropped " + label, Some(child))
          @san.remove_child_at(root, index)
        } else {
          apply_drop_kind_transform(child, kind, transform)
          index += 1
        }
      }
    }
    _ => ()
  }
}

///|
fn node_has_foreign_namespace(node : @dom.Node) -> Bool {
  match node.ns {
    Some(ns) => ns != "html"
    None => false
  }
}

///|
fn apply_drop_foreign_namespaces_transform(
  root : @dom.Node,
  transform : TransformSpec,
) -> Unit {
  match root.kind {
    Document | Fragment | Element => {
      let mut index = 0
      while index < root.children.length() {
        let child = root.children[index]
        if child.kind == Element && node_has_foreign_namespace(child) {
          transform_call_hook(child, transform)
          transform_report(
            transform,
            "Unsafe tag '" +
            @syn.lower_ascii(child.name) +
            "' (foreign namespace)",
            Some(child),
          )
          @san.remove_child_at(root, index)
        } else {
          apply_drop_foreign_namespaces_transform(child, transform)
          index += 1
        }
      }
    }
    _ => ()
  }
}

///|
fn collapse_transform_html_space(value : StringView) -> String {
  let out = StringBuilder::new(size_hint=value.length())
  let mut in_ws = false
  for ch in value {
    if is_html_whitespace_char(ch) {
      if !in_ws {
        out.write_char(' ')
        in_ws = true
      }
    } else {
      out.write_char(ch)
      in_ws = false
    }
  }
  out.to_string()
}

///|
fn apply_collapse_whitespace_transform(
  root : @dom.Node,
  skip_tags : Set[String],
  transform : TransformSpec,
) -> Unit {
  match root.kind {
    Document | Fragment =>
      collapse_whitespace_children(root, skip_tags, false, transform)
    Element =>
      collapse_whitespace_children(
        root,
        skip_tags,
        skip_tags.contains(@syn.lower_ascii(root.name)),
        transform,
      )
    _ => ()
  }
}

///|
fn collapse_whitespace_children(
  parent : @dom.Node,
  skip_tags : Set[String],
  skip : Bool,
  transform : TransformSpec,
) -> Unit {
  let mut index = 0
  while index < parent.children.length() {
    let child = parent.children[index]
    match child.kind {
      Text if !skip && child.data != "" => {
        let collapsed = collapse_transform_html_space(child.data)
        if collapsed != child.data {
          transform_call_hook(child, transform)
          transform_report(
            transform,
            "Collapsed whitespace in text node",
            Some(child),
          )
          let replacement = @dom.text(collapsed)
          replacement.parent = Some(parent)
          parent.children[index] = replacement
          if child.parent is Some(current_parent) &&
            physical_equal(current_parent, parent) {
            child.parent = None
          }
        }
      }
      Document | Fragment =>
        collapse_whitespace_children(child, skip_tags, skip, transform)
      Element => {
        let child_skip = skip ||
          skip_tags.contains(@syn.lower_ascii(child.name))
        collapse_whitespace_children(child, skip_tags, child_skip, transform)
      }
      _ => ()
    }
    index += 1
  }
}

///|
fn prune_empty_node_is_effectively_empty(
  node : @dom.Node,
  strip_whitespace : Bool,
) -> Bool {
  if node.kind != Element {
    return false
  }
  if node.ns == Some("html") && @ser.is_void_element(node.name) {
    return false
  }
  for child in node.children {
    match child.kind {
      Text =>
        if strip_whitespace {
          if !child.data[:].trim().is_empty() {
            return false
          }
        } else if child.data != "" {
          return false
        }
      Comment | Doctype => ()
      Element | Document | Fragment => return false
    }
  }
  true
}

///|
fn apply_prune_empty_transform(
  root : @dom.Node,
  transform : TransformSpec,
  limits : @sel.SelectorLimits,
) -> Unit raise @core.HtmlError {
  apply_prune_empty_transforms(root, [transform], limits)
}

///|
fn apply_prune_empty_transforms(
  root : @dom.Node,
  transforms : Array[TransformSpec],
  limits : @sel.SelectorLimits,
) -> Unit raise @core.HtmlError {
  match root.kind {
    Document | Fragment | Element =>
      prune_empty_children(root, transforms, limits)
    _ => ()
  }
}

///|
fn prune_empty_children(
  parent : @dom.Node,
  transforms : Array[TransformSpec],
  limits : @sel.SelectorLimits,
) -> Unit raise @core.HtmlError {
  let mut index = 0
  while index < parent.children.length() {
    let child = parent.children[index]
    match child.kind {
      Document | Fragment => {
        prune_empty_children(child, transforms, limits)
        index += 1
      }
      Element => {
        prune_empty_children(child, transforms, limits)
        let mut removed = false
        for transform in transforms {
          if transform_matches_element(child, transform, limits) &&
            prune_empty_node_is_effectively_empty(
              child,
              transform.strip_whitespace,
            ) {
            transform_call_hook(child, transform)
            transform_report(
              transform,
              "Pruned empty <" +
              @syn.lower_ascii(child.name) +
              "> (matched selector '" +
              transform.selector +
              "')",
              Some(child),
            )
            @san.remove_child_at(parent, index)
            removed = true
            break
          }
        }
        if removed {
          ()
        } else {
          index += 1
        }
      }
      _ => index += 1
    }
  }
}

///|
fn apply_linkify_transform(
  root : @dom.Node,
  config : @link.LinkifyConfig,
  skip_tags : Set[String],
  transform : TransformSpec,
) -> @dom.Node {
  match root.kind {
    Text => {
      let wrapper = @dom.fragment(children=[root])
      linkify_transform_children(wrapper, config, skip_tags, false, transform)
      if wrapper.children.length() == 1 {
        let only = wrapper.children[0]
        ignore(wrapper.children.remove(0))
        only.parent = None
        only
      } else {
        wrapper
      }
    }
    Document | Fragment | Element => {
      let skip = root.kind == Element &&
        skip_tags.contains(@syn.lower_ascii(root.name))
      linkify_transform_children(root, config, skip_tags, skip, transform)
      root
    }
    Comment | Doctype => root
  }
}

///|
fn linkify_transform_children(
  parent : @dom.Node,
  config : @link.LinkifyConfig,
  skip_tags : Set[String],
  skip_linkify : Bool,
  transform : TransformSpec,
) -> Unit {
  let mut index = 0
  while index < parent.children.length() {
    let child = parent.children[index]
    match child.kind {
      Text if !skip_linkify && child.data != "" => {
        let matches = @link.find_links_with_config(child.data, config)
        if matches.is_empty() {
          index += 1
        } else {
          transform_call_hook(child, transform)
          transform_report(
            transform,
            "Linkified " +
            matches.length().to_string() +
            " link(s) in text node",
            Some(child),
          )
          let inserted = @link.linkify_text_child_at_matches(
            parent, index, child, matches,
          )
          index += inserted
        }
      }
      Document | Fragment => {
        linkify_transform_children(
          child, config, skip_tags, skip_linkify, transform,
        )
        index += 1
      }
      Element => {
        let child_skip = skip_linkify ||
          skip_tags.contains(@syn.lower_ascii(child.name))
        linkify_transform_children(
          child, config, skip_tags, child_skip, transform,
        )
        index += 1
      }
      _ => index += 1
    }
  }
}
