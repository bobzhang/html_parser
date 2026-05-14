///|
fn Parser::uses_document_frameset_rules(self : Parser) -> Bool {
  !self.is_fragment_parser() || self.fragment_context_html
}

///|
fn Parser::handle_document_frameset_end_tag(
  self : Parser,
  name : String,
  tag_close_pos : Int,
) -> Bool {
  if self.is_fragment_parser() && !self.fragment_context_html {
    return false
  }
  if self.after_frameset {
    if name == "html" {
      ()
    } else if name == "frameset" {
      self.error_at("unexpected-token-after-frameset", tag_close_pos)
    } else {
      self.error_at("unexpected-token-after-frameset", tag_close_pos)
      self.error_at("unexpected-token-in-frameset", tag_close_pos)
    }
    return true
  }
  if self.detached_frameset_mode {
    if name == "frameset" {
      self.error_at("unexpected-end-tag", tag_close_pos)
    } else {
      self.error_at("unexpected-token-in-frameset", tag_close_pos)
    }
    return true
  }
  if !self.has_open_element("frameset") {
    return false
  }
  if self.frameset_reprocesses_in_body_mode {
    if name != "frameset" {
      return false
    }
    ignore(self.close_open_element("frameset"))
    if !self.has_open_element("frameset") {
      self.frameset_reprocesses_in_body_mode = false
    }
    return true
  }
  if name == "frameset" {
    ignore(self.close_open_element("frameset"))
    if !self.has_open_element("frameset") {
      self.after_frameset = true
    }
  } else {
    self.error_at("unexpected-token-in-frameset", tag_close_pos)
  }
  true
}

///|
fn document_body_start_tag_preserves_frameset_ok(
  name : StringView,
  attrs : Map[String, String?],
) -> Bool {
  match name {
    "a"
    | "address"
    | "article"
    | "aside"
    | "b"
    | "big"
    | "blockquote"
    | "center"
    | "code"
    | "details"
    | "dialog"
    | "dir"
    | "div"
    | "dl"
    | "em"
    | "fieldset"
    | "figcaption"
    | "figure"
    | "font"
    | "footer"
    | "header"
    | "hgroup"
    | "i"
    | "main"
    | "math"
    | "menu"
    | "nav"
    | "nobr"
    | "ol"
    | "optgroup"
    | "option"
    | "p"
    | "param"
    | "rb"
    | "rp"
    | "rt"
    | "rtc"
    | "s"
    | "search"
    | "section"
    | "small"
    | "source"
    | "strike"
    | "strong"
    | "summary"
    | "svg"
    | "track"
    | "tt"
    | "u"
    | "ul" => true
    "input" => input_attrs_type_is_hidden(attrs)
    _ => false
  }
}

///|
fn Parser::document_start_tag_preserves_frameset_ok(
  self : Parser,
  name : StringView,
  attrs : Map[String, String?],
) -> Bool {
  (self.is_fragment_parser() && !self.fragment_context_html) ||
  name == "html" ||
  name == "head" ||
  name == "frameset" ||
  is_document_head_element_name(name) ||
  document_body_start_tag_preserves_frameset_ok(name, attrs)
}

///|
fn Parser::handle_document_frameset_start_tag(
  self : Parser,
  name : String,
  attrs : Map[String, String?],
  _self_closing : Bool,
  start : Int,
  tag_close_pos : Int,
) -> Bool {
  if self.is_fragment_parser() && !self.fragment_context_html {
    return false
  }
  if self.after_frameset {
    if name == "noframes" {
      return false
    }
    if name == "html" {
      self.after_frameset = false
      self.frameset_ok = false
      self.error_at("unexpected-start-tag", tag_close_pos)
      self.merge_document_html_attrs(attrs)
      self.repeated_document_html_shell = true
      return true
    }
    self.error_at("unexpected-token-after-frameset", tag_close_pos)
    self.after_frameset = false
    self.detached_frameset_mode = true
  }
  if self.frameset_reprocesses_in_body_mode && self.has_open_element("frameset") {
    match name {
      "html" => {
        self.error_at("unexpected-start-tag", tag_close_pos)
        self.merge_document_html_attrs(attrs)
        true
      }
      "frame" | "frameset" => {
        self.error_at("unexpected-start-tag-ignored", tag_close_pos)
        true
      }
      _ => false
    }
  } else if self.has_open_element("frameset") || self.detached_frameset_mode {
    match name {
      "frameset" => {
        self.insert_element_maybe_push(name, attrs, true, start~)
        self.detached_frameset_mode = false
        true
      }
      "frame" => {
        self.insert_empty_frameset_child(name, attrs, start)
        true
      }
      "noframes" => false
      "html" =>
        if self.detached_frameset_mode {
          self.detached_frameset_mode = false
          self.frameset_ok = false
          self.error_at("unexpected-start-tag", tag_close_pos)
          self.merge_document_html_attrs(attrs)
          self.repeated_document_html_shell = true
          true
        } else {
          self.error_at("unexpected-start-tag", tag_close_pos)
          self.merge_document_html_attrs(attrs)
          self.frameset_reprocesses_in_body_mode = true
          true
        }
      _ => {
        self.error_at("unexpected-token-in-frameset", tag_close_pos)
        true
      }
    }
  } else if name == "frameset" {
    if !self.frameset_ok {
      self.error_at("unexpected-start-tag-ignored", tag_close_pos)
      true
    } else if !self.prepare_document_frameset_replacement() {
      self.error_at("unexpected-start-tag-ignored", tag_close_pos)
      true
    } else {
      self.insert_element_maybe_push(name, attrs, true, start~)
      true
    }
  } else {
    false
  }
}
