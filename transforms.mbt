///|
priv enum TransformKind {
  DropElements
  UnwrapElements
  EscapeElements
  EmptyElements
  DropCommentNodes
  DropDoctypeNodes
  CollapseTextWhitespace
  LinkifyTextNodes
} derive(Debug)

///|
/// A DOM transform specification for `apply_transforms`.
///
/// The current port covers deterministic structural transforms and utility
/// transforms. Callback-based Python specs will be added as separate slices.
pub struct TransformSpec {
  priv kind : TransformKind
  priv selector : String
  priv skip_tags : Array[String]
  priv linkify_config : LinkifyConfig?
  priv linkify_skip_tags : Array[String]
} derive(Debug)

///|
fn make_transform_spec(
  kind : TransformKind,
  selector? : String = "",
  skip_tags? : Array[String] = [],
  linkify_config? : LinkifyConfig,
  linkify_skip_tags? : Array[String] = [],
) -> TransformSpec {
  {
    kind,
    selector,
    skip_tags: skip_tags.copy(),
    linkify_config,
    linkify_skip_tags: linkify_skip_tags.copy(),
  }
}

///|
/// Build a transform that removes elements matching `selector`.
pub fn TransformSpec::drop(selector : StringView) -> TransformSpec {
  make_transform_spec(DropElements, selector=selector.to_owned())
}

///|
/// Build a transform that replaces matching elements with their children.
pub fn TransformSpec::unwrap(selector : StringView) -> TransformSpec {
  make_transform_spec(UnwrapElements, selector=selector.to_owned())
}

///|
/// Build a transform that emits matching element tags as text and keeps children.
pub fn TransformSpec::escape(selector : StringView) -> TransformSpec {
  make_transform_spec(EscapeElements, selector=selector.to_owned())
}

///|
/// Build a transform that removes all children from matching elements.
pub fn TransformSpec::empty(selector : StringView) -> TransformSpec {
  make_transform_spec(EmptyElements, selector=selector.to_owned())
}

///|
/// Build a transform that removes comment nodes.
pub fn TransformSpec::drop_comments() -> TransformSpec {
  make_transform_spec(DropCommentNodes)
}

///|
/// Build a transform that removes doctype nodes.
pub fn TransformSpec::drop_doctype() -> TransformSpec {
  make_transform_spec(DropDoctypeNodes)
}

///|
fn default_collapse_whitespace_skip_tags() -> Array[String] {
  ["code", "pre", "script", "style", "textarea", "title"]
}

///|
/// Build a transform that collapses runs of HTML whitespace in text nodes.
pub fn TransformSpec::collapse_whitespace(
  skip_tags? : Array[String],
) -> TransformSpec {
  make_transform_spec(
    CollapseTextWhitespace,
    skip_tags=skip_tags.unwrap_or(default_collapse_whitespace_skip_tags()),
  )
}

///|
/// Build a transform that linkifies URL and email text nodes.
pub fn TransformSpec::linkify(
  config? : LinkifyConfig,
  skip_tags? : Array[String],
) -> TransformSpec {
  let config = config.unwrap_or(LinkifyConfig::new())
  let skip_tags = skip_tags.unwrap_or(linkify_default_dom_skip_tags())
  make_transform_spec(
    LinkifyTextNodes,
    linkify_config=config,
    linkify_skip_tags=skip_tags,
  )
}

///|
/// Apply DOM transforms in order.
///
/// The transform mutates and returns `node`. Selector transforms process the
/// children of the supplied root, matching the Python constructor-time pipeline
/// where the root is normally a document or document fragment container.
pub fn apply_transforms(node : Node, transforms : Array[TransformSpec]) -> Node {
  for transform in transforms {
    apply_transform(node, transform)
  }
  node
}

///|
fn apply_transform(node : Node, transform : TransformSpec) -> Unit {
  match transform.kind {
    DropElements | UnwrapElements | EscapeElements | EmptyElements =>
      apply_selector_transform(node, transform)
    DropCommentNodes => apply_drop_kind_transform(node, Comment)
    DropDoctypeNodes => apply_drop_kind_transform(node, Doctype)
    CollapseTextWhitespace =>
      apply_collapse_whitespace_transform(
        node,
        transform_skip_tag_set(transform.skip_tags),
      )
    LinkifyTextNodes => {
      let config = transform.linkify_config.unwrap_or(LinkifyConfig::new())
      let skip_tags = transform.linkify_skip_tags.copy()
      ignore(linkify_dom(node, config~, skip_tags~))
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
    if child.kind == Element && matches(child, transform.selector) {
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
