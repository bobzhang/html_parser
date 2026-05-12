///|
priv enum TransformKind {
  DropElements
  UnwrapElements
  EscapeElements
  EmptyElements
  SetAttributes
  DropAttributes
  AllowlistAttributes
  MergeAttributeTokens
  EditElement
  EditDocumentRoot
  EditAttributes
  SanitizeTree
  DropUrlAttributes
  AllowStyleAttributes
  DropCommentNodes
  DropDoctypeNodes
  CollapseTextWhitespace
  LinkifyTextNodes
} derive(Debug)

///|
priv struct TransformNodeCallback {
  callback : (Node) -> Unit
}

///|
impl Debug for TransformNodeCallback with to_repr(_) {
  Repr::opaque_("TransformNodeCallback", Repr::unit())
}

///|
priv struct TransformAttrsCallback {
  callback : (Node) -> Map[String, String?]?
}

///|
impl Debug for TransformAttrsCallback with to_repr(_) {
  Repr::opaque_("TransformAttrsCallback", Repr::unit())
}

///|
/// A DOM transform specification for `apply_transforms`.
///
/// The current port covers deterministic structural, attribute, callback,
/// URL/style, utility, and sanitizer transforms. Callback hooks/reports will be
/// added as separate slices.
pub struct TransformSpec {
  priv kind : TransformKind
  priv enabled : Bool
  priv selector : String
  priv attr_patch : Map[String, String?]?
  priv attr_patterns : Array[String]
  priv allowed_attrs : Map[String, Array[String]]?
  priv merge_tag : String
  priv merge_attr : String
  priv merge_tokens : Array[String]
  priv sanitize_policy : SanitizationPolicy?
  priv node_callback : TransformNodeCallback?
  priv attrs_callback : TransformAttrsCallback?
  priv skip_tags : Array[String]
  priv linkify_config : LinkifyConfig?
  priv linkify_skip_tags : Array[String]
} derive(Debug)

///|
fn make_transform_spec(
  kind : TransformKind,
  enabled? : Bool = true,
  selector? : String = "",
  attr_patch? : Map[String, String?],
  attr_patterns? : Array[String] = [],
  allowed_attrs? : Map[String, Array[String]],
  merge_tag? : String = "",
  merge_attr? : String = "",
  merge_tokens? : Array[String] = [],
  sanitize_policy? : SanitizationPolicy,
  node_callback? : TransformNodeCallback,
  attrs_callback? : TransformAttrsCallback,
  skip_tags? : Array[String] = [],
  linkify_config? : LinkifyConfig,
  linkify_skip_tags? : Array[String] = [],
) -> TransformSpec {
  {
    kind,
    enabled,
    selector,
    attr_patch: attr_patch.map(fn(attrs) { attrs.copy() }),
    attr_patterns: attr_patterns.copy(),
    allowed_attrs: allowed_attrs.map(copy_allowed_attrs_map),
    merge_tag,
    merge_attr,
    merge_tokens: merge_tokens.copy(),
    sanitize_policy,
    node_callback,
    attrs_callback,
    skip_tags: skip_tags.copy(),
    linkify_config,
    linkify_skip_tags: linkify_skip_tags.copy(),
  }
}

///|
/// Build a transform that removes elements matching `selector`.
pub fn TransformSpec::drop(
  selector : StringView,
  enabled? : Bool = true,
) -> TransformSpec {
  make_transform_spec(DropElements, enabled~, selector=selector.to_owned())
}

///|
/// Build a transform that replaces matching elements with their children.
pub fn TransformSpec::unwrap(
  selector : StringView,
  enabled? : Bool = true,
) -> TransformSpec {
  make_transform_spec(UnwrapElements, enabled~, selector=selector.to_owned())
}

///|
/// Build a transform that emits matching element tags as text and keeps children.
pub fn TransformSpec::escape(
  selector : StringView,
  enabled? : Bool = true,
) -> TransformSpec {
  make_transform_spec(EscapeElements, enabled~, selector=selector.to_owned())
}

///|
/// Build a transform that removes all children from matching elements.
pub fn TransformSpec::empty(
  selector : StringView,
  enabled? : Bool = true,
) -> TransformSpec {
  make_transform_spec(EmptyElements, enabled~, selector=selector.to_owned())
}

///|
/// Build a transform that invokes `callback` for matching elements.
pub fn TransformSpec::edit(
  selector : StringView,
  callback : (Node) -> Unit,
  enabled? : Bool = true,
) -> TransformSpec {
  make_transform_spec(EditElement, enabled~, selector=selector.to_owned(), node_callback={
    callback,
  })
}

///|
/// Build a transform that invokes `callback` once on the supplied root.
pub fn TransformSpec::edit_document(
  callback : (Node) -> Unit,
  enabled? : Bool = true,
) -> TransformSpec {
  make_transform_spec(EditDocumentRoot, enabled~, node_callback={ callback, })
}

///|
/// Build a transform that sets or adds attributes on matching elements.
pub fn TransformSpec::set_attrs(
  selector : StringView,
  attrs : Map[String, String?],
  enabled? : Bool = true,
) -> TransformSpec {
  make_transform_spec(
    SetAttributes,
    enabled~,
    selector=selector.to_owned(),
    attr_patch=attrs,
  )
}

///|
/// Build a transform that removes matching attributes from matching elements.
pub fn TransformSpec::drop_attrs(
  selector : StringView,
  patterns : Array[String],
  enabled? : Bool = true,
) -> TransformSpec {
  make_transform_spec(
    DropAttributes,
    enabled~,
    selector=selector.to_owned(),
    attr_patterns=normalize_transform_strings(patterns),
  )
}

///|
/// Build a transform that keeps only allowed attributes on matching elements.
pub fn TransformSpec::allowlist_attrs(
  selector : StringView,
  allowed_attributes : Map[String, Array[String]],
  enabled? : Bool = true,
) -> TransformSpec {
  make_transform_spec(
    AllowlistAttributes,
    enabled~,
    selector=selector.to_owned(),
    allowed_attrs=normalize_allowed_attrs_map(allowed_attributes),
  )
}

///|
/// Build a transform that replaces matching element attributes when `callback`
/// returns a map.
pub fn TransformSpec::edit_attrs(
  selector : StringView,
  callback : (Node) -> Map[String, String?]?,
  enabled? : Bool = true,
) -> TransformSpec {
  make_transform_spec(EditAttributes, enabled~, selector=selector.to_owned(), attrs_callback={
    callback,
  })
}

///|
/// Build a transform that merges tokens into a whitespace-delimited attribute.
pub fn TransformSpec::merge_attrs(
  tag : StringView,
  attr~ : StringView,
  tokens~ : Array[String],
  enabled? : Bool = true,
) -> TransformSpec {
  let tag = lower_ascii(tag.trim())
  let attr = lower_ascii(attr.trim())
  make_transform_spec(
    MergeAttributeTokens,
    enabled~,
    selector=tag,
    merge_tag=tag,
    merge_attr=attr,
    merge_tokens=normalize_transform_strings(tokens),
  )
}

///|
/// Build a transform that validates URL-valued attributes with `url_policy`.
pub fn TransformSpec::drop_url_attrs(
  selector : StringView,
  url_policy~ : UrlPolicy,
  enabled? : Bool = true,
) -> TransformSpec {
  make_transform_spec(
    DropUrlAttributes,
    enabled~,
    selector=selector.to_owned(),
    sanitize_policy=SanitizationPolicy::new([], url_policy~),
  )
}

///|
/// Build a transform that sanitizes inline `style` attributes.
pub fn TransformSpec::allow_style_attrs(
  selector : StringView,
  allowed_css_properties~ : Array[String],
  enabled? : Bool = true,
) -> TransformSpec {
  make_transform_spec(
    AllowStyleAttributes,
    enabled~,
    selector=selector.to_owned(),
    sanitize_policy=SanitizationPolicy::new(
      [],
      allowed_css_properties=normalize_transform_strings(allowed_css_properties),
    ),
  )
}

///|
/// Build a transform that sanitizes the DOM tree with an optional policy.
pub fn TransformSpec::sanitize(
  policy? : SanitizationPolicy,
  enabled? : Bool = true,
) -> TransformSpec {
  match policy {
    Some(policy) =>
      make_transform_spec(SanitizeTree, enabled~, sanitize_policy=policy)
    None => make_transform_spec(SanitizeTree, enabled~)
  }
}

///|
/// Build a transform that removes comment nodes.
pub fn TransformSpec::drop_comments(enabled? : Bool = true) -> TransformSpec {
  make_transform_spec(DropCommentNodes, enabled~)
}

///|
/// Build a transform that removes doctype nodes.
pub fn TransformSpec::drop_doctype(enabled? : Bool = true) -> TransformSpec {
  make_transform_spec(DropDoctypeNodes, enabled~)
}

///|
fn default_collapse_whitespace_skip_tags() -> Array[String] {
  ["code", "pre", "script", "style", "textarea", "title"]
}

///|
/// Build a transform that collapses runs of HTML whitespace in text nodes.
pub fn TransformSpec::collapse_whitespace(
  skip_tags? : Array[String],
  enabled? : Bool = true,
) -> TransformSpec {
  make_transform_spec(
    CollapseTextWhitespace,
    enabled~,
    skip_tags=skip_tags.unwrap_or(default_collapse_whitespace_skip_tags()),
  )
}

///|
/// Build a transform that linkifies URL and email text nodes.
pub fn TransformSpec::linkify(
  config? : LinkifyConfig,
  skip_tags? : Array[String],
  enabled? : Bool = true,
) -> TransformSpec {
  let config = config.unwrap_or(LinkifyConfig::new())
  let skip_tags = skip_tags.unwrap_or(linkify_default_dom_skip_tags())
  make_transform_spec(
    LinkifyTextNodes,
    enabled~,
    linkify_config=config,
    linkify_skip_tags=skip_tags,
  )
}

///|
/// Apply DOM transforms in order.
///
/// The transform mutates and returns the current root. Selector transforms process the
/// children of the supplied root, matching the Python constructor-time pipeline
/// where the root is normally a document or document fragment container.
pub fn apply_transforms(
  node : Node,
  transforms : Array[TransformSpec],
) -> Node raise HtmlError {
  let mut current = node
  for transform in transforms {
    if transform.enabled {
      current = apply_transform(current, transform)
    }
  }
  current
}

///|
fn apply_transform(
  node : Node,
  transform : TransformSpec,
) -> Node raise HtmlError {
  match transform.kind {
    EditDocumentRoot => {
      apply_edit_document_transform(node, transform)
      node
    }
    DropElements
    | UnwrapElements
    | EscapeElements
    | EmptyElements
    | SetAttributes
    | DropAttributes
    | AllowlistAttributes
    | MergeAttributeTokens
    | EditElement
    | EditAttributes
    | DropUrlAttributes
    | AllowStyleAttributes => {
      apply_selector_transform(node, transform)
      node
    }
    SanitizeTree =>
      match transform.sanitize_policy {
        Some(policy) => sanitize_dom(node, policy~)
        None => sanitize_dom(node)
      }
    DropCommentNodes => {
      apply_drop_kind_transform(node, Comment)
      node
    }
    DropDoctypeNodes => {
      apply_drop_kind_transform(node, Doctype)
      node
    }
    CollapseTextWhitespace => {
      apply_collapse_whitespace_transform(
        node,
        transform_skip_tag_set(transform.skip_tags),
      )
      node
    }
    LinkifyTextNodes => {
      let config = transform.linkify_config.unwrap_or(LinkifyConfig::new())
      let skip_tags = transform.linkify_skip_tags.copy()
      ignore(linkify_dom(node, config~, skip_tags~))
      node
    }
  }
}

///|
fn transform_skip_tag_set(tags : Array[String]) -> Set[String] {
  let out : Set[String] = Set::default()
  for tag in tags {
    let normalized = lower_ascii(tag.trim())
    if normalized != "" {
      out.add(normalized)
    }
  }
  out
}

///|
fn normalize_transform_strings(values : Array[String]) -> Array[String] {
  let out : Array[String] = []
  for value in values {
    let normalized = lower_ascii(value.trim())
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
    let normalized_tag = lower_ascii(tag[:].trim())
    if normalized_tag != "" {
      out[normalized_tag] = normalize_transform_strings(attrs)
    }
  }
  out
}

///|
fn apply_selector_transform(root : Node, transform : TransformSpec) -> Unit {
  match root.kind {
    Document | Fragment | Element => transform_children(root, transform)
    _ => ()
  }
}

///|
fn transform_children(parent : Node, transform : TransformSpec) -> Unit {
  let mut index = 0
  while index < parent.children.length() {
    let child = parent.children[index]
    if child.kind == Element && transform_matches_element(child, transform) {
      match transform.kind {
        DropElements => remove_child_at(parent, index)
        UnwrapElements => {
          let inserted = unwrap_child_at(parent, index)
          if inserted == 0 {
            ()
          }
        }
        EscapeElements => {
          let inserted = escape_transform_child_at(parent, index)
          if inserted == 0 {
            ()
          }
        }
        EmptyElements => {
          empty_transform_node(child)
          index += 1
        }
        SetAttributes => {
          apply_set_attrs_transform(child, transform)
          transform_children(child, transform)
          index += 1
        }
        DropAttributes => {
          apply_drop_attrs_transform(child, transform)
          transform_children(child, transform)
          index += 1
        }
        AllowlistAttributes => {
          apply_allowlist_attrs_transform(child, transform)
          transform_children(child, transform)
          index += 1
        }
        MergeAttributeTokens => {
          apply_merge_attrs_transform(child, transform)
          transform_children(child, transform)
          index += 1
        }
        EditElement => {
          apply_edit_transform(child, transform)
          if index < parent.children.length() &&
            physical_equal(parent.children[index], child) {
            transform_children(child, transform)
            index += 1
          }
        }
        EditAttributes => {
          apply_edit_attrs_transform(child, transform)
          if index < parent.children.length() &&
            physical_equal(parent.children[index], child) {
            transform_children(child, transform)
            index += 1
          }
        }
        DropUrlAttributes => {
          apply_drop_url_attrs_transform(child, transform)
          transform_children(child, transform)
          index += 1
        }
        AllowStyleAttributes => {
          apply_allow_style_attrs_transform(child, transform)
          transform_children(child, transform)
          index += 1
        }
        _ => index += 1
      }
    } else {
      match child.kind {
        Document | Fragment | Element => transform_children(child, transform)
        _ => ()
      }
      index += 1
    }
  }
}

///|
fn transform_matches_element(node : Node, transform : TransformSpec) -> Bool {
  match transform.kind {
    MergeAttributeTokens => lower_ascii(node.name) == transform.merge_tag
    _ => matches(node, transform.selector)
  }
}

///|
fn empty_transform_node(node : Node) -> Unit {
  while !node.children.is_empty() {
    let child = node.children[0]
    ignore(node.children.remove(0))
    if child.parent is Some(current_parent) &&
      physical_equal(current_parent, node) {
      child.parent = None
    }
  }
}

///|
fn apply_edit_document_transform(
  node : Node,
  transform : TransformSpec,
) -> Unit {
  match transform.node_callback {
    Some(callback) => (callback.callback)(node)
    None => ()
  }
}

///|
fn apply_edit_transform(node : Node, transform : TransformSpec) -> Unit {
  match transform.node_callback {
    Some(callback) => (callback.callback)(node)
    None => ()
  }
}

///|
fn apply_edit_attrs_transform(node : Node, transform : TransformSpec) -> Unit {
  match transform.attrs_callback {
    Some(callback) =>
      match (callback.callback)(node) {
        Some(attrs) => attrs_replace_with(node, attrs)
        None => ()
      }
    None => ()
  }
}

///|
fn apply_set_attrs_transform(node : Node, transform : TransformSpec) -> Unit {
  match transform.attr_patch {
    Some(attrs) =>
      for name, value in attrs {
        node.attrs[name] = value
      }
    None => ()
  }
}

///|
fn attrs_replace_with(node : Node, attrs : Map[String, String?]) -> Unit {
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
  match pattern.get_char(pattern_pos) {
    Some('*') => {
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
        match value.get_char(scan) {
          Some(ch) => scan += ch.utf16_len()
          None => break
        }
      }
      false
    }
    Some(pattern_ch) =>
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
    None => false
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
fn transform_drop_attrs_hot_path(patterns : Array[String]) -> Bool {
  patterns.length() == 3 &&
  patterns.contains("*:*") &&
  patterns.contains("on*") &&
  patterns.contains("srcdoc")
}

///|
fn apply_drop_attrs_transform(node : Node, transform : TransformSpec) -> Unit {
  if transform.attr_patterns.is_empty() || node.attrs.length() == 0 {
    return
  }
  let preserve_safe_key_case = transform_drop_attrs_hot_path(
    transform.attr_patterns,
  )
  let mut found = false
  for raw_name, _ in node.attrs {
    let name = lower_ascii(raw_name[:].trim())
    if name != "" && attr_matches_any_pattern(name, transform.attr_patterns) {
      found = true
      break
    }
  }
  if !found {
    return
  }
  let out : Map[String, String?] = {}
  for raw_name, value in node.attrs {
    let name = lower_ascii(raw_name[:].trim())
    if name != "" && !attr_matches_any_pattern(name, transform.attr_patterns) {
      if preserve_safe_key_case {
        out[raw_name] = value
      } else {
        out[name] = value
      }
    }
  }
  attrs_replace_with(node, out)
}

///|
fn allowed_attrs_for_node(
  node : Node,
  allowed : Map[String, Array[String]],
) -> Array[String] {
  let tag = lower_ascii(node.name)
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
  node : Node,
  transform : TransformSpec,
) -> Unit {
  guard transform.allowed_attrs is Some(allowed) else { return }
  if node.attrs.length() == 0 {
    return
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
      let normalized = lower_ascii(trimmed)
      if allowed_for_node.contains(normalized) {
        out[normalized] = value
        if normalized != raw_name {
          changed = true
        }
      } else {
        changed = true
      }
    }
  }
  if changed {
    attrs_replace_with(node, out)
  }
}

///|
fn apply_merge_attrs_transform(node : Node, transform : TransformSpec) -> Unit {
  if transform.merge_attr == "" || transform.merge_tokens.is_empty() {
    return
  }
  let matched_keys : Array[String] = []
  let existing : Array[String] = []
  for raw_name, value in node.attrs {
    if lower_ascii(raw_name[:].trim()) == transform.merge_attr {
      matched_keys.push(raw_name)
      match value {
        Some(raw_value) => push_html_whitespace_tokens(existing, raw_value)
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
  }
}

///|
fn find_attr_key_case_insensitive(node : Node, target : String) -> String? {
  for key, _ in node.attrs {
    if lower_ascii(key[:]) == target {
      return Some(key)
    }
  }
  None
}

///|
fn attr_value_is_refresh(value : String?) -> Bool {
  match value {
    Some(raw) => lower_ascii(raw[:].trim()) == "refresh"
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
fn apply_drop_url_attrs_transform(
  node : Node,
  transform : TransformSpec,
) -> Unit {
  guard transform.sanitize_policy is Some(policy) else { return }
  if node.attrs.length() == 0 {
    return
  }
  let tag_name = lower_ascii(node.name[:])
  match
    (
      find_attr_key_case_insensitive(node, "http-equiv"),
      find_attr_key_case_insensitive(node, "content"),
    ) {
    (Some(http_equiv_key), Some(content_key)) => {
      let http_equiv_value = match node.attrs.get(http_equiv_key) {
        Some(value) => value
        None => None
      }
      if attr_value_is_refresh(http_equiv_value) {
        node.attrs.remove(content_key)
      }
    }
    _ => ()
  }
  let effectively_foreign = node_is_effectively_foreign(node)
  let keys = node.attrs.keys().to_array()
  for key in keys {
    guard node.attrs.contains(key) else { continue }
    let attr_name = lower_ascii(key[:])
    let current_value = match node.attrs.get(key) {
      Some(value) => value
      None => None
    }
    if !transform_attr_is_url_like(
        attr_name, current_value, effectively_foreign,
      ) {
      continue
    }
    match current_value {
      Some(raw_value) =>
        match
          sanitize_attribute_value(
            policy,
            tag_name,
            attr_name,
            raw_value,
            effectively_foreign~,
          ) {
          Some(cleaned) =>
            if cleaned != raw_value || attr_name != key {
              node.attrs.remove(key)
              node.attrs[attr_name] = Some(cleaned)
            }
          None => node.attrs.remove(key)
        }
      None => node.attrs.remove(key)
    }
  }
}

///|
fn apply_allow_style_attrs_transform(
  node : Node,
  transform : TransformSpec,
) -> Unit {
  guard transform.sanitize_policy is Some(policy) else { return }
  guard find_attr_key_case_insensitive(node, "style") is Some(style_key) else {
    return
  }
  let tag_name = lower_ascii(node.name[:])
  match node.attrs.get(style_key) {
    Some(Some(raw_value)) =>
      match sanitize_inline_style_value(policy, tag_name, raw_value) {
        Some(cleaned) =>
          if cleaned != raw_value || style_key != "style" {
            node.attrs.remove(style_key)
            node.attrs["style"] = Some(cleaned)
          }
        None => node.attrs.remove(style_key)
      }
    Some(None) => node.attrs.remove(style_key)
    None => ()
  }
}

///|
fn escape_transform_child_at(parent : Node, index : Int) -> Int {
  let child = parent.children[index]
  let start_tag = serialize_start_tag_unchecked(child, '"')
  let end_tag = escaped_end_tag_for(child)
  ignore(parent.children.remove(index))
  if child.parent is Some(current_parent) &&
    physical_equal(parent, current_parent) {
    child.parent = None
  }
  let mut inserted = 0
  let start = text(start_tag)
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
      let end = text(value)
      end.parent = Some(parent)
      parent.children.insert(index + inserted, end)
      inserted += 1
    }
    None => ()
  }
  inserted
}

///|
fn apply_drop_kind_transform(root : Node, kind : NodeKind) -> Unit {
  match root.kind {
    Document | Fragment | Element => {
      let mut index = 0
      while index < root.children.length() {
        let child = root.children[index]
        if child.kind == kind {
          remove_child_at(root, index)
        } else {
          apply_drop_kind_transform(child, kind)
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
  root : Node,
  skip_tags : Set[String],
) -> Unit {
  match root.kind {
    Document | Fragment => collapse_whitespace_children(root, skip_tags, false)
    Element =>
      collapse_whitespace_children(
        root,
        skip_tags,
        skip_tags.contains(lower_ascii(root.name)),
      )
    _ => ()
  }
}

///|
fn collapse_whitespace_children(
  parent : Node,
  skip_tags : Set[String],
  skip : Bool,
) -> Unit {
  let mut index = 0
  while index < parent.children.length() {
    let child = parent.children[index]
    match child.kind {
      Text if !skip && child.data != "" => {
        let collapsed = collapse_transform_html_space(child.data)
        if collapsed != child.data {
          let replacement = text(collapsed)
          replacement.parent = Some(parent)
          parent.children[index] = replacement
          if child.parent is Some(current_parent) &&
            physical_equal(current_parent, parent) {
            child.parent = None
          }
        }
      }
      Document | Fragment =>
        collapse_whitespace_children(child, skip_tags, skip)
      Element => {
        let child_skip = skip || skip_tags.contains(lower_ascii(child.name))
        collapse_whitespace_children(child, skip_tags, child_skip)
      }
      _ => ()
    }
    index += 1
  }
}
