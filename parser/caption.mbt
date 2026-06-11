///|
fn caption_start_closes_current_caption(name : StringView) -> Bool {
  match name {
    "caption"
    | "col"
    | "colgroup"
    | "table"
    | "tbody"
    | "td"
    | "tfoot"
    | "th"
    | "thead"
    | "tr" => true
    _ => false
  }
}

///|
fn Parser::close_current_caption_for_start(
  self : Parser,
  name : String,
  tag_close_pos : Int,
) -> Bool {
  if !caption_start_closes_current_caption(name) {
    return false
  }
  let table_index = self.last_open_table_index()
  let caption_index = self.last_stack_index_of("caption")
  if table_index < 0 {
    let template_index = self.last_open_template_index()
    if template_index < 0 || caption_index <= template_index {
      return false
    }
    self.error_at("unexpected-start-tag-implies-end-tag", tag_close_pos)
    self.close_open_caption_element()
    self.set_template_content_mode("table")
    self.enable_template_table_context_mode()
    return true
  }
  if caption_index <= table_index {
    return false
  }
  self.error_at("unexpected-start-tag-implies-end-tag", tag_close_pos)
  self.close_open_caption_element()
  true
}

///|
fn Parser::handle_caption_end_tag(
  self : Parser,
  name : String,
  start : Int,
) -> Bool {
  let table_index = self.last_open_table_index()
  let caption_index = self.last_stack_index_of("caption")
  if table_index < 0 {
    let template_index = self.last_open_template_index()
    if template_index < 0 || caption_index <= template_index {
      return false
    }
    match name {
      "caption" => {
        self.close_open_caption_element()
        self.set_template_content_mode("table")
        self.enable_template_table_context_mode()
        true
      }
      "tbody" | "tfoot" | "thead" => {
        self.error_at("unexpected-end-tag", start)
        true
      }
      _ => false
    }
  } else if caption_index <= table_index {
    return false
  } else {
    match name {
      "caption" => {
        self.close_open_caption_element()
        true
      }
      "tbody" | "tfoot" | "thead" => {
        self.error_at("unexpected-end-tag", start)
        true
      }
      "table" => {
        self.close_open_caption_element()
        false
      }
      _ => false
    }
  }
}

///|
fn fragment_context_caption_structural_start(name : StringView) -> Bool {
  match name {
    "caption"
    | "col"
    | "colgroup"
    | "table"
    | "tbody"
    | "td"
    | "tfoot"
    | "th"
    | "thead"
    | "tr" => true
    _ => false
  }
}

///|
fn Parser::handle_fragment_context_caption_start_tag(
  self : Parser,
  name : String,
  start : Int,
) -> Bool {
  if !self.fragment_context_caption ||
    !fragment_context_caption_structural_start(name) {
    return false
  }
  self.error_at("unexpected-start-tag-implies-end-tag", start)
  self.error_at("unexpected-end-tag", start)
  if name == "table" {
    self.fragment_context_caption = false
    return false
  }
  true
}
