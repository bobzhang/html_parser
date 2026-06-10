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
fn scaffold_document(
  root : @dom.Node,
  foster_parented_texts : Array[@dom.Node],
  forced_body_nodes : Array[@dom.Node],
  after_body_comments : Array[@dom.Node],
  after_html_comments : Array[@dom.Node],
) -> Unit {
  match document_html_element(root) {
    Some(html) => {
      absorb_root_html_siblings(root, html, forced_body_nodes)
      scaffold_existing_html_element(
        html, foster_parented_texts, forced_body_nodes, after_body_comments,
      )
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
    } else if child.kind == Comment &&
      (
        nodes_contain(after_body_comments, child) ||
        nodes_contain(after_html_comments, child)
      ) {
      // Routed at parse time: re-attached after the body (or after the
      // html element) during assembly below.
      ()
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
      !body_started &&
      !nodes_contain(forced_body_nodes, child) {
      head_children.push(child)
    } else if child.kind == Comment && !body_started {
      head_children.push(child)
    } else if is_whitespace_text_node(child) &&
      !body_started &&
      !nodes_contain(forced_body_nodes, child) {
      if head is Some(_) {
        between_head_body_children.push(child)
      } else if !head_children.is_empty() {
        head_children.push(child)
      }
    } else if child.kind == Text && !body_started {
      if nodes_contain(foster_parented_texts, child) ||
        nodes_contain(forced_body_nodes, child) {
        // Foster-parented table text was produced after body content
        // started (a table is open); keep it verbatim, including leading
        // whitespace.
        body_started = true
        body_children.push(child)
      } else if head is None && !head_children.is_empty() {
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
  append_children_to(html, after_body_comments)
  root.append_child(html)
  append_children_to(root, after_html_comments)
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

///|
fn nodes_contain(nodes : Array[@dom.Node], node : @dom.Node) -> Bool {
  for candidate in nodes {
    if physical_equal(candidate, node) {
      return true
    }
  }
  false
}
