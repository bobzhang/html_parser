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
