///|
fn transform_remove_child_at(parent : @dom.Node, index : Int) -> Unit {
  let child = parent.children[index]
  ignore(parent.children.remove(index))
  if child.parent is Some(current_parent) &&
    physical_equal(parent, current_parent) {
    child.parent = None
  }
}

///|
fn transform_unwrap_child_at(parent : @dom.Node, index : Int) -> Int {
  let child = parent.children[index]
  ignore(parent.children.remove(index))
  if child.parent is Some(current_parent) &&
    physical_equal(parent, current_parent) {
    child.parent = None
  }
  let mut inserted = 0
  while !child.children.is_empty() {
    let grandchild = child.children[0]
    ignore(child.children.remove(0))
    grandchild.parent = Some(parent)
    parent.children.insert(index + inserted, grandchild)
    inserted += 1
  }
  inserted
}

///|
fn transform_escaped_end_tag_for(node : @dom.Node) -> String? {
  if @ser.is_void_element(node.name) {
    None
  } else {
    Some("</" + node.name + ">")
  }
}

///|
fn transform_push_unique_string(values : Array[String], value : String) -> Unit {
  if value != "" && !values.contains(value) {
    values.push(value)
  }
}

///|
fn transform_html_whitespace_char(ch : Char) -> Bool {
  match ch {
    '\u{0009}' | '\u{000A}' | '\u{000C}' | '\u{000D}' | '\u{0020}' => true
    _ => false
  }
}

///|
fn transform_push_html_whitespace_tokens(
  tokens : Array[String],
  value : StringView,
) -> Unit {
  let mut token_start = 0
  let mut pos = 0
  while pos < value.length() {
    let ch = value.get_char(pos).unwrap()
    if transform_html_whitespace_char(ch) {
      if token_start < pos {
        let token = value[token_start:pos]
        transform_push_unique_string(tokens, @syn.lower_ascii(token.trim()))
      }
      pos += ch.utf16_len()
      token_start = pos
    } else {
      pos += ch.utf16_len()
    }
  }
  if token_start < value.length() {
    let token = value[token_start:value.length()]
    transform_push_unique_string(tokens, @syn.lower_ascii(token.trim()))
  }
}
