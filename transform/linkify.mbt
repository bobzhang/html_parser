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
