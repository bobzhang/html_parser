///|
fn Parser::error_at(self : Parser, code : String, pos : Int) -> Unit {
  self.errors.push(self.make_error_at(code, pos))
}

///|
fn Parser::make_error_at(
  self : Parser,
  code : String,
  pos : Int,
) -> @core.ParseError {
  let (line, column) = line_col_at(self.input, pos)
  ParseError(code, line~, column~, category=@core.parser_error_category(code))
}

///|
fn Parser::report_current_noncharacter(self : Parser) -> Unit {
  match self.current() {
    Some(ch) if is_xml_noncharacter(ch) =>
      self.error_at("noncharacter-in-input-stream", self.pos)
    _ => ()
  }
}

///|
fn view_starts_with_at(
  input : StringView,
  pos : Int,
  prefix : StringView,
) -> Bool {
  @syn.view_starts_with_at(input, pos, prefix)
}

///|
fn find_markup_close(input : StringView, start : Int) -> Int? {
  let mut pos = start
  while pos < input.length() {
    match input.get_char(pos) {
      Some('>') => return Some(pos)
      Some(ch) => pos += ch.utf16_len()
      None => break
    }
  }
  None
}

///|
fn find_comment_close(input : StringView, start : Int) -> Int? {
  let scan = @tok.scan_comment_data(input, start + "<!--".length())
  if scan.eof {
    None
  } else {
    Some(scan.end)
  }
}

///|
fn Parser::report_initial_doctype_error(self : Parser) -> @core.ParseError? {
  let mut pos = 0
  let mut defer_doctype = false
  while pos < self.input.length() {
    let ch = self.input.get_char(pos).unwrap()
    match ch {
      _ if ch.is_ascii_whitespace() => pos += ch.utf16_len()
      '<' if view_starts_with_at(self.input, pos, "<!--") =>
        match find_comment_close(self.input, pos) {
          Some(end) => pos = end
          None =>
            return Some(self.make_error_at_eof("expected-doctype-but-got-eof"))
        }
      '<' if starts_with_case_insensitive(self.input, pos, "<!doctype") =>
        return None
      '<' if view_starts_with_at(self.input, pos, "<!") => {
        defer_doctype = true
        match find_markup_close(self.input, pos) {
          Some(close) => pos = close + 1
          None =>
            return Some(self.make_error_at_eof("expected-doctype-but-got-eof"))
        }
      }
      '<' if view_starts_with_at(self.input, pos, "</") =>
        match find_markup_close(self.input, pos) {
          Some(close) => {
            let malformed = match self.input.get_char(pos + 2) {
              Some(ch) if ch == '>' || !@tok.is_tag_name_start(ch) => true
              _ => false
            }
            if malformed {
              defer_doctype = true
              pos = close + 1
            } else {
              let error = self.make_error_at(
                "expected-doctype-but-got-end-tag", close,
              )
              if defer_doctype {
                return Some(error)
              }
              self.errors.push(error)
              return None
            }
          }
          None =>
            return Some(self.make_error_at_eof("expected-doctype-but-got-eof"))
        }
      '<' =>
        match self.input.get_char(pos + 1) {
          Some(ch) if @tok.is_tag_name_start(ch) =>
            match find_markup_close(self.input, pos) {
              Some(close) => {
                let error = self.make_error_at(
                  "expected-doctype-but-got-start-tag", close,
                )
                if defer_doctype {
                  return Some(error)
                }
                self.errors.push(error)
                return None
              }
              None =>
                return Some(
                  self.make_error_at_eof("expected-doctype-but-got-eof"),
                )
            }
          Some('?') => {
            defer_doctype = true
            match find_markup_close(self.input, pos) {
              Some(close) => pos = close + 1
              None =>
                return Some(
                  self.make_error_at_eof("expected-doctype-but-got-eof"),
                )
            }
          }
          _ => {
            let error = self.make_error_at(
              "expected-doctype-but-got-chars", pos,
            )
            return Some(error)
          }
        }
      _ => {
        let error = self.make_error_at("expected-doctype-but-got-chars", pos)
        if defer_doctype {
          return Some(error)
        }
        self.errors.push(error)
        return None
      }
    }
  }
  let error = self.make_error_at_eof("expected-doctype-but-got-eof")
  if defer_doctype {
    Some(error)
  } else {
    self.errors.push(error)
    None
  }
}

///|
fn Parser::flush_deferred_initial_doctype_error(self : Parser) -> Unit {
  match self.deferred_initial_doctype_error {
    Some(error) => {
      self.errors.push(error)
      self.deferred_initial_doctype_error = None
    }
    None => ()
  }
}

///|
fn Parser::eof_error_pos(self : Parser) -> Int {
  eof_error_pos(self.input)
}

///|
fn eof_error_pos(input : StringView) -> Int {
  @syn.eof_error_pos(input)
}

///|
fn Parser::error_at_eof(self : Parser, code : String) -> Unit {
  self.errors.push(self.make_error_at_eof(code))
}

///|
fn Parser::make_error_at_eof(self : Parser, code : String) -> @core.ParseError {
  if self.input.is_empty() {
    ParseError(
      code,
      line=1,
      column=0,
      category=@core.parser_error_category(code),
    )
  } else {
    self.make_error_at(code, self.eof_error_pos())
  }
}

///|
fn eof_allows_unclosed_element(name : StringView) -> Bool {
  match name {
    "body"
    | "dd"
    | "dt"
    | "head"
    | "html"
    | "li"
    | "optgroup"
    | "option"
    | "p"
    | "rb"
    | "rp"
    | "rt"
    | "rtc"
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
fn Parser::report_eof_tree_errors(self : Parser) -> Unit {
  let table_index = self.last_open_table_index()
  let caption_index = self.last_stack_index_of("caption")
  if table_index >= 0 && caption_index > table_index {
    self.error_at("expected-closing-tag-but-got-eof", self.eof_error_pos())
    return
  }
  if table_index >= 0 {
    self.error_at("eof-in-table", self.eof_error_pos())
    return
  }
  for node in self.stack {
    if node.kind == Element && !eof_allows_unclosed_element(node.name) {
      self.error_at("expected-closing-tag-but-got-eof", self.eof_error_pos())
      return
    }
  }
}
