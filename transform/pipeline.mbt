///|
/// Apply DOM transforms in order.
///
/// The transform mutates and returns the current root. Selector transforms process the
/// children of the supplied root, matching the Python constructor-time pipeline
/// where the root is normally a document or document fragment container.
pub fn apply_transforms(
  node : @dom.Node,
  transforms : Array[TransformSpec],
) -> @dom.Node raise @core.HtmlError {
  let limits = selector_limits_from_transforms(transforms)
  if transform_list_has_enabled_stage(transforms) {
    return apply_staged_transforms(node, transforms, limits)
  }
  apply_stage_items(node, transforms, limits)
}

///|
fn selector_limits_from_transforms(
  transforms : Array[TransformSpec],
) -> @sel.SelectorLimits {
  selector_limits_from_transform_list(transforms).unwrap_or(
    default_selector_limits(),
  )
}

///|
fn selector_limits_from_transform_list(
  transforms : Array[TransformSpec],
) -> @sel.SelectorLimits? {
  let mut limits : @sel.SelectorLimits? = None
  for transform in transforms {
    if transform.enabled {
      match transform.kind {
        SanitizeTree =>
          match transform.sanitize_policy {
            Some(policy) => limits = Some(policy.selector_limits())
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
  node : @dom.Node,
  transforms : Array[TransformSpec],
  limits : @sel.SelectorLimits,
) -> @dom.Node raise @core.HtmlError {
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
  node : @dom.Node,
  stage : TransformSpec,
  index : Int,
  limits : @sel.SelectorLimits,
) -> @dom.Node raise @core.HtmlError {
  transform_call_hook(node, stage)
  transform_report(stage, "Stage \{index}", Some(node))
  apply_stage_items(node, stage.stage_transforms, limits)
}

///|
fn apply_stage_items(
  node : @dom.Node,
  transforms : Array[TransformSpec],
  limits : @sel.SelectorLimits,
) -> @dom.Node raise @core.HtmlError {
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
  node : @dom.Node,
  transform : TransformSpec,
  limits : @sel.SelectorLimits,
) -> @dom.Node raise @core.HtmlError {
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
      @san.sanitize_dom_with_observer(
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
      let config = transform.linkify_config.unwrap_or(LinkifyConfig())
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
    let normalized = @syn.lower_ascii(tag.trim())
    if normalized != "" {
      out.add(normalized)
    }
  }
  out
}
