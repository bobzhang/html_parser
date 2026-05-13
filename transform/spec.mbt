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
fn default_selector_limits() -> @sel.SelectorLimits {
  @sel.SelectorLimits::new()
}

///|
priv struct TransformNodeCallback {
  callback : (@dom.Node) -> Unit
}

///|
impl Debug for TransformNodeCallback with to_repr(_) {
  Repr::opaque_("TransformNodeCallback", Repr::unit())
}

///|
priv struct TransformAttrsCallback {
  callback : (@dom.Node) -> Map[String, String?]?
}

///|
impl Debug for TransformAttrsCallback with to_repr(_) {
  Repr::opaque_("TransformAttrsCallback", Repr::unit())
}

///|
priv struct TransformDecideCallback {
  callback : (@dom.Node) -> DecideAction
}

///|
impl Debug for TransformDecideCallback with to_repr(_) {
  Repr::opaque_("TransformDecideCallback", Repr::unit())
}

///|
priv struct TransformReportCallback {
  callback : (String, @dom.Node?) -> Unit
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
  priv sanitize_policy : @san.SanitizationPolicy?
  priv node_callback : TransformNodeCallback?
  priv attrs_callback : TransformAttrsCallback?
  priv decide_callback : TransformDecideCallback?
  priv node_hook : TransformNodeCallback?
  priv report_callback : TransformReportCallback?
  priv skip_tags : Array[String]
  priv strip_whitespace : Bool
  priv linkify_config : @link.LinkifyConfig?
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
  sanitize_policy? : @san.SanitizationPolicy,
  node_callback? : TransformNodeCallback,
  attrs_callback? : TransformAttrsCallback,
  decide_callback? : TransformDecideCallback,
  node_hook? : TransformNodeCallback,
  report_callback? : TransformReportCallback,
  skip_tags? : Array[String] = [],
  strip_whitespace? : Bool = true,
  linkify_config? : @link.LinkifyConfig,
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
  callback : ((@dom.Node) -> Unit)?,
) -> TransformNodeCallback? {
  match callback {
    Some(callback) => Some({ callback, })
    None => None
  }
}

///|
fn wrap_transform_report_callback(
  callback : ((String, @dom.Node?) -> Unit)?,
) -> TransformReportCallback? {
  match callback {
    Some(callback) => Some({ callback, })
    None => None
  }
}

///|
fn with_transform_hooks(
  spec : TransformSpec,
  hook : ((@dom.Node) -> Unit)?,
  report : ((String, @dom.Node?) -> Unit)?,
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
