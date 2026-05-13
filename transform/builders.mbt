///|
/// Build a transform that removes elements matching `selector`.
pub fn TransformSpec::drop(
  selector : StringView,
  enabled? : Bool = true,
  hook? : (@dom.Node) -> Unit,
  report? : (String, @dom.Node?) -> Unit,
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
  hook? : (@dom.Node) -> Unit,
  report? : (String, @dom.Node?) -> Unit,
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
  hook? : (@dom.Node) -> Unit,
  report? : (String, @dom.Node?) -> Unit,
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
  hook? : (@dom.Node) -> Unit,
  report? : (String, @dom.Node?) -> Unit,
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
  callback : (@dom.Node) -> Unit,
  enabled? : Bool = true,
  hook? : (@dom.Node) -> Unit,
  report? : (String, @dom.Node?) -> Unit,
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
  callback : (@dom.Node) -> DecideAction,
  enabled? : Bool = true,
  hook? : (@dom.Node) -> Unit,
  report? : (String, @dom.Node?) -> Unit,
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
  callback : (@dom.Node) -> Unit,
  enabled? : Bool = true,
  hook? : (@dom.Node) -> Unit,
  report? : (String, @dom.Node?) -> Unit,
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
  hook? : (@dom.Node) -> Unit,
  report? : (String, @dom.Node?) -> Unit,
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
  hook? : (@dom.Node) -> Unit,
  report? : (String, @dom.Node?) -> Unit,
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
  hook? : (@dom.Node) -> Unit,
  report? : (String, @dom.Node?) -> Unit,
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
  callback : (@dom.Node) -> Map[String, String?]?,
  enabled? : Bool = true,
  hook? : (@dom.Node) -> Unit,
  report? : (String, @dom.Node?) -> Unit,
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
  hook? : (@dom.Node) -> Unit,
  report? : (String, @dom.Node?) -> Unit,
) -> TransformSpec {
  let tag = @syn.lower_ascii(tag.trim())
  let attr = @syn.lower_ascii(attr.trim())
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
  url_policy~ : @san.UrlPolicy,
  enabled? : Bool = true,
  hook? : (@dom.Node) -> Unit,
  report? : (String, @dom.Node?) -> Unit,
) -> TransformSpec {
  with_transform_hooks(
    make_transform_spec(
      DropUrlAttributes,
      enabled~,
      selector=selector.to_owned(),
      sanitize_policy=@san.SanitizationPolicy::new([], url_policy~),
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
  hook? : (@dom.Node) -> Unit,
  report? : (String, @dom.Node?) -> Unit,
) -> TransformSpec {
  with_transform_hooks(
    make_transform_spec(
      AllowStyleAttributes,
      enabled~,
      selector=selector.to_owned(),
      sanitize_policy=@san.SanitizationPolicy::new(
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
  policy? : @san.SanitizationPolicy,
  enabled? : Bool = true,
  hook? : (@dom.Node) -> Unit,
  report? : (String, @dom.Node?) -> Unit,
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
  hook? : (@dom.Node) -> Unit,
  report? : (String, @dom.Node?) -> Unit,
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
  hook? : (@dom.Node) -> Unit,
  report? : (String, @dom.Node?) -> Unit,
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
  hook? : (@dom.Node) -> Unit,
  report? : (String, @dom.Node?) -> Unit,
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
  hook? : (@dom.Node) -> Unit,
  report? : (String, @dom.Node?) -> Unit,
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
  hook? : (@dom.Node) -> Unit,
  report? : (String, @dom.Node?) -> Unit,
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
  hook? : (@dom.Node) -> Unit,
  report? : (String, @dom.Node?) -> Unit,
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
  config? : @link.LinkifyConfig,
  skip_tags? : Array[String],
  enabled? : Bool = true,
  hook? : (@dom.Node) -> Unit,
  report? : (String, @dom.Node?) -> Unit,
) -> TransformSpec {
  let config = config.unwrap_or(@link.LinkifyConfig::new())
  let skip_tags = skip_tags.unwrap_or(@link.linkify_default_dom_skip_tags())
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
