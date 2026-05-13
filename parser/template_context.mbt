///|
fn Parser::last_open_template_index(self : Parser) -> Int {
  self.last_stack_index_of("template")
}

///|
fn Parser::in_template_content_without_inner_table(self : Parser) -> Bool {
  let template_index = self.last_open_template_index()
  template_index >= 0 && self.last_open_table_index() < template_index
}

///|
fn Parser::current_template_node(self : Parser) -> @dom.Node? {
  let template_index = self.last_open_template_index()
  if template_index >= 0 {
    Some(self.stack[template_index])
  } else {
    None
  }
}

///|
fn node_array_contains_identity(
  nodes : Array[@dom.Node],
  target : @dom.Node,
) -> Bool {
  for node in nodes {
    if physical_equal(node, target) {
      return true
    }
  }
  false
}

///|
fn remove_parser_node_identity(
  nodes : Array[@dom.Node],
  target : @dom.Node,
) -> Unit {
  let mut index = 0
  while index < nodes.length() {
    if physical_equal(nodes[index], target) {
      ignore(nodes.remove(index))
    } else {
      index += 1
    }
  }
}

///|
fn Parser::template_column_group_mode_active(self : Parser) -> Bool {
  match self.current_template_node() {
    Some(template) =>
      node_array_contains_identity(
        self.template_column_group_templates,
        template,
      )
    None => false
  }
}

///|
fn Parser::enable_template_column_group_mode(self : Parser) -> Unit {
  match self.current_template_node() {
    Some(template) =>
      if !node_array_contains_identity(
          self.template_column_group_templates,
          template,
        ) {
        self.template_column_group_templates.push(template)
      }
    None => ()
  }
}

///|
fn Parser::disable_current_template_column_group_mode(self : Parser) -> Unit {
  match self.current_template_node() {
    Some(template) =>
      remove_parser_node_identity(
        self.template_column_group_templates,
        template,
      )
    None => ()
  }
}

///|
fn Parser::disable_template_column_group_mode_for_node(
  self : Parser,
  template : @dom.Node,
) -> Unit {
  remove_parser_node_identity(self.template_column_group_templates, template)
}

///|
fn Parser::template_table_context_mode_active(self : Parser) -> Bool {
  if self.template_table_context_detached_mode &&
    self.last_open_template_index() < 0 {
    return true
  }
  match self.current_template_node() {
    Some(template) =>
      node_array_contains_identity(
        self.template_table_context_templates,
        template,
      )
    None => false
  }
}

///|
fn Parser::enable_template_table_context_mode(self : Parser) -> Unit {
  match self.current_template_node() {
    Some(template) =>
      if !node_array_contains_identity(
          self.template_table_context_templates,
          template,
        ) {
        self.template_table_context_templates.push(template)
      }
    None => self.template_table_context_detached_mode = true
  }
}

///|
fn Parser::disable_current_template_table_context_mode(self : Parser) -> Unit {
  match self.current_template_node() {
    Some(template) =>
      remove_parser_node_identity(
        self.template_table_context_templates,
        template,
      )
    None => self.template_table_context_detached_mode = false
  }
}

///|
fn Parser::disable_template_table_context_mode_for_node(
  self : Parser,
  template : @dom.Node,
) -> Unit {
  remove_parser_node_identity(self.template_table_context_templates, template)
}

///|
fn Parser::clear_detached_template_table_context_for_template_start(
  self : Parser,
  name : StringView,
) -> Unit {
  if name == "template" &&
    self.template_table_context_detached_mode &&
    self.last_open_template_index() < 0 {
    self.template_table_context_detached_mode = false
  }
}
