///|
fn is_default_scope_terminator(name : StringView) -> Bool {
  match name {
    "applet"
    | "caption"
    | "html"
    | "marquee"
    | "object"
    | "table"
    | "td"
    | "template"
    | "th" => true
    _ => false
  }
}

///|
fn Parser::has_open_element_in_default_scope(
  self : Parser,
  name : String,
) -> Bool {
  let mut index = self.stack.length()
  while index > 0 {
    index -= 1
    let node = self.stack[index]
    if node.kind == Element {
      if node.name == name {
        return true
      }
      if is_default_scope_terminator(node.name) {
        return false
      }
    }
  }
  false
}

///|
fn is_list_item_scope_terminator(name : StringView) -> Bool {
  match name {
    "applet"
    | "caption"
    | "html"
    | "marquee"
    | "object"
    | "ol"
    | "table"
    | "td"
    | "template"
    | "th"
    | "ul" => true
    _ => false
  }
}

///|
fn Parser::close_open_list_item(self : Parser) -> Unit {
  let mut index = self.stack.length()
  while index > 0 {
    index -= 1
    let node = self.stack[index]
    if node.kind == Element {
      if node.name == "li" {
        ignore(self.close_open_element("li"))
        return
      }
      if is_list_item_scope_terminator(node.name) {
        return
      }
    }
  }
}

///|
fn is_definition_scope_terminator(name : StringView) -> Bool {
  match name {
    "applet"
    | "caption"
    | "dl"
    | "html"
    | "marquee"
    | "object"
    | "table"
    | "td"
    | "template"
    | "th" => true
    _ => false
  }
}

///|
fn Parser::close_open_definition_item_name(
  self : Parser,
  name : String,
) -> Unit {
  let mut index = self.stack.length()
  while index > 0 {
    index -= 1
    let node = self.stack[index]
    if node.kind == Element {
      if node.name == name {
        ignore(self.close_open_element(name))
        return
      }
      if is_definition_scope_terminator(node.name) {
        return
      }
    }
  }
}

///|
fn Parser::close_open_p_element(self : Parser) -> Unit {
  ignore(self.close_open_element("p"))
}

///|
fn Parser::close_open_definition_item(self : Parser, name : String) -> Unit {
  if name == "dd" {
    self.close_open_definition_item_name("dd")
    self.close_open_definition_item_name("dt")
  } else {
    self.close_open_definition_item_name("dt")
    self.close_open_definition_item_name("dd")
  }
}

///|
fn Parser::has_open_element(self : Parser, name : String) -> Bool {
  for node in self.stack {
    if node.kind == Element && node.name == name {
      return true
    }
  }
  false
}

///|
fn Parser::has_open_html_element(self : Parser, name : String) -> Bool {
  for node in self.stack {
    if node.kind == Element && node.name == name && node.ns is Some("html") {
      return true
    }
  }
  false
}
