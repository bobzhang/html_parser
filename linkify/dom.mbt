///|
/// Linkify URL and email text inside a DOM subtree.
///
/// The transform mutates and returns `node`. By default it skips existing
/// anchors and whitespace-preserving tags (`code`, `pre`, `script`, `style`,
/// and `textarea`), while still processing normal children such as template
/// contents.
pub fn linkify_dom(
  node : @dom.Node,
  config? : LinkifyConfig,
  skip_tags? : Array[String],
) -> @dom.Node {
  let config = match config {
    Some(value) => value
    None => LinkifyConfig::new()
  }
  let skip_tags = match skip_tags {
    Some(value) => value
    None => linkify_default_dom_skip_tags()
  }
  let skip_set = linkify_dom_skip_tag_set(skip_tags)
  match node.kind {
    Text => {
      let wrapper = @dom.fragment(children=[node])
      linkify_dom_children(wrapper, config, skip_set, false)
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
      let skip = node.kind == Element &&
        skip_set.contains(@syn.lower_ascii(node.name))
      linkify_dom_children(node, config, skip_set, skip)
      node
    }
    Comment | Doctype => node
  }
}

///|
pub fn linkify_default_dom_skip_tags() -> Array[String] {
  ["a", "code", "pre", "script", "style", "textarea"]
}

///|
fn linkify_dom_skip_tag_set(tags : Array[String]) -> Set[String] {
  let out : Set[String] = Set::default()
  for tag in tags {
    let normalized = @syn.lower_ascii(tag.trim())
    if normalized != "" {
      out.add(normalized)
    }
  }
  out
}

///|
fn linkify_dom_children(
  parent : @dom.Node,
  config : LinkifyConfig,
  skip_tags : Set[String],
  skip_linkify : Bool,
) -> Unit {
  let mut index = 0
  while index < parent.children.length() {
    let child = parent.children[index]
    match child.kind {
      Text if !skip_linkify && child.data != "" => {
        let inserted = linkify_text_child_at(parent, index, child, config)
        if inserted > 0 {
          index += inserted
        } else {
          index += 1
        }
      }
      Document | Fragment => {
        linkify_dom_children(child, config, skip_tags, skip_linkify)
        index += 1
      }
      Element => {
        let child_skip = skip_linkify ||
          skip_tags.contains(@syn.lower_ascii(child.name))
        linkify_dom_children(child, config, skip_tags, child_skip)
        index += 1
      }
      _ => index += 1
    }
  }
}

///|
fn linkify_text_child_at(
  parent : @dom.Node,
  index : Int,
  child : @dom.Node,
  config : LinkifyConfig,
) -> Int {
  let matches = find_links_with_config(child.data, config)
  if matches.is_empty() {
    return 0
  }
  linkify_text_child_at_matches(parent, index, child, matches)
}

///|
pub fn linkify_text_child_at_matches(
  parent : @dom.Node,
  index : Int,
  child : @dom.Node,
  matches : Array[LinkMatch],
) -> Int {
  if matches.is_empty() {
    return 0
  }
  let replacements : Array[@dom.Node] = []
  let mut cursor = 0
  for m in matches {
    if m.start > cursor {
      match child.data.get_view(start=cursor, end=m.start) {
        Some(prefix) if !prefix.is_empty() =>
          replacements.push(@dom.text(prefix))
        _ => ()
      }
    }
    let ns = parent.ns.unwrap_or("html")
    let anchor = @dom.element(
      "a",
      attrs={ "href": Some(m.href) },
      children=[@dom.text(m.text)],
      ns~,
    )
    replacements.push(anchor)
    cursor = m.end
  }
  if cursor < child.data.length() {
    match child.data.get_view(start=cursor, end=child.data.length()) {
      Some(tail) if !tail.is_empty() => replacements.push(@dom.text(tail))
      _ => ()
    }
  }
  ignore(parent.children.remove(index))
  child.parent = None
  let mut inserted = 0
  for replacement in replacements {
    replacement.parent = Some(parent)
    parent.children.insert(index + inserted, replacement)
    inserted += 1
  }
  inserted
}
