///|
fn push_children_reverse(stack : Array[@dom.Node], node : @dom.Node) -> Unit {
  let mut index = node.children.length()
  while index > 0 {
    index -= 1
    stack.push(node.children[index])
  }
}

///|
fn find_elements_by_name(root : @dom.Node, name : String) -> Array[@dom.Node] {
  let found : Array[@dom.Node] = []
  let stack : Array[@dom.Node] = [root]
  while !stack.is_empty() {
    let node = stack.pop().unwrap()
    if node.kind == Element && node.name == name {
      found.push(node)
    }
    push_children_reverse(stack, node)
  }
  found
}

///|
fn find_first_element_by_name(root : @dom.Node, name : String) -> @dom.Node? {
  let stack : Array[@dom.Node] = [root]
  while !stack.is_empty() {
    let node = stack.pop().unwrap()
    if node.kind == Element && node.name == name {
      return Some(node)
    }
    push_children_reverse(stack, node)
  }
  None
}

///|
fn selected_option_in(options : Array[@dom.Node]) -> @dom.Node? {
  for option in options {
    if option.attrs.contains("selected") {
      return Some(option)
    }
  }
  options.get(0)
}

///|
fn append_cloned_children(source : @dom.Node, target : @dom.Node) -> Unit {
  for child in source.children {
    target.append_child(child.clone_node(deep=true))
  }
}

///|
fn populate_selectedcontent(root : @dom.Node) -> Unit {
  let selects = find_elements_by_name(root, "select")
  for select in selects {
    match find_first_element_by_name(select, "selectedcontent") {
      Some(selectedcontent) => {
        let options = find_elements_by_name(select, "option")
        match selected_option_in(options) {
          Some(option) => append_cloned_children(option, selectedcontent)
          None => ()
        }
      }
      None => ()
    }
  }
}
