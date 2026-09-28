///|
fn unescape_quoted_pseudo_arg(value : StringView, quote : Char) -> String {
  let out = StringBuilder(size_hint=value.length())
  let mut escaped = false
  for ch in value {
    if escaped {
      if ch == quote || ch == '\\' {
        out.write_char(ch)
      } else {
        out.write_char('\\')
        out.write_char(ch)
      }
      escaped = false
    } else if ch == '\\' {
      escaped = true
    } else {
      out.write_char(ch)
    }
  }
  if escaped {
    out.write_char('\\')
  }
  out.to_string()
}

///|
fn unquote_pseudo_arg(arg : StringView) -> String? {
  let arg = arg.trim()
  if arg.is_empty() {
    return None
  }
  if arg.length() >= 2 {
    let end = arg.length() - 1
    match (arg.get_char(0), arg.get_char(end)) {
      (Some('"'), Some('"')) => {
        guard arg.get_view(start=1, end~) is Some(inner) else { return None }
        return Some(unescape_quoted_pseudo_arg(inner, '"'))
      }
      (Some('\''), Some('\'')) => {
        guard arg.get_view(start=1, end~) is Some(inner) else { return None }
        return Some(unescape_quoted_pseudo_arg(inner, '\''))
      }
      _ => ()
    }
  }
  Some(arg.to_owned())
}

///|
fn remove_node_identity(nodes : Array[@dom.Node], node : @dom.Node) -> Unit {
  let mut index = 0
  while index < nodes.length() {
    if physical_equal(nodes[index], node) {
      ignore(nodes.remove(index))
      return
    }
    index += 1
  }
}

///|
fn node_text_cache_get(
  nodes : Array[@dom.Node],
  texts : Array[String],
  node : @dom.Node,
) -> String? {
  for index in 0..<nodes.length() {
    if physical_equal(nodes[index], node) {
      return Some(texts[index])
    }
  }
  None
}

///|
fn node_text_cache_set(
  nodes : Array[@dom.Node],
  texts : Array[String],
  node : @dom.Node,
  text : String,
) -> Unit {
  nodes.push(node)
  texts.push(text)
}

///|
/// Text of `node` for `:contains` and the match byte budget: the trimmed
/// data of text nodes, joined with single spaces, template contents first.
fn selector_text_content(node : @dom.Node) -> String {
  if text_walk_is_regular(node) {
    regular_text_content(node)
  } else {
    general_text_content(node)
  }
}

///|
/// Whether the walk of `general_text_content` from `start` only follows
/// regular tree edges: into a child whose `parent` is the node being expanded,
/// that is its first occurrence in `children` and not also the node's
/// template contents, or into template contents whose `parent` is the host,
/// and never back into `start`.
///
/// Then every node is reached exactly once: if `y` were the first node reached
/// twice, both edges would come from `y.parent`, expanded only once (it was not
/// reached twice before `y`), so they would be two occurrences in `children`
/// or both a child and the contents, which the checks exclude. Without shared
/// or cyclic nodes, `general_text_content` reduces to `regular_text_content`.
fn text_walk_is_regular(start : @dom.Node) -> Bool {
  let stack : Array[@dom.Node] = [start]
  while stack.pop() is Some(node) {
    match node.template_contents {
      Some(contents) => {
        if physical_equal(contents, start) ||
          !(contents.parent is Some(host) && physical_equal(host, node)) {
          return false
        }
        stack.push(contents)
      }
      None => ()
    }
    let children = node.children
    for index, child in children {
      if physical_equal(child, start) ||
        !(child.parent is Some(parent) && physical_equal(parent, node)) ||
        (
          node.template_contents is Some(contents) &&
          physical_equal(contents, child)
        ) {
        return false
      }
      for earlier in 0..<index {
        if physical_equal(children[earlier], child) {
          return false
        }
      }
      stack.push(child)
    }
  }
  true
}

///|
priv struct TextFrame {
  node : @dom.Node
  parts : Array[String]
  /// Next part to collect: `-1` for template contents, then child indices.
  mut next : Int
}

///|
/// `general_text_content` for a walk that reaches every node exactly once, in
/// time linear in the size of the subtree.
fn regular_text_content(start : @dom.Node) -> String {
  if start.kind == Text {
    return start.data[:].trim().to_owned()
  }
  let stack : Array[TextFrame] = [{ node: start, parts: [], next: -1, }]
  while stack.last() is Some(frame) {
    let index = frame.next
    frame.next = index + 1
    let child = if index < 0 {
      frame.node.template_contents
    } else {
      frame.node.children.get(index)
    }
    match child {
      Some(child) if child.kind == Text => {
        let text = child.data[:].trim().to_owned()
        if text != "" {
          frame.parts.push(text)
        }
      }
      Some(child) => stack.push({ node: child, parts: [], next: -1, })
      None =>
        if index >= 0 {
          ignore(stack.pop())
          let text = frame.parts.join(" ")
          match stack.last() {
            Some(parent) => if text != "" { parent.parts.push(text) }
            None => return text
          }
        }
    }
  }
  ""
}

///|
fn general_text_content(node : @dom.Node) -> String {
  let cache_nodes : Array[@dom.Node] = []
  let cache_texts : Array[String] = []
  let visiting : Array[@dom.Node] = []
  let stack : Array[(@dom.Node, Bool)] = [(node, false)]
  while !stack.is_empty() {
    let (current, visited) = stack[stack.length() - 1]
    ignore(stack.pop())
    if node_text_cache_get(cache_nodes, cache_texts, current) is Some(_) {
      continue
    }
    if visited {
      remove_node_identity(visiting, current)
      if current.kind == Text {
        node_text_cache_set(
          cache_nodes,
          cache_texts,
          current,
          current.data[:].trim().to_owned(),
        )
      } else {
        let parts : Array[String] = []
        match current.template_contents {
          Some(contents) =>
            match node_text_cache_get(cache_nodes, cache_texts, contents) {
              Some(text) if text != "" => parts.push(text)
              _ => ()
            }
          None => ()
        }
        for child in current.children {
          match node_text_cache_get(cache_nodes, cache_texts, child) {
            Some(text) if text != "" => parts.push(text)
            _ => ()
          }
        }
        node_text_cache_set(cache_nodes, cache_texts, current, parts.join(" "))
      }
    } else if node_identity_seen(visiting, current) {
      node_text_cache_set(cache_nodes, cache_texts, current, "")
    } else {
      visiting.push(current)
      stack.push((current, true))
      let mut index = current.children.length()
      while index > 0 {
        index -= 1
        stack.push((current.children[index], false))
      }
      match current.template_contents {
        Some(contents) => stack.push((contents, false))
        None => ()
      }
    }
  }
  node_text_cache_get(cache_nodes, cache_texts, node).unwrap_or("")
}

///|
fn contains_text(node : @dom.Node, arg : StringView) -> Bool {
  guard unquote_pseudo_arg(arg) is Some(needle) else { return false }
  if needle == "" {
    return true
  }
  let text = selector_text_content(node)
  string_view_contains(text, needle)
}
