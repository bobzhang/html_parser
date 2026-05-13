///|
fn unescape_quoted_pseudo_arg(value : StringView, quote : Char) -> String {
  let out = StringBuilder::new(size_hint=value.length())
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
fn selector_text_content(node : @dom.Node) -> String {
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
