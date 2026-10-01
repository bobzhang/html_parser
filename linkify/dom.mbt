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
  let config = config.unwrap_or_else(() => LinkifyConfig())
  let skip_tags = skip_tags.unwrap_or_else(() => linkify_default_dom_skip_tags())
  let skip_set = linkify_dom_skip_tag_set(skip_tags)
  match node.kind {
    Text => {
      let wrapper = @dom.fragment(children=[node])
      linkify_dom_children(
        wrapper,
        config,
        skip_set,
        false,
        then_template=false,
      )
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
      linkify_dom_children(node, config, skip_set, skip, then_template=true)
      node
    }
    Comment | Doctype => node
  }
}

///|
/// Return the default element names whose descendants are not linkified.
///
/// The list includes existing anchors and text contexts where automatic link
/// insertion would change code, raw text, or whitespace-preserving content.
pub fn linkify_default_dom_skip_tags() -> Array[String] {
  ["a", "code", "pre", "script", "style", "textarea"]
}

///|
fn linkify_dom_skip_tag_set(tags : Array[String]) -> Set[String] {
  let out : Set[String] = Default::default()
  for tag in tags {
    let normalized = @syn.lower_ascii(tag.trim())
    if normalized != "" {
      out.add(normalized)
    }
  }
  out
}

///|
/// Explicit-stack frame for `linkify_dom_children`: the children of `parent`
/// are scanned from `index` with the inherited `skip` state. When
/// `then_template` is set, `parent`'s template contents are walked (with the
/// same skip state) after its regular children.
priv struct LinkifyDomFrame {
  parent : @dom.Node
  skip : Bool
  then_template : Bool
  mut index : Int
}

///|
/// Linkify text below `root`, then (when `then_template` is set) inside its
/// template contents. Element children are walked children-first, then their
/// template contents. Uses an explicit frame stack instead of recursion so
/// deeply nested trees cannot overflow the call stack.
fn linkify_dom_children(
  root : @dom.Node,
  config : LinkifyConfig,
  skip_tags : Set[String],
  skip_linkify : Bool,
  then_template~ : Bool,
) -> Unit {
  let stack : Array[LinkifyDomFrame] = [
    { parent: root, skip: skip_linkify, then_template, index: 0, },
  ]
  while stack.last() is Some(frame) {
    let parent = frame.parent
    let index = frame.index
    if index >= parent.children.length() {
      ignore(stack.pop())
      if frame.then_template && parent.template_contents is Some(contents) {
        stack.push({
          parent: contents,
          skip: frame.skip,
          then_template: false,
          index: 0,
        })
      }
      continue
    }
    let child = parent.children[index]
    match child.kind {
      Text if !frame.skip && child.data != "" => {
        let inserted = linkify_text_child_at(parent, index, child, config)
        if inserted > 0 {
          frame.index = index + inserted
        } else {
          frame.index = index + 1
        }
      }
      Document | Fragment => {
        frame.index = index + 1
        stack.push({
          parent: child,
          skip: frame.skip,
          then_template: false,
          index: 0,
        })
      }
      Element => {
        let child_skip = frame.skip ||
          skip_tags.contains(@syn.lower_ascii(child.name))
        frame.index = index + 1
        stack.push({
          parent: child,
          skip: child_skip,
          then_template: true,
          index: 0,
        })
      }
      _ => frame.index = index + 1
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
/// Replace one text child with text and anchor nodes for precomputed matches.
///
/// `matches` must use UTF-16 offsets into `child.data`. The helper detaches the
/// original child, inserts replacement nodes at `index`, preserves the parent's
/// namespace for generated anchors, and returns the number of inserted nodes.
fn linkify_text_child_at_matches(
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
