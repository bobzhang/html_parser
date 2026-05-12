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
  DecideNode
  SanitizeTree
  DropUrlAttributes
  AllowStyleAttributes
  DropCommentNodes
  DropDoctypeNodes
  DropForeignNamespaceNodes
  CollapseTextWhitespace
  PruneEmptyElements
  LinkifyTextNodes
  StageGroup
} derive(Debug)

///|
/// Action returned by a `TransformSpec::decide` callback.
///
/// `Keep` leaves the matched node unchanged. The other variants apply the same
/// structural operations as the corresponding selector transforms.
pub(all) enum DecideAction {
  Keep
  Drop
  Unwrap
  Empty
  Escape
} derive(Eq, Debug)

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
priv struct TransformDecideCallback {
  callback : (Node) -> DecideAction
}

///|
impl Debug for TransformDecideCallback with to_repr(_) {
  Repr::opaque_("TransformDecideCallback", Repr::unit())
}

///|
priv struct TransformReportCallback {
  callback : (String, Node?) -> Unit
}

///|
impl Debug for TransformReportCallback with to_repr(_) {
  Repr::opaque_("TransformReportCallback", Repr::unit())
}

///|
/// A DOM transform specification for `apply_transforms`.
///
/// The current port covers deterministic structural, attribute, callback,
/// URL/style, utility, and sanitizer transforms. Most selector and node-kind
/// transforms also support hook/report callbacks.
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
  priv decide_callback : TransformDecideCallback?
  priv node_hook : TransformNodeCallback?
  priv report_callback : TransformReportCallback?
  priv skip_tags : Array[String]
  priv strip_whitespace : Bool
  priv linkify_config : LinkifyConfig?
  priv linkify_skip_tags : Array[String]
  priv stage_transforms : Array[TransformSpec]
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
  decide_callback? : TransformDecideCallback,
  node_hook? : TransformNodeCallback,
  report_callback? : TransformReportCallback,
  skip_tags? : Array[String] = [],
  strip_whitespace? : Bool = true,
  linkify_config? : LinkifyConfig,
  linkify_skip_tags? : Array[String] = [],
  stage_transforms? : Array[TransformSpec] = [],
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
    decide_callback,
    node_hook,
    report_callback,
    skip_tags: skip_tags.copy(),
    strip_whitespace,
    linkify_config,
    linkify_skip_tags: linkify_skip_tags.copy(),
    stage_transforms: stage_transforms.copy(),
  }
}

///|
fn wrap_transform_node_callback(
  callback : ((Node) -> Unit)?,
) -> TransformNodeCallback? {
  match callback {
    Some(callback) => Some({ callback, })
    None => None
  }
}

///|
fn wrap_transform_report_callback(
  callback : ((String, Node?) -> Unit)?,
) -> TransformReportCallback? {
  match callback {
    Some(callback) => Some({ callback, })
    None => None
  }
}

///|
fn with_transform_hooks(
  spec : TransformSpec,
  hook : ((Node) -> Unit)?,
  report : ((String, Node?) -> Unit)?,
) -> TransformSpec {
  {
    kind: spec.kind,
    enabled: spec.enabled,
    selector: spec.selector,
    attr_patch: spec.attr_patch.map(fn(attrs) { attrs.copy() }),
    attr_patterns: spec.attr_patterns.copy(),
    allowed_attrs: spec.allowed_attrs.map(copy_allowed_attrs_map),
    merge_tag: spec.merge_tag,
    merge_attr: spec.merge_attr,
    merge_tokens: spec.merge_tokens.copy(),
    sanitize_policy: spec.sanitize_policy,
    node_callback: spec.node_callback,
    attrs_callback: spec.attrs_callback,
    decide_callback: spec.decide_callback,
    node_hook: wrap_transform_node_callback(hook),
    report_callback: wrap_transform_report_callback(report),
    skip_tags: spec.skip_tags.copy(),
    strip_whitespace: spec.strip_whitespace,
    linkify_config: spec.linkify_config,
    linkify_skip_tags: spec.linkify_skip_tags.copy(),
    stage_transforms: spec.stage_transforms.copy(),
  }
}

///|
/// Build a transform that removes elements matching `selector`.
pub fn TransformSpec::drop(
  selector : StringView,
  enabled? : Bool = true,
  hook? : (Node) -> Unit,
  report? : (String, Node?) -> Unit,
) -> TransformSpec {
  with_transform_hooks(
    make_transform_spec(DropElements, enabled~, selector=selector.to_owned()),
    hook,
    report,
  )
}

///|
/// Build a transform that replaces matching elements with their children.
pub fn TransformSpec::unwrap(
  selector : StringView,
  enabled? : Bool = true,
  hook? : (Node) -> Unit,
  report? : (String, Node?) -> Unit,
) -> TransformSpec {
  with_transform_hooks(
    make_transform_spec(UnwrapElements, enabled~, selector=selector.to_owned()),
    hook,
    report,
  )
}

///|
/// Build a transform that emits matching element tags as text and keeps children.
pub fn TransformSpec::escape(
  selector : StringView,
  enabled? : Bool = true,
  hook? : (Node) -> Unit,
  report? : (String, Node?) -> Unit,
) -> TransformSpec {
  with_transform_hooks(
    make_transform_spec(EscapeElements, enabled~, selector=selector.to_owned()),
    hook,
    report,
  )
}

///|
/// Build a transform that removes all children from matching elements.
pub fn TransformSpec::empty(
  selector : StringView,
  enabled? : Bool = true,
  hook? : (Node) -> Unit,
  report? : (String, Node?) -> Unit,
) -> TransformSpec {
  with_transform_hooks(
    make_transform_spec(EmptyElements, enabled~, selector=selector.to_owned()),
    hook,
    report,
  )
}

///|
/// Build a transform that invokes `callback` for matching elements.
pub fn TransformSpec::edit(
  selector : StringView,
  callback : (Node) -> Unit,
  enabled? : Bool = true,
  hook? : (Node) -> Unit,
  report? : (String, Node?) -> Unit,
) -> TransformSpec {
  with_transform_hooks(
    make_transform_spec(EditElement, enabled~, selector=selector.to_owned(), node_callback={
      callback,
    }),
    hook,
    report,
  )
}

///|
/// Build a transform that chooses a structural action for matching nodes.
pub fn TransformSpec::decide(
  selector : StringView,
  callback : (Node) -> DecideAction,
  enabled? : Bool = true,
  hook? : (Node) -> Unit,
  report? : (String, Node?) -> Unit,
) -> TransformSpec {
  with_transform_hooks(
    make_transform_spec(DecideNode, enabled~, selector=selector.to_owned(), decide_callback={
      callback,
    }),
    hook,
    report,
  )
}

///|
/// Build a transform that invokes `callback` once on the supplied root.
pub fn TransformSpec::edit_document(
  callback : (Node) -> Unit,
  enabled? : Bool = true,
  hook? : (Node) -> Unit,
  report? : (String, Node?) -> Unit,
) -> TransformSpec {
  with_transform_hooks(
    make_transform_spec(EditDocumentRoot, enabled~, node_callback={ callback, }),
    hook,
    report,
  )
}

///|
/// Build a transform that sets or adds attributes on matching elements.
pub fn TransformSpec::set_attrs(
  selector : StringView,
  attrs : Map[String, String?],
  enabled? : Bool = true,
  hook? : (Node) -> Unit,
  report? : (String, Node?) -> Unit,
) -> TransformSpec {
  with_transform_hooks(
    make_transform_spec(
      SetAttributes,
      enabled~,
      selector=selector.to_owned(),
      attr_patch=attrs,
    ),
    hook,
    report,
  )
}

///|
/// Build a transform that removes matching attributes from matching elements.
pub fn TransformSpec::drop_attrs(
  selector : StringView,
  patterns : Array[String],
  enabled? : Bool = true,
  hook? : (Node) -> Unit,
  report? : (String, Node?) -> Unit,
) -> TransformSpec {
  with_transform_hooks(
    make_transform_spec(
      DropAttributes,
      enabled~,
      selector=selector.to_owned(),
      attr_patterns=normalize_transform_strings(patterns),
    ),
    hook,
    report,
  )
}

///|
/// Build a transform that keeps only allowed attributes on matching elements.
pub fn TransformSpec::allowlist_attrs(
  selector : StringView,
  allowed_attributes : Map[String, Array[String]],
  enabled? : Bool = true,
  hook? : (Node) -> Unit,
  report? : (String, Node?) -> Unit,
) -> TransformSpec {
  with_transform_hooks(
    make_transform_spec(
      AllowlistAttributes,
      enabled~,
      selector=selector.to_owned(),
      allowed_attrs=normalize_allowed_attrs_map(allowed_attributes),
    ),
    hook,
    report,
  )
}

///|
/// Build a transform that replaces matching element attributes when `callback`
/// returns a map.
pub fn TransformSpec::edit_attrs(
  selector : StringView,
  callback : (Node) -> Map[String, String?]?,
  enabled? : Bool = true,
  hook? : (Node) -> Unit,
  report? : (String, Node?) -> Unit,
) -> TransformSpec {
  with_transform_hooks(
    make_transform_spec(
      EditAttributes,
      enabled~,
      selector=selector.to_owned(),
      attrs_callback={ callback, },
    ),
    hook,
    report,
  )
}

///|
/// Build a transform that merges tokens into a whitespace-delimited attribute.
pub fn TransformSpec::merge_attrs(
  tag : StringView,
  attr~ : StringView,
  tokens~ : Array[String],
  enabled? : Bool = true,
  hook? : (Node) -> Unit,
  report? : (String, Node?) -> Unit,
) -> TransformSpec {
  let tag = lower_ascii(tag.trim())
  let attr = lower_ascii(attr.trim())
  with_transform_hooks(
    make_transform_spec(
      MergeAttributeTokens,
      enabled~,
      selector=tag,
      merge_tag=tag,
      merge_attr=attr,
      merge_tokens=normalize_transform_strings(tokens),
    ),
    hook,
    report,
  )
}

///|
/// Build a transform that validates URL-valued attributes with `url_policy`.
pub fn TransformSpec::drop_url_attrs(
  selector : StringView,
  url_policy~ : UrlPolicy,
  enabled? : Bool = true,
  hook? : (Node) -> Unit,
  report? : (String, Node?) -> Unit,
) -> TransformSpec {
  with_transform_hooks(
    make_transform_spec(
      DropUrlAttributes,
      enabled~,
      selector=selector.to_owned(),
      sanitize_policy=SanitizationPolicy::new([], url_policy~),
    ),
    hook,
    report,
  )
}

///|
/// Build a transform that sanitizes inline `style` attributes.
pub fn TransformSpec::allow_style_attrs(
  selector : StringView,
  allowed_css_properties~ : Array[String],
  enabled? : Bool = true,
  hook? : (Node) -> Unit,
  report? : (String, Node?) -> Unit,
) -> TransformSpec {
  with_transform_hooks(
    make_transform_spec(
      AllowStyleAttributes,
      enabled~,
      selector=selector.to_owned(),
      sanitize_policy=SanitizationPolicy::new(
        [],
        allowed_css_properties=normalize_transform_strings(
          allowed_css_properties,
        ),
      ),
    ),
    hook,
    report,
  )
}

///|
/// Build a transform that sanitizes the DOM tree with an optional policy.
pub fn TransformSpec::sanitize(
  policy? : SanitizationPolicy,
  enabled? : Bool = true,
  hook? : (Node) -> Unit,
  report? : (String, Node?) -> Unit,
) -> TransformSpec {
  let spec = match policy {
    Some(policy) =>
      make_transform_spec(SanitizeTree, enabled~, sanitize_policy=policy)
    None => make_transform_spec(SanitizeTree, enabled~)
  }
  with_transform_hooks(spec, hook, report)
}

///|
/// Build an explicit transform stage. Stages split a transform list into
/// separate passes and may report against the current root before the pass.
pub fn TransformSpec::stage(
  transforms : Array[TransformSpec],
  enabled? : Bool = true,
  hook? : (Node) -> Unit,
  report? : (String, Node?) -> Unit,
) -> TransformSpec {
  with_transform_hooks(
    make_transform_spec(StageGroup, enabled~, stage_transforms=transforms),
    hook,
    report,
  )
}

///|
/// Build a transform that removes comment nodes.
pub fn TransformSpec::drop_comments(
  enabled? : Bool = true,
  hook? : (Node) -> Unit,
  report? : (String, Node?) -> Unit,
) -> TransformSpec {
  with_transform_hooks(
    make_transform_spec(DropCommentNodes, enabled~),
    hook,
    report,
  )
}

///|
/// Build a transform that removes doctype nodes.
pub fn TransformSpec::drop_doctype(
  enabled? : Bool = true,
  hook? : (Node) -> Unit,
  report? : (String, Node?) -> Unit,
) -> TransformSpec {
  with_transform_hooks(
    make_transform_spec(DropDoctypeNodes, enabled~),
    hook,
    report,
  )
}

///|
/// Build a transform that removes elements outside the HTML namespace.
pub fn TransformSpec::drop_foreign_namespaces(
  enabled? : Bool = true,
  hook? : (Node) -> Unit,
  report? : (String, Node?) -> Unit,
) -> TransformSpec {
  with_transform_hooks(
    make_transform_spec(DropForeignNamespaceNodes, enabled~),
    hook,
    report,
  )
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
  hook? : (Node) -> Unit,
  report? : (String, Node?) -> Unit,
) -> TransformSpec {
  with_transform_hooks(
    make_transform_spec(
      CollapseTextWhitespace,
      enabled~,
      skip_tags=skip_tags.unwrap_or(default_collapse_whitespace_skip_tags()),
    ),
    hook,
    report,
  )
}

///|
/// Build a transform that recursively removes empty matching elements.
pub fn TransformSpec::prune_empty(
  selector : StringView,
  strip_whitespace? : Bool = true,
  enabled? : Bool = true,
  hook? : (Node) -> Unit,
  report? : (String, Node?) -> Unit,
) -> TransformSpec {
  with_transform_hooks(
    make_transform_spec(
      PruneEmptyElements,
      enabled~,
      selector=selector.to_owned(),
      strip_whitespace~,
    ),
    hook,
    report,
  )
}

///|
/// Build a transform that linkifies URL and email text nodes.
pub fn TransformSpec::linkify(
  config? : LinkifyConfig,
  skip_tags? : Array[String],
  enabled? : Bool = true,
  hook? : (Node) -> Unit,
  report? : (String, Node?) -> Unit,
) -> TransformSpec {
  let config = config.unwrap_or(LinkifyConfig::new())
  let skip_tags = skip_tags.unwrap_or(linkify_default_dom_skip_tags())
  with_transform_hooks(
    make_transform_spec(
      LinkifyTextNodes,
      enabled~,
      linkify_config=config,
      linkify_skip_tags=skip_tags,
    ),
    hook,
    report,
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
  let limits = selector_limits_from_transforms(transforms)
  if transform_list_has_enabled_stage(transforms) {
    return apply_staged_transforms(node, transforms, limits)
  }
  apply_stage_items(node, transforms, limits)
}

///|
fn selector_limits_from_transforms(
  transforms : Array[TransformSpec],
) -> SelectorLimits {
  selector_limits_from_transform_list(transforms).unwrap_or(
    default_selector_limits(),
  )
}

///|
fn selector_limits_from_transform_list(
  transforms : Array[TransformSpec],
) -> SelectorLimits? {
  let mut limits : SelectorLimits? = None
  for transform in transforms {
    if transform.enabled {
      match transform.kind {
        SanitizeTree =>
          match transform.sanitize_policy {
            Some(policy) => limits = Some(policy.selector_limits)
            None => limits = Some(default_selector_limits())
          }
        StageGroup =>
          match
            selector_limits_from_transform_list(transform.stage_transforms) {
            Some(stage_limits) => limits = Some(stage_limits)
            None => ()
          }
        _ => ()
      }
    }
  }
  limits
}

///|
fn transform_list_has_enabled_stage(transforms : Array[TransformSpec]) -> Bool {
  for transform in transforms {
    if transform.enabled {
      match transform.kind {
        StageGroup => return true
        _ => ()
      }
    }
  }
  false
}

///|
fn apply_staged_transforms(
  node : Node,
  transforms : Array[TransformSpec],
  limits : SelectorLimits,
) -> Node raise HtmlError {
  let mut current = node
  let mut pending : Array[TransformSpec] = []
  let mut stage_index = 0
  for transform in transforms {
    match transform.kind {
      StageGroup =>
        if transform.enabled {
          if !pending.is_empty() {
            stage_index += 1
            current = apply_stage_items(current, pending, limits)
            pending = []
          }
          stage_index += 1
          current = apply_explicit_stage(
            current, transform, stage_index, limits,
          )
        }
      _ => pending.push(transform)
    }
  }
  if !pending.is_empty() {
    current = apply_stage_items(current, pending, limits)
  }
  current
}

///|
fn apply_explicit_stage(
  node : Node,
  stage : TransformSpec,
  index : Int,
  limits : SelectorLimits,
) -> Node raise HtmlError {
  transform_call_hook(node, stage)
  transform_report(stage, "Stage " + index.to_string(), Some(node))
  apply_stage_items(node, stage.stage_transforms, limits)
}

///|
fn apply_stage_items(
  node : Node,
  transforms : Array[TransformSpec],
  limits : SelectorLimits,
) -> Node raise HtmlError {
  let transforms = flatten_enabled_stage_items(transforms)
  let mut current = node
  let mut index = 0
  while index < transforms.length() {
    let transform = transforms[index]
    match transform.kind {
      PruneEmptyElements => {
        let prune_batch : Array[TransformSpec] = []
        while index < transforms.length() &&
              transform_kind_is_prune_empty(transforms[index]) {
          prune_batch.push(transforms[index])
          index += 1
        }
        apply_prune_empty_transforms(current, prune_batch, limits)
      }
      _ => {
        current = apply_transform(current, transform, limits)
        index += 1
      }
    }
  }
  current
}

///|
fn transform_kind_is_prune_empty(transform : TransformSpec) -> Bool {
  match transform.kind {
    PruneEmptyElements => true
    _ => false
  }
}

///|
fn flatten_enabled_stage_items(
  transforms : Array[TransformSpec],
) -> Array[TransformSpec] {
  let out : Array[TransformSpec] = []
  for transform in transforms {
    if transform.enabled {
      match transform.kind {
        StageGroup => {
          let nested = flatten_enabled_stage_items(transform.stage_transforms)
          for item in nested {
            out.push(item)
          }
        }
        _ => out.push(transform)
      }
    }
  }
  out
}

///|
fn apply_transform(
  node : Node,
  transform : TransformSpec,
  limits : SelectorLimits,
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
      apply_selector_transform(node, transform, limits)
      node
    }
    DecideNode => {
      apply_decide_transform(node, transform, limits)
      node
    }
    SanitizeTree =>
      sanitize_dom_with_observer(
        node,
        transform.sanitize_policy,
        sanitize_transform_observer(transform),
      )
    DropCommentNodes => {
      apply_drop_kind_transform(node, Comment, transform)
      node
    }
    DropDoctypeNodes => {
      apply_drop_kind_transform(node, Doctype, transform)
      node
    }
    DropForeignNamespaceNodes => {
      apply_drop_foreign_namespaces_transform(node, transform)
      node
    }
    CollapseTextWhitespace => {
      apply_collapse_whitespace_transform(
        node,
        transform_skip_tag_set(transform.skip_tags),
        transform,
      )
      node
    }
    PruneEmptyElements => {
      apply_prune_empty_transform(node, transform, limits)
      node
    }
    LinkifyTextNodes => {
      let config = transform.linkify_config.unwrap_or(LinkifyConfig::new())
      apply_linkify_transform(
        node,
        config,
        transform_skip_tag_set(transform.linkify_skip_tags),
        transform,
      )
    }
    StageGroup => apply_stage_items(node, transform.stage_transforms, limits)
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
fn transform_call_hook(node : Node, transform : TransformSpec) -> Unit {
  match transform.node_hook {
    Some(hook) => (hook.callback)(node)
    None => ()
  }
}

///|
fn sanitize_transform_observer(
  transform : TransformSpec,
) -> SanitizeTransformObserver? {
  match (transform.node_hook, transform.report_callback) {
    (None, None) => None
    _ =>
      Some({
        hook: transform.node_hook,
        report_callback: transform.report_callback,
      })
  }
}

///|
fn transform_report(
  transform : TransformSpec,
  message : String,
  node : Node?,
) -> Unit {
  match transform.report_callback {
    Some(report) => (report.callback)(message, node)
    None => ()
  }
}

///|
fn transform_report_node_action(
  node : Node,
  transform : TransformSpec,
  action : StringView,
) -> Unit {
  transform_call_hook(node, transform)
  let tag = lower_ascii(node.name)
  transform_report(
    transform,
    action.to_owned() +
    " <" +
    tag +
    "> (matched selector '" +
    transform.selector +
    "')",
    Some(node),
  )
}

///|
fn apply_selector_transform(
  root : Node,
  transform : TransformSpec,
  limits : SelectorLimits,
) -> Unit raise HtmlError {
  match root.kind {
    Document | Fragment | Element => transform_children(root, transform, limits)
    _ => ()
  }
}

///|
fn transform_children(
  parent : Node,
  transform : TransformSpec,
  limits : SelectorLimits,
) -> Unit raise HtmlError {
  let mut index = 0
  while index < parent.children.length() {
    let child = parent.children[index]
    if child.kind == Element &&
      transform_matches_element(child, transform, limits) {
      match transform.kind {
        DropElements => {
          transform_report_node_action(child, transform, "Dropped")
          remove_child_at(parent, index)
        }
        UnwrapElements => {
          transform_report_node_action(child, transform, "Unwrapped")
          let inserted = unwrap_child_at(parent, index)
          if inserted > 0 {
            transform_inserted_children_after_unwrap(
              parent, index, inserted, transform, limits,
            )
            index += inserted
          }
        }
        EscapeElements => {
          transform_report_node_action(child, transform, "Escaped")
          let inserted = escape_transform_child_at(parent, index)
          if inserted == 0 {
            ()
          }
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
  parent : Node,
  start : Int,
  count : Int,
  transform : TransformSpec,
  limits : SelectorLimits,
) -> Unit raise HtmlError {
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
  root : Node,
  transform : TransformSpec,
  limits : SelectorLimits,
) -> Unit raise HtmlError {
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
fn decide_node_label(node : Node) -> String {
  if node.name.has_prefix("#") || node.name == "!doctype" {
    node.name
  } else {
    lower_ascii(node.name)
  }
}

///|
fn decide_transform_matches_node(
  node : Node,
  transform : TransformSpec,
  all_nodes : Bool,
  limits : SelectorLimits,
) -> Bool raise HtmlError {
  if all_nodes {
    true
  } else {
    node.kind == Element && transform_matches_element(node, transform, limits)
  }
}

///|
fn decide_transform_action(
  node : Node,
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
fn decide_escape_child_at(parent : Node, index : Int) -> Unit {
  match parent.children[index].kind {
    Element => ignore(escape_transform_child_at(parent, index))
    Document | Fragment => ignore(unwrap_child_at(parent, index))
    Text | Comment | Doctype => remove_child_at(parent, index)
  }
}

///|
fn decide_transform_children(
  parent : Node,
  transform : TransformSpec,
  limits : SelectorLimits,
) -> Unit raise HtmlError {
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
        Drop => remove_child_at(parent, index)
        Unwrap => ignore(unwrap_child_at(parent, index))
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
  node : Node,
  transform : TransformSpec,
  limits : SelectorLimits,
) -> Bool raise HtmlError {
  match transform.kind {
    MergeAttributeTokens => lower_ascii(node.name) == transform.merge_tag
    _ => matches_selector_list_with_limits(node, transform.selector, limits)
  }
}

///|
fn empty_transform_node(node : Node) -> Bool {
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
  node : Node,
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
fn apply_edit_transform(node : Node, transform : TransformSpec) -> Unit {
  match transform.node_callback {
    Some(callback) => {
      transform_report_node_action(node, transform, "Edited")
      (callback.callback)(node)
    }
    None => ()
  }
}

///|
fn apply_edit_attrs_transform(node : Node, transform : TransformSpec) -> Bool {
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
fn apply_set_attrs_transform(node : Node, transform : TransformSpec) -> Bool {
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
  node : Node,
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
fn apply_drop_attrs_transform(node : Node, transform : TransformSpec) -> Bool {
  if transform.attr_patterns.is_empty() || node.attrs.length() == 0 {
    return false
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
    return false
  }
  let out : Map[String, String?] = {}
  for raw_name, value in node.attrs {
    let name = lower_ascii(raw_name[:].trim())
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
      let normalized = lower_ascii(trimmed)
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
fn apply_merge_attrs_transform(node : Node, transform : TransformSpec) -> Bool {
  if transform.merge_attr == "" || transform.merge_tokens.is_empty() {
    return false
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
    true
  } else {
    false
  }
}

///|
fn find_attr_key_case_insensitive(node : Node, target : String) -> String? {
  for key, _ in node.attrs {
    if lower_ascii(key) == target {
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
fn transform_report_unsafe_url_attr(
  node : Node,
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
  node : Node,
  transform : TransformSpec,
) -> Bool {
  guard transform.sanitize_policy is Some(policy) else { return false }
  if node.attrs.length() == 0 {
    return false
  }
  let to_drop : Array[String] = []
  let to_set : Map[String, String?] = {}
  let tag_name = lower_ascii(node.name)
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
        push_unique_string(to_drop, content_key)
      }
    }
    _ => ()
  }
  let effectively_foreign = node_is_effectively_foreign(node)
  let keys = node.attrs.keys().to_array()
  for key in keys {
    let attr_name = lower_ascii(key)
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
      push_unique_string(to_drop, key)
      continue
    }
    match current_value {
      Some(raw_value) =>
        match policy.url_policy.lookup_rule(tag_name, attr_name) {
          None => {
            transform_report_unsafe_url_attr(
              node,
              transform,
              attr_name,
              reason="no rule",
            )
            push_unique_string(to_drop, key)
          }
          Some(_) =>
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
                  push_unique_string(to_drop, key)
                  to_set[attr_name] = Some(cleaned)
                }
              None => {
                transform_report_unsafe_url_attr(node, transform, attr_name)
                push_unique_string(to_drop, key)
              }
            }
        }
      None => {
        transform_report_unsafe_url_attr(node, transform, attr_name)
        push_unique_string(to_drop, key)
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
  node : Node,
  transform : TransformSpec,
) -> Bool {
  guard transform.sanitize_policy is Some(policy) else { return false }
  guard find_attr_key_case_insensitive(node, "style") is Some(style_key) else {
    return false
  }
  let tag_name = lower_ascii(node.name)
  match node.attrs.get(style_key).unwrap() {
    Some(raw_value) =>
      match sanitize_inline_style_value(policy, tag_name, raw_value) {
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
fn apply_drop_kind_transform(
  root : Node,
  kind : NodeKind,
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
          remove_child_at(root, index)
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
fn node_has_foreign_namespace(node : Node) -> Bool {
  match node.ns {
    Some(ns) => ns != "html"
    None => false
  }
}

///|
fn apply_drop_foreign_namespaces_transform(
  root : Node,
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
            "Unsafe tag '" + lower_ascii(child.name) + "' (foreign namespace)",
            Some(child),
          )
          remove_child_at(root, index)
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
  root : Node,
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
        skip_tags.contains(lower_ascii(root.name)),
        transform,
      )
    _ => ()
  }
}

///|
fn collapse_whitespace_children(
  parent : Node,
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
        collapse_whitespace_children(child, skip_tags, skip, transform)
      Element => {
        let child_skip = skip || skip_tags.contains(lower_ascii(child.name))
        collapse_whitespace_children(child, skip_tags, child_skip, transform)
      }
      _ => ()
    }
    index += 1
  }
}

///|
fn prune_empty_node_is_effectively_empty(
  node : Node,
  strip_whitespace : Bool,
) -> Bool {
  if node.kind != Element {
    return false
  }
  if node.ns == Some("html") && is_void_element(node.name) {
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
  root : Node,
  transform : TransformSpec,
  limits : SelectorLimits,
) -> Unit raise HtmlError {
  apply_prune_empty_transforms(root, [transform], limits)
}

///|
fn apply_prune_empty_transforms(
  root : Node,
  transforms : Array[TransformSpec],
  limits : SelectorLimits,
) -> Unit raise HtmlError {
  match root.kind {
    Document | Fragment | Element =>
      prune_empty_children(root, transforms, limits)
    _ => ()
  }
}

///|
fn prune_empty_children(
  parent : Node,
  transforms : Array[TransformSpec],
  limits : SelectorLimits,
) -> Unit raise HtmlError {
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
              lower_ascii(child.name) +
              "> (matched selector '" +
              transform.selector +
              "')",
              Some(child),
            )
            remove_child_at(parent, index)
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
  root : Node,
  config : LinkifyConfig,
  skip_tags : Set[String],
  transform : TransformSpec,
) -> Node {
  match root.kind {
    Text => {
      let wrapper = fragment(children=[root])
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
        skip_tags.contains(lower_ascii(root.name))
      linkify_transform_children(root, config, skip_tags, skip, transform)
      root
    }
    Comment | Doctype => root
  }
}

///|
fn linkify_transform_children(
  parent : Node,
  config : LinkifyConfig,
  skip_tags : Set[String],
  skip_linkify : Bool,
  transform : TransformSpec,
) -> Unit {
  let mut index = 0
  while index < parent.children.length() {
    let child = parent.children[index]
    match child.kind {
      Text if !skip_linkify && child.data != "" => {
        let matches = find_links_with_config(child.data, config)
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
          let inserted = linkify_text_child_at_matches(
            parent, index, child, matches,
          )
          if inserted > 0 {
            index += inserted
          } else {
            index += 1
          }
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
          skip_tags.contains(lower_ascii(child.name))
        linkify_transform_children(
          child, config, skip_tags, child_skip, transform,
        )
        index += 1
      }
      _ => index += 1
    }
  }
}
