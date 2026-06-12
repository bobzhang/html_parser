///|
fn Parser::insert_empty_frameset_child(
  self : Parser,
  name : StringView,
  attrs : Map[String, String?],
  start : Int,
) -> Unit {
  self
  .current_node()
  .append_child(self.node_with_origin(@dom.element(name, attrs~), start))
}

///|
fn detach_removed_frameset_replacement_child(
  parent : @dom.Node,
  child : @dom.Node,
) -> Unit {
  match child.parent {
    Some(current) if physical_equal(current, parent) => child.parent = None
    _ => ()
  }
}

///|
fn child_is_preserved_before_implicit_frameset_body(
  child : @dom.Node,
  saw_head_content : Bool,
) -> (Bool, Bool) {
  match child.kind {
    Doctype | Comment => (true, saw_head_content)
    Element if child.name == "head" || is_document_head_element_name(child.name) =>
      (true, true)
    Text if is_whitespace_text_node(child) =>
      (saw_head_content, saw_head_content)
    _ => (false, saw_head_content)
  }
}

///|
fn replace_implicit_body_children_for_frameset(parent : @dom.Node) -> Unit {
  let original = parent.children.copy()
  parent.children.clear()
  let mut saw_head_content = false
  let mut body_started = false
  for child in original {
    if body_started {
      detach_removed_frameset_replacement_child(parent, child)
      continue
    }
    let (preserve, next_saw_head_content) = child_is_preserved_before_implicit_frameset_body(
      child, saw_head_content,
    )
    saw_head_content = next_saw_head_content
    if preserve {
      parent.append_child(child)
    } else {
      body_started = true
      detach_removed_frameset_replacement_child(parent, child)
    }
  }
}

///|
fn Parser::frameset_replacement_parent(self : Parser) -> @dom.Node {
  match self.open_html_element() {
    Some(html) => html
    None => self.root
  }
}

///|
fn Parser::reset_stack_to_frameset_replacement_parent(
  self : Parser,
  parent : @dom.Node,
) -> Unit {
  self.clear_open_elements()
  self.push_open_element(self.root)
  if !physical_equal(parent, self.root) {
    self.push_open_element(parent)
  }
}

///|
fn Parser::prepare_document_frameset_replacement(self : Parser) -> Bool {
  let parent = self.frameset_replacement_parent()
  if node_has_direct_element_child(parent, "body") {
    return false
  }
  replace_implicit_body_children_for_frameset(parent)
  self.reset_stack_to_frameset_replacement_parent(parent)
  true
}
