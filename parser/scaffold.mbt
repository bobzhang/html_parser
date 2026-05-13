///|
fn document_html_element(root : @dom.Node) -> @dom.Node? {
  for child in root.children {
    if child.kind == Element && child.name == "html" {
      return Some(child)
    }
  }
  None
}

///|
fn is_document_head_element_name(name : StringView) -> Bool {
  match name {
    "base"
    | "basefont"
    | "bgsound"
    | "link"
    | "meta"
    | "noframes"
    | "noscript"
    | "script"
    | "style"
    | "template"
    | "title" => true
    _ => false
  }
}

///|
fn is_whitespace_text_node(node : @dom.Node) -> Bool {
  if node.kind != Text {
    return false
  }
  for ch in node.data {
    if !ch.is_ascii_whitespace() {
      return false
    }
  }
  true
}

///|
fn append_children_to(target : @dom.Node, children : Array[@dom.Node]) -> Unit {
  for child in children {
    target.append_child(child)
  }
}

///|
fn text_node_without_leading_ascii_whitespace(node : @dom.Node) -> @dom.Node? {
  let view = node.data[:]
  let mut start = 0
  while start < view.length() {
    match view.get_char(start) {
      Some(ch) if ch.is_ascii_whitespace() => start += ch.utf16_len()
      _ => break
    }
  }
  if start == 0 {
    Some(node)
  } else if start >= view.length() {
    None
  } else {
    Some(@dom.text(view[start:view.length()]))
  }
}

///|
fn split_text_node_leading_ascii_whitespace(
  node : @dom.Node,
) -> (@dom.Node?, @dom.Node?) {
  let view = node.data[:]
  let mut start = 0
  while start < view.length() {
    match view.get_char(start) {
      Some(ch) if ch.is_ascii_whitespace() => start += ch.utf16_len()
      _ => break
    }
  }
  if start == 0 {
    (None, Some(node))
  } else if start >= view.length() {
    (Some(node), None)
  } else {
    (Some(@dom.text(view[0:start])), Some(@dom.text(view[start:view.length()])))
  }
}

///|
fn append_body_node_contents(
  body_node : @dom.Node,
  source : @dom.Node,
  body_children : Array[@dom.Node],
) -> Unit {
  merge_missing_attrs(body_node, source)
  let existing = source.children.copy()
  source.children.clear()
  for child in existing {
    if child.kind == Element && child.name == "body" {
      append_body_node_contents(body_node, child, body_children)
    } else {
      body_children.push(child)
    }
  }
}

///|
fn append_html_node_contents(
  html_node : @dom.Node,
  source : @dom.Node,
  html_children : Array[@dom.Node],
) -> Unit {
  merge_missing_attrs(html_node, source)
  let existing = source.children.copy()
  source.children.clear()
  for child in existing {
    if child.kind == Element && child.name == "html" {
      append_html_node_contents(html_node, child, html_children)
    } else {
      html_children.push(child)
    }
  }
}

///|
fn Parser::document_doctype_is_initial(self : Parser) -> Bool {
  for child in self.root.children {
    if child.kind == Comment {
      ()
    } else if child.kind == Text && is_whitespace_text_node(child) {
      ()
    } else {
      return false
    }
  }
  true
}

///|
fn absorb_root_html_siblings(root : @dom.Node, html : @dom.Node) -> Unit {
  let original = root.children.copy()
  root.children.clear()
  let mut saw_html = false
  for child in original {
    if child.kind == Element && child.name == "html" {
      if saw_html {
        append_html_node_contents(html, child, html.children)
      } else {
        root.append_child(child)
        saw_html = true
      }
    } else {
      root.append_child(child)
    }
  }
}

///|
fn scaffold_existing_html_element(html : @dom.Node) -> Unit {
  let raw_original = html.children.copy()
  html.children.clear()
  let original : Array[@dom.Node] = []
  for child in raw_original {
    if child.kind == Element && child.name == "html" {
      append_html_node_contents(html, child, original)
    } else {
      original.push(child)
    }
  }
  let mut head : @dom.Node? = None
  let mut body : @dom.Node? = None
  let mut frameset : @dom.Node? = None
  let before_head_children : Array[@dom.Node] = []
  let between_head_body_children : Array[@dom.Node] = []
  let head_children : Array[@dom.Node] = []
  let body_children : Array[@dom.Node] = []
  let after_frameset_children : Array[@dom.Node] = []
  let mut body_started = false
  for child in original {
    if child.kind == Comment &&
      !body_started &&
      head is None &&
      head_children.is_empty() {
      before_head_children.push(child)
    } else if child.kind == Comment && !body_started && head is Some(_) {
      between_head_body_children.push(child)
    } else if child.kind == Element &&
      child.name == "head" &&
      head is None &&
      !body_started {
      head = Some(child)
    } else if child.kind == Element && child.name == "body" && body is None {
      body = Some(child)
      body_started = true
      append_body_node_contents(child, child, body_children)
    } else if child.kind == Element && child.name == "body" {
      append_body_node_contents(body.unwrap(), child, body_children)
      body_started = true
    } else if child.kind == Element &&
      child.name == "frameset" &&
      body is None &&
      frameset is None &&
      !body_started {
      frameset = Some(child)
      body_started = true
    } else if frameset is Some(_) && body is None {
      after_frameset_children.push(child)
    } else if child.kind == Element && child.name == "head" {
      let existing = child.children.copy()
      for grandchild in existing {
        body_children.push(grandchild)
      }
      body_started = true
    } else if child.kind == Element &&
      is_document_head_element_name(child.name) &&
      !body_started {
      head_children.push(child)
    } else if child.kind == Comment && !body_started {
      head_children.push(child)
    } else if is_whitespace_text_node(child) && !body_started {
      if head is Some(_) {
        between_head_body_children.push(child)
      } else if !head_children.is_empty() {
        head_children.push(child)
      }
    } else if child.kind == Text && !body_started {
      if head is None && !head_children.is_empty() {
        let (leading, rest) = split_text_node_leading_ascii_whitespace(child)
        match leading {
          Some(node) => head_children.push(node)
          None => ()
        }
        body_started = true
        body_children.push(rest.unwrap())
      } else if head is None {
        body_started = true
        body_children.push(
          text_node_without_leading_ascii_whitespace(child).unwrap(),
        )
      } else {
        body_started = true
        body_children.push(child)
      }
    } else {
      body_started = true
      body_children.push(child)
    }
  }
  let head_node = head.unwrap_or(@dom.element("head"))
  append_children_to(html, before_head_children)
  html.append_child(head_node)
  append_children_to(head_node, head_children)
  append_children_to(html, between_head_body_children)
  match frameset {
    Some(frameset_node) if body is None && body_children.is_empty() => {
      html.append_child(frameset_node)
      append_children_to(html, after_frameset_children)
    }
    _ => {
      let body_node = body.unwrap_or(@dom.element("body"))
      append_children_to(body_node, body_children)
      html.append_child(body_node)
    }
  }
}

///|
fn scaffold_document(root : @dom.Node) -> Unit {
  match document_html_element(root) {
    Some(html) => {
      absorb_root_html_siblings(root, html)
      scaffold_existing_html_element(html)
      return
    }
    None => ()
  }
  let original = root.children.copy()
  root.children.clear()
  let mut head : @dom.Node? = None
  let mut body : @dom.Node? = None
  let mut frameset : @dom.Node? = None
  let between_head_body_children : Array[@dom.Node] = []
  let head_children : Array[@dom.Node] = []
  let body_children : Array[@dom.Node] = []
  let after_frameset_children : Array[@dom.Node] = []
  let mut body_started = false
  for child in original {
    if child.kind == Doctype {
      root.append_child(child)
    } else if child.kind == Element &&
      child.name == "head" &&
      head is None &&
      !body_started {
      head = Some(child)
    } else if child.kind == Element && child.name == "body" && body is None {
      body = Some(child)
      body_started = true
      append_body_node_contents(child, child, body_children)
    } else if child.kind == Element && child.name == "body" {
      append_body_node_contents(body.unwrap(), child, body_children)
      body_started = true
    } else if child.kind == Element &&
      child.name == "frameset" &&
      body is None &&
      frameset is None &&
      !body_started {
      frameset = Some(child)
      body_started = true
    } else if frameset is Some(_) && body is None {
      after_frameset_children.push(child)
    } else if child.kind == Comment && !body_started && head is Some(_) {
      between_head_body_children.push(child)
    } else if child.kind == Comment && !body_started && head_children.is_empty() {
      root.append_child(child)
    } else if child.kind == Element && child.name == "head" {
      let existing = child.children.copy()
      for grandchild in existing {
        body_children.push(grandchild)
      }
      body_started = true
    } else if child.kind == Element &&
      is_document_head_element_name(child.name) &&
      !body_started {
      head_children.push(child)
    } else if child.kind == Comment && !body_started {
      head_children.push(child)
    } else if is_whitespace_text_node(child) && !body_started {
      if head is Some(_) {
        between_head_body_children.push(child)
      } else if !head_children.is_empty() {
        head_children.push(child)
      }
    } else if child.kind == Text && !body_started {
      if head is None && !head_children.is_empty() {
        let (leading, rest) = split_text_node_leading_ascii_whitespace(child)
        match leading {
          Some(node) => head_children.push(node)
          None => ()
        }
        body_started = true
        body_children.push(rest.unwrap())
      } else if head is None {
        body_started = true
        body_children.push(
          text_node_without_leading_ascii_whitespace(child).unwrap(),
        )
      } else {
        body_started = true
        body_children.push(child)
      }
    } else {
      body_started = true
      body_children.push(child)
    }
  }
  let html = @dom.element("html")
  let head_node = head.unwrap_or(@dom.element("head"))
  html.append_child(head_node)
  append_children_to(head_node, head_children)
  append_children_to(html, between_head_body_children)
  match frameset {
    Some(frameset_node) if body is None && body_children.is_empty() => {
      html.append_child(frameset_node)
      append_children_to(html, after_frameset_children)
    }
    _ => {
      let body_node = body.unwrap_or(@dom.element("body"))
      append_children_to(body_node, body_children)
      html.append_child(body_node)
    }
  }
  root.append_child(html)
}

///|
fn append_post_body_html_children(
  root : @dom.Node,
  children : Array[@dom.Node],
) -> Unit {
  if children.is_empty() {
    return
  }
  match document_html_element(root) {
    Some(html) => append_children_to(html, children)
    None => append_children_to(root, children)
  }
}
