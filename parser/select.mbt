///|
fn Parser::has_open_html_select(self : Parser) -> Bool {
  self.has_open_html_element("select")
}

///|
fn Parser::in_select_insertion_mode(self : Parser) -> Bool {
  self.select_insertion_mode || self.has_open_html_select()
}

///|
fn Parser::reset_select_insertion_mode(self : Parser) -> Unit {
  self.select_insertion_mode = self.has_open_element("select")
}

///|
fn select_start_tag_reprocesses_in_body(name : StringView) -> Bool {
  match name {
    "caption"
    | "col"
    | "colgroup"
    | "input"
    | "table"
    | "tbody"
    | "td"
    | "textarea"
    | "tfoot"
    | "th"
    | "thead"
    | "tr" => true
    _ => false
  }
}

///|
fn Parser::close_select_for_reprocessed_start_tag(
  self : Parser,
  name : StringView,
  start : Int,
) -> Bool {
  if !self.in_select_insertion_mode() ||
    !select_start_tag_reprocesses_in_body(name) {
    return false
  }
  self.error_at("unexpected-start-tag-in-select", start)
  ignore(self.close_open_element("select"))
  self.reset_select_insertion_mode()
  true
}

///|
fn Parser::pop_until_select_in_insertion_mode(self : Parser) -> Unit {
  while self.stack.length() > 1 {
    let node = self.stack.pop().unwrap()
    if node.kind == Element && node.name == "select" {
      break
    }
  }
}

///|
fn Parser::close_open_select_item(self : Parser, name : String) -> Unit {
  self.close_current_element_if_name("option")
  if name == "optgroup" && self.in_select_insertion_mode() {
    self.close_current_element_if_name("optgroup")
  }
}

///|
fn Parser::handle_select_end_tag(
  self : Parser,
  name : String,
  tag_close_pos : Int,
) -> Bool {
  match name {
    "optgroup" =>
      if self.in_select_insertion_mode() {
        ignore(self.pop_current_element_if_name("option"))
        if !self.pop_current_element_if_name("optgroup") {
          self.error_at("unexpected-end-tag-in-select", tag_close_pos)
        }
        true
      } else {
        false
      }
    "option" =>
      if self.in_select_insertion_mode() {
        if !self.pop_current_element_if_name("option") {
          self.error_at("unexpected-end-tag-in-select", tag_close_pos)
        }
        true
      } else {
        false
      }
    "select" =>
      if self.in_select_insertion_mode() {
        self.pop_until_select_in_insertion_mode()
        self.reset_select_insertion_mode()
        true
      } else {
        false
      }
    _ if select_common_element_start_reports_in_select(name) &&
      self.in_select_insertion_mode() => {
      self.error_at("unexpected-end-tag-in-select", tag_close_pos)
      self.close_open_select_common_element(name)
      true
    }
    "menuitem" =>
      if self.in_select_insertion_mode() {
        self.error_at("unexpected-end-tag", tag_close_pos)
        true
      } else {
        false
      }
    _ if self.in_select_insertion_mode() &&
      select_formatting_end_reports_in_select(name) &&
      self.formatting_end_tag_is_outside_current_select(name) => {
      self.error_at("unexpected-end-tag-in-select", tag_close_pos)
      true
    }
    _ => false
  }
}

///|
fn select_common_element_start_reports_in_select(name : StringView) -> Bool {
  match name {
    "button" | "datalist" | "div" | "p" | "selectedcontent" | "span" => true
    _ => false
  }
}

///|
fn select_formatting_end_reports_in_select(name : StringView) -> Bool {
  match name {
    "a"
    | "b"
    | "big"
    | "code"
    | "em"
    | "font"
    | "i"
    | "nobr"
    | "s"
    | "small"
    | "strike"
    | "strong"
    | "tt"
    | "u" => true
    _ => false
  }
}

///|
fn select_ignored_start_reports_in_select(name : StringView) -> Bool {
  match name {
    "aside" => true
    _ => false
  }
}

///|
fn Parser::formatting_end_tag_is_outside_current_select(
  self : Parser,
  name : String,
) -> Bool {
  let target_index = self.last_stack_index_of(name)
  if target_index < 0 {
    return true
  }
  let select_index = self.last_stack_index_of("select")
  select_index >= 0 && target_index < select_index
}

///|
fn Parser::close_open_select_common_element(
  self : Parser,
  name : String,
) -> Unit {
  let select_index = self.last_stack_index_of("select")
  let target_index = self.last_stack_index_of(name)
  if target_index > select_index {
    while self.stack.length() > target_index {
      ignore(self.stack.pop())
    }
  }
}

///|
fn Parser::handle_select_special_start_tag(
  self : Parser,
  name : String,
  attrs : Map[String, String?],
  self_closing : Bool,
  start : Int,
  tag_close_pos : Int,
) -> Bool {
  if !self.in_select_insertion_mode() {
    return false
  }
  if name == "plaintext" {
    self.error_at("unexpected-start-tag-in-select", tag_close_pos)
    let node = self.node_with_origin(@dom.element(name, attrs~), start)
    self.current_node().append_child(node)
    self.consume_special_element_content(node, name)
    ignore(self.close_open_element("select"))
    self.reset_select_insertion_mode()
    return true
  }
  if name == "hr" {
    self.error_at("unexpected-start-tag-in-select", tag_close_pos)
    ignore(self.pop_current_element_if_name("option"))
    ignore(self.pop_current_element_if_name("optgroup"))
    self.insert_element_without_push("hr", attrs, Some(start))
    return true
  }
  if name == "br" || name == "img" {
    self.error_at("unexpected-start-tag-in-select", tag_close_pos)
    self.insert_element_without_push(name, attrs, Some(start))
    return true
  }
  if name == "menuitem" {
    self.error_at("unexpected-start-tag-in-select", tag_close_pos)
    self.insert_element_maybe_push(name, attrs, !self_closing, Some(start))
    return true
  }
  if select_common_element_start_reports_in_select(name) {
    self.error_at("unexpected-start-tag-in-select", tag_close_pos)
    self.insert_element_maybe_push(name, attrs, !self_closing, Some(start))
    return true
  }
  if select_ignored_start_reports_in_select(name) {
    self.error_at("unexpected-start-tag-in-select", tag_close_pos)
    return true
  }
  false
}
