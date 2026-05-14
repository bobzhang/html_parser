///|
fn Parser::report_form_end_tag_table_voodoo(
  self : Parser,
  name : String,
  start : Int,
) -> Unit {
  if name == "form" && self.current_is_table_or_section_context() {
    self.error_at("unexpected-end-tag-implies-table-voodoo", start)
  }
}

///|
fn Parser::handle_form_end_tag(self : Parser, start : Int) -> Unit {
  match self.form_element {
    Some(node) => {
      let removed = self.remove_open_node(node)
      self.form_element = None
      if !removed {
        self.error_at("unexpected-end-tag", start)
      }
    }
    None => self.error_at("unexpected-end-tag", start)
  }
}
